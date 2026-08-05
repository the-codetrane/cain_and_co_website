namespace :photos do
  IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .gif .webp .avif].freeze

  desc "Import photos from DigitalOcean Spaces into the Photo model (all imported as unpublished)"
  task import: :environment do
    require "aws-sdk-s3"

    creds = Rails.application.credentials.dig(:digitalocean)
    unless creds&.dig(:spaces_key) && creds&.dig(:spaces_secret)
      abort "\nMissing DigitalOcean Spaces credentials.\nRun: bin/rails credentials:edit\n\nAdd:\n  digitalocean:\n    spaces_key: ...\n    spaces_secret: ...\n"
    end

    client = Aws::S3::Client.new(
      access_key_id:     creds[:spaces_key],
      secret_access_key: creds[:spaces_secret],
      endpoint:          "https://sfo3.digitaloceanspaces.com",
      region:            "sfo3"
    )
    bucket = "ig-mcp-images"

    puts "\nConnecting to #{bucket}..."

    # List top-level prefixes ("directories") and any root-level images
    root_resp = client.list_objects_v2(bucket: bucket, delimiter: "/")
    prefixes   = root_resp.common_prefixes.map(&:prefix)
    root_keys  = root_resp.contents
                          .map(&:key)
                          .select { |k| image_file?(k) }

    if prefixes.empty? && root_keys.empty?
      abort "No directories or images found in #{bucket}."
    end

    # ── Directory selection ────────────────────────────────────────────────
    selected_prefixes = []
    include_root      = false

    if prefixes.any?
      puts "\nFound #{prefixes.size} director#{prefixes.size == 1 ? 'y' : 'ies'}:\n\n"
      prefixes.each_with_index { |p, i| puts "  #{i + 1}. #{p}" }
      puts "  0. (root — #{root_keys.size} image(s) at top level)" if root_keys.any?
      puts

      print "Enter numbers to import (comma-separated, or 'all'): "
      input = $stdin.gets.chomp.strip

      if input.downcase == "all"
        selected_prefixes = prefixes
        include_root      = root_keys.any?
      else
        nums = input.split(",").map { |n| n.strip.to_i }
        include_root      = nums.delete(0) ? root_keys.any? : false
        selected_prefixes = prefixes.values_at(*nums.map { |n| n - 1 }).compact
      end
    else
      puts "No subdirectories found — importing #{root_keys.size} root-level image(s)."
      include_root = true
    end

    # ── Collect all object keys to import ─────────────────────────────────
    keys_to_import = []
    keys_to_import += root_keys if include_root

    selected_prefixes.each do |prefix|
      token = nil
      loop do
        resp = client.list_objects_v2(bucket: bucket, prefix: prefix, continuation_token: token)
        resp.contents.each { |obj| keys_to_import << obj.key if image_file?(obj.key) }
        break unless resp.is_truncated
        token = resp.next_continuation_token
      end
    end

    if keys_to_import.empty?
      abort "\nNo image files found in the selected location(s)."
    end

    puts "\n#{keys_to_import.size} image(s) to import. Starting...\n\n"

    imported = 0
    skipped  = 0
    failed   = 0

    keys_to_import.each do |key|
      filename = File.basename(key)
      ext      = File.extname(filename)
      print "  #{key} ... "

      begin
        Tempfile.create([ File.basename(filename, ext), ext ]) do |tmp|
          tmp.binmode
          client.get_object(bucket: bucket, key: key) { |chunk| tmp.write(chunk) }
          tmp.rewind

          photo = Photo.new(published: false)
          photo.image.attach(io: tmp, filename: filename)

          if photo.save
            puts "done (id: #{photo.id})"
            imported += 1
          else
            puts "skipped — #{photo.errors.full_messages.join(', ')}"
            skipped += 1
          end
        end
      rescue Aws::S3::Errors::ServiceError => e
        puts "S3 error — #{e.message}"
        failed += 1
      rescue => e
        puts "error — #{e.message}"
        failed += 1
      end
    end

    puts
    puts "─" * 50
    puts "  Imported : #{imported}"
    puts "  Skipped  : #{skipped}"
    puts "  Failed   : #{failed}"
    puts "─" * 50
    puts "\nAll imported photos are unpublished."
    puts "Review and publish at: /admin/photos"
    puts
  end

  desc "Re-point Photo blob keys at their current DigitalOcean Spaces object keys (dry run unless APPLY=1)"
  task rekey: :environment do
    require "aws-sdk-s3"

    apply = ENV["APPLY"] == "1"
    bucket = "ig-mcp-images"

    creds = Rails.application.credentials.dig(:digitalocean)
    unless creds&.dig(:spaces_key) && creds&.dig(:spaces_secret)
      abort "\nMissing DigitalOcean Spaces credentials. Run: bin/rails credentials:edit\n"
    end

    client = Aws::S3::Client.new(
      access_key_id:     creds[:spaces_key],
      secret_access_key: creds[:spaces_secret],
      endpoint:          "https://sfo3.digitaloceanspaces.com",
      region:            "sfo3"
    )

    puts "\nListing #{bucket}..."
    objects = []
    token   = nil
    loop do
      resp = client.list_objects_v2(bucket: bucket, continuation_token: token)
      resp.contents.each { |o| objects << [ o.key, o.size ] unless o.key.end_with?("/") }
      break unless resp.is_truncated
      token = resp.next_continuation_token
    end
    puts "#{objects.size} object(s) found.\n\n"

    # Active Storage sanitizes filenames on upload (`:` becomes `-`, among
    # others), so match on the sanitized basename rather than the raw one.
    by_filename = objects.group_by { |key, _size| ActiveStorage::Filename.new(File.basename(key)).sanitized }
    live_keys   = objects.map(&:first).to_set

    already     = 0
    unmatched   = []
    by_new_key  = Hash.new { |h, k| h[k] = [] }

    Photo.includes(image_attachment: :blob).find_each do |photo|
      blob = photo.image_attachment&.blob
      next unless blob

      if live_keys.include?(blob.key)
        already += 1
        next
      end

      candidates = by_filename[blob.filename.to_s] || []
      candidates = candidates.select { |_key, size| size == blob.byte_size } if candidates.size > 1

      if candidates.size == 1
        by_new_key[candidates.first.first] << photo
      else
        unmatched << [ photo.id, blob.filename.to_s, candidates.size ]
      end
    end

    # `active_storage_blobs.key` is uniquely indexed, so when an earlier
    # `photos:import` run imported the same object twice only one record can
    # own the key. Keep the published record, then the oldest, and leave the
    # rest alone for a human to review.
    rekeyed    = 0
    duplicates = []

    by_new_key.each do |new_key, photos|
      winner, *losers = photos.sort_by { |p| [ p.published? ? 0 : 1, p.id ] }

      puts "  photo #{winner.id}: #{winner.image_attachment.blob.key} -> #{new_key}"
      winner.image_attachment.blob.update_column(:key, new_key) if apply
      rekeyed += 1

      losers.each { |p| duplicates << [ p.id, p.published?, new_key ] }
    end

    puts
    puts "─" * 60
    puts "  Already correct     : #{already}"
    puts "  #{apply ? 'Re-keyed           ' : 'Would re-key       '} : #{rekeyed}"
    puts "  Duplicate records   : #{duplicates.size}"
    puts "  Unmatched           : #{unmatched.size}"
    puts "─" * 60

    if duplicates.any?
      puts "\nDuplicate photos (same Spaces object as another record — left untouched):"
      duplicates.each { |id, published, key| puts "  photo #{id}#{published ? ' [published]' : ''} — duplicate of #{key}" }
      puts "\nReview and delete these at /admin/photos, or run:"
      puts "  bin/rails photos:rekey APPLY=1 PRUNE_DUPLICATES=1"
    end

    unmatched.each { |id, filename, count| puts "  photo #{id}: #{filename} — #{count} candidate(s) in Spaces" }

    if ENV["PRUNE_DUPLICATES"] == "1" && duplicates.any?
      if apply
        # Only destroy records whose blob still points at a key that no longer
        # exists in Spaces — never one that owns a live object.
        prunable = Photo.where(id: duplicates.map(&:first)).includes(image_attachment: :blob)
                        .reject { |p| live_keys.include?(p.image_attachment&.blob&.key) }
        prunable.each(&:destroy)
        puts "\nPruned #{prunable.size} duplicate photo record(s)."
      else
        puts "\nPRUNE_DUPLICATES is set but APPLY is not — nothing was deleted."
      end
    end

    puts "\nDry run — re-run with APPLY=1 to write the new keys.\n" unless apply
    puts
  end

  def image_file?(key)
    IMAGE_EXTENSIONS.include?(File.extname(key).downcase)
  end
end

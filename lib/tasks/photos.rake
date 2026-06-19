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

  def image_file?(key)
    IMAGE_EXTENSIONS.include?(File.extname(key).downcase)
  end
end

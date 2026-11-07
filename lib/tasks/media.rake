namespace :media do
  desc "Generate every preprocessed image variant that doesn't exist yet"
  task variants: :environment do
    generated = 0
    failed    = 0

    generate = lambda do |attachment, names|
      names.each do |name|
        attachment.variant(name).processed
        generated += 1
      rescue StandardError => e # one bad image shouldn't stop the rest
        failed += 1
        puts "  blob #{attachment.blob_id} #{name}: #{e.class} #{e.message}"
      end
    end

    Product.with_attached_images.find_each do |product|
      product.images.each { |image| generate.call(image, Product::IMAGE_VARIANTS) if image.variable? }
    end

    Photo.with_attached_image.find_each do |photo|
      generate.call(photo.image, %i[ admin_grid ]) if photo.image.attached? && photo.image.variable?
    end

    Photo.published.with_attached_image.find_each do |photo|
      generate.call(photo.image, %i[ carousel ]) if photo.image.attached? && photo.image.variable?
    end

    Photo.epk.with_attached_image.find_each do |photo|
      generate.call(photo.image, %i[ press_lead press_thumb ]) if photo.image.attached? && photo.image.variable?
    end

    puts "Checked #{generated} variant(s), #{failed} failed."
  end

  desc "Add Cache-Control to objects uploaded before storage.yml set it (dry run unless APPLY=1)"
  task cache_headers: :environment do
    require "aws-sdk-s3"

    service = ActiveStorage::Blob.service
    abort "Active Storage isn't on S3 in this environment." unless service.respond_to?(:bucket)

    apply = ENV["APPLY"] == "1"
    blobs = ActiveStorage::Blob.where(service_name: service.name.to_s)
    blobs = blobs.limit(ENV["LIMIT"].to_i) if ENV["LIMIT"]

    result = MediaCacheHeaderBackfill.new(
      client: service.client.client,
      bucket: service.bucket.name,
      cache_control: service.upload_options.fetch(:cache_control),
      blobs: blobs,
      apply: apply,
      log: method(:puts)
    ).call

    puts "Already current: #{result.current}"
    puts "#{apply ? 'Updated' : 'Would update'}: #{result.updated}"
    puts "Failed: #{result.failed}"
    puts "Dry run. Re-run with APPLY=1 to write the headers." unless apply
  end
end

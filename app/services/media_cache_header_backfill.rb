# Stamps the Cache-Control from config/storage.yml onto objects uploaded before that
# setting existed. S3 can't edit metadata in place, so each object is copied onto itself.
#
# The bucket is shared with other apps, so this only ever visits keys owned by a blob.
class MediaCacheHeaderBackfill
  Result = Struct.new(:current, :updated, :failed, keyword_init: true)

  # A self-copy resets anything not restated, so the ACL, content type, disposition and
  # custom metadata all have to be sent again. Dropping the ACL would make the object
  # private and break the image.
  ACL = "public-read"

  def initialize(client:, bucket:, cache_control:, blobs: ActiveStorage::Blob.all, apply: false, log: ->(_line) { })
    @client = client
    @bucket = bucket
    @cache_control = cache_control
    @blobs = blobs
    @apply = apply
    @log = log
  end

  def call
    result = Result.new(current: 0, updated: 0, failed: 0)

    @blobs.find_each do |blob|
      head = @client.head_object(bucket: @bucket, key: blob.key)

      if head.cache_control == @cache_control
        result.current += 1
      else
        rewrite(blob.key, head) if @apply
        result.updated += 1
      end
    rescue Aws::S3::Errors::ServiceError => e
      result.failed += 1
      @log.call("  #{blob.key}: #{e.class.name.demodulize} #{e.message}")
    end

    result
  end

  private

  def rewrite(key, head)
    @client.copy_object(
      bucket: @bucket,
      key: key,
      copy_source: "#{@bucket}/#{key.split("/").map { |part| ERB::Util.url_encode(part) }.join("/")}",
      metadata_directive: "REPLACE",
      acl: ACL,
      cache_control: @cache_control,
      content_type: head.content_type,
      content_disposition: head.content_disposition,
      metadata: head.metadata
    )
  end
end

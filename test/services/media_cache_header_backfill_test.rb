require "test_helper"
require "aws-sdk-s3"

class MediaCacheHeaderBackfillTest < ActiveSupport::TestCase
  CACHE_CONTROL = "public, max-age=31536000, immutable"

  setup do
    @blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("test_photo.gif").open, filename: "photo.gif", content_type: "image/gif",
      key: "Big Guy's Shoot/photo #{SecureRandom.hex(4)}.gif"
    )
    @client = Aws::S3::Client.new(stub_responses: true, region: "sfo3", credentials: Aws::Credentials.new("a", "b"))
  end

  test "a dry run writes nothing" do
    stub_head(cache_control: nil)

    result = backfill(apply: false).call

    assert_equal 1, result.updated
    assert_empty copies
  end

  test "restates the ACL and metadata a self-copy would otherwise drop" do
    stub_head(cache_control: nil, content_type: "image/gif", content_disposition: "inline", metadata: { "a" => "b" })

    backfill(apply: true).call

    params = copies.sole
    assert_equal "public-read", params[:acl]
    assert_equal "REPLACE", params[:metadata_directive]
    assert_equal CACHE_CONTROL, params[:cache_control]
    assert_equal "image/gif", params[:content_type]
    assert_equal "inline", params[:content_disposition]
    assert_equal({ "a" => "b" }, params[:metadata])
  end

  test "encodes the copy source, keeping folder separators" do
    stub_head(cache_control: nil)

    backfill(apply: true).call

    source = copies.sole[:copy_source]
    assert source.start_with?("bucket/Big%20Guy%27s%20Shoot/photo%20")
  end

  test "skips objects that already have the header" do
    stub_head(cache_control: CACHE_CONTROL)

    result = backfill(apply: true).call

    assert_equal 1, result.current
    assert_empty copies
  end

  test "counts a missing object and carries on" do
    @client.stub_responses(:head_object, "NotFound")
    lines = []

    result = backfill(apply: true, log: lines.method(:<<)).call

    assert_equal 1, result.failed
    assert_match @blob.key, lines.sole
  end

  private

  def backfill(**options)
    MediaCacheHeaderBackfill.new(client: @client, bucket: "bucket", cache_control: CACHE_CONTROL,
                                 blobs: ActiveStorage::Blob.where(id: @blob.id), **options)
  end

  def stub_head(**attributes)
    @client.stub_responses(:head_object, attributes)
  end

  def copies
    @client.api_requests.select { |request| request[:operation_name] == :copy_object }.pluck(:params)
  end
end

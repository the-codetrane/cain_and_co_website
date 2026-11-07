require "test_helper"

class ActiveStorageDefaultFolderTest < ActiveSupport::TestCase
  test "a blob without its own key is stored in the default folder" do
    blob = upload

    assert_match %r{\APublicMisc/[a-z0-9]{28}\z}, blob.key
    assert blob.service.exist?(blob.key)
  end

  test "a blob given its own key keeps it" do
    assert_equal "Gig Flyers/flyer", upload(key: "Gig Flyers/flyer").key
  end

  test "generated variants are stored in the default folder" do
    variant = upload.variant(resize_to_limit: [ 10, 10 ]).processed

    assert_match %r{\APublicMisc/}, variant.image.blob.key
  end

  private

  def upload(**options)
    ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("test_photo.gif").open, filename: "test_photo.gif", content_type: "image/gif", **options
    )
  end
end

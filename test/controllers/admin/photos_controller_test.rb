require "test_helper"

class Admin::PhotosControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  def photo_file
    fixture_file_upload("test_photo.gif", "image/gif")
  end

  # ── Auth ─────────────────────────────────────────────────────────────────

  test "all actions require authentication" do
    reset!
    get admin_photos_path
    assert_redirected_to new_session_path
  end

  # ── index ─────────────────────────────────────────────────────────────────

  test "index renders successfully and lists all photos" do
    get admin_photos_path
    assert_response :success
    assert_match photos(:outdoor_shoot).caption, response.body
    assert_match photos(:hidden_draft).caption,  response.body
    assert_match "Hidden", response.body
  end

  test "index filters to visible photos only" do
    get admin_photos_path(filter: "visible")
    assert_response :success
    assert_match photos(:outdoor_shoot).caption, response.body
    assert_no_match photos(:hidden_draft).caption, response.body
  end

  test "index filters to hidden photos only" do
    get admin_photos_path(filter: "hidden")
    assert_response :success
    assert_no_match photos(:outdoor_shoot).caption, response.body
    assert_match photos(:hidden_draft).caption, response.body
  end

  # ── new ───────────────────────────────────────────────────────────────────

  test "new renders the upload form" do
    get new_admin_photo_path
    assert_response :success
  end

  # ── create ────────────────────────────────────────────────────────────────

  test "create saves a new photo and redirects to index" do
    assert_difference -> { Photo.count }, 1 do
      post admin_photos_path, params: {
        photo: { image: photo_file, caption: "New shot", published: "0" }
      }
    end
    assert_redirected_to admin_photos_path
    assert_equal "Photo added.", flash[:notice]
  end

  test "create re-renders new when no image is attached" do
    assert_no_difference -> { Photo.count } do
      post admin_photos_path, params: { photo: { caption: "Missing image" } }
    end
    assert_response :unprocessable_entity
  end

  test "create defaults to unpublished false when not specified" do
    post admin_photos_path, params: { photo: { image: photo_file } }
    assert Photo.last.published?
  end

  # ── edit / update ─────────────────────────────────────────────────────────

  test "edit renders the form" do
    get edit_admin_photo_path(photos(:outdoor_shoot))
    assert_response :success
  end

  test "update changes caption and redirects to index" do
    patch admin_photo_path(photos(:outdoor_shoot)), params: {
      photo: { caption: "Updated caption" }
    }
    assert_redirected_to admin_photos_path
    assert_equal "Photo updated.", flash[:notice]
    assert_equal "Updated caption", photos(:outdoor_shoot).reload.caption
  end

  test "update can flag a photo for the EPK" do
    patch admin_photo_path(photos(:outdoor_shoot)), params: { photo: { epk: "1" } }
    assert photos(:outdoor_shoot).reload.epk?
  end

  test "update can toggle published flag" do
    patch admin_photo_path(photos(:hidden_draft)), params: {
      photo: { published: "1" }
    }
    assert photos(:hidden_draft).reload.published?
  end

  test "update re-renders edit on validation failure" do
    patch admin_photo_path(photos(:outdoor_shoot)), params: {
      photo: { position: -1 }
    }
    assert_response :unprocessable_entity
  end

  # ── visible ───────────────────────────────────────────────────────────────

  test "visible renders only published photos" do
    get visible_admin_photos_path
    assert_response :success
    assert_match photos(:outdoor_shoot).caption, response.body
    assert_match photos(:stage_shot).caption,    response.body
    assert_no_match photos(:hidden_draft).caption, response.body
  end

  # ── reorder ───────────────────────────────────────────────────────────────

  test "reorder updates positions of visible photos in submitted order" do
    patch reorder_admin_photos_path, params: {
      ids: [ photos(:stage_shot).id, photos(:outdoor_shoot).id ]
    }, as: :json
    assert_response :ok
    assert_equal 1, photos(:stage_shot).reload.position
    assert_equal 2, photos(:outdoor_shoot).reload.position
  end

  test "reorder ignores hidden photos" do
    original_position = photos(:hidden_draft).position
    patch reorder_admin_photos_path, params: {
      ids: [ photos(:hidden_draft).id ]
    }, as: :json
    assert_response :ok
    assert_equal original_position, photos(:hidden_draft).reload.position
  end

  # ── bulk_update ───────────────────────────────────────────────────────────

  test "bulk_update publishes selected photos" do
    patch bulk_update_admin_photos_path, params: {
      photo_ids: [ photos(:hidden_draft).id ],
      published: "1"
    }
    assert_redirected_to admin_photos_path
    assert photos(:hidden_draft).reload.published?
  end

  test "bulk_update hides selected photos" do
    patch bulk_update_admin_photos_path, params: {
      photo_ids: [ photos(:outdoor_shoot).id, photos(:stage_shot).id ],
      published: "0"
    }
    assert_redirected_to admin_photos_path
    assert_not photos(:outdoor_shoot).reload.published?
    assert_not photos(:stage_shot).reload.published?
  end

  test "bulk_update preserves current filter in redirect" do
    patch bulk_update_admin_photos_path, params: {
      photo_ids: [ photos(:hidden_draft).id ],
      published: "1",
      filter: "hidden"
    }
    assert_redirected_to admin_photos_path(filter: "hidden")
  end

  test "bulk_update with no ids redirects with alert" do
    patch bulk_update_admin_photos_path, params: { published: "1" }
    assert_redirected_to admin_photos_path
    assert_equal "No photos selected.", flash[:alert]
  end

  # ── destroy ───────────────────────────────────────────────────────────────

  test "destroy removes the photo and redirects to index" do
    photo = photos(:hidden_draft)
    assert_difference -> { Photo.count }, -1 do
      delete admin_photo_path(photo)
    end
    assert_redirected_to admin_photos_path
    assert_equal "Photo removed.", flash[:notice]
  end
end

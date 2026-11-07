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

  test "visible is not paginated, because reorder needs every photo" do
    add_photos(Admin::PhotosController::PER_PAGE + 5, published: true)

    get visible_admin_photos_path

    assert_select "[data-photo-id]", Photo.where(published: true).count
  end

  # ── endless scroll ───────────────────────────────────────────────────────

  test "index shows the first page and a frame for the next" do
    add_photos(Admin::PhotosController::PER_PAGE + 5)

    get admin_photos_path

    assert_select "#photos_grid input[type=checkbox]", Admin::PhotosController::PER_PAGE
    assert_select "turbo-frame#photos_next_page[loading=lazy][src=?]", admin_photos_path(page: 2)
  end

  test "index has no next frame when everything fits on a page" do
    get admin_photos_path

    assert_select "turbo-frame#photos_next_page", 0
  end

  test "the next page keeps the filter" do
    add_photos(Admin::PhotosController::PER_PAGE + 5, published: false)

    get admin_photos_path(filter: "hidden")

    assert_select "turbo-frame#photos_next_page[src=?]", admin_photos_path(filter: "hidden", page: 2)
  end

  test "a frame request appends its cards and points at the following page" do
    add_photos(Admin::PhotosController::PER_PAGE * 2 + 5)

    get admin_photos_path(page: 2), headers: { "Turbo-Frame" => "photos_next_page" }

    assert_response :success
    assert_select "turbo-frame#photos_next_page turbo-stream[action=append][target=photos_grid]"
    assert_select "turbo-frame#photos_next_page turbo-stream[action=replace][target=photos_next_page]"
    assert_no_match "<h1", response.body
  end

  test "the last page removes the frame" do
    add_photos(Admin::PhotosController::PER_PAGE + 5)

    get admin_photos_path(page: 2), headers: { "Turbo-Frame" => "photos_next_page" }

    assert_select "turbo-stream[action=remove][target=photos_next_page]"
    assert_select "turbo-stream[action=replace]", 0
  end

  test "pages don't repeat or skip photos that share a position" do
    add_photos(Admin::PhotosController::PER_PAGE + 5, position: 7)

    ids = [ 1, 2 ].flat_map do |page|
      get admin_photos_path(page: page)
      css_select("#photos_grid input[type=checkbox]").map { |box| box["value"] }
    end

    assert_equal Photo.count, ids.uniq.size
  end

  test "the grid shows a thumbnail rather than the original" do
    photo = photos(:outdoor_shoot)
    photo.image.attach(io: file_fixture("test_photo.gif").open, filename: "photo.gif", content_type: "image/gif")

    get admin_photos_path

    assert_select "#photos_grid img[src*='/representations/']"
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

  test "bulk_update with select_all covers photos that were never loaded" do
    add_photos(Admin::PhotosController::PER_PAGE + 5, published: true)

    patch bulk_update_admin_photos_path, params: { select_all: "1", published: "0" }

    assert_equal 0, Photo.where(published: true).count
  end

  test "bulk_update with select_all stays inside the filter" do
    patch bulk_update_admin_photos_path, params: { select_all: "1", published: "1", filter: "hidden" }
    assert_equal 0, Photo.where(published: false).count

    photos(:hidden_draft).update_column(:published, false)
    patch bulk_update_admin_photos_path, params: { select_all: "1", published: "0", filter: "visible" }
    assert_equal Photo.count, Photo.where(published: false).count
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

  private

  def add_photos(count, published: true, position: nil)
    next_position = Photo.maximum(:position).to_i
    rows = Array.new(count) do |n|
      { position: position || next_position + n + 1, published: published, created_at: Time.current, updated_at: Time.current }
    end
    Photo.insert_all!(rows)
  end
end

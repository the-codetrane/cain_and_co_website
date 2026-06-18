require "test_helper"

class ShowsControllerTest < ActionDispatch::IntegrationTest
  test "index lists upcoming shows without login" do
    get shows_path
    assert_response :success
    assert_select "h1", "Upcoming shows"
    assert_match shows(:upcoming).venue_name, response.body
  end

  test "past lists past shows" do
    get past_shows_path
    assert_response :success
    assert_match shows(:past).venue_name, response.body
  end
end

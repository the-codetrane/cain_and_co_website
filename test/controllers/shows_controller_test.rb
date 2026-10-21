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

  test "index only shows a Tickets button when tickets are on sale" do
    shows(:upcoming).update!(offers: [])
    get shows_path
    assert_select "a", text: "Tickets", count: 0

    shows(:upcoming).update!(offers: [ { "url" => "https://tickets.example.com/echo", "status" => "available" } ])
    get shows_path
    assert_select "a[href=?]", "https://tickets.example.com/echo", text: "Tickets"
  end
end

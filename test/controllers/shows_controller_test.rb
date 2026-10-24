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

  test "index marks free shows and hides their Tickets button" do
    shows(:upcoming).update!(free: true)
    get shows_path
    assert_select "a", text: "Tickets", count: 0
    assert_select "span", text: "Free"
  end

  test "show renders an upcoming show by id without login" do
    get show_path(shows(:upcoming))
    assert_response :success
    assert_select "h1", shows(:upcoming).title
    assert_select "a[href=?]", "https://tickets.example.com/echo", text: "Tickets"
  end

  test "show renders a past show with a link back to past shows" do
    get show_path(shows(:past))
    assert_response :success
    assert_select "a[href=?]", past_shows_path
    assert_select "a", text: "Tickets", count: 0
  end

  test "show renders a canceled show with a badge and no tickets" do
    shows(:upcoming).update!(status: "canceled")
    get show_path(shows(:upcoming))
    assert_response :success
    assert_select "span", text: "Canceled"
    assert_select "a", text: "Tickets", count: 0
  end

  test "show renders lineup and description when present" do
    shows(:upcoming).update!(lineup: [ "Cain & Co.", "Opener" ], description: "Doors at 7.")
    get show_path(shows(:upcoming))
    assert_select "li", text: "Opener"
    assert_match "Doors at 7.", response.body
  end

  test "show works for manual shows" do
    get show_path(shows(:manual_upcoming))
    assert_response :success
    assert_select "a", text: "View on Bandsintown", count: 0
  end

  test "show does not link non-http ticket or event urls" do
    shows(:upcoming).update!(offers: [ { "url" => "javascript:alert(1)", "status" => "available" } ],
                             bandsintown_url: "javascript:alert(2)")
    get show_path(shows(:upcoming))
    assert_response :success
    assert_select "a[href^=javascript]", count: 0
  end

  test "show 404s for an unknown id" do
    get show_path(id: 0)
    assert_response :not_found
  end

  test "index cards link to the show page" do
    get shows_path
    assert_select "a[href=?]", show_path(shows(:upcoming))
  end
end

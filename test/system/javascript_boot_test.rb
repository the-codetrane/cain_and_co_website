require "application_system_test_case"

# Dependabot bumps of turbo-rails, stimulus-rails and importmap-rails can break the JS
# bundle while every non-browser test still passes. These tests load real pages and
# exercise one Stimulus action and one Turbo form each, so a broken bundle fails CI.
class JavascriptBootTest < ApplicationSystemTestCase
  test "home page boots Turbo and registers the Stimulus controllers" do
    visit root_path

    assert_text(/listen/i)
    assert_selector "[data-controller~='mobile-menu']"
    assert_js "typeof window.Turbo === 'object'", "Turbo did not load"
    wait_for_stimulus_controller "mobile-menu"
  end

  test "mobile menu toggles open" do
    page.driver.browser.manage.window.resize_to(390, 800)
    visit root_path
    wait_for_stimulus_controller "mobile-menu"

    assert_no_selector "#mobile-nav-menu", visible: :visible
    find("button[aria-label='Toggle menu']").click
    assert_selector "#mobile-nav-menu", visible: :visible
    assert_link "Merch", visible: :visible
  end

  test "visitor adds a product to the cart" do
    visit product_path(products(:published_shirt))

    choose "S", allow_label_click: true
    assert_text "$25.00"
    click_button "Add to cart"

    assert_current_path cart_path
    assert_text "Band Shirt"
  end

  test "admin signs in" do
    visit new_session_path

    fill_in "Email", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_current_path admin_root_path
    assert_text "Welcome back"
  end
end

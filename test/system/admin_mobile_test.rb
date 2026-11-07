require "application_system_test_case"

class AdminMobileTest < ApplicationSystemTestCase
  PHONE = { width: 390, height: 844 }.freeze

  # Headless Chrome won't size a window below 500px, so a phone needs device emulation.
  setup do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", **PHONE, deviceScaleFactor: 1, mobile: true)
    sign_in users(:one)
  end

  teardown { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  test "the tab bar moves between sections" do
    within("nav", text: "More") { click_on "Products" }
    assert_selector "h1", text: "Products"
    assert_selector "nav a[aria-current=page]", text: "Products"
  end

  test "More opens the remaining sections and account actions" do
    assert_no_selector "#admin_more_menu", visible: :visible

    click_on "More"
    within("#admin_more_menu") { click_on "Orders" }
    assert_selector "h1", text: "Orders"

    assert_no_selector "#admin_more_menu", visible: :visible
    click_on "More"
    within("#admin_more_menu") { click_on "Sign out" }
    assert_text "Admin sign in"
  end

  test "More closes from its backdrop" do
    click_on "More"
    assert_button "Sign out"
    page.driver.browser.action.move_to_location(195, 20).click.perform
    assert_no_button "Sign out"
  end

  test "stock can be changed from the variant card" do
    variant = variants(:shirt_small)
    visit admin_product_path(variant.product)

    find("[aria-label='Increase stock of S']").click
    assert_selector "#stock_variant_#{variant.id}", text: "11"
    assert_equal 11, variant.reload.stock_quantity
  end

  test "photos can be edited without hover" do
    visit admin_photos_path
    first(:link, "Edit").click
    assert_selector "h1", text: "Edit Photo"
  end

  # A swipe that starts on a tile used to leave Sortable mid-drag, so the next press did nothing.
  test "photos can be reordered by touch straight after scrolling the grid" do
    with_forgery_protection do # the save reads the CSRF meta tag, absent when this is off
      4.times { |i| create_visible_photo(position: 10 + i) }
      page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: true, maxTouchPoints: 5)
      visit visible_admin_photos_path
      wait_for_stimulus_controller "photo-sort"
      before = photo_order

      x, y = tile_center(0)
      touch "touchStart", x, y
      8.times { |i| touch "touchMove", x, [ y - 30 * (i + 1), 5 ].max }
      touch "touchEnd"
      assert_js "window.scrollY > 0", "A swipe across the grid should scroll the page"
      assert_equal before, photo_order

      sleep 0.5 # let the fling finish, or it overrides the scroll back to the top
      page.execute_script("window.scrollTo(0, 0)")
      sleep 0.2
      x, y = tile_center(0)
      to_x, to_y = tile_center(1)
      touch "touchStart", x, y
      sleep 0.4 # past the press-and-hold delay
      12.times do |i|
        progress = (i + 1) / 12.0
        touch "touchMove", x + (to_x - x) * progress, y + (to_y - y) * progress
        sleep 0.04
      end
      sleep 0.2
      touch "touchEnd"

      assert_js "document.querySelector('[data-photo-id]').dataset.photoId == '#{before.second}'", "The tiles should swap"
      assert_equal before.second, wait_for_saved_first_photo(before.second)
    ensure
      page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    end
  end

  # iOS zooms into a field under 16px, and Turbo carries that zoom into the admin after
  # signing in, which leaves every page hanging off the right of the screen.
  test "sign-in fields are large enough to avoid the iOS focus zoom" do
    click_on "More"
    within("#admin_more_menu") { click_on "Sign out" }
    assert_text "Admin sign in"

    [ new_session_path, new_password_path ].each do |path|
      visit path
      sizes = page.evaluate_script(<<~JS)
        [...document.querySelectorAll("input:not([type=hidden]):not([type=submit])")]
          .map(field => parseFloat(getComputedStyle(field).fontSize))
      JS
      assert_not_empty sizes
      assert sizes.all? { |size| size >= 16 }, "Fields under 16px on #{path}: #{sizes}"
    end
  end

  test "no control is pushed off a phone screen" do
    product = products(:published_shirt)
    [ admin_product_path(product), admin_products_path, admin_orders_path, admin_shows_path,
      admin_photos_path, admin_subscribers_path, admin_users_path ].each do |path|
      visit path
      assert_empty offscreen_controls, "Controls past the right edge of #{path}"
    end
  end

  private

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  def create_visible_photo(position:)
    photo = Photo.new(position: position, published: true)
    photo.image.attach(io: file_fixture("test_photo.gif").open, filename: "test_photo.gif")
    photo.save!
  end

  def touch(type, x = nil, y = nil)
    page.driver.browser.execute_cdp("Input.dispatchTouchEvent", type: type, touchPoints: x ? [ { x: x, y: y } ] : [])
  end

  def tile_center(index)
    page.evaluate_script(<<~JS)
      (() => {
        const rect = document.querySelectorAll("[data-photo-id]")[#{index}].getBoundingClientRect()
        return [ rect.x + rect.width / 2, rect.y + rect.height / 2 ]
      })()
    JS
  end

  def photo_order
    page.evaluate_script(%q([ ...document.querySelectorAll("[data-photo-id]") ].map(tile => tile.dataset.photoId)))
  end

  def wait_for_saved_first_photo(expected)
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until Photo.where(published: true).order(:position).first.id.to_s == expected
    end
    expected
  end

  def offscreen_controls
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("main a, main button, main input:not([type=hidden])")]
        .filter(e => e.getBoundingClientRect().width > 0 && e.getBoundingClientRect().right > innerWidth)
        .map(e => e.innerText || e.name)
    JS
  end

  def sign_in(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_text "Dashboard"
  end
end

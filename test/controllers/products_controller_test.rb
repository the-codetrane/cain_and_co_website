require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  test "index renders without login" do
    get products_path
    assert_response :success
    assert_select "h1", "Merch"
  end

  test "index shows published products only" do
    get products_path
    assert_match products(:published_shirt).name, response.body
    assert_no_match products(:draft_vinyl).name, response.body
  end

  test "show renders a published product" do
    get product_path(products(:published_shirt))
    assert_response :success
    assert_match products(:published_shirt).name, response.body
  end

  test "show returns 404 for unpublished product" do
    get product_path(products(:draft_vinyl))
    assert_response :not_found
  end

  test "show renders a size button per variant in size order" do
    get product_path(products(:published_shirt))
    assert_response :success
    assert_select "legend", "Select size"
    assert_select "input[type=radio][name=variant_id]", 1 # only the in-stock size is selectable
    assert_select "input[type=radio][value=?]", variants(:shirt_small).id.to_s
  end

  test "show marks a sold-out size as unselectable rather than hiding it" do
    get product_path(products(:published_shirt))
    assert_select "input[type=radio][value=?]", variants(:shirt_large).id.to_s, count: 0
    assert_select "span.line-through", text: variants(:shirt_large).name
  end

  test "show orders the size buttons S then L regardless of fixture order" do
    product = products(:published_shirt)
    product.variants.update_all(stock_quantity: 5)
    get product_path(product)
    small = response.body.index(%(value="#{variants(:shirt_small).id}"))
    large = response.body.index(%(value="#{variants(:shirt_large).id}"))
    assert small && large, "both size buttons should render"
    assert_operator small, :<, large
  end

  test "show falls back to a hidden field for a single-variant product" do
    product = Product.create!(name: "Tote", published: true)
    product.variants.create!(name: "One Size", price_cents: 1500, stock_quantity: 4)
    get product_path(product)
    assert_select "input[type=hidden][name=variant_id]", 1
    assert_select "input[type=radio][name=variant_id]", 0
  end

  test "index runs the same number of queries however many products there are" do
    add_product_with_image("First")
    baseline = count_queries { get products_path }

    3.times { |n| add_product_with_image("Extra #{n}") }

    assert_equal baseline, count_queries { get products_path }
  end

  # ── Product grid cache ───────────────────────────────────────────────────

  test "a cached grid shows a sale as soon as stock changes" do
    with_fragment_caching do
      variants(:shirt_small).update!(stock_quantity: 1)
      get products_path
      assert_no_match "Out of stock", response.body

      variants(:shirt_small).adjust_stock(-1) # update_all, so no callbacks run
      get products_path
      assert_match "Out of stock", response.body
    end
  end

  test "a cached grid notices a removed variant" do
    with_fragment_caching do
      get products_path
      assert_no_match "Out of stock", response.body

      variants(:shirt_small).destroy! # the only size in stock, and not the newest row
      get products_path
      assert_match "Out of stock", response.body
    end
  end

  test "a repeat visit reads the grid from the cache" do
    with_fragment_caching do
      get products_path

      hits = []
      subscriber = ->(*, payload) { hits << payload[:hit] }
      ActiveSupport::Notifications.subscribed(subscriber, "cache_read.active_support") do
        get products_path
      end

      assert_includes hits, true
    end
  end

  test "the product page is never cached, so its form keeps a fresh CSRF token" do
    with_fragment_caching do
      ActionController::Base.allow_forgery_protection = true
      get product_path(products(:published_shirt))
      first = css_select("form input[name=authenticity_token]").first["value"]

      reset!
      get product_path(products(:published_shirt))
      assert_not_equal first, css_select("form input[name=authenticity_token]").first["value"]
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end

  private

  def add_product_with_image(name)
    product = Product.create!(name: name, published: true)
    product.variants.create!(name: "M", price_cents: 2000, stock_quantity: 3)
    product.images.attach(io: file_fixture("test_photo.gif").open, filename: "photo.gif", content_type: "image/gif")
    product.images.first.variant(:card).processed
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[ SCHEMA TRANSACTION ]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  def with_fragment_caching
    store = ActionController::Base.cache_store
    ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
    ActionController::Base.perform_caching = true
    yield
  ensure
    ActionController::Base.perform_caching = false
    ActionController::Base.cache_store = store
  end
end

require "test_helper"

# Browsers ask for these by convention, whether or not a page links them.
class BrowserIconsTest < ActionDispatch::IntegrationTest
  %w[/favicon.ico /apple-touch-icon.png /apple-touch-icon-precomposed.png].each do |path|
    test "#{path} is served" do
      get path
      assert_response :success
    end
  end
end

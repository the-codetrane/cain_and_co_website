require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "safe_external_url allows http and https" do
    assert_equal "https://example.com/a?b=1", safe_external_url("https://example.com/a?b=1")
    assert_equal "http://example.com", safe_external_url(" http://example.com ")
  end

  test "safe_external_url rejects other schemes and junk" do
    assert_nil safe_external_url("javascript:alert(1)")
    assert_nil safe_external_url("data:text/html,hi")
    assert_nil safe_external_url("not a url")
    assert_nil safe_external_url("/relative")
    assert_nil safe_external_url(nil)
  end
end

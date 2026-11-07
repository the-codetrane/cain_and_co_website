require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "a new password must meet the minimum length" do
    user = User.new(email_address: "new@example.com", password: "a" * 11)
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 12 characters)"

    user.password = "a" * 12
    assert user.valid?
  end

  test "an existing short password doesn't block other updates" do
    assert users(:member).update(admin: true)
  end

  test "defaults to non-admin" do
    assert_not User.new.admin?
  end

  test "an admin can be demoted while another admin remains" do
    assert users(:two).update(admin: false)
  end

  test "the last admin can't be demoted" do
    users(:two).update!(admin: false)

    assert_not users(:one).update(admin: false)
    assert_includes users(:one).errors[:base], "The site must keep at least one admin"
    assert users(:one).reload.admin?
  end
end

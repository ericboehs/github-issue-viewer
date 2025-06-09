require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email_address: "test@example.com", password: "password123")
    @session = @user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test Agent")
  end

  test "should set and get session" do
    Current.session = @session
    assert_equal @session, Current.session
  end

  test "should get user from session" do
    Current.session = @session
    assert_equal @user, Current.user
  end

  test "should return nil user when no session" do
    Current.session = nil
    assert_nil Current.user
  end

  test "should reset between requests" do
    Current.session = @session
    assert_equal @session, Current.session

    # Simulate new request
    Current.reset
    assert_nil Current.session
    assert_nil Current.user
  end
end

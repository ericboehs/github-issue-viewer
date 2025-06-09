require "test_helper"

class SessionTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email_address: "test@example.com", password: "password123")
  end

  test "should belong to user" do
    session = Session.new(user: @user, ip_address: "127.0.0.1", user_agent: "Test Agent")
    assert_equal @user, session.user
  end

  test "should be valid with valid attributes" do
    session = Session.new(user: @user, ip_address: "127.0.0.1", user_agent: "Test Agent")
    assert session.valid?
  end

  test "should require user" do
    session = Session.new(ip_address: "127.0.0.1", user_agent: "Test Agent")
    assert_not session.valid?
  end

  test "should allow nil ip_address and user_agent" do
    session = Session.new(user: @user, ip_address: nil, user_agent: nil)
    assert session.valid?
  end
end

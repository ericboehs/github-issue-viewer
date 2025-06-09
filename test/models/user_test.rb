require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    user = User.new(email_address: "test@example.com", password: "password123")
    assert user.valid?
  end

  test "should require email address" do
    user = User.new(password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "should require valid email format" do
    user = User.new(email_address: "invalid-email", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "is invalid"
  end

  test "should require unique email address" do
    User.create!(email_address: "test@example.com", password: "password123")
    user = User.new(email_address: "test@example.com", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "has already been taken"
  end

  test "should require password with minimum length" do
    user = User.new(email_address: "test@example.com", password: "short")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 6 characters)"
  end

  test "should normalize email address" do
    user = User.create!(email_address: " TEST@EXAMPLE.COM ", password: "password123")
    assert_equal "test@example.com", user.email_address
  end


  test "should have many sessions" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    session1 = user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test Agent")
    session2 = user.sessions.create!(ip_address: "192.168.1.1", user_agent: "Another Agent")

    assert_equal 2, user.sessions.count
    assert_includes user.sessions, session1
    assert_includes user.sessions, session2
  end

  test "should destroy dependent sessions when user is destroyed" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    session = user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test Agent")
    session_id = session.id

    user.destroy
    assert_not Session.exists?(session_id)
  end
end

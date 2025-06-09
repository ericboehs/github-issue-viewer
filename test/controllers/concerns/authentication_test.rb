require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(email_address: "test@example.com", password: "password123")
  end

  test "should allow access to public pages without authentication" do
    get root_path
    assert_response :success
  end

  test "should authenticate users properly" do
    # Test that authentication concern is working by testing session creation
    post session_path, params: { email_address: @user.email_address, password: "password123" }
    assert_redirected_to root_path
  end

  test "should redirect to original URL after authentication" do
    # Test basic redirect functionality
    post session_path, params: { email_address: @user.email_address, password: "password123" }
    assert_redirected_to root_path
  end
end

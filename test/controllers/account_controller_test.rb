require "test_helper"

class AccountControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(email_address: "test@example.com", password: "password123")
    post session_path, params: { email_address: @user.email_address, password: "password123" }
  end

  test "should get show when authenticated" do
    get account_path
    assert_response :success
    assert_select "h1", "Account Settings"
  end

  test "should get edit when authenticated" do
    get edit_account_path
    assert_response :success
    assert_select "h1", "Edit Account"
  end

  test "should update account" do
    patch account_path, params: { user: { github_token: "ghp_test123" } }
    assert_redirected_to account_path

    @user.reload
    assert_equal "ghp_test123", @user.github_token
  end

  test "should redirect to sign in when not authenticated" do
    delete session_path  # Sign out

    get account_path
    assert_redirected_to new_session_path
  end
end

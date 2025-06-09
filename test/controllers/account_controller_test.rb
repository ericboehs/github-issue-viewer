require "test_helper"

class AccountControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(email_address: "test@example.com", password: "password123")
    post session_path, params: { email_address: @user.email_address, password: "password123" }
  end

  test "should get show when authenticated and token configured" do
    @user.update!(github_token: "ghp_test123")

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

  test "should redirect to edit when no github token is configured" do
    get account_path
    assert_redirected_to edit_account_path
  end

  test "should show account when github token is configured" do
    @user.update!(github_token: "ghp_test123")

    get account_path
    assert_response :success
    assert_select "h1", "Account Settings"
  end

  test "should display masked token with correct prefix for ghp tokens" do
    @user.update!(github_token: "ghp_test123456789")

    get account_path
    assert_response :success
    assert_select ".font-mono", text: /^ghp_••••••••••••••••••••$/
  end

  test "should display masked token with correct prefix for gho tokens" do
    @user.update!(github_token: "gho_test123456789")

    get account_path
    assert_response :success
    assert_select ".font-mono", text: /^gho_••••••••••••••••••••$/
  end

  test "should display masked token with correct prefix for github_pat tokens" do
    @user.update!(github_token: "github_pat_test123456789")

    get account_path
    assert_response :success
    assert_select ".font-mono", text: /^github_pat_••••••••••••••••••••$/
  end

  test "should show not configured state when no token" do
    get account_path
    # This will redirect to edit, so let's test the edit page instead
    follow_redirect!
    assert_response :success
    assert_select "h1", "Edit Account"
  end

  test "should destroy all other sessions" do
    @user.update!(github_token: "ghp_test123")

    # Create additional sessions
    session2 = @user.sessions.create!(user_agent: "Other Browser", ip_address: "192.168.1.2")
    session3 = @user.sessions.create!(user_agent: "Mobile", ip_address: "192.168.1.3")

    assert_equal 3, @user.sessions.count

    delete destroy_all_sessions_account_path
    assert_redirected_to account_path

    @user.reload
    assert_equal 1, @user.sessions.count
    assert_equal "All other sessions have been logged out.", flash[:notice]
  end

  test "should not show logout all sessions button when only one session" do
    @user.update!(github_token: "ghp_test123")

    get account_path
    assert_response :success
    assert_select "a", text: "Logout All Other Sessions", count: 0
  end

  test "should show logout all sessions button when multiple sessions" do
    @user.update!(github_token: "ghp_test123")
    @user.sessions.create!(user_agent: "Other Browser", ip_address: "192.168.1.2")

    get account_path
    assert_response :success
    assert_select "a", text: "Logout All Other Sessions", count: 1
  end
end

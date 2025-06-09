require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_user_registration_path
    assert_response :success
    assert_select "h1", "Sign up"
    assert_select "form"
  end

  test "should create user with valid attributes" do
    assert_difference("User.count") do
      post registrations_path, params: {
        user: {
          email_address: "test@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
    assert_redirected_to root_path

    # Verify user was created and logged in
    user = User.find_by(email_address: "test@example.com")
    assert_not_nil user
    assert_not_nil user.sessions.last

    # Follow redirect and check for success (flash message testing is complex in integration tests)
    follow_redirect!
    assert_response :success
  end

  test "should create user with github token" do
    assert_difference("User.count") do
      post registrations_path, params: {
        user: {
          email_address: "test@example.com",
          password: "password123",
          password_confirmation: "password123",
          github_token: "ghp_secret123"
        }
      }
    end

    user = User.find_by(email_address: "test@example.com")
    assert_equal "ghp_secret123", user.github_token
  end

  test "should not create user with invalid attributes" do
    assert_no_difference("User.count") do
      post registrations_path, params: {
        user: {
          email_address: "invalid-email",
          password: "short",
          password_confirmation: "different"
        }
      }
    end
    assert_response :unprocessable_entity
    assert_select ".bg-red-50"
  end

  test "should not create user with mismatched password confirmation" do
    assert_no_difference("User.count") do
      post registrations_path, params: {
        user: {
          email_address: "test@example.com",
          password: "password123",
          password_confirmation: "different"
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create user with duplicate email" do
    User.create!(email_address: "test@example.com", password: "password123")

    assert_no_difference("User.count") do
      post registrations_path, params: {
        user: {
          email_address: "test@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
    assert_response :unprocessable_entity
  end
end

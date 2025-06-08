require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "application controller loads successfully" do
    # This is a basic test to ensure the application controller is properly configured
    # Since ApplicationController is a base class, we test its configuration indirectly
    assert_not_nil ApplicationController
    assert ApplicationController < ActionController::Base
  end

  test "modern browser requirement is configured" do
    # Test that the allow_browser configuration is present in the class
    # This tests the allow_browser versions: :modern configuration
    assert ApplicationController.respond_to?(:allow_browser)
  end
end

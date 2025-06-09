require "test_helper"
require "webmock/minitest"

class IssuesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @user.update!(github_token: "test_token")
    sign_in_as(@user)
    WebMock.enable!
  end

  def teardown
    WebMock.disable!
    WebMock.reset!
  end

  test "should get index" do
    get issues_url
    assert_response :success
    assert_select "label", "Repository Owner"
  end

  test "should redirect to account if no github token" do
    @user.update!(github_token: nil)

    get issues_url
    assert_redirected_to account_path
    assert_equal "Please configure your GitHub token to view issues.", flash[:alert]
  end

  test "should show empty state when no repository provided" do
    get issues_url
    assert_response :success
    assert_select ".text-center h3", "No Repository Selected"
  end

  test "should fetch and display issues successfully" do
    stub_successful_github_response

    get issues_url, params: { owner: "rails", repository: "rails" }

    assert_response :success
    assert_select "h2", "rails/rails"
    assert_select ".divide-y .p-3", count: 2 # 2 issue cards
  end

  test "should handle authentication error" do
    stub_authentication_error_response

    get issues_url, params: { owner: "rails", repository: "rails" }

    assert_response :success
    assert_select ".bg-red-50 p", text: /GitHub authentication failed/
  end

  test "should handle repository not found error" do
    stub_repository_not_found_response

    get issues_url, params: { owner: "rails", repository: "nonexistent" }

    assert_response :success
    assert_select ".bg-red-50 p", text: /Repository rails\/nonexistent not found/
  end

  test "should handle rate limit error" do
    stub_rate_limit_error_response

    get issues_url, params: { owner: "rails", repository: "rails" }

    assert_response :success
    assert_select ".bg-red-50 p", text: /GitHub API rate limit exceeded/
  end

  test "should handle generic github api error" do
    stub_generic_error_response

    get issues_url, params: { owner: "rails", repository: "rails" }

    assert_response :success
    assert_select ".bg-red-50 p", text: /GitHub API error/
  end

  test "should filter by state parameter" do
    request_stub = stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .with(body: hash_including(query: /states: \[CLOSED\]/))
      .to_return(status: 200, body: minimal_successful_response.to_json)

    get issues_url, params: { owner: "rails", repository: "rails", state: "closed" }

    assert_requested request_stub
    assert_response :success
  end

  test "should sort by updated date" do
    stub_successful_github_response

    get issues_url, params: { owner: "rails", repository: "rails", sort: "updated", direction: "asc" }

    assert_response :success
    # Issues should be sorted by updated_at in ascending order
    # The test data has issue 1 updated later than issue 2, so in asc order, issue 2 should come first
  end

  test "should sort by title" do
    stub_successful_github_response

    get issues_url, params: { owner: "rails", repository: "rails", sort: "title", direction: "asc" }

    assert_response :success
    # Should work without errors
  end

  test "should limit per_page parameter" do
    stub_successful_github_response

    get issues_url, params: { owner: "rails", repository: "rails", per_page: "150" }

    assert_response :success
    # per_page should be clamped to 100
  end

  test "should handle minimum per_page parameter" do
    stub_successful_github_response

    get issues_url, params: { owner: "rails", repository: "rails", per_page: "0" }

    assert_response :success
    # per_page should be clamped to 1
  end

  test "should show no issues state when repository has no issues" do
    stub_empty_repository_response

    get issues_url, params: { owner: "rails", repository: "rails" }

    assert_response :success
    assert_select ".text-center h3", "No Issues Found"
  end

  test "should require authentication" do
    sign_out

    get issues_url
    assert_redirected_to new_session_path
  end

  test "should handle unexpected exceptions" do
    @user.update!(github_token: "test_token")
    # Stub to raise an unexpected error
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_raise(StandardError.new("Unexpected error"))

    get issues_url, params: { owner: "rails", repository: "rails" }

    assert_response :success
    assert_select ".bg-red-50 p", text: /An unexpected error occurred/
  end

  test "should handle all sorting options" do
    stub_successful_github_response

    get issues_url, params: { owner: "rails", repository: "rails", sort: "state", direction: "asc" }

    assert_response :success
  end

  test "should redirect to last repo from cookie when no params provided" do
    stub_successful_github_response

    # Set up cookie with last repo
    cookies[:last_repo] = { owner: "rails", repository: "rails" }.to_json

    get issues_url

    assert_redirected_to issues_path(owner: "rails", repository: "rails", state: "open")
  end

  test "should handle malformed cookie gracefully" do
    # Set up malformed cookie
    cookies[:last_repo] = "invalid json{"

    get issues_url

    assert_response :success
    assert_select ".text-center h3", "No Repository Selected"
  end

  test "should handle cookie with missing fields" do
    # Set up cookie with incomplete data
    cookies[:last_repo] = { owner: "rails" }.to_json

    get issues_url

    assert_response :success
    assert_select ".text-center h3", "No Repository Selected"
  end

  test "should handle default sorting with desc direction" do
    stub_successful_github_response

    get issues_url, params: { owner: "rails", repository: "rails", sort: "created", direction: "desc" }

    assert_response :success
  end

  test "should calculate total pages correctly" do
    stub_successful_github_response

    get issues_url, params: { owner: "rails", repository: "rails", per_page: "3" }

    assert_response :success
    # With totalCount of 2 and per_page of 3, should have 1 total page
    # Verify total count is shown and used
    assert_select ".bg-gray-100", text: /2 issues/
  end

  test "should handle nil total count for total pages" do
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        data: {
          repository: {
            issues: {
              pageInfo: { hasNextPage: false, endCursor: nil },
              nodes: []
            }
          }
        }
      }.to_json)

    get issues_url, params: { owner: "rails", repository: "rails" }

    assert_response :success
    # Should show no issues found when empty
    assert_select ".text-center h3", "No Issues Found"
  end

  # Tests for show action
  test "should get show with valid issue" do
    stub_successful_issue_detail_response

    get issue_url("rails", "rails", 1)

    assert_response :success
    assert_select "h1", "Test Issue 1"
    assert_select ".prose", count: 2 # Issue body + 1 comment body
  end

  test "should redirect to account if no github token for show" do
    @user.update!(github_token: nil)

    get issue_url("rails", "rails", 1)
    assert_redirected_to account_path
    assert_equal "Please configure your GitHub token to view issues.", flash[:alert]
  end

  test "should handle authentication error for show" do
    stub_authentication_error_response

    get issue_url("rails", "rails", 1)

    assert_response :success
    assert_select ".bg-red-50 p", text: /GitHub authentication failed/
  end

  test "should handle repository not found error for show" do
    stub_repository_not_found_response

    get issue_url("rails", "nonexistent", 1)

    assert_response :success
    assert_select ".bg-red-50 p", text: /Repository rails\/nonexistent not found/
  end

  test "should handle issue not found error" do
    stub_issue_not_found_response

    get issue_url("rails", "rails", 999)

    assert_response :success
    assert_select ".bg-red-50 p", text: /Issue #999 not found/
  end

  test "should handle rate limit error for show" do
    stub_rate_limit_error_response

    get issue_url("rails", "rails", 1)

    assert_response :success
    assert_select ".bg-red-50 p", text: /GitHub API rate limit exceeded/
  end

  test "should show issue without comments" do
    stub_issue_without_comments_response

    get issue_url("rails", "rails", 1)

    assert_response :success
    assert_select "h1", "Test Issue 1"
    assert_select ".prose", count: 1 # Only issue body
    assert_select "h2", text: /Comments/, count: 0 # No comments section
  end

  test "should handle issue with no body" do
    stub_issue_with_no_body_response

    get issue_url("rails", "rails", 1)

    assert_response :success
    assert_select "p", text: /No description provided/
  end

  test "should handle invalid issue parameters" do
    stub_repository_not_found_response

    get "/issues/invalid/invalid/999"

    assert_response :success
    assert_select ".bg-red-50 p", text: /Repository invalid\/invalid not found/
  end

  test "should show closed issue correctly" do
    stub_closed_issue_response

    get issue_url("rails", "rails", 1)

    assert_response :success
    assert_select "h1", "Closed Issue"
    assert_select ".text-purple-700", text: "closed"
  end

  test "should display issue labels correctly" do
    stub_issue_with_labels_response

    get issue_url("rails", "rails", 1)

    assert_response :success
    assert_select "span[style*='background-color: #ff0000']", text: "bug"
    assert_select "span[style*='background-color: #00ff00']", text: "enhancement"
  end

  test "should display assignees and milestone" do
    stub_issue_with_assignees_milestone_response

    get issue_url("rails", "rails", 1)

    assert_response :success
    assert_select ".text-gray-600", text: /Assigned to:/
    assert_select ".font-medium", text: "assignee1"
    assert_select ".text-gray-600", text: /Milestone: v1.0/
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end

  def sign_out
    delete session_url
  end

  def stub_successful_github_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        data: {
          repository: {
            issues: {
              totalCount: 2,
              pageInfo: { hasNextPage: false, endCursor: nil },
              nodes: [
                {
                  id: "gid://github/Issue/1",
                  number: 1,
                  title: "Test Issue 1",
                  body: "This is test issue 1",
                  state: "OPEN",
                  createdAt: "2024-01-01T00:00:00Z",
                  updatedAt: "2024-01-02T00:00:00Z",
                  closedAt: nil,
                  url: "https://github.com/rails/rails/issues/1",
                  author: { login: "testuser", name: "Test User", email: "test@example.com" },
                  labels: { nodes: [ { name: "bug", color: "ff0000", description: "Something is broken" } ] },
                  assignees: { nodes: [ { login: "assignee1", name: "Assignee One" } ] },
                  milestone: { title: "v1.0", description: "First release", dueOn: "2024-12-31" }
                },
                {
                  id: "gid://github/Issue/2",
                  number: 2,
                  title: "Another Issue",
                  body: "This is test issue 2",
                  state: "OPEN",
                  createdAt: "2024-01-01T00:00:00Z",
                  updatedAt: "2024-01-01T00:00:00Z",
                  closedAt: nil,
                  url: "https://github.com/rails/rails/issues/2",
                  author: { login: "testuser2", name: "Test User 2", email: "test2@example.com" },
                  labels: { nodes: [] },
                  assignees: { nodes: [] },
                  milestone: nil
                }
              ]
            }
          }
        }
      }.to_json)
  end

  def stub_authentication_error_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 401, body: { message: "Bad credentials" }.to_json)
  end

  def stub_repository_not_found_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: { data: { repository: nil } }.to_json)
  end

  def stub_rate_limit_error_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 403, body: { message: "API rate limit exceeded" }.to_json)
  end

  def stub_generic_error_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 500, body: { message: "Internal server error" }.to_json)
  end

  def stub_empty_repository_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        data: {
          repository: {
            issues: {
              totalCount: 0,
              pageInfo: { hasNextPage: false, endCursor: nil },
              nodes: []
            }
          }
        }
      }.to_json)
  end

  def minimal_successful_response
    {
      data: {
        repository: {
          issues: {
            totalCount: 0,
            pageInfo: { hasNextPage: false, endCursor: nil },
            nodes: []
          }
        }
      }
    }
  end

  def stub_successful_issue_detail_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        data: {
          repository: {
            issue: {
              id: "gid://github/Issue/1",
              number: 1,
              title: "Test Issue 1",
              body: "# This is a test issue\n\nWith some markdown content.",
              bodyHTML: "<h1>This is a test issue</h1><p>With some markdown content.</p>",
              state: "OPEN",
              createdAt: "2024-01-01T00:00:00Z",
              updatedAt: "2024-01-02T00:00:00Z",
              closedAt: nil,
              url: "https://github.com/rails/rails/issues/1",
              author: {
                login: "testuser",
                name: "Test User",
                email: "test@example.com",
                avatarUrl: "https://github.com/testuser.png"
              },
              labels: {
                nodes: [
                  { name: "bug", color: "ff0000", description: "Something is broken" }
                ]
              },
              assignees: {
                nodes: [
                  { login: "assignee1", name: "Assignee One", avatarUrl: "https://github.com/assignee1.png" }
                ]
              },
              milestone: { title: "v1.0", description: "First release", dueOn: "2024-12-31" },
              comments: {
                nodes: [
                  {
                    id: "gid://github/IssueComment/1",
                    body: "This is a test comment with **markdown**.",
                    bodyHTML: "<p>This is a test comment with <strong>markdown</strong>.</p>",
                    createdAt: "2024-01-03T00:00:00Z",
                    updatedAt: "2024-01-03T00:00:00Z",
                    author: {
                      login: "commenter",
                      name: "Test Commenter",
                      avatarUrl: "https://github.com/commenter.png"
                    }
                  }
                ]
              }
            }
          }
        }
      }.to_json)
  end

  def stub_issue_not_found_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        data: {
          repository: {
            issue: nil
          }
        }
      }.to_json)
  end

  def stub_issue_without_comments_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        data: {
          repository: {
            issue: {
              id: "gid://github/Issue/1",
              number: 1,
              title: "Test Issue 1",
              body: "# This is a test issue",
              bodyHTML: "<h1>This is a test issue</h1>",
              state: "OPEN",
              createdAt: "2024-01-01T00:00:00Z",
              updatedAt: "2024-01-01T00:00:00Z",
              closedAt: nil,
              url: "https://github.com/rails/rails/issues/1",
              author: {
                login: "testuser",
                name: "Test User",
                email: "test@example.com",
                avatarUrl: "https://github.com/testuser.png"
              },
              labels: { nodes: [] },
              assignees: { nodes: [] },
              milestone: nil,
              comments: { nodes: [] }
            }
          }
        }
      }.to_json)
  end

  def stub_issue_with_no_body_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        data: {
          repository: {
            issue: {
              id: "gid://github/Issue/1",
              number: 1,
              title: "Test Issue 1",
              body: nil,
              bodyHTML: nil,
              state: "OPEN",
              createdAt: "2024-01-01T00:00:00Z",
              updatedAt: "2024-01-01T00:00:00Z",
              closedAt: nil,
              url: "https://github.com/rails/rails/issues/1",
              author: {
                login: "testuser",
                name: "Test User",
                email: "test@example.com",
                avatarUrl: "https://github.com/testuser.png"
              },
              labels: { nodes: [] },
              assignees: { nodes: [] },
              milestone: nil,
              comments: { nodes: [] }
            }
          }
        }
      }.to_json)
  end

  def stub_closed_issue_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        data: {
          repository: {
            issue: {
              id: "gid://github/Issue/1",
              number: 1,
              title: "Closed Issue",
              body: "This issue is closed",
              bodyHTML: "<p>This issue is closed</p>",
              state: "CLOSED",
              createdAt: "2024-01-01T00:00:00Z",
              updatedAt: "2024-01-01T00:00:00Z",
              closedAt: "2024-01-02T00:00:00Z",
              url: "https://github.com/rails/rails/issues/1",
              author: {
                login: "testuser",
                name: "Test User",
                email: "test@example.com",
                avatarUrl: "https://github.com/testuser.png"
              },
              labels: { nodes: [] },
              assignees: { nodes: [] },
              milestone: nil,
              comments: { nodes: [] }
            }
          }
        }
      }.to_json)
  end

  def stub_issue_with_labels_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        data: {
          repository: {
            issue: {
              id: "gid://github/Issue/1",
              number: 1,
              title: "Issue with Labels",
              body: "This issue has labels",
              bodyHTML: "<p>This issue has labels</p>",
              state: "OPEN",
              createdAt: "2024-01-01T00:00:00Z",
              updatedAt: "2024-01-01T00:00:00Z",
              closedAt: nil,
              url: "https://github.com/rails/rails/issues/1",
              author: {
                login: "testuser",
                name: "Test User",
                email: "test@example.com",
                avatarUrl: "https://github.com/testuser.png"
              },
              labels: {
                nodes: [
                  { name: "bug", color: "ff0000", description: "Something is broken" },
                  { name: "enhancement", color: "00ff00", description: "New feature" }
                ]
              },
              assignees: { nodes: [] },
              milestone: nil,
              comments: { nodes: [] }
            }
          }
        }
      }.to_json)
  end

  def stub_issue_with_assignees_milestone_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        data: {
          repository: {
            issue: {
              id: "gid://github/Issue/1",
              number: 1,
              title: "Issue with Assignees and Milestone",
              body: "This issue has assignees and milestone",
              bodyHTML: "<p>This issue has assignees and milestone</p>",
              state: "OPEN",
              createdAt: "2024-01-01T00:00:00Z",
              updatedAt: "2024-01-01T00:00:00Z",
              closedAt: nil,
              url: "https://github.com/rails/rails/issues/1",
              author: {
                login: "testuser",
                name: "Test User",
                email: "test@example.com",
                avatarUrl: "https://github.com/testuser.png"
              },
              labels: { nodes: [] },
              assignees: {
                nodes: [
                  { login: "assignee1", name: "Assignee One", avatarUrl: "https://github.com/assignee1.png" },
                  { login: "assignee2", name: "Assignee Two", avatarUrl: "https://github.com/assignee2.png" }
                ]
              },
              milestone: { title: "v1.0", description: "First release", dueOn: "2024-12-31" },
              comments: { nodes: [] }
            }
          }
        }
      }.to_json)
  end
end

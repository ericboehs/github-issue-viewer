require "test_helper"
require "webmock/minitest"

class GithubIssuesServiceTest < ActiveSupport::TestCase
  def setup
    @service = GithubIssuesService.new("rails", "rails", token: "test_token")
    WebMock.enable!
  end

  def teardown
    WebMock.disable!
    WebMock.reset!
  end

  test "should initialize with owner, repository name and token" do
    service = GithubIssuesService.new("owner", "repo", token: "token")
    assert_equal "owner", service.instance_variable_get(:@owner)
    assert_equal "repo", service.instance_variable_get(:@repository_name)
    assert_equal "token", service.instance_variable_get(:@token)
  end

  test "should use environment token when none provided" do
    ENV["GITHUB_TOKEN"] = "env_token"
    service = GithubIssuesService.new("owner", "repo")
    assert_equal "env_token", service.instance_variable_get(:@token)
  ensure
    ENV.delete("GITHUB_TOKEN")
  end

  test "should raise authentication error when no token provided" do
    ENV.delete("GITHUB_TOKEN")
    error = assert_raises(GithubIssuesService::AuthenticationError) do
      GithubIssuesService.new("owner", "repo")
    end
    assert_equal "GitHub token is required", error.message
  end

  test "should fetch issues successfully" do
    stub_successful_graphql_response

    result = @service.fetch_issues

    assert_equal 2, result[:issues].length
    assert result[:has_next_page]
    assert_equal "cursor123", result[:end_cursor]

    issue = result[:issues].first
    assert_equal "gid://github/Issue/1", issue[:id]
    assert_equal 1, issue[:number]
    assert_equal "Test Issue 1", issue[:title]
    assert_equal "open", issue[:state]
    assert_equal "https://github.com/rails/rails/issues/1", issue[:url]
    assert_instance_of Time, issue[:created_at]
  end

  test "should handle repository not found error" do
    stub_repository_not_found_response

    error = assert_raises(GithubIssuesService::RepositoryNotFoundError) do
      @service.fetch_issues
    end
    assert_match(/Repository rails\/rails not found/, error.message)
  end

  test "should handle authentication errors" do
    stub_authentication_error_response

    error = assert_raises(GithubIssuesService::AuthenticationError) do
      @service.fetch_issues
    end
    assert_match(/Invalid or missing GitHub token/, error.message)
    assert_equal "401", error.response_code
  end

  test "should handle rate limit errors" do
    stub_rate_limit_error_response

    error = assert_raises(GithubIssuesService::RateLimitError) do
      @service.fetch_issues
    end
    assert_match(/GitHub API rate limit exceeded/, error.message)
    assert_equal "403", error.response_code
  end

  test "should handle network timeout errors" do
    stub_timeout_error

    error = assert_raises(GithubIssuesService::GithubApiError) do
      @service.fetch_issues
    end
    assert_match(/Network timeout/, error.message)
  end

  test "should handle invalid JSON response" do
    stub_invalid_json_response

    error = assert_raises(GithubIssuesService::GithubApiError) do
      @service.fetch_issues
    end
    assert_match(/Invalid JSON response/, error.message)
  end

  test "should handle GraphQL errors in response" do
    stub_graphql_error_response

    error = assert_raises(GithubIssuesService::GithubApiError) do
      @service.fetch_issues
    end
    assert_match(/GraphQL errors: Field 'invalid' doesn't exist/, error.message)
  end

  test "should fetch all issues with pagination" do
    stub_paginated_graphql_responses

    issues = @service.fetch_all_issues(batch_size: 1)

    assert_equal 3, issues.length
    assert_equal "Test Issue 1", issues[0][:title]
    assert_equal "Test Issue 2", issues[1][:title]
    assert_equal "Test Issue 3", issues[2][:title]
  end

  test "should pass state parameter correctly" do
    request_stub = stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .with(body: hash_including(query: /states: \[CLOSED\]/))
      .to_return(status: 200, body: minimal_successful_response.to_json)

    @service.fetch_issues(state: "CLOSED")

    assert_requested request_stub
  end

  test "should pass pagination parameters correctly" do
    request_stub = stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .with(body: hash_including(query: /first: 50.*after: "test_cursor"/m))
      .to_return(status: 200, body: minimal_successful_response.to_json)

    @service.fetch_issues(limit: 50, after_cursor: "test_cursor")

    assert_requested request_stub
  end

  test "should handle 404 response code" do
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 404, body: { message: "Not Found" }.to_json)

    error = assert_raises(GithubIssuesService::RepositoryNotFoundError) do
      @service.fetch_issues
    end
    assert_match(/Repository rails\/rails not found/, error.message)
    assert_equal "404", error.response_code
  end

  test "should handle 422 unprocessable entity" do
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 422, body: { message: "Unprocessable Entity" }.to_json)

    error = assert_raises(GithubIssuesService::GithubApiError) do
      @service.fetch_issues
    end
    assert_match(/Unprocessable entity - check your GraphQL query/, error.message)
    assert_equal "422", error.response_code
  end

  test "should handle 403 forbidden without rate limit" do
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 403, body: { message: "Forbidden" }.to_json)

    error = assert_raises(GithubIssuesService::GithubApiError) do
      @service.fetch_issues
    end
    assert_match(/Forbidden access to GitHub API/, error.message)
    assert_equal "403", error.response_code
  end

  test "should handle other HTTP error codes" do
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 500, body: { message: "Internal Server Error" }.to_json)

    error = assert_raises(GithubIssuesService::GithubApiError) do
      @service.fetch_issues
    end
    assert_match(/GitHub API error: 500/, error.message)
    assert_equal "500", error.response_code
  end

  test "should handle empty token" do
    error = assert_raises(GithubIssuesService::AuthenticationError) do
      GithubIssuesService.new("owner", "repo", token: "")
    end
    assert_equal "GitHub token is required", error.message
  end

  test "should handle nil repository data in response" do
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: { data: { repository: nil } }.to_json)

    error = assert_raises(GithubIssuesService::RepositoryNotFoundError) do
      @service.fetch_issues
    end
    assert_match(/Repository rails\/rails not found/, error.message)
  end

  test "should handle issues with nil author" do
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        data: {
          repository: {
            issues: {
              pageInfo: { hasNextPage: false, endCursor: nil },
              nodes: [
                {
                  id: "gid://github/Issue/1",
                  number: 1,
                  title: "Test Issue",
                  body: "Test body",
                  state: "OPEN",
                  createdAt: "2024-01-01T00:00:00Z",
                  updatedAt: "2024-01-01T00:00:00Z",
                  closedAt: nil,
                  url: "https://github.com/test/test/issues/1",
                  author: nil,
                  labels: { nodes: [] },
                  assignees: { nodes: [] },
                  milestone: nil
                }
              ]
            }
          }
        }
      }.to_json)

    result = @service.fetch_issues
    issue = result[:issues].first
    assert_nil issue[:author]
  end

  test "should handle issues with nil milestone" do
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        data: {
          repository: {
            issues: {
              pageInfo: { hasNextPage: false, endCursor: nil },
              nodes: [
                {
                  id: "gid://github/Issue/1",
                  number: 1,
                  title: "Test Issue",
                  body: "Test body",
                  state: "OPEN",
                  createdAt: "2024-01-01T00:00:00Z",
                  updatedAt: "2024-01-01T00:00:00Z",
                  closedAt: nil,
                  url: "https://github.com/test/test/issues/1",
                  author: { login: "test", name: "Test", email: "test@example.com" },
                  labels: { nodes: [] },
                  assignees: { nodes: [] },
                  milestone: nil
                }
              ]
            }
          }
        }
      }.to_json)

    result = @service.fetch_issues
    issue = result[:issues].first
    assert_nil issue[:milestone]
  end

  test "should handle issues with closed_at timestamp" do
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        data: {
          repository: {
            issues: {
              pageInfo: { hasNextPage: false, endCursor: nil },
              nodes: [
                {
                  id: "gid://github/Issue/1",
                  number: 1,
                  title: "Test Issue",
                  body: "Test body",
                  state: "CLOSED",
                  createdAt: "2024-01-01T00:00:00Z",
                  updatedAt: "2024-01-01T12:00:00Z",
                  closedAt: "2024-01-01T12:00:00Z",
                  url: "https://github.com/test/test/issues/1",
                  author: { login: "test", name: "Test", email: "test@example.com" },
                  labels: { nodes: [] },
                  assignees: { nodes: [] },
                  milestone: nil
                }
              ]
            }
          }
        }
      }.to_json)

    result = @service.fetch_issues
    issue = result[:issues].first
    assert_not_nil issue[:closed_at]
    assert_instance_of Time, issue[:closed_at]
  end

  test "should handle milestone with nil due date" do
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        data: {
          repository: {
            issues: {
              pageInfo: { hasNextPage: false, endCursor: nil },
              nodes: [
                {
                  id: "gid://github/Issue/1",
                  number: 1,
                  title: "Test Issue",
                  body: "Test body",
                  state: "OPEN",
                  createdAt: "2024-01-01T00:00:00Z",
                  updatedAt: "2024-01-01T00:00:00Z",
                  closedAt: nil,
                  url: "https://github.com/test/test/issues/1",
                  author: { login: "test", name: "Test", email: "test@example.com" },
                  labels: { nodes: [] },
                  assignees: { nodes: [] },
                  milestone: {
                    title: "Test Milestone",
                    description: "Test Description",
                    dueOn: nil
                  }
                }
              ]
            }
          }
        }
      }.to_json)

    result = @service.fetch_issues
    issue = result[:issues].first
    assert_not_nil issue[:milestone]
    assert_nil issue[:milestone][:due_on]
  end

  private

  def stub_successful_graphql_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: successful_graphql_response.to_json)
  end

  def stub_repository_not_found_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: { data: { repository: nil } }.to_json)
  end

  def stub_authentication_error_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 401, body: { message: "Bad credentials" }.to_json)
  end

  def stub_rate_limit_error_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 403, body: { message: "API rate limit exceeded" }.to_json)
  end

  def stub_timeout_error
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_timeout
  end

  def stub_invalid_json_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: "invalid json{")
  end

  def stub_graphql_error_response
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .to_return(status: 200, body: {
        errors: [ { message: "Field 'invalid' doesn't exist on type 'Repository'" } ]
      }.to_json)
  end

  def stub_paginated_graphql_responses
    # First page
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .with(body: hash_including(query: /first: 1(?![\d])/)) # exactly 1, not 10+
      .to_return(status: 200, body: {
        data: {
          repository: {
            issues: {
              pageInfo: { hasNextPage: true, endCursor: "cursor1" },
              nodes: [ sample_issue(1) ]
            }
          }
        }
      }.to_json)

    # Second page
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .with(body: hash_including(query: /after: "cursor1"/))
      .to_return(status: 200, body: {
        data: {
          repository: {
            issues: {
              pageInfo: { hasNextPage: true, endCursor: "cursor2" },
              nodes: [ sample_issue(2) ]
            }
          }
        }
      }.to_json)

    # Third page
    stub_request(:post, GithubIssuesService::GITHUB_GRAPHQL_URL)
      .with(body: hash_including(query: /after: "cursor2"/))
      .to_return(status: 200, body: {
        data: {
          repository: {
            issues: {
              pageInfo: { hasNextPage: false, endCursor: "cursor3" },
              nodes: [ sample_issue(3) ]
            }
          }
        }
      }.to_json)
  end

  def successful_graphql_response
    {
      data: {
        repository: {
          issues: {
            pageInfo: { hasNextPage: true, endCursor: "cursor123" },
            nodes: [ sample_issue(1), sample_issue(2) ]
          }
        }
      }
    }
  end

  def minimal_successful_response
    {
      data: {
        repository: {
          issues: {
            pageInfo: { hasNextPage: false, endCursor: nil },
            nodes: []
          }
        }
      }
    }
  end

  def sample_issue(number)
    {
      id: "gid://github/Issue/#{number}",
      number: number,
      title: "Test Issue #{number}",
      body: "This is test issue #{number}",
      state: "OPEN",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      closedAt: nil,
      url: "https://github.com/rails/rails/issues/#{number}",
      author: {
        login: "testuser",
        name: "Test User",
        email: "test@example.com"
      },
      labels: {
        nodes: [
          {
            name: "bug",
            color: "ff0000",
            description: "Something is not working"
          }
        ]
      },
      assignees: {
        nodes: [
          {
            login: "assignee1",
            name: "Assignee One"
          }
        ]
      },
      milestone: {
        title: "v1.0",
        description: "First release",
        dueOn: "2024-12-31"
      }
    }
  end
end

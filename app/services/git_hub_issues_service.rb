require "net/http"
require "json"
require "uri"

class GitHubIssuesService
  GITHUB_GRAPHQL_URL = "https://api.github.com/graphql"

  class GitHubApiError < StandardError
    attr_reader :response_code, :response_body

    def initialize(message, response_code: nil, response_body: nil)
      super(message)
      @response_code = response_code
      @response_body = response_body
    end
  end

  class RateLimitError < GitHubApiError; end
  class AuthenticationError < GitHubApiError; end
  class RepositoryNotFoundError < GitHubApiError; end

  def initialize(owner, repository_name, token: nil)
    @owner = owner
    @repository_name = repository_name
    @token = token || ENV["GITHUB_TOKEN"]

    raise AuthenticationError, "GitHub token is required" if @token.nil? || @token.empty?
  end

  def fetch_issues(limit: 20, after_cursor: nil, state: "OPEN")
    query = build_issues_query(limit: limit, after_cursor: after_cursor, state: state)

    response = execute_graphql_query(query)
    parse_issues_response(response)
  rescue Net::ReadTimeout, Net::OpenTimeout => e
    raise GitHubApiError, "Network timeout: #{e.message}"
  rescue JSON::ParserError => e
    raise GitHubApiError, "Invalid JSON response: #{e.message}"
  end

  def fetch_all_issues(state: "OPEN", batch_size: 20)
    all_issues = []
    cursor = nil

    loop do
      response = fetch_issues(limit: batch_size, after_cursor: cursor, state: state)
      all_issues.concat(response[:issues])

      break unless response[:has_next_page]
      cursor = response[:end_cursor]
    end

    all_issues
  end

  private

  def build_issues_query(limit:, after_cursor:, state:)
    after_clause = after_cursor ? %Q(, after: "#{after_cursor}") : ""

    <<~GRAPHQL
      query {
        repository(owner: "#{@owner}", name: "#{@repository_name}") {
          issues(first: #{limit}, states: [#{state}], orderBy: {field: CREATED_AT, direction: DESC}#{after_clause}) {
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              id
              number
              title
              body
              state
              createdAt
              updatedAt
              closedAt
              url
              author {
                login
                ... on User {
                  name
                  email
                }
              }
              labels(first: 10) {
                nodes {
                  name
                  color
                  description
                }
              }
              assignees(first: 10) {
                nodes {
                  login
                  name
                }
              }
              milestone {
                title
                description
                dueOn
              }
            }
          }
        }
      }
    GRAPHQL
  end

  def execute_graphql_query(query)
    uri = URI(GITHUB_GRAPHQL_URL)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@token}"
    request["Content-Type"] = "application/json"
    request["User-Agent"] = "GitHubIssuesService/1.0"

    request.body = JSON.generate({ query: query })

    response = http.request(request)

    handle_response_errors(response)

    JSON.parse(response.body, symbolize_names: true)
  end

  def handle_response_errors(response)
    case response.code.to_i
    when 200, 201
      # Success - do nothing
    when 401
      raise AuthenticationError.new("Invalid or missing GitHub token",
                                  response_code: response.code,
                                  response_body: response.body)
    when 403
      if response.body.include?("rate limit")
        raise RateLimitError.new("GitHub API rate limit exceeded",
          response_code: response.code,
          response_body: response.body)
      else
        raise GitHubApiError.new("Forbidden access to GitHub API",
          response_code: response.code,
          response_body: response.body)
      end
    when 404
      raise RepositoryNotFoundError.new("Repository #{@owner}/#{@repository_name} not found",
                                      response_code: response.code,
                                      response_body: response.body)
    when 422
      raise GitHubApiError.new("Unprocessable entity - check your GraphQL query",
        response_code: response.code,
        response_body: response.body)
    else
      raise GitHubApiError.new("GitHub API error: #{response.code} #{response.message}",
        response_code: response.code,
        response_body: response.body)
    end
  end

  def parse_issues_response(response)
    if response[:errors]
      error_messages = response[:errors].map { |e| e[:message] }.join(", ")
      raise GitHubApiError, "GraphQL errors: #{error_messages}"
    end

    repository_data = response.dig(:data, :repository)
    raise RepositoryNotFoundError, "Repository #{@owner}/#{@repository_name} not found" if repository_data.nil?

    issues_data = repository_data[:issues]
    page_info = issues_data[:pageInfo]

    {
      issues: issues_data[:nodes].map { |issue| format_issue(issue) },
      has_next_page: page_info[:hasNextPage],
      end_cursor: page_info[:endCursor]
    }
  end

  def format_issue(issue)
    {
      id: issue[:id],
      number: issue[:number],
      title: issue[:title],
      body: issue[:body],
      state: issue[:state].downcase,
      created_at: Time.parse(issue[:createdAt]),
      updated_at: Time.parse(issue[:updatedAt]),
      closed_at: issue[:closedAt] ? Time.parse(issue[:closedAt]) : nil,
      url: issue[:url],
      author: format_user(issue[:author]),
      labels: issue[:labels][:nodes].map { |label| format_label(label) },
      assignees: issue[:assignees][:nodes].map { |assignee| format_user(assignee) },
      milestone: issue[:milestone] ? format_milestone(issue[:milestone]) : nil
    }
  end

  def format_user(user)
    return nil if user.nil?

    {
      login: user[:login],
      name: user[:name],
      email: user[:email]
    }
  end

  def format_label(label)
    {
      name: label[:name],
      color: label[:color],
      description: label[:description]
    }
  end

  def format_milestone(milestone)
    {
      title: milestone[:title],
      description: milestone[:description],
      due_on: milestone[:dueOn] ? Date.parse(milestone[:dueOn]) : nil
    }
  end
end

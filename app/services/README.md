# Services

This directory contains service objects that encapsulate business logic and external API interactions. Service objects help keep controllers and models thin by extracting complex operations into dedicated, testable classes.

## What are Service Objects?

Service objects are Plain Old Ruby Objects (POROs) that:
- Encapsulate a single business operation or workflow
- Interact with external APIs or complex data processing
- Keep controllers and models focused on their core responsibilities
- Provide a clear, testable interface for complex operations

## Naming Conventions

- Use descriptive names that clearly indicate the service's purpose
- End class names with "Service" (e.g., `GithubIssuesService`)
- Use snake_case for file names (e.g., `github_issues_service.rb`)
- Place in the `app/services/` directory

## Testing

All service objects should have comprehensive test coverage in `test/services/`. Use dependency injection and mocking to test services in isolation from external dependencies.

---

## Available Services

### GithubIssuesService

**Purpose**: Fetches issues from any GitHub repository using the GitHub GraphQL API v4.

**Key Features**:
- GraphQL API integration for efficient data fetching
- Comprehensive error handling (authentication, rate limits, network issues)
- Pagination support for repositories with many issues
- Configurable for any public GitHub repository
- Command-line interface via rake tasks

**Usage**:

```ruby
# Basic usage
service = GithubIssuesService.new('rails', 'rails')
issues = service.fetch_issues(limit: 10)

# Fetch all issues with pagination
all_issues = service.fetch_all_issues(batch_size: 20)

# Fetch closed issues
closed_issues = service.fetch_issues(state: 'CLOSED')

# With custom token
service = GithubIssuesService.new('owner', 'repo', token: 'your_token')
```

**Command Line Interface**:

```bash
# Fetch first 10 issues
rails github:fetch_issues[rails,rails]

# Fetch all issues (with pagination)
rails github:fetch_all_issues[owner,repo]

# Show usage examples
rails github:examples
```

**Environment Variables**:
- `GITHUB_TOKEN`: Your GitHub personal access token (required)
- `DEBUG`: Show detailed error backtraces when debugging

**Error Handling**:
- `GithubIssuesService::AuthenticationError`: Invalid or missing GitHub token
- `GithubIssuesService::RepositoryNotFoundError`: Repository doesn't exist or is private
- `GithubIssuesService::RateLimitError`: GitHub API rate limit exceeded
- `GithubIssuesService::GithubApiError`: General API errors

**Testing**: Uses WebMock for HTTP stubbing with comprehensive test coverage including error scenarios and pagination.

---

## Adding New Services

When adding a new service:

1. Create the service file in `app/services/`
2. Follow the naming conventions above
3. Add comprehensive tests in `test/services/`
4. Document the service in this README
5. Consider adding rake tasks for CLI usage if applicable

Example service structure:

```ruby
class MyNewService
  def initialize(required_params)
    # Initialize with required dependencies
  end

  def call
    # Main service method - use #call for simple services
    # or named methods for more complex services
  end

  private

  # Private helper methods
end
```

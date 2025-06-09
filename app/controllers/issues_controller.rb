class IssuesController < ApplicationController
  before_action :ensure_github_token

  def index
    @owner = params[:owner]
    @repository = params[:repository]
    @state = params[:state] || "open"
    @sort = params[:sort] || "created"
    @direction = params[:direction] || "desc"
    @per_page = (params[:per_page] || 20).to_i.clamp(1, 100)
    @after_cursor = params[:after_cursor]
    @page = params[:page]&.to_i || 1

    # Check for last searched repository in cookie if no params provided
    if @owner.blank? && @repository.blank? && cookies[:last_repo].present?
      last_repo = JSON.parse(cookies[:last_repo]) rescue {}
      if last_repo["owner"].present? && last_repo["repository"].present?
        redirect_to issues_path(owner: last_repo["owner"], repository: last_repo["repository"], state: @state)
        return
      end
    end

    if @owner.present? && @repository.present?
      begin
        @github_service = GithubIssuesService.new(@owner, @repository, token: Current.user.github_token)

        # Convert state parameter to uppercase for GraphQL API, handle "all" case
        graphql_state = @state == "all" ? nil : @state.upcase

        result = @github_service.fetch_issues(limit: @per_page, after_cursor: @after_cursor, state: graphql_state)
        @issues = result[:issues]
        @has_next_page = result[:has_next_page]
        @end_cursor = result[:end_cursor]
        @total_count = result[:total_count]
        @total_pages = @total_count ? (@total_count.to_f / @per_page).ceil : nil

        # Apply client-side sorting if needed (since GraphQL API has limited sorting options)
        @issues = sort_issues(@issues) unless @sort == "created" && @direction == "desc"

        # Save successful search to cookie
        cookies[:last_repo] = {
          value: { owner: @owner, repository: @repository }.to_json,
          expires: 30.days.from_now
        }

      rescue GithubIssuesService::AuthenticationError => e
        @error = "GitHub authentication failed. Please #{view_context.link_to('check your token', edit_account_path, class: 'underline hover:text-red-800 dark:hover:text-red-300', data: { turbo: false })}.".html_safe
      rescue GithubIssuesService::RepositoryNotFoundError => e
        @error = "Repository #{@owner}/#{@repository} not found or you don't have access to it."
      rescue GithubIssuesService::RateLimitError => e
        @error = "GitHub API rate limit exceeded. Please try again later."
      rescue GithubIssuesService::GithubApiError => e
        @error = "GitHub API error: #{e.message}"
      rescue => e
        @error = "An unexpected error occurred: #{e.message}"
      end
    end
  end

  private

  def ensure_github_token
    unless Current.user&.github_token.present?
      redirect_to account_path, alert: "Please configure your GitHub token to view issues."
    end
  end

  def sort_issues(issues)
    case @sort
    when "updated"
      issues.sort_by { |issue| issue[:updated_at] }
    when "title"
      issues.sort_by { |issue| issue[:title].downcase }
    when "state"
      issues.sort_by { |issue| issue[:state] }
    when "created"
      issues.sort_by { |issue| issue[:created_at] }
    else
      issues
    end.then do |sorted_issues|
      @direction == "desc" ? sorted_issues.reverse : sorted_issues
    end
  end
end

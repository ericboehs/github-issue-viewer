namespace :github do
  desc "Fetch issues from a GitHub repository using GraphQL API"
  task :fetch_issues, [ :owner, :repo ] => :environment do |t, args|
    if args[:owner].blank? || args[:repo].blank?
      puts "Usage: rails github:fetch_issues[owner,repo]"
      puts "Example: rails github:fetch_issues[rails,rails]"
      exit 1
    end

    begin
      service = GithubIssuesService.new(args[:owner], args[:repo])

      puts "Fetching issues from #{args[:owner]}/#{args[:repo]}..."

      issues = service.fetch_issues(limit: 10)

      if issues[:issues].empty?
        puts "No open issues found."
      else
        puts "\nFound #{issues[:issues].length} issues:"
        puts "-" * 80

        issues[:issues].each do |issue|
          puts "##{issue[:number]} - #{issue[:title]}"
          puts "  State: #{issue[:state].capitalize}"
          puts "  Author: #{issue[:author][:login] if issue[:author]}"
          puts "  Created: #{issue[:created_at].strftime('%Y-%m-%d %H:%M')}"
          puts "  URL: #{issue[:url]}"

          unless issue[:labels].empty?
            labels = issue[:labels].map { |l| l[:name] }.join(", ")
            puts "  Labels: #{labels}"
          end

          puts
        end

        if issues[:has_next_page]
          puts "Note: This repository has more issues. Use the service directly for pagination."
        end
      end

    rescue GithubIssuesService::AuthenticationError => e
      puts "❌ Authentication Error: #{e.message}"
      puts "Make sure to set your GITHUB_TOKEN environment variable:"
      puts "export GITHUB_TOKEN=your_token_here"
      exit 1
    rescue GithubIssuesService::RepositoryNotFoundError => e
      puts "❌ Repository Error: #{e.message}"
      exit 1
    rescue GithubIssuesService::RateLimitError => e
      puts "❌ Rate Limit Error: #{e.message}"
      puts "Please wait before making more requests."
      exit 1
    rescue GithubIssuesService::GitHubApiError => e
      puts "❌ GitHub API Error: #{e.message}"
      exit 1
    rescue => e
      puts "❌ Unexpected Error: #{e.message}"
      puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
      exit 1
    end
  end

  desc "Fetch all issues from a GitHub repository (with pagination)"
  task :fetch_all_issues, [ :owner, :repo ] => :environment do |t, args|
    if args[:owner].blank? || args[:repo].blank?
      puts "Usage: rails github:fetch_all_issues[owner,repo]"
      puts "Example: rails github:fetch_all_issues[rails,rails]"
      exit 1
    end

    begin
      service = GithubIssuesService.new(args[:owner], args[:repo])

      puts "Fetching ALL issues from #{args[:owner]}/#{args[:repo]}..."
      puts "This may take a while for repositories with many issues..."

      issues = service.fetch_all_issues(batch_size: 20)

      if issues.empty?
        puts "No open issues found."
      else
        puts "\nFetched #{issues.length} total issues:"
        puts "-" * 80

        # Group by state
        by_state = issues.group_by { |issue| issue[:state] }
        by_state.each do |state, state_issues|
          puts "#{state.capitalize}: #{state_issues.length} issues"
        end

        puts "\nMost recent issues:"
        issues.first(10).each do |issue|
          puts "##{issue[:number]} - #{issue[:title]} (#{issue[:state]})"
        end

        if issues.length > 10
          puts "\n... and #{issues.length - 10} more issues"
        end
      end

    rescue GithubIssuesService::AuthenticationError => e
      puts "❌ Authentication Error: #{e.message}"
      puts "Make sure to set your GITHUB_TOKEN environment variable:"
      puts "export GITHUB_TOKEN=your_token_here"
      exit 1
    rescue GithubIssuesService::RepositoryNotFoundError => e
      puts "❌ Repository Error: #{e.message}"
      exit 1
    rescue GithubIssuesService::RateLimitError => e
      puts "❌ Rate Limit Error: #{e.message}"
      puts "Please wait before making more requests."
      exit 1
    rescue GithubIssuesService::GitHubApiError => e
      puts "❌ GitHub API Error: #{e.message}"
      exit 1
    rescue => e
      puts "❌ Unexpected Error: #{e.message}"
      puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
      exit 1
    end
  end

  desc "Show GitHub Issues Service usage examples"
  task examples: :environment do
    puts "GitHub Issues Service Examples:"
    puts "=" * 50
    puts
    puts "1. Fetch first 10 issues from Rails repository:"
    puts "   rails github:fetch_issues[rails,rails]"
    puts
    puts "2. Fetch all issues from a smaller repository:"
    puts "   rails github:fetch_all_issues[owner,repo]"
    puts
    puts "3. Use in Rails console or script:"
    puts "   rails runner \"puts GithubIssuesService.new('rails', 'rails').fetch_issues.inspect\""
    puts
    puts "4. Use in Ruby code:"
    puts "   service = GithubIssuesService.new('owner', 'repo')"
    puts "   issues = service.fetch_issues(limit: 20, state: 'CLOSED')"
    puts "   all_issues = service.fetch_all_issues"
    puts
    puts "Environment Variables:"
    puts "  GITHUB_TOKEN - Your GitHub personal access token (required)"
    puts "  DEBUG        - Show detailed error backtraces"
    puts
    puts "Note: Make sure to set your GITHUB_TOKEN environment variable!"
  end
end

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Rails 8.0.2 application configured to view GitHub issues. It uses modern Rails conventions including:
- Import Maps for JavaScript (no Node.js required)
- Hotwire (Turbo + Stimulus) for frontend interactivity
- SQLite with Solid Suite (Queue, Cache, Cable) for all data persistence
- Docker-based deployment via Kamal

### Documentation
- README.md contains setup instructions and development guidelines
- Contributing guidelines follow conventional commits format
- Licensed under MIT License (see LICENSE file)

## Essential Commands

### Development
```bash
bin/setup          # Initial setup
bin/dev            # Start development server
bin/rails console  # Rails console
bin/rails db:prepare  # Setup database (create, migrate, seed)
```

### Testing
```bash
bin/rails test                    # Run all tests
bin/rails test test/models/user_test.rb  # Run specific test
bin/rails test:system            # Run system tests
```

### Code Quality
```bash
bin/rubocop        # Check Ruby style
bin/rubocop -a     # Auto-fix style issues
bin/brakeman       # Security analysis
```

### JavaScript Dependencies
```bash
bin/importmap pin <package>      # Add JavaScript package
bin/importmap unpin <package>    # Remove JavaScript package
```

## Architecture

### Database Configuration
- Development/Test: SQLite files in `storage/`
- Production: Multiple SQLite databases for primary, cache, queue, and cable
- Migrations: Standard Rails migrations in `db/migrate/`

### Key Technologies
- **Frontend**: Stimulus controllers in `app/javascript/controllers/`
- **Styling**: CSS in `app/assets/stylesheets/`
- **Background Jobs**: Solid Queue (database-backed, no Redis needed)
- **Real-time**: Action Cable with Solid Cable adapter
- **Deployment**: Dockerized via Kamal to servers defined in `config/deploy.yml`

### Code Style
This project follows Rails Omakase conventions. RuboCop is configured to enforce these standards. Always run `bin/rubocop` before committing.

### Testing Approach
- Minitest for all tests
- System tests use Capybara with Selenium
- Tests run in parallel by default
- Use fixtures for test data

### Repository Information
- GitHub URL: https://github.com/oddboehs/github-issue-viewer
- Main branch: main
- PRs should follow conventional commits format
- Link issues in commit messages (e.g., "Closes #123")
# GitHub Issue Viewer

A Rails application for viewing and managing GitHub issues with a clean, modern interface.

## Setup

### Prerequisites
- Ruby 3.3.0 or higher
- SQLite3
- Git

### Installation

1. Clone the repository:
```bash
git clone https://github.com/oddboehs/github-issue-viewer.git
cd github-issue-viewer
```

2. Install dependencies and setup the database:
```bash
bin/setup
```

3. Start the development server:
```bash
bin/dev
```

The application will be available at http://localhost:3000.

### Git Hooks Installation

This project includes git hooks to ensure code quality and automate common tasks:

```bash
bin/install-hooks
```

#### Available Hooks

- **pre-commit**: Runs for Claude-authored commits only
  - Checks EditorConfig compliance (if `editorconfig-checker` is installed)
  - Executes `bin/rubocop` to check code style
  - Runs `bin/rails test` to ensure tests pass
  - Prevents commit if any check fails

- **post-checkout**: Runs automatically when switching branches
  - Runs `bundle install` if Gemfile.lock changed
  - Runs `bin/rails db:migrate` if there are pending migrations
  - Skips during merge/rebase operations and detached HEAD state

### EditorConfig

This project uses [EditorConfig](https://editorconfig.org/) to maintain consistent coding styles. Make sure your editor supports EditorConfig, or install the appropriate plugin.

For command-line validation, install the EditorConfig checker:
```bash
npm install -g editorconfig-checker
```

## Development

### Running tests
```bash
bin/rails test
```

### Code quality checks
```bash
bin/rubocop        # Check Ruby style
bin/brakeman       # Security analysis
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Copyright

Copyright (c) 2025 Eric Boehs

## Contributing

We welcome contributions! Please follow these guidelines:

### Commit Messages
- Use [conventional commits](https://www.conventionalcommits.org/) format
- Examples:
  - `feat: add user authentication`
  - `fix: resolve issue with issue pagination`
  - `docs: update setup instructions`

### Pull Requests
- Link issues in your commit messages to automatically close them when the PR is merged
- Use one of these formats in your commit message:
  - `Fixes #123`
  - `Closes #123`
  - `Resolves #123`
- Example: `feat: add issue filtering\n\nCloses #123`

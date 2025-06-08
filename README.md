# GitHub Issue Viewer

A Rails application for viewing and managing GitHub issues with a clean, intuitive interface.

## Setup

This is a Ruby on Rails application. Follow these steps to get it running:

### Prerequisites

- Ruby 3.4.0 (see `.ruby-version`)
- SQLite3
- Node.js (for asset pipeline)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/oddboehs/github-issue-viewer.git
   cd github-issue-viewer
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Setup the database:
   ```bash
   rails db:prepare
   ```

4. Start the development server:
   ```bash
   rails server
   ```

5. Visit `http://localhost:3000` in your browser

### Testing

Run the test suite:
```bash
rails test
```

For system tests:
```bash
rails test:system
```

## Contributing

We welcome contributions! Please follow these guidelines:

- Use conventional commit messages (e.g., `feat:`, `fix:`, `docs:`, `chore:`)
- Link your commits to issues where applicable using `Fixes #issue-number`
- Follow the existing code style (we use RuboCop Rails Omakase)
- Write tests for new features
- Update documentation as needed

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Copyright (c) 2024 Eric Boehs

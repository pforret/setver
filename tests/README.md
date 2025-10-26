# Setver Test Suite

Comprehensive test suite for the `setver` script using the [bats-core](https://github.com/bats-core/bats-core) testing framework.

## Prerequisites

### Install bats-core

**macOS (using Homebrew):**
```bash
brew install bats-core
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install bats
```

**Manual installation:**
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

**Verify installation:**
```bash
bats --version
```

## Running Tests

### Run all tests
```bash
cd /Users/pforret/Code/bash/setver
bats tests/setver.bats
```

### Run tests with detailed output
```bash
bats tests/setver.bats --tap
```

### Run tests with timing information
```bash
bats tests/setver.bats --timing
```

### Run a specific test
```bash
bats tests/setver.bats --filter "bump major"
```

### Run tests with verbose output (show all commands)
```bash
bats tests/setver.bats --trace
```

## Test Structure

```
tests/
├── README.md           # This file
├── test_helper.bash    # Common test utilities and helper functions
├── setver.bats        # Main test suite
├── composer_no_version/     # Test fixtures
├── composer_only/           # Test fixtures
└── package_no_version/      # Test fixtures
```

## Test Coverage

The test suite covers:

### ✅ Basic Functionality
- Version retrieval from various sources
- Version checking and validation
- Script existence and executability

### ✅ Version Bumping
- **Major version bumps** (1.2.3 → 2.0.0)
  - Lowercase: `major`
  - Uppercase: `MAJOR`
- **Minor version bumps** (1.2.3 → 1.3.0)
  - Standard: `minor`
  - Edge cases (2.9.15 → 2.10.0)
- **Patch version bumps** (1.2.3 → 1.2.4)
  - Standard: `patch`
  - Aliases: `bug`, `bugfix`

### ✅ Manual Version Setting
- Setting specific versions (`setver set 3.2.1`)
- Using `version` alias command

### ✅ Error Handling
- **Typos and invalid input:**
  - `miinor` (should fail)
  - `majoor` (should fail)
  - `ptach` (should fail)
  - `invalid-bump-type` (should fail)
  - Empty bump type (should fail)

### ✅ Git Integration
- Git tag creation with default `v` prefix
- Git tag creation with custom prefix
- Clean working directory validation
- Dirty working directory rejection

### ✅ Multiple File Formats
- VERSION.md updates
- package.json updates (npm)
- composer.json updates (PHP)
- .env.example updates
- Synchronized updates across multiple files

### ✅ Edge Cases
- Version with leading zeros
- Bumping from 0.0.0
- Bumping from 0.9.9 to 1.0.0
- Pre-1.0 version handling

### ✅ Help and Info
- Help flag (`--help`, `-h`)
- Usage information

## Test Helpers

The `test_helper.bash` file provides:

- `setup_test_repo()` - Creates a temporary git repository for testing
- `teardown_test_repo()` - Cleans up the test repository
- `create_version_file()` - Creates VERSION.md with specified version
- `create_package_json()` - Creates package.json with specified version
- `create_composer_json()` - Creates composer.json with specified version
- `create_env_example()` - Creates .env.example with specified version
- `create_git_tag()` - Creates a git tag
- `ensure_clean_git()` - Commits all changes to have a clean working directory
- `get_version_from_file()` - Reads current version from VERSION.md
- `run_setver()` - Executes setver command and captures output

## Continuous Integration

To run these tests in CI/CD pipelines:

### GitHub Actions Example
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install bats
        run: |
          sudo apt-get update
          sudo apt-get install -y bats
      - name: Run tests
        run: bats tests/setver.bats
```

### GitLab CI Example
```yaml
test:
  image: ubuntu:latest
  before_script:
    - apt-get update
    - apt-get install -y bats git
  script:
    - bats tests/setver.bats
```

## Writing New Tests

To add new tests, edit `tests/setver.bats`:

```bash
@test "description of test" {
  # Setup
  create_version_file "1.0.0"
  ensure_clean_git

  # Execute
  run_setver new patch

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" =~ "expected text" ]]

  # Verify
  version=$(get_version_from_file)
  [ "$version" = "1.0.1" ]
}
```

### Test Naming Convention
- Use descriptive names: `setver bump major - from 1.2.3 to 2.0.0`
- Group related tests with common prefixes
- Use hyphens to separate words in test names

### Assertions
- `[ "$status" -eq 0 ]` - Command succeeded
- `[ "$status" -ne 0 ]` - Command failed
- `[[ "$output" =~ "pattern" ]]` - Output contains pattern
- `[ "$variable" = "value" ]` - Exact match

## Troubleshooting

### Tests fail with "command not found"
Ensure setver.sh is executable:
```bash
chmod +x setver.sh
```

### Tests fail with git errors
Ensure git is configured:
```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

### Tests hang or timeout
Some tests require network access for npm/composer. Run tests with timeout:
```bash
timeout 60 bats tests/setver.bats
```

## Test Statistics

Total tests: **50+**

Categories:
- Basic Functionality: 6 tests
- Version Bumping (Major): 3 tests
- Version Bumping (Minor): 2 tests
- Version Bumping (Patch): 3 tests
- Manual Version Setting: 2 tests
- Error Handling: 5 tests
- Git Status: 2 tests
- Multiple File Formats: 4 tests
- Git Tag Prefix: 2 tests
- Edge Cases: 4 tests
- Help and Info: 3 tests

## Contributing

When adding new features to setver:
1. Write tests first (TDD approach)
2. Ensure all existing tests pass
3. Add tests for error conditions
4. Test edge cases
5. Update this README if adding new test categories

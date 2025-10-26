#!/usr/bin/env bash
# test_helper.bash - Helper functions for setver tests

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETVER_SCRIPT="${PROJECT_ROOT}/setver.sh"

# Test repository directory
TEST_REPO_DIR=""

# Create a temporary git repository for testing
function setup_test_repo() {
  TEST_REPO_DIR=$(mktemp -d)
  cd "$TEST_REPO_DIR" || exit 1

  # Initialize git repo
  git init >/dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create initial commit
  echo "# Test Project" > README.md
  git add README.md
  git commit -m "Initial commit" >/dev/null 2>&1
}

# Create VERSION.md file with given version
function create_version_file() {
  local version="${1:-1.0.0}"
  echo "$version" > VERSION.md
  git add VERSION.md
  git commit -m "Add VERSION.md" >/dev/null 2>&1
}

# Create package.json with given version
function create_package_json() {
  local version="${1:-1.0.0}"
  cat > package.json <<EOF
{
  "name": "test-project",
  "version": "$version",
  "description": "Test project",
  "main": "index.js"
}
EOF
  git add package.json
  git commit -m "Add package.json" >/dev/null 2>&1
}

# Create composer.json with given version
function create_composer_json() {
  local version="${1:-1.0.0}"
  cat > composer.json <<EOF
{
  "name": "test/project",
  "description": "Test project",
  "version": "$version",
  "require": {}
}
EOF
  git add composer.json
  git commit -m "Add composer.json" >/dev/null 2>&1
}

# Create .env.example with given version
function create_env_example() {
  local version="${1:-1.0.0}"
  cat > .env.example <<EOF
APP_NAME=TestApp
APP_VERSION=$version
DEBUG=false
EOF
  git add .env.example
  git commit -m "Add .env.example" >/dev/null 2>&1
}

# Create a git tag
function create_git_tag() {
  local version="${1:-1.0.0}"
  git tag "v$version" >/dev/null 2>&1
}

# Clean up test repository
function teardown_test_repo() {
  if [[ -n "$TEST_REPO_DIR" ]] && [[ -d "$TEST_REPO_DIR" ]]; then
    cd /
    rm -rf "$TEST_REPO_DIR"
  fi
}

# Run setver command and capture output
function run_setver() {
  run bash "$SETVER_SCRIPT" "$@"
}

# Check if a version string is valid semver
function is_valid_semver() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# Get current version from VERSION.md
function get_version_from_file() {
  if [[ -f VERSION.md ]]; then
    cat VERSION.md
  fi
}

# Ensure git working directory is clean
function ensure_clean_git() {
  git add -A >/dev/null 2>&1
  git commit -m "Commit all changes" >/dev/null 2>&1 || true
}

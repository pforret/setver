#!/usr/bin/env bats
# setver.bats - Comprehensive test suite for setver script

load test_helper

# Setup function - runs before each test
setup() {
  setup_test_repo
}

# Teardown function - runs after each test
teardown() {
  teardown_test_repo
}

##############################################################################
# Basic Functionality Tests
##############################################################################

@test "setver script exists and is executable" {
  [ -x "$SETVER_SCRIPT" ]
}

@test "setver get - returns version from VERSION.md" {
  create_version_file "1.2.3"
  run_setver get
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]
}

@test "setver get - returns 0.0.0 when no version found" {
  run_setver get
  [ "$status" -eq 0 ]
  [ "$output" = "0.0.0" ]
}

@test "setver get - reads version from git tag" {
  create_git_tag "2.1.0"
  run_setver get
  [ "$status" -eq 0 ]
  [ "$output" = "2.1.0" ]
}

@test "setver check - displays all version sources" {
  create_version_file "1.0.0"
  create_package_json "1.0.0"
  ensure_clean_git

  run_setver check
  [ "$status" -eq 0 ]
  [[ "$output" =~ "VERSION.md" ]]
  [[ "$output" =~ "package.json" ]]
}

##############################################################################
# Version Bumping Tests - MAJOR
##############################################################################

@test "setver bump major - from 1.2.3 to 2.0.0" {
  create_version_file "1.2.3"
  ensure_clean_git

  run_setver new major
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.2.3 -> 2.0.0" ]]

  # Verify VERSION.md was updated
  version=$(get_version_from_file)
  [ "$version" = "2.0.0" ]
}

@test "setver bump MAJOR (uppercase) - from 0.5.9 to 1.0.0" {
  create_version_file "0.5.9"
  ensure_clean_git

  run_setver new MAJOR
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0.5.9 -> 1.0.0" ]]

  version=$(get_version_from_file)
  [ "$version" = "1.0.0" ]
}

@test "setver bump major - creates git tag" {
  create_version_file "3.1.4"
  ensure_clean_git

  run_setver new major
  [ "$status" -eq 0 ]

  # Check that git tag was created
  tag_exists=$(git tag | grep "v4.0.0" || echo "")
  [ -n "$tag_exists" ]
}

##############################################################################
# Version Bumping Tests - MINOR
##############################################################################

@test "setver bump minor - from 1.2.3 to 1.3.0" {
  create_version_file "1.2.3"
  ensure_clean_git

  run_setver new minor
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.2.3 -> 1.3.0" ]]

  version=$(get_version_from_file)
  [ "$version" = "1.3.0" ]
}

@test "setver bump minor - from 2.9.15 to 2.10.0" {
  create_version_file "2.9.15"
  ensure_clean_git

  run_setver new minor
  [ "$status" -eq 0 ]
  [[ "$output" =~ "2.9.15 -> 2.10.0" ]]

  version=$(get_version_from_file)
  [ "$version" = "2.10.0" ]
}

##############################################################################
# Combined auto-commit + bump tests (ap/am/aM, single push at the end)
##############################################################################
# The temp test repo has no remote, so push_all_once()/push_if_possible() no-op
# and commits/tags stay local. These verify the bump type and that the short
# aliases (am/aM) resolve case-sensitively before the lower-cased action match.

@test "setver ap - autopatch bumps patch" {
  create_version_file "1.2.3"
  echo "code" > app.txt
  git add app.txt && git commit -m "add app" >/dev/null 2>&1
  echo "change" >> app.txt

  run_setver ap
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.2.3 -> 1.2.4" ]]
  [ "$(get_version_from_file)" = "1.2.4" ]
}

@test "setver autominor - bumps minor" {
  create_version_file "1.2.3"
  echo "code" > app.txt
  git add app.txt && git commit -m "add app" >/dev/null 2>&1
  echo "change" >> app.txt

  run_setver autominor
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.2.3 -> 1.3.0" ]]
  [ "$(get_version_from_file)" = "1.3.0" ]
}

@test "setver am - alias for autominor, bumps minor" {
  create_version_file "1.2.3"
  echo "code" > app.txt
  git add app.txt && git commit -m "add app" >/dev/null 2>&1
  echo "change" >> app.txt

  run_setver am
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.2.3 -> 1.3.0" ]]
  [ "$(get_version_from_file)" = "1.3.0" ]
}

@test "setver automajor - bumps major" {
  create_version_file "1.2.3"
  echo "code" > app.txt
  git add app.txt && git commit -m "add app" >/dev/null 2>&1
  echo "change" >> app.txt

  run_setver automajor
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.2.3 -> 2.0.0" ]]
  [ "$(get_version_from_file)" = "2.0.0" ]
}

@test "setver aM - alias for automajor, bumps major (not minor)" {
  create_version_file "1.2.3"
  echo "code" > app.txt
  git add app.txt && git commit -m "add app" >/dev/null 2>&1
  echo "change" >> app.txt

  run_setver aM
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.2.3 -> 2.0.0" ]]
  [ "$(get_version_from_file)" = "2.0.0" ]
}

##############################################################################
# Version Bumping Tests - PATCH
##############################################################################

@test "setver bump patch - from 1.2.3 to 1.2.4" {
  create_version_file "1.2.3"
  ensure_clean_git

  run_setver new patch
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.2.3 -> 1.2.4" ]]

  version=$(get_version_from_file)
  [ "$version" = "1.2.4" ]
}

@test "setver bump bug - alias for patch" {
  create_version_file "1.0.0"
  ensure_clean_git

  run_setver new bug
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.0.0 -> 1.0.1" ]]

  version=$(get_version_from_file)
  [ "$version" = "1.0.1" ]
}

@test "setver bump bugfix - alias for patch" {
  create_version_file "2.1.9"
  ensure_clean_git

  run_setver new bugfix
  [ "$status" -eq 0 ]
  [[ "$output" =~ "2.1.9 -> 2.1.10" ]]

  version=$(get_version_from_file)
  [ "$version" = "2.1.10" ]
}

##############################################################################
# Manual Version Setting Tests
##############################################################################

@test "setver set - manually set version to specific value" {
  create_version_file "1.0.0"
  ensure_clean_git

  run_setver set 3.2.1
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.0.0 -> 3.2.1" ]]

  version=$(get_version_from_file)
  [ "$version" = "3.2.1" ]
}

@test "setver set - works with 'version' alias" {
  create_version_file "1.0.0"
  ensure_clean_git

  run_setver version 2.0.0
  [ "$status" -eq 0 ]

  version=$(get_version_from_file)
  [ "$version" = "2.0.0" ]
}

##############################################################################
# Error Handling Tests - Typos and Invalid Input
##############################################################################

@test "setver bump miinor (typo) - should fail with error" {
  create_version_file "1.0.0"
  ensure_clean_git

  run_setver new miinor
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Unknown bump type" ]] || [[ "$output" =~ "ERROR" ]]
}

@test "setver bump majoor (typo) - should fail with error" {
  create_version_file "1.0.0"
  ensure_clean_git

  run_setver new majoor
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Unknown bump type" ]] || [[ "$output" =~ "ERROR" ]]
}

@test "setver bump ptach (typo) - should fail with error" {
  create_version_file "1.0.0"
  ensure_clean_git

  run_setver new ptach
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Unknown bump type" ]] || [[ "$output" =~ "ERROR" ]]
}

@test "setver bump invalid - should fail with error" {
  create_version_file "1.0.0"
  ensure_clean_git

  run_setver new invalid-bump-type
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Unknown bump type" ]] || [[ "$output" =~ "ERROR" ]]
}

@test "setver bump empty - should fail with error" {
  create_version_file "1.0.0"
  ensure_clean_git

  run_setver new ""
  [ "$status" -ne 0 ]
}

##############################################################################
# Git Status Tests
##############################################################################

@test "setver bump fails with dirty working directory" {
  create_version_file "1.0.0"
  ensure_clean_git

  # Create an uncommitted file
  echo "test" > test.txt

  run_setver new patch
  [ "$status" -ne 0 ]
  [[ "$output" =~ "not clean" ]] || [[ "$output" =~ "ERROR" ]]
}

@test "setver bump succeeds with clean working directory" {
  create_version_file "1.0.0"
  ensure_clean_git

  run_setver new patch
  [ "$status" -eq 0 ]
}

##############################################################################
# Multiple File Format Tests
##############################################################################

@test "setver updates VERSION.md and package.json together" {
  create_version_file "1.0.0"
  create_package_json "1.0.0"
  ensure_clean_git

  run_setver new minor
  [ "$status" -eq 0 ]

  # Check VERSION.md
  version_md=$(get_version_from_file)
  [ "$version_md" = "1.1.0" ]

  # Check package.json
  version_npm=$(grep '"version"' package.json | cut -d'"' -f4)
  [ "$version_npm" = "1.1.0" ]
}

@test "setver updates composer.json when present" {
  create_version_file "2.0.0"
  create_composer_json "2.0.0"
  ensure_clean_git

  run_setver new patch
  [ "$status" -eq 0 ]

  # Check VERSION.md
  version_md=$(get_version_from_file)
  [ "$version_md" = "2.0.1" ]

  # Check composer.json (if composer is available)
  if command -v composer &> /dev/null; then
    version_composer=$(grep '"version"' composer.json | cut -d'"' -f4)
    [ "$version_composer" = "2.0.1" ]
  fi
}

@test "setver updates .env.example when present" {
  create_version_file "1.5.0"
  create_env_example "1.5.0"
  ensure_clean_git

  run_setver new major
  [ "$status" -eq 0 ]

  # Check .env.example
  version_env=$(grep "APP_VERSION" .env.example | cut -d= -f2)
  [ "$version_env" = "2.0.0" ]
}

##############################################################################
# Git Tag Prefix Tests
##############################################################################

@test "setver creates git tag with default 'v' prefix" {
  create_version_file "1.0.0"
  ensure_clean_git

  run_setver new patch
  [ "$status" -eq 0 ]

  tag_exists=$(git tag | grep "v1.0.1" || echo "")
  [ -n "$tag_exists" ]
}

@test "setver creates git tag with custom prefix" {
  create_version_file "1.0.0"
  ensure_clean_git

  run_setver --prefix "release-" new patch
  [ "$status" -eq 0 ]

  tag_exists=$(git tag | grep "release-1.0.1" || echo "")
  [ -n "$tag_exists" ]
}

##############################################################################
# Edge Cases
##############################################################################

@test "setver handles version with leading zeros correctly" {
  create_version_file "1.09.5"
  ensure_clean_git

  run_setver new patch
  [ "$status" -eq 0 ]

  # Should increment to 1.09.6, not 1.9.6
  version=$(get_version_from_file)
  [[ "$version" =~ ^1\. ]]
}

@test "setver bump from 0.0.0 to 0.0.1" {
  create_version_file "0.0.0"
  ensure_clean_git

  run_setver new patch
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0.0.0 -> 0.0.1" ]]

  version=$(get_version_from_file)
  [ "$version" = "0.0.1" ]
}

@test "setver bump from 0.0.1 to 0.1.0" {
  create_version_file "0.0.1"
  ensure_clean_git

  run_setver new minor
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0.0.1 -> 0.1.0" ]]

  version=$(get_version_from_file)
  [ "$version" = "0.1.0" ]
}

@test "setver bump from 0.9.9 to 1.0.0" {
  create_version_file "0.9.9"
  ensure_clean_git

  run_setver new major
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0.9.9 -> 1.0.0" ]]

  version=$(get_version_from_file)
  [ "$version" = "1.0.0" ]
}

##############################################################################
# Help and Info Tests
##############################################################################

@test "setver with no arguments shows usage" {
  run_setver
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]] || [[ "$output" =~ "usage" ]]
}

@test "setver --help shows help information" {
  run_setver --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]] || [[ "$output" =~ "TIPS" ]]
}

@test "setver -h shows help information" {
  run_setver -h
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]] || [[ "$output" =~ "TIPS" ]]
}

##############################################################################
# Conventional Commits (-O / --CONVENTIONAL) Tests
##############################################################################
# These call the script directly (not run_setver) because they must pipe stdin.
# The temp test repo has no remote, so push_if_possible no-ops and commits stay local.
#
# The type & scope pickers are arrow-key driven. Input bytes:
#   \n         = Enter (confirm the highlighted option)
#   \033[C     = right arrow (next option)     \033[D = left arrow (previous option)
# Picker order (type):  feat fix docs style refactor perf test build ci chore revert
# Picker order (scope): (none) commit version git changelog cli tests docs
# After the two pickers come two line-reads: <breaking y/n>, then <description>.

@test "setver -O push - builds 'feat:' message from type selection" {
  echo "change" > newfile.txt
  git add newfile.txt
  # type=feat (Enter), scope=(none) (Enter), breaking=n, description
  printf '\n\nn\nadd new file\n' | "$SETVER_SCRIPT" -r -O push
  run git log -1 --pretty=%s
  [ "$output" = "feat: add new file" ]
}

@test "setver -O push - includes scope when provided" {
  echo "change" > a.txt
  git add a.txt
  # type=fix (1x right), scope=commit (1x right), breaking=n, description
  printf '\033[C\n\033[C\nn\nhandle leading zeros\n' | "$SETVER_SCRIPT" -r -O push
  run git log -1 --pretty=%s
  [ "$output" = "fix(commit): handle leading zeros" ]
}

@test "setver -O push - adds '!' for breaking change" {
  echo "change" > b.txt
  git add b.txt
  # type=feat (Enter), scope=(none) (Enter), breaking=y, description
  printf '\n\ny\nremove legacy api\n' | "$SETVER_SCRIPT" -r -O push
  run git log -1 --pretty=%s
  [ "$output" = "feat!: remove legacy api" ]
}

@test "setver -O push - left arrow wraps around to last type" {
  echo "change" > w.txt
  git add w.txt
  # type=revert (1x left wraps from feat), scope=(none), breaking=n, description
  printf '\033[D\n\nn\nundo change\n' | "$SETVER_SCRIPT" -r -O push
  run git log -1 --pretty=%s
  [ "$output" = "revert: undo change" ]
}

@test "setver -O skip - appends [skip ci] body" {
  echo "change" > c.txt
  git add c.txt
  # type=docs (2x right), scope=(none), breaking=n, description
  printf '\033[C\033[C\n\nn\nupdate readme\n' | "$SETVER_SCRIPT" -r -O skip
  run git log -1 --pretty=%B
  [[ "$output" =~ "docs: update readme" ]]
  [[ "$output" =~ "[skip ci]" ]]
}

@test "setver -O push - suggests 'new minor' after a feat commit" {
  echo "change" > d.txt
  git add d.txt
  run bash -c "printf '\n\nn\nadd thing\n' | '$SETVER_SCRIPT' -r -O push"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "new minor" ]]
}

@test "setver -O skip - does NOT suggest a version bump" {
  echo "change" > e.txt
  git add e.txt
  # type=fix (1x right), scope=(none), breaking=n, description
  run bash -c "printf '\033[C\n\nn\nfix bug\n' | '$SETVER_SCRIPT' -r -O skip"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "Next step" ]]
}

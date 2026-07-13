#!/usr/bin/env bats
# prep.bats - tests for the 'setver prep' prepared-release command family
#
# The temp test repo has no remote, so push_if_possible()/push_all_once() no-op
# and any created tag stays local - which is exactly what we assert on.

load test_helper

setup() {
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

# helper: number of git tags in the current repo
tag_count() { git tag | grep -c . || true; }

##############################################################################
# The core invariant: no tag is created/pushed while a prep is active
##############################################################################

@test "prep: active prep suppresses tags for 'ap' and 'new'" {
  create_version_file "1.4.3"

  run_setver prep major
  [ "$status" -eq 0 ]

  local before
  before=$(tag_count)

  # 'ap' bumps the version files but must NOT create a tag
  echo "work" >> README.md
  run_setver -f ap
  [ "$status" -eq 0 ]
  [ "$(cat VERSION.md)" = "2.0.1" ]

  # 'new patch' must NOT create a tag either
  run_setver new patch
  [ "$status" -eq 0 ]
  [ "$(cat VERSION.md)" = "2.0.2" ]

  # highest-value assertion: the tag count never moved
  [ "$(tag_count)" -eq "$before" ]
}

##############################################################################
# prep major / minor
##############################################################################

@test "prep major from 1.4.3 creates prep-v2, target 2.0.0, sets files, no tag" {
  create_version_file "1.4.3"

  run_setver prep major
  [ "$status" -eq 0 ]

  [ "$(git rev-parse --abbrev-ref HEAD)" = "prep-v2" ]
  [ -f .setver-prep ]
  grep -q "SETVER_PREP_TARGET=2.0.0" .setver-prep
  grep -q "SETVER_PREP_LEVEL=major" .setver-prep
  [ "$(cat VERSION.md)" = "2.0.0" ]
  [ "$(tag_count)" -eq 0 ]
}

@test "prep minor from 1.4.3 creates prep-v1.5 with target 1.5.0" {
  create_version_file "1.4.3"

  run_setver prep minor
  [ "$status" -eq 0 ]

  [ "$(git rev-parse --abbrev-ref HEAD)" = "prep-v1.5" ]
  grep -q "SETVER_PREP_TARGET=1.5.0" .setver-prep
  [ "$(cat VERSION.md)" = "1.5.0" ]
  [ "$(tag_count)" -eq 0 ]
}

@test "prep patch is rejected with a hint to use ap" {
  create_version_file "1.4.3"
  run_setver prep patch
  [ "$status" -ne 0 ]
  [[ "$output" == *"not supported"* ]]
}

##############################################################################
# prep finish
##############################################################################

@test "prep finish releases exactly v2.0.0 on base history" {
  create_version_file "1.4.3"
  local base
  base=$(git rev-parse --abbrev-ref HEAD)

  run_setver prep major
  echo "drift" >> README.md
  run_setver -f ap            # version files drift to 2.0.1

  git checkout -q "$base"
  git merge -q --no-ff -m "merge prep" prep-v2

  run_setver prep finish
  [ "$status" -eq 0 ]

  [ ! -f .setver-prep ]                       # marker consumed
  [ "$(cat VERSION.md)" = "2.0.0" ]           # clean target, not the drift
  run git tag
  [[ "$output" == *"v2.0.0"* ]]
  [ "$(git tag | grep -c '^v2')" -eq 1 ]      # exactly one 2.x tag
}

@test "prep finish --keep-version releases the drifted version" {
  create_version_file "1.4.3"
  local base
  base=$(git rev-parse --abbrev-ref HEAD)

  run_setver prep major
  echo "a" >> README.md ; run_setver -f ap    # 2.0.1
  echo "b" >> README.md ; run_setver -f ap    # 2.0.2

  git checkout -q "$base"
  git merge -q --no-ff -m "merge prep" prep-v2

  run_setver prep finish --keep-version
  [ "$status" -eq 0 ]

  run git tag
  [[ "$output" == *"v2.0.2"* ]]
  [[ "$output" != *"v2.0.0"* ]]
  [ "$(cat VERSION.md)" = "2.0.2" ]
}

@test "prep finish refuses when prep branch is not merged into base" {
  create_version_file "1.4.3"
  local base
  base=$(git rev-parse --abbrev-ref HEAD)

  run_setver prep major

  # bring ONLY the marker to base (not a real merge of the prep commits)
  git checkout -q "$base"
  git checkout -q prep-v2 -- .setver-prep
  git add .setver-prep
  git commit -qm "marker only, not merged"

  run_setver prep finish
  [ "$status" -ne 0 ]
  [ "$(git tag | grep -c '^v2')" -eq 0 ]      # no release tag created
}

##############################################################################
# prep pause / resume
##############################################################################

@test "prep pause --stash then resume round-trips uncommitted work" {
  create_version_file "1.4.3"
  local base
  base=$(git rev-parse --abbrev-ref HEAD)

  run_setver prep major
  echo "uncommitted work" >> README.md

  run_setver prep pause --stash
  [ "$status" -eq 0 ]
  [ "$(git rev-parse --abbrev-ref HEAD)" = "$base" ]
  [ -f .git/setver-prep-session ]
  [ -z "$(git status -s)" ]                   # stash left a clean tree

  run_setver prep resume
  [ "$status" -eq 0 ]
  [ "$(git rev-parse --abbrev-ref HEAD)" = "prep-v2" ]
  grep -q "uncommitted work" README.md        # stash popped back
  [ ! -f .git/setver-prep-session ]
}

@test "prep pause refuses a dirty tree without --stash" {
  create_version_file "1.4.3"
  run_setver prep major
  echo "dirty" >> README.md

  run_setver prep pause
  [ "$status" -ne 0 ]
  [ "$(git rev-parse --abbrev-ref HEAD)" = "prep-v2" ]
}

##############################################################################
# prep status
##############################################################################

@test "prep status reports target + suppression on a prep branch, else nothing" {
  create_version_file "1.4.3"

  run_setver prep status
  [[ "$output" == *"no prep in progress"* ]]

  run_setver prep major
  run_setver prep status
  [ "$status" -eq 0 ]
  [[ "$output" == *"preparing v2.0.0"* ]]
  [[ "$output" == *"suppressed"* ]]
}

##############################################################################
# Cross-cutting: hotfix during a prep
##############################################################################

@test "hotfix on a branch off the release tag still tags while a prep is active" {
  create_version_file "1.4.3"
  create_git_tag "1.4.3"

  run_setver prep major                       # prep active on prep-v2

  # hotfix branches off the v1.4.3 tag -> carries no .setver-prep marker
  git checkout -q -b hotfix-1.4.4 v1.4.3
  [ ! -f .setver-prep ]
  echo "fix" >> README.md

  run_setver -f ap
  [ "$status" -eq 0 ]
  run git tag
  [[ "$output" == *"v1.4.4"* ]]               # hotfix is NOT suppressed
}

##############################################################################
# prep abort
##############################################################################

@test "prep abort deletes the prep branch and returns to base" {
  create_version_file "1.4.3"
  local base
  base=$(git rev-parse --abbrev-ref HEAD)

  run_setver prep major
  run_setver -f prep abort
  [ "$status" -eq 0 ]

  [ "$(git rev-parse --abbrev-ref HEAD)" = "$base" ]
  run git show-ref --verify --quiet refs/heads/prep-v2
  [ "$status" -ne 0 ]                         # branch is gone
}

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `setver` - a semantic versioning helper script for managing version numbers across multiple file formats. It's a bash script built with the bashew framework that automates version management for various project types.

## Core Architecture

### Main Script Structure
- **setver.sh**: The main executable script (1,280 lines) based on bashew framework
- **setver**: Symlink to setver.sh for easier execution
- **VERSION.md**: Current version file (2.3.3)
- **package.json**: NPM package configuration
- **composer.json**: PHP Composer package configuration

### Supported Version Sources
The script can read and update versions from:
1. **VERSION.md**: For bash projects
2. **Git tags**: Using semantic versioning tags (e.g., v1.2.3)
3. **composer.json**: For PHP projects
4. **package.json**: For NPM/Node.js projects
5. **\*.sh files**: For bash scripts with version variables
6. **.env.example**: For environment-based version configuration

## Key Commands

### Version Management
- `./setver get` - Get current version from any available source
- `./setver check` - Check all version sources for consistency
- `./setver set <version>` - Set specific version (e.g., 1.2.3)
- `./setver new <type>` - Bump version by type (major/minor/patch)

### Git Operations
- `./setver auto` - Auto-commit with an auto-generated message and push to remote
- `./setver autopatch` or `./setver ap` - Auto-commit, push, and bump patch version
- `./setver push` - Commit and push changes
- `./setver skip` - Commit with [skip ci] flag

### Utilities
- `./setver md` - Create VERSION.md file if it doesn't exist
- `./setver message` - Show the auto-generated message for current changes
- `./setver history` - Show compact git history
- `./setver changelog` - Add entry to CHANGELOG.md

## Development Workflow

### Version Bumping Process
1. Script checks git working directory is clean
2. Determines the current version from priority order: VERSION.md → git tags → composer.json → package.json → .sh files
3. Updates all relevant files with the new version
4. Commits changes with "setver: set version to X.Y.Z" message
5. Creates git tag with version
6. Pushes commits and tags to remote

### Testing
- **Test Framework**: bats-core (Bash Automated Testing System)
- **Test Location**: `tests/setver.bats` (50+ comprehensive tests)
- **Test Helper**: `tests/test_helper.bash` (common test utilities)
- **Installation**: `tests/install-bats.sh` (automatic bats installation)
- **Run Tests**: `tests/run-tests.sh` or `bats tests/setver.bats`
- **Test Coverage**:
  - Version bumping (major/minor/patch)
  - Error handling (typos, invalid input)
  - Git integration (tags, clean status)
  - Multiple file format updates
  - Edge cases (0.0.0, leading zeros)
- **CI/CD Ready**: Tests can be integrated into GitHub Actions, GitLab CI, etc.

## Configuration Options

### Flags
- `-f|--force`: Skip confirmation prompts
- `-r|--root`: Don't check if in git repo root
- `-C|--SKIP_COMPOSER`: Skip composer.json updates
- `-N|--SKIP_NPM`: Skip package.json updates
- `-v|--verbose`: Enable verbose output
- `-q|--quiet`: Suppress output

### Options
- `-p|--prefix`: Git tag prefix (default: "v")
- `-l|--log_dir`: Log file directory
- `-t|--tmp_dir`: Temporary file directory

## Important Notes

- Script requires a clean git working directory for version operations
- Automatically detects available version sources and package managers
- Supports multiple git hosting platforms (GitHub, Bitbucket, GitLab)
- Built on the `bashew` framework for robust bash scripting
- Uses semantic versioning principles (major.minor.patch)
- Automatically generates commit messages based on git status
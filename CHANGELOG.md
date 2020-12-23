![Changelog v1.0.0](https://img.shields.io/badge/CHANGELOG-v1.0.0-orange) 
# CHANGELOG
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
- add content to CHANGELOG.md automatically
 
## [1.12.11] - 2020-12-23
### Added/changed
- remove traces of semver.sh
- remove tmp folders
- add logo, created with splashmark 

## [1.11.0] - 2020-08-13
### Added/changed
- add .env.example versioning
- fix git tag retrieval so that 1.10.0 > 1.9.0
 
## [1.9.0] - 2020-08-13
### Added/changed
- add semver.sh auto / add semver.sh skip-ci
- add semver.sh history
- fix all Github issues
 
## [1.7.5] - 2020-08-06
### Added/changed
- Add [skip ci] test to CI yml's
- Adapt README.md
 
## [1.7.0] - 2020-08-06
### Added/changed
- Write temp file with echo
- Auto-add new lines to CHANGELOG.md with 'semver.sh changes'
- Add support for automatic CHANGELOG appending
 
## [1.6.0] - 2020-08-06
### Added
- add [skip_ci] to git commits purely related to versioning

## [1.5.3] - 2020-08-01
### Added
- also works for npm/package.json
- also supports `semver.sh push`


## [1.0.0] - 2020-08-01
### Added
- should take care of composer.json and git tag versions

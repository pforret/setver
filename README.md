![GitHub tag](https://img.shields.io/github/v/tag/pforret/semver)
![Shellcheck CI](https://github.com/pforret/semver/workflows/Shellcheck%20CI/badge.svg)
![Bash CI](https://github.com/pforret/semver/workflows/Bash%20CI/badge.svg)
![GitHub](https://img.shields.io/github/license/pforret/semver)

# semver.sh

* Semantic Versioning helper script
* get and set semver version numbers
* works for PHP packages: composer.json, packagist, git tag
* works for bash/shell scripts: git tag, VERSION.md

## Usage

* `semver.sh push`: short for git commit -a && git push
* `semver.sh get`: get current version (from git tag and composer)
* `semver.sh check`: compare versions of git tag and composer
* `semver.sh set <version>`: set current version through git tag and composer
* `semver.sh set major`: add +1 major version e.g. 2.4.17 -> 3.0.0
* `semver.sh set minor`: add +1 minor version e.g. 2.4.17 -> 2.5.0
* `semver.sh set patch`: add +1 patch version e.g. 2.4.17 -> 2.4.18
* `semver.sh set auto`: same as patch
* `semver.sh set fix`: same as patch

## Install

### per project 

1. download https://raw.githubusercontent.com/pforret/semver/master/semver.sh in the root of your git repo
2. `chmod +x semver.sh`
3. `./semver.sh check`

### global
1. git clone this repo
2. symlink the script to a location in your path: `ln -s <cloned_folder>/semver.sh /usr/local/bin/`
3. call semver.sh from the root of your git repo

or with [basher](https://github.com/basherpm/basher)

`basher install pforret/semver`

## References
* https://semver.org/

		Given a version number MAJOR.MINOR.PATCH, increment the:
		MAJOR version when you make incompatible API changes,
		MINOR version when you add functionality in a backwards compatible manner, and
		PATCH version when you make backwards compatible bug fixes.

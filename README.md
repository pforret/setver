![GitHub tag](https://img.shields.io/github/v/tag/pforret/setver)
![Shellcheck CI](https://github.com/pforret/setver/workflows/Shellcheck%20CI/badge.svg)
![Bash CI](https://github.com/pforret/setver/workflows/Bash%20CI/badge.svg)
![GitHub](https://img.shields.io/github/license/pforret/setver)
[![basher install](https://img.shields.io/badge/basher-install-white?logo=gnu-bash&style=flat)](https://basher.gitparade.com/package/)

# setver
![setver logo](setver.jpg)

## TL;DR

to push new changes to Github/Bitbucket

    setver push
    
to bump the version 

    setver new minor
    
## Supported versioning 

* Semantic Versioning helper script, to get and set semver version numbers
* handles versioning for `composer.json`: for PHP, composer packages
* handles versioning for `package.json`: for node, npm
* handles versioning for `.env.example`: for PHP, Python, Ruby
* handles versioning for `VERSION.md`: for bash
* handles versioning for `shellscript.sh`: for bash
* handles versioning by '`git tag`': for Github, Bitbucket

## Usage
```
Program: setver 2.3.0 by peter@forret.com
Updated: Mar 18 16:57:57 2023
Description: setver but based on bashew
Usage: setver [-h] [-q] [-v] [-f] [-r] [-C] [-N] [-l <log_dir>] [-t <tmp_dir>] [-p <prefix>] <action> <input?>
Flags, options and parameters:
    -h|--help        : [flag] show usage [default: off]
    -q|--quiet       : [flag] no output [default: off]
    -v|--verbose     : [flag] output more [default: off]
    -f|--force       : [flag] do not ask for confirmation [default: off]
    -r|--root        : [flag] do not check if in root folder of repo [default: off]
    -C|--SKIP_COMPOSER: [flag] do not modify composer.json [default: off]
    -N|--SKIP_NPM    : [flag] do not modify package.json (for npm) [default: off]
    -l|--log_dir <?> : [option] folder for log files   [default: /Users/pforret/log/setver]
    -t|--tmp_dir <?> : [option] folder for temp files  [default: /tmp/setver]
    -p|--prefix <?>  : [option] prefix to use for git tags  [default: v]
    <action>         : [parameter] action to perform: get/check/push/set/new/md/message/auto/autopatch/ap/skip/changelog/history
    <input>          : [parameter] input text (optional)
                                                                                                             
                                  
### TIPS & EXAMPLES
* use setver get to get the version (returns 1 line with the version nr)
* use setver check to get all versions available in this repo
* use setver message to get the current auto-generated commit message
* use setver auto to do commit/push with auto-generated commit message
* use setver autopatch or setver ap to do commit/push with auto-generated commit message & bump patch version
* use setver autominor to do commit/push with auto-generated commit message & bump minor version
* use setver skip to do commit/push with auto-generated commit message and skip GH actions
* use setver md to generate a correct VERSION.md file, if it does not yet exist
* use setver new major/minor/patch to bump version number with 1
* use setver set x.y.z to set new version number
* use setver push to do commit/push with auto-generated commit message
* use setver history to show the git history in a compact format
* use setver check to check if this script is ready to execute and what values the options/flags are
  setver check
* use setver env to generate an example .env file
  setver env > .env
* use setver update to update to the latest version
  setver check
* >>> bash script created with pforret/bashew
* >>> for bash development, also check out pforret/setver and pforret/progressbar
```

## Example:

    > setver new patch   
    ✔  version 1.12.0 -> 1.12.1
    ✔  set version in package.json
    ✔  set version in composer.json
    ✔  set version in .env.example
    ✔  set version in VERSION.md
    ✔  set version in shellscript.sh
    ✔  commit and push changed files
    ✔  push tags to git@github.com:pforret/setver.git
    ✔  to create a release, go to https://github.com/pforret/setver


## Installation

with [basher](https://github.com/basherpm/basher)

    basher install pforret/setver

or the hard way

    # clone this repo
    git clone https://github.com/pforret/setver.git
    # if you want the script to be in your path
    ln -s <cloned_folder>/setver /usr/local/bin/

## References
* https://semver.org/

		Given a version number MAJOR.MINOR.PATCH, increment the:
		MAJOR version when you make incompatible API changes,
		MINOR version when you add functionality in a backwards compatible manner, and
		PATCH version when you make backwards compatible bug fixes.

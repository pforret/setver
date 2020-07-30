# semver.sh
Get/Set package versions for composer.json/git tag -- bash script


## Usage

    # semver.sh v1.0 - by Peter Forret <peter@forret.com>
    # Usage:
        `semver.sh get`: get current version (from git tag and composer)
        `semver.sh check`: compare versions of git tag and composer
        `semver.sh set <version>`: set current version through git tag and composer
        `semver.sh set auto`: add +1 bugfix version X.Y.Z ->X.Y.Z+1
## Install

### per project 

1. download https://raw.githubusercontent.com/pforret/semver/master/semver.sh in the root of your git repo
2. `chmod +x semver.sh`
3. `./semver.sh check`

### global
1. git clone this repo
2. symlink the script to a location in your path: `ln -s <cloned_folder>/semver.sh /usr/local/bin/`
3. call semver.sh from the root of your git repo

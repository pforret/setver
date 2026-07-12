![GitHub tag](https://img.shields.io/github/v/tag/pforret/setver)
![Shellcheck CI](https://github.com/pforret/setver/workflows/Shellcheck%20CI/badge.svg)
![Bash CI](https://github.com/pforret/setver/workflows/Bash%20CI/badge.svg)
[![BATS tests](https://github.com/pforret/setver/actions/workflows/tests.yml/badge.svg)](https://github.com/pforret/setver/actions/workflows/tests.yml)
![GitHub](https://img.shields.io/github/license/pforret/setver)
[![basher install](https://img.shields.io/badge/basher-install-white?logo=gnu-bash&style=flat)](https://basher.gitparade.com/package/)

# setver
![setver logo](setver.jpg)

## TL;DR
```bash
# to commit (and ask for message) and push new changes to GitHub/Bitbucket
setver push
    
# to commit with automatic commit message and push new changes to GitHub/Bitbucket
setver auto
    
# to just bump the version 
setver new minor

# to commit, push and bump the version in 1 go
setver ap               # stands for autopatch    
```
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
Program: setver 2.4.0 by peter@forret.com
Updated: Oct 26 16:37:07 2025
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
    <action>         : [parameter] action to perform: get/check/push/set/new/md/message/auto/autopatch/ap/autominor/automajor/prep/skip/changelog/history
    <input>          : [parameter] input text, or prep sub-action (optional)
                                                                                                             
                                  
### TIPS & EXAMPLES
* use 'setver get' to get the version (returns 1 line with the version nr)
* use 'setver check' to get all versions available in this repo
* use 'setver message' to get the current auto-generated commit message
* use 'setver auto' to do commit/push with auto-generated commit message
* use 'setver autopatch' or 'setver ap' to do commit/push with auto-generated commit message & bump patch version
* use 'setver autominor' to do commit/push with auto-generated commit message & bump minor version
* use 'setver automajor' to do commit/push with auto-generated commit message & bump major version
* use 'setver prep major' or 'setver prep minor' to start a prepared release (git tags stay suppressed until you finish)
* use 'setver prep finish' to create the single release tag once the prepared work is merged onto the base branch
* use 'setver prep status/pause/resume/abort' to inspect or manage a prepared release
* use 'setver skip' to do commit/push with auto-generated commit message and skip GH actions
* use 'setver md' to generate a correct VERSION.md file, if it does not yet exist
* use 'setver set x.y.z' to set new version number
* use 'setver new major/minor/patch' to bump version number with 1
* use 'setver bump major/minor/patch' to bump version number with 1
* use 'setver push' to do commit/push with auto-generated commit message
* use 'setver history' to show the git history in a compact format
* use 'setver check' to check if this script is ready to execute and what values the options/flags are
* use 'setver env' to generate an example .env file (setver env > .env)
* use 'setver update' to update to the latest version
* >>> bash script created with pforret/bashew
```

## Smart commit & push helpers

`setver auto`, `setver ap` and `setver push` include a few safety checks before committing:

* **No git repo yet?** If `.git` doesn't exist, setver offers to run `git init && git add .` for you.
* **Untracked files?** If new files haven't been `git add`'ed yet, setver lists them and offers to stage them before committing.
* **No upstream branch yet?** If a remote exists but the current branch has no upstream, setver pushes with `git push -u origin <branch>` to set up tracking automatically.

Use `-f|--force` to skip the confirmation prompts.

The combined commands `setver ap`/`autopatch`, `setver autominor` and `setver automajor` commit the code changes, bump the version and create the git tag, then do a **single** `git push` of commits and tags together at the very end — so they trigger only 1 CI/CD run instead of one per intermediate push.

## Prepared releases (`setver prep`)

Composer/Packagist (and most other consumers) resolve installable versions from **git tags**. When you prepare a big `v2.0.0`, bumping versions while you work would push intermediate tags (`v2.0.1`, `v2.0.2`, …) that become installable immediately — because tags are repository-global, not branch-scoped. A major release should instead be **one publish event**, on the base branch, after the work is merged.

`setver prep` enforces that: while a prep is active, **all git tags are hard-suppressed**. The single real tag is created only at `prep finish`.

```sh
# on main, start preparing the next major (2.0.0) on a dedicated branch
setver prep major            # -> creates branch 'prep-v2', writes .setver-prep, sets files to 2.0.0

# develop as usual; dev version numbers may climb, but NO tag is ever pushed
setver ap                    # 2.0.0 -> 2.0.1 (files + commit), tag suppressed
setver ap                    # 2.0.1 -> 2.0.2, tag suppressed

# step away and come back at any time
setver prep pause --stash    # remember the branch, stash WIP, return to base
setver prep resume           # jump back onto the prep branch, restore the WIP
setver prep status           # target, suppression, and how far base has moved

# after the prep branch is merged into the base branch (e.g. the PR is merged):
setver prep finish           # releases the clean target v2.0.0 as the ONE tag, in a single push
```

* The marker file **`.setver-prep`** is committed to the prep branch, so it travels with the PR and into the base branch on merge. Its presence is the tag-suppression switch — the base branch therefore stays suppressed in the window between merge and `finish`, preventing an accidental tag.
* `prep finish` releases the **clean target** (`2.0.0`) by default, not the drifted dev number; pass `--keep-version` to tag whatever the files currently say. Use `--no-ff` to have `finish` merge the prep branch locally first (for a non-PR workflow).
* `prep finish` refuses unless the prep branch is actually merged into the base branch (override with `-f`).
* **Hotfixes are unaffected.** A `v1.x` hotfix branched off the release tag (`git checkout -b hotfix-1.4.4 v1.4.3`) carries no `.setver-prep`, so `setver ap` there tags `v1.4.4` normally while the prep stays suppressed elsewhere. `prep status` shows how many commits landed on the base branch since the prep started — your cue to merge the fix into the prep branch so it isn't lost at `2.0.0`.
* `prep abort` cancels a prep: it returns to the base branch and deletes the prep branch (locally, and optionally on the remote).

`prep patch` is intentionally not supported — a patch doesn't warrant a prepared branch; use `setver ap`.

## Conventional Commits messages

Add the `-O|--CONVENTIONAL` flag to any commit action (`push`, `auto`, `skip`) to build a
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/#summary) compliant
message interactively instead of using the auto-generated message:

    setver -O push

setver will then:

1. **Show the changed files.**
2. **Ask for the commit type** — pick a number from the list
   (`feat fix docs style refactor perf test build ci chore revert`).
3. **Ask for an optional scope** (free text, e.g. `commit`, `version`, `git`, `cli`).
4. **Ask whether it's a BREAKING CHANGE** (adds `!`).
5. **Ask for a short description.**

The result is a message like `feat: add upstream detection`, `fix(parser): handle leading zeros`
or `feat!: drop legacy api`.

After committing with `setver -O push` or `setver -O auto`, setver also **suggests the matching
version bump** based on the commit type:

| commit type            | suggested next step      |
| ---------------------- | ------------------------ |
| `feat`                 | `setver new minor`       |
| `fix`                  | `setver new patch`       |
| any type with `!`      | `setver new major`       |
| other (docs, chore, …) | `setver new patch`       |

The suggestion is informational only — setver never bumps the version automatically.

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

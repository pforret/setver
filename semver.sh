#!/bin/bash

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_VERSION="1.0"
readonly SCRIPT_AUTHOR="Peter Forret <peter@forret.com>"
readonly PROG_DIRNAME=$(dirname "$0")
if [[ -z "$PROG_DIRNAME" ]] ; then
	# script called without  path specified ; must be in $PATH somewhere
  readonly PROG_PATH=$(which "$0")
  readonly PROG_FOLDER=$(dirname "$PROG_PATH")
else
  readonly PROG_FOLDER=$(cd "$PROG_DIRNAME" && pwd)
  readonly PROG_PATH="$PROG_FOLDER/$SCRIPT_NAME"
fi

main(){
    check_requirements
    [[ -z "$1" ]] && show_usage_and_quit

    # there is always a composer version, not always a tag version
    [[ "$1" == "get" ]] && get_version_composer && safe_exit

    [[ "$1" == "check" ]] && check_versions
    [[ "$1" == "set" ]] && set_versions "$2"
}

#####################################################################
## HELPER FUNCTIONS FOR USING composer.json, git tag, ...
#####################################################################

check_requirements(){
    git --version > /dev/null 2>&1 || die "ERROR: git is not installed on this machine"
    git status    > /dev/null 2>&1 || die "ERROR: this folder [] is not a git repository"
    [[ -d .git ]] || die "ERROR: $SCRIPT_NAME should be run from the git repo root"
}

semver_to_decver(){
    echo $1 | awk -F '.' '{print int($1)*1000000 + int($2)*1000 + int($3)}'
}

decver_to_semver(){
    echo $1 | awk '{print int($1/1000000) "." int(($1/1000) % 1000) "." int($1 % 1000)}'
}

show_usage_and_quit(){
        cat <<END >&2
# $SCRIPT_NAME v$SCRIPT_VERSION - by $SCRIPT_AUTHOR
# Usage:
    $SCRIPT_NAME get: get current version (from git tag and composer)
    $SCRIPT_NAME check: compare versions of git tag and composer
    $SCRIPT_NAME set <version>: set current version through git tag and composer
END
    safe_exit
}


get_version_tag(){
    git tag | tail -1 | sed 's/v//'
    }

get_version_composer(){
    composer config version
    }

set_version_composer(){
    composer config version "$1"
}

set_version_tag(){
    git tag "v$1"
}

check_versions(){
    version_tag=$(get_version_tag)
    version_composer=$(get_version_composer)
    if [[ "$version_tag" == "$version_composer" ]] ; then
        success "Version: $version_tag (both as git tag and in composer)"
        safe_exit
    else
        alert "Version conflict!"
        alert "Version according to git tag: $version_tag"
        alert "Version in composer.json    : $version_composer"
       safe_exit 1
    fi
}

set_versions(){
    remote_url=$(git config remote.origin.url)
    new_version="$1"
    if [[ "$1" == "auto" ]] ; then
        current_semver=$(get_version_composer)
        current_decver=$(semver_to_decver "$current_semver")
        new_decver=$(($current_decver + 1))
        new_version=$(decver_to_semver $new_decver)
        out "0. version $current_semver -> $new_version"
    fi
    # first change composer.json
    out "1. set version in composer.json"
    sleep 1
    set_version_composer "$new_version"

    # commit composer.json and push it
    out "2. commit new composer.json"
    sleep 1
    ( git add composer.json && git commit -m "semver.sh: set version to $new_version" && git push ) 2>&1 | grep 'semver'

    # now create new version tag
    out "3. set git version tag"
    sleep 1
    set_version_tag "$new_version"

    # also push tags to github/bitbucket
    out "4. push tags to $remote_url"
    sleep 1
    git push --tags  2>&1 | grep 'new tag'
    safe_exit
}
#####################################################################
## HELPER FUNCTIONS FROM https://github.com/pforret/bash-boilerplate/
#####################################################################

[[ -t 1 ]] && output_to_pipe=0 || output_to_pipe=1        # detect if output is sent to pipe or to terminal
[[ $(echo -e '\xe2\x82\xac') == '€' ]] && supports_unicode=1 || supports_unicode=0 # detect if supports_unicode is supported

if [[ $output_to_pipe -eq 0 ]] ; then
  readonly col_reset="\033[0m"
  readonly col_red="\033[1;31m"
  readonly col_grn="\033[1;32m"
  readonly col_ylw="\033[1;33m"
else
  # no colors for output_to_pipe content
  readonly col_reset=""
  readonly col_red=""
  readonly col_grn=""
  readonly col_ylw=""
fi

if [[ $supports_unicode -gt 0 ]] ; then
  readonly char_succ="✔"
  readonly char_fail="✖"
  readonly char_alrt="➨"
  readonly char_wait="…"
else
  # no supports_unicode chars if not supported
  readonly char_succ="OK "
  readonly char_fail="!! "
  readonly char_alrt="?? "
  readonly char_wait="..."
fi

out() {     printf '%b\n' "$*"; }
success() { out "${col_grn}${char_succ}${col_reset}  $*"; }
alert()   { out "${col_red}${char_alrt}${col_reset}: $*" >&2 ; }
die()     { tput bel; out "${col_red}${char_fail} $PROGIDEN${col_reset}: $*" >&2; safe_exit; }

error_prefix="${col_red}>${col_reset}"
trap "die \"ERROR \$? after \$SECONDS seconds \n\
\${error_prefix} last command : '\$BASH_COMMAND' \" \
\$(< \$PROG_PATH awk -v lineno=\$LINENO \
'NR == lineno {print \" from line \" lineno \" : \" \$0}')" INT TERM EXIT

safe_exit() {
  trap - INT TERM EXIT
  exit 0
}

main "$1" "$2"

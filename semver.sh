#!/bin/bash
readonly script_fname=$(basename "$0")
script_version="?.?.?"
# will be retrieved later
readonly this_author="Peter Forret <peter@forret.com>"
script_folder=$(dirname "$0")
if [[ -z "$script_folder" ]]; then
  # script called without path ; must be in $PATH somewhere
  # shellcheck disable=SC2230
  script_install_path=$(which "$0")
  script_install_path=$(readlink "$script_install_path") # when script was installed with e.g. basher
  readonly script_install_folder=$(dirname "$script_install_path")
else
  # script called with (full) path
  readonly script_install_folder=$(cd "$script_folder" && pwd)
  readonly script_install_path="$script_install_folder/$script_fname"
fi

uses_composer=0
# shellcheck disable=SC2230
[[ -f "composer.json" ]] && [[ -n $(which composer) ]] && uses_composer=1
uses_npm=0
# shellcheck disable=SC2230
[[ -f "package.json" ]]  && [[ -n $(which npm) ]]    && uses_npm=1
uses_env=0
env_example=".env.example"
[[ -f "$env_example" ]]  && uses_env=1

main() {
  check_requirements
  [[ -z "$1" ]] && show_usage_and_quit 0

  case "$1" in
  -h)
    #USAGE: semver.sh -h       : show detailed usage info
    show_usage_and_quit 1
    ;;

  get)
    #USAGE: semver.sh get      : get semver version for current repo folder
    get_any_version
    ;;

  check)
    #USAGE: semver.sh get      : compare version of composer.json, package.json, VERSION.md and git tag
    check_versions
    ;;

  set | new | bump | version)
    #USAGE: semver.sh new major: set new MAJOR version (e.g. 2.4.7 -> 3.0.0) -- new functionality, NOT backwards compatible
    #USAGE: semver.sh new minor: set new MINOR version (e.g. 2.4.7 -> 2.5.0) -- new functionality, backwards compatible
    #USAGE: semver.sh new patch: set new PATCH version (e.g. 2.4.7 -> 2.4.8) -- bugfix, refactor, no new functionality
    #USAGE:   also: semver.sh set <major/minor/patch> ; semver.sh version <major/minor/patch> ; semver.sh bump <major/minor/patch>
    set_versions "$2"
    ;;

  push | commit | github)
    #USAGE: semver.sh push     : commit and push changed files
    #USAGE:   also: semver.sh commit
    commit_and_push
    ;;

  auto )
    #USAGE: semver.sh auto     : commit & push with auto-generated commit message
    commit_and_push auto
    ;;

  skip | skip-ci | skipci)
    #USAGE: semver.sh skip-ci     : commit & push with auto-generated commit message with [ckip ci]
    commit_and_push skipci
    ;;

  changes | changelog)
    #USAGE: semver.sh changelog : format new CHANGELOG.md chapter
    add_to_changelog "$(get_any_version)"
    ;;

  history)
    #USAGE: semver.sh history : show all commits in short format: "2020-08-06 21:18:24 +0200 ; peter@forret.com ; Update CHANGELOG.md"
    trap - INT TERM EXIT
    git log --pretty=format:"%ci ; %ce ; %s" | grep -v "semver.sh: set" | more
    ;;

  *)
    die "Don't understand action [$1]"
    ;;
  esac
  safe_exit

}

#####################################################################
## HELPER FUNCTIONS FOR USING composer.json, git tag, ...
#####################################################################

check_requirements() {
  git --version >/dev/null 2>&1 || die "ERROR: git is not installed on this machine"
  git status >/dev/null 2>&1 || die "ERROR: this folder [] is not a git repository"
  [[ -d .git ]] || die "ERROR: $script_fname should be run from the git repo root"
  [[ -f "$script_install_folder/VERSION.md" ]] && script_version=$(cat "$script_install_folder/VERSION.md")
}

show_usage_and_quit() {
  detailed="${1:=0}"
  cat <<END >&2
# $script_fname v$script_version - by $this_author
# Usage:
    $script_fname get: get current version (from git tag and composer) -- can be used in scripts
    $script_fname check: compare versions of git tag and composer
    $script_fname set <version>: set current version through git tag and composer
    $script_fname set major: new major version e.g. 2.5.17 -> 3.0.0
    $script_fname set minor: new minor version e.g. 2.5.17 -> 2.6.0
    $script_fname set patch: new patch version e.g. 2.5.17 -> 2.5.18
    $script_fname history: show last commits
    $script_fname changelog: add chapter with latest changes to CHANGELOG.md
END
  if ((detailed)); then
    grep "#USAGE:" "$script_install_path" |
      grep -v "grep " |
      grep -v "sed " |
      sed 's/#USAGE:/# /' \
        >&2
  fi
  safe_exit
}

get_any_version() {
  local version="0.0.0"
  if [[ $uses_composer -gt 0 ]]; then
    version=$(composer config version)
  fi
  if [[ $uses_npm -gt 0 ]]; then
    version=$(get_version_npm)
  fi
  if [[ -n $(get_version_tag) ]]; then
    version=$(get_version_tag)
  fi
  echo "$version"
}

get_version_tag() {
  # git tag gives sorted list, which means that 1.10.4 < 1.6.0
  git tag \
  | sed 's/v//' \
  | awk -F. '{printf("%04d.%04d.%04d\n",$1,$2,$3);}' \
  | sort \
  | tail -1 \
  | awk -F. '{printf ("%d.%d.%d",$1 + 0 ,$2 + 0,$3 + 0);}'
}

get_version_md() {
  if [[ -f VERSION.md ]]; then
    cat VERSION.md
  else
    echo ""
  fi
}

get_version_composer() {
  if [[ $uses_composer -gt 0 ]]; then
    composer config version
  else
    echo ""
  fi
}

get_version_npm() {
  if [[ $uses_npm -gt 0 ]]; then
    npm version | grep semver | cut -d\' -f2
  else
    echo ""
  fi
}

get_version_env() {
  if [[ $uses_env -gt 0 ]]; then
        awk -F= '
      {
        if($1 == "VERSION" || $1 == "APP_VERSION"){
          print $2
          }
      }
      ' < "$env_example" | head -1

  else
    echo ""
  fi
}

add_to_changelog() {
  local version="$1"
  local changelog=CHANGELOG.md
  if [[ -f "$changelog" ]]; then
    today=$(date '+%Y-%m-%d')
    temp_file=.CHANGELOG.tmp
    (
      echo "## [$version] - $today"
      echo "### Added/changed"
      # take last 3 commits that were not version-related
      git log -3 --pretty=format:"%s" --grep '\.[0-9]' --invert-grep |
        sed 's/^/- /'
      echo " "
    ) >$temp_file
    \
      awk <"$changelog" \
      '
        BEGIN {
          inserted=0
          }
        function copyfile(filename){
          while ((getline line < filename) > 0) print line;
          close(filename);
          }
        {
          if($0 ~ /^## \[[0-9]/ && inserted==0) {
            copyfile(".CHANGELOG.tmp");
            inserted=1;
          }
          print $0
        }
        END {
          if(inserted==0) {
            copyfile(".CHANGELOG.tmp");
            }
          }
          ' \
      >$changelog.tmp
    if [[ -s "$changelog.tmp" ]]; then
      success "added to $changelog:"
      cat $temp_file
      rm $temp_file
      rm $changelog
      mv $changelog.tmp $changelog
      git add $changelog
    else
      rm $changelog.tmp
    fi
  fi
}

check_versions() {
  version_tag=$(get_version_tag)
  version_composer=$(get_version_composer)
  version_md=$(get_version_md)
  version_npm=$(get_version_npm)
  version_env=$(get_version_env)
  alert "Check versions:"
  [[ -n $version_tag ]]      && alert "Version in git tag       : $version_tag"
  [[ -n $version_composer ]] && alert "Version in composer.json : $version_composer"
  [[ -n $version_md ]]       && alert "Version in VERSION.md    : $version_md"
  [[ -n $version_npm ]]      && alert "Version in package.json  : $version_npm"
  [[ -n $version_env ]]      && alert "Version in .env          : $version_env"
}

set_versions() {
  git_status=$(git status -s)
  if [[ -n "$git_status" ]]; then
    die "ERROR: Git working directory not clean (check 'git status') "
  fi
  remote_url=$(git config remote.origin.url)
  new_version="$1"
  do_git_push=0
  current_semver=$(get_any_version)
  semver_major=$(echo "$current_semver" | cut -d. -f1)
  semver_minor=$(echo "$current_semver" | cut -d. -f2)
  semver_patch=$(echo "$current_semver" | cut -d. -f3)
  case "$new_version" in
  major|MAJOR)
    new_version="$((semver_major + 1)).0.0"
    success "version $current_semver -> $new_version"
    ;;
  minor)
    new_version="$semver_major.$((semver_minor + 1)).0"
    success "version $current_semver -> $new_version"
    ;;
  patch|bug|bugfix)
    # supports auto|patch|fix
    new_version="$semver_major.$semver_minor.$((semver_patch + 1))"
    success "version $current_semver -> $new_version"
    ;;

  *)
    new_version="$1"
    success "version $current_semver -> $new_version"
  esac
  # TODO: fully support  [<newversion> | major | minor | patch | premajor | preminor | prepatch | prerelease [--preid=<prerelease-id>] | from-git]

  skip_git_tag=0
  ### package.json
  if [[ $uses_npm -gt 0 ]]; then
    # for NPM/node repos
    # first change package.json
    success "set version in package.json"
    wait 1
    npm version "$new_version"
    skip_git_tag=1 # npm also creates the tag
    git add package.json
    do_git_push=1
  fi

  ### composer.json
  if [[ $uses_composer -gt 0 ]]; then
    # for PHP repos
    # first change composer.json
    success "set version in composer.json"
    wait 1
    composer config version "$new_version"
    git add composer.json
    do_git_push=1
  fi

  ### .env
  if [[ $uses_env -gt 0 ]]; then
    # for Ruby/PHP/bash/...
    success "set version in .env"
    wait 1
    env_temp="$env_example.tmp"
    awk -F= -v version="$new_version" '
      {
        if($1 == "VERSION" || $1 == "APP_VERSION"){
          print $1 "=" version
          }
        else {
          print
          }
      }
      ' < "$env_example" > "$env_temp"
    if [[ -n $(diff "$env_example" "$env_temp") ]] ; then
      rm "$env_example"
      mv "$env_temp" "$env_example"
      git add "$env_example"
      do_git_push=1
    else
      rm "$env_temp"
    fi
  fi

  ### VERSION.md
  if [[ -f VERSION.md ]]; then
    # for bash repos
    success "set version in VERSION.md"
    wait 1
    echo "$new_version" >VERSION.md
    git add VERSION.md
    do_git_push=1
  fi

  if [[ $do_git_push -gt 0 ]]; then
    success "commit and push changed files"
    wait 1
    (git commit -m "semver.sh: set version to $new_version" -m "[skip ci]" && git push) 2>&1 | grep 'semver'
  fi

  # now create new version tag
  if [[ $skip_git_tag == 0 ]]; then
    success "set git version tag"
    wait 1
    git tag "v$new_version"
  fi

  # also push tags to github/bitbucket
  success "push tags to $remote_url"
  wait 1
  git push --tags 2>&1 | grep 'new tag'

  web_url=$(echo "$remote_url" | cut -d: -f2)
  # should be like <username>/<repo>.git
  git_host=$(echo "$remote_url" | cut -d: -f1)
  # should be like <username>/<repo>.git
  if [[ -n "$web_url" ]]; then
    username=$(dirname "$web_url")
    reponame=$(basename "$web_url" .git)
    case "$git_host" in
    git@github.com)
      web_url="https://github.com/$username/$reponame"
      success "to create a release, go to $web_url"
      ;;
    git@bitbucket.org)
      web_url="https://bitbucket.org/$username/$reponame"
      success "Repo online on $web_url"
      ;;
    esac
  fi
}

commit_and_push() {
  set +e
  trap - INT TERM EXIT

  mode=${1:-}

  default_message="$(git diff --compact-summary  | tail -1): $(git diff --compact-summary  | awk -F\| '/\|/ {print $1 "," }' | xargs)"
  case "$mode" in
  skip-ci|skipci)
    success "Commit: $default_message [skip ci]"
    git commit -a -m "$default_message" -m "[skip ci]" && git push
    ;;

  auto | fast)
    success "Commit: $default_message"
    git commit -a -m "$default_message" && git push
    ;;

  *)
    # interactive commit
    git commit -a && git push

  esac

}
#####################################################################
## HELPER FUNCTIONS FROM https://github.com/pforret/bash-boilerplate/
#####################################################################

[[ -t 1 ]] && output_to_pipe=0 || output_to_pipe=1                                   # detect if output is sent to pipe or to terminal
[[ $(echo -e '\xe2\x82\xac') == '€' ]] && supports_unicode=1 || supports_unicode=0 # detect if supports_unicode is supported

if [[ $output_to_pipe -eq 0 ]]; then
  readonly col_def="\033[0m"
  readonly col_red="\033[1;31m"
  readonly col_grn="\033[1;32m"
  readonly col_ylw="\033[1;33m"
else
  # no colors for output_to_pipe content
  readonly col_def=""
  readonly col_red=""
  readonly col_grn=""
  readonly col_ylw=""
fi

if [[ $supports_unicode -gt 0 ]]; then
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

out() { printf '%b\n' "$*"; }
wait() { printf '%b\r' "$char_wait" && sleep "$1"; }
success() { out "${col_grn}${char_succ}${col_def}  $*"; }
alert() { out "${col_ylw}${char_alrt}${col_def}: $*" >&2; }
die() {
  tput bel
  out "${col_red}${char_fail} $PROGIDEN${col_def}: $*" >&2
  safe_exit
}

error_prefix="${col_red}>${col_def}"
trap "die \"ERROR \$? after \$SECONDS seconds \n\
\${error_prefix} last command : '\$BASH_COMMAND' \" \
\$(< \$script_install_path awk -v lineno=\$LINENO \
'NR == lineno {print \" from line \" lineno \" : \" \$0}')" INT TERM EXIT

safe_exit() {
  trap - INT TERM EXIT
  exit 0
}

main "$1" "$2" "$3"

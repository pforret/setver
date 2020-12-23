#!/bin/bash
script_fname=$(basename "$0")
script_version="?.?.?"
# will be retrieved later
script_author="Peter Forret <peter@forret.com>"
if [[ -z $(dirname "$0") ]]; then
  # script called without path ; must be in $PATH somewhere
  # shellcheck disable=SC2230
  script_install_path=$(which "$0")
else
  # script called with relative/absolute path
  script_install_path="$0"
  script_install_folder=$(dirname "$script_install_path")
  # shellcheck disable=SC2164
  script_install_folder=$(cd "$script_install_folder" ; pwd)
  script_install_path="$script_install_folder/$script_fname"
fi

[[ -n $(readlink "$script_install_path") ]] && script_install_path=$(readlink "$script_install_path")
# when script was installed with e.g. basher
script_install_folder=$(dirname "$script_install_path")

uses_composer=0
# shellcheck disable=SC2230
[[ -f "composer.json" ]] && [[ -n $(which composer) ]] && uses_composer=1

uses_npm=0
# shellcheck disable=SC2230
[[ -f "package.json" ]]  && [[ -n $(which npm) ]]    && uses_npm=1

uses_env=0
env_example=".env.example"
[[ -f "$env_example" ]]  && uses_env=1

verbose=0
check_in_root=1
usage=0
while getopts rvh option ; do
  case $option in
  r)  check_in_root=0 ;;
  v)  verbose=1 ;;
  h)  usage=1 ;;
  *)  echo "Unknown option -$option"
  esac
done
shift $((OPTIND - 1))

main() {
  check_requirements
  [[ -z "$1" ]] && show_usage_and_quit $usage

  case "$1" in
  -h)
    #USAGE: setver -h       : show detailed usage info
    show_usage_and_quit 1
    ;;

  get)
    #USAGE: setver get      : get semver version for current repo folder
    get_any_version
    ;;

  check)
    #USAGE: setver check    : compare version of composer.json, package.json, VERSION.md and git tag
    check_versions
    ;;

  set | new | bump | version)
    #USAGE: setver new major: set new MAJOR version (e.g. 2.4.7 -> 3.0.0) -- new functionality, NOT backwards compatible
    #USAGE: setver new minor: set new MINOR version (e.g. 2.4.7 -> 2.5.0) -- new functionality, backwards compatible
    #USAGE: setver new patch: set new PATCH version (e.g. 2.4.7 -> 2.4.8) -- bugfix, refactor, no new functionality
    #USAGE: = setver set <major/minor/patch>
    #USAGE: = setver version <major/minor/patch>
    #USAGE: = setver bump <major/minor/patch>
    set_versions "$2"
    ;;

  push | commit | github)
    #USAGE: setver push     : commit and push changed files
    #USAGE: = setver commit
    commit_and_push
    ;;

  message)
    def_commit_message
    ;;

  auto )
    #USAGE: setver auto     : commit & push with auto-generated commit message
    commit_and_push auto
    ;;

  skip | skip-ci | skipci)
    #USAGE: setver skip-ci  : commit & push with auto-generated commit message with [skip ci]
    commit_and_push skipci
    ;;

  changes | changelog)
    #USAGE: setver changelog: format new CHANGELOG.md chapter
    add_to_changelog "$(get_any_version)"
    ;;

  history)
    #USAGE: setver history  : show all commits in short format: "YYYY-MM-DD HH:MM:SS +TTTT ; <author> ; <message>"
    trap - INT TERM EXIT
    git log --pretty=format:"%ci ; %ce ; %s" \
    | grep -v "semver.sh: set" \
    | grep -v "setver: set" \
    | more
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
  if [[ $check_in_root -gt 0 ]] ; then
    [[ -d .git ]] || die "ERROR: $script_fname should be run from the git repo root"
  fi
  [[ -f "$script_install_folder/VERSION.md" ]] && script_version=$(cat "$script_install_folder/VERSION.md")
}

show_usage_and_quit() {
  detailed="${1:=0}"
  cat <<END >&2
# $script_fname v$script_version - by $script_author
# Usage:
    $script_fname [-h] [-v] [-s] [get/check/push/auto/skip/set/new/history/changelog] [version]
    -h: extended help
    -v: verbose mode (more output to stderr)
    -s: add [skip_ci] flag to
    get      : get current version (from git tag and composer) -- can be used in scripts
    check    : compare versions of git tag and composer
    push     : do a git commit -a and and git push, edit commit message manually
    auto     : like 'push', with automatic commit message
    skip     : like 'auto', and add [skip_ci] to commit message
    set <version>: set current version through git tag and composer
    new major: new major version e.g. 2.5.17 -> 3.0.0
    new minor: new minor version e.g. 2.5.17 -> 2.6.0
    new patch: new patch version e.g. 2.5.17 -> 2.5.18
    history  : show last commits
    changelog: add chapter with latest changes to CHANGELOG.md
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
  if [[ -f VERSION.md ]]; then
    log "Version from VERSION.md"
    get_version_md
    return 0
  fi
  if [[ -n $(get_version_tag) ]]; then
    log "Version from git tag"
    get_version_tag
    return 0
  fi
  if [[ $uses_composer -gt 0 ]]; then
    log "Version from composer"
    get_version_composer
    return 0
  fi
  if [[ $uses_npm -gt 0 ]]; then
    log "Version from npm"
    get_version_npm
    return
  fi
  echo "$version"
}

get_version_tag() {
  # git tag gives sorted list, which means that 1.10.4 < 1.6.0
  if [[ -n $(git tag) ]] ; then
    git tag \
    | sed 's/v//' \
    | awk -F. '{printf("%04d.%04d.%04d\n",$1,$2,$3);}' \
    | sort \
    | tail -1 \
    | awk -F. '{printf ("%d.%d.%d",$1 + 0 ,$2 + 0,$3 + 0);}'
  else
    log "No git tag yet in this repo"
    echo ""
  fi
}

get_version_md() {
  local version
  if [[ -f VERSION.md ]]; then
    version=$(cat VERSION.md)
    echo "$version"
  else
    log "No 'VERSION.md' in this folder"
    echo ""
  fi
}

get_version_composer() {
  local version
  if [[ $uses_composer -gt 0 ]]; then
    # composer.json exists
    if grep -q '"version"' composer.json ; then
      # shellcheck disable=SC2230
      if [[ -n $(which composer) ]] ; then
        version=$(composer config version 2> /dev/null)
        echo "$version"
      else
        # composer not installed on this machine
        log "Composer not installed"
        echo ""
      fi
    else
      # no "version" field in composer.json
      log "No 'version' field in composer.json"
      echo ""
    fi
  else
    # no composer.json in this folder
    log "No 'composer.json' in this folder"
    echo ""
  fi
}

get_version_npm() {
  if [[ $uses_npm -gt 0 ]] ; then
    #package.json exists
    if grep -q '"version"' package.json ; then
      if npm version >/dev/null 2>&1; then
        npm ls 2>/dev/null \
        | head -1 \
        | cut -d' ' -f1 \
        | cut -d@ -f2
      else
        log "npm not installed"
      fi
    else
      # no "version" field in package.json
      log "No 'version' field in package.json"
      echo ""
    fi
  else
    # no package.json in this folder
    log "No 'package.json' in this folder"
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
    log "no $env_example in this folder"
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

show_version(){
  local version="$1"
  local location="$2"
  if [[ -z "$first_version" ]] ; then
    first_version="$version"
    printf "$col_grn$char_succ Version in %14s: %s$col_def\n" "$location" "$version"
  else
    if [[ "$version" == "$first_version" ]] ; then
      printf "$col_grn$char_succ Version in %14s: %s$col_def\n" "$location" "$version"
    else
      printf "$col_red$char_fail Version in %14s: [%s] != [$first_version]$col_def\n" "$location" "$version"
    fi
  fi
}

check_versions() {
  first_version=""
  success "$script_fname check versions:"
  version_tag=$(get_version_tag)
  [[ -n $version_tag ]]      && show_version "$version_tag"      "git tag"
  version_composer=$(get_version_composer)
  [[ -n $version_composer ]] && show_version "$version_composer" "composer.json"
  version_md=$(get_version_md)
  [[ -n $version_md ]]       && show_version "$version_md"       "VERSION.md"
  version_npm=$(get_version_npm)
  [[ -n $version_npm ]]      && show_version "$version_npm"      "package.json"
  version_env=$(get_version_env)
  [[ -n $version_env ]]      && show_version "$version_env"      ".env.example"
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
    composer config version "$new_version" 2> /dev/null
    git add composer.json
    do_git_push=1
  fi

  ### .env
  if [[ $uses_env -gt 0 ]]; then
    # for Ruby/PHP/bash/...
    success "set version in $env_example"
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
    (git commit -m "setver: set version to $new_version" -m "[skip ci]" && push_if_possible) 2>&1 | grep 'setver'
  fi

  # now create new version tag
  if [[ $skip_git_tag == 0 ]]; then
    success "set git version tag"
    wait 1
    git tag "v$new_version"
  fi

  # also push tags to github/bitbucket
  if [[ -n "$remote_url" ]] ; then
    success "push tags to $remote_url"
    wait 1
    git push --tags 2>&1 | grep 'new tag'
  fi

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

def_commit_message(){
  git status --short \
  | sed 's/^ //' \
  | awk '
  function basename(file) {
    sub(".*/", "", file)
    return file
  }
  BEGIN {add=""; mod=""; del=""; ren=""}
  /^A/ {add=add " " basename($2);}
  /^R/ {ren=ren " " basename($2);}
  /^M/ {mod=mod " " basename($2);}
  /^D/ {del=del " " basename($2);}
  END {
    if(length(add)>0){printf "ADD:" add ", "}
    if(length(del)>0){printf "DEL:" del ", "}
    if(length(ren)>0){printf "MOV:" ren ", "}
    if(length(mod)>0){printf "MOD:" mod}
    print "\n";
    }
  '
}

commit_and_push() {
  set +e
  trap - INT TERM EXIT

  mode=${1:-}

  #default_message="$(git diff --shortstat  | tail -1): $(git diff --compact-summary  | awk -F\| '/\|/ {print $1 "," }' | xargs)"
  default_message="$(def_commit_message)"
  log "Commit message = [$default_message]"

  case "$mode" in
  skip-ci|skipci)
    success "Commit: $default_message [skip ci]"
    git commit -a -m "$default_message" -m "[skip ci]" && push_if_possible
    ;;

  auto | fast)
    success "Commit: $default_message"
    git commit -a -m "$default_message" && push_if_possible
    ;;

  *)
    # interactive commit
    git commit -a && push_if_possible

  esac

}

push_if_possible(){
  local check_remote=""
  check_remote=$(git remote -v | awk '/\(push\)/ {print $2}')
  if [[ -n "$check_remote" ]] ; then
    log "push to remote [$check_remote]"
    git push
  else
    log "No remote set - skip git push"
  fi
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
  readonly char_warn="➨"
  readonly char_wait="…"
else
  # no supports_unicode chars if not supported
  readonly char_succ="OK "
  readonly char_fail="!! "
  readonly char_warn="?? "
  readonly char_wait="..."
fi

out() { printf '%b\n' "$*"; }
log() { [[ $verbose -gt 0 ]] && printf "  ${col_ylw}%b${col_def}\n" "$*" >&2; }
wait() { printf '%b\r' "$char_wait" && sleep "$1"; }
success() { out "${col_grn}${char_succ}${col_def}  $*"; }
alert() { out "${col_ylw}${char_warn}${col_def}: $*" >&2; }
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

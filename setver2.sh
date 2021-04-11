#!/usr/bin/env bash
### Created by Peter Forret ( pforret ) on 2021-04-11
### Based on https://github.com/pforret/bashew 1.15.4
script_version="0.0.1" # if there is a VERSION.md in this script's folder, it will take priority for version number
readonly script_author="peter@forret.com"
readonly script_created="2021-04-11"
readonly run_as_root=-1 # run_as_root: 0 = don't check anything / 1 = script MUST run as root / -1 = script MAY NOT run as root

list_options() {
  echo -n "
#commented lines will be filtered
flag|h|help|show usage
flag|q|quiet|no output
flag|v|verbose|output more
flag|f|force|do not ask for confirmation
flag|r|root|do not check if in root folder of repo
option|l|log_dir|folder for log files |$HOME/log/$script_prefix
option|t|tmp_dir|folder for temp files|/tmp/$script_prefix
option|p|prefix|prefix to use for git tags|v
param|1|action|action to perform: get/check/push/set/new/md/message/auto/skip/changelog/history
param|?|input|input text
" | grep -v '^#' | grep -v '^\s*$'
}

#####################################################################
## Put your main script here
#####################################################################

main() {
  log_to_file "[$script_basename] $script_version started"

  uses_composer=0
  # shellcheck disable=SC2230
  [[ -f "composer.json" ]] && [[ -n $(which composer) ]] && uses_composer=1

  uses_npm=0
  # shellcheck disable=SC2230
  [[ -f "package.json" ]]  && [[ -n $(which npm) ]]    && uses_npm=1

  uses_env=0
  env_example=".env.example"
  [[ -f "$env_example" ]]  && uses_env=1

  action=$(lower_case "$action")
  case $action in
    #TIP: use «$script_prefix get» to get the version (returns 1 line with the version nr)
    get)  get_any_version ;;

    #TIP: use «$script_prefix check» to get all versions available in this repo
    check)  check_versions ;;

    #TIP: use «$script_prefix message» to get the current auto-generated commit message
    message)  def_commit_message ;;

    #TIP: use «$script_prefix auto» to do commit/push with auto-generated commit message
    auto)  commit_and_push auto ;;

    #TIP: use «$script_prefix skip» to do commit/push with auto-generated commit message and skip GH actions
    skip | skip-ci | skipci)  commit_and_push skipci ;;

    #TIP: use «$script_prefix auto» to do commit/push with auto-generated commit message
    md)  create_version_md ;;

    #TIP: use «$script_prefix new major/minor/patch» to bump version number with 1
    #TIP: use «$script_prefix set x.y.z» to set new version number
    set | new | bump | version)  set_versions "$input"    ;;

    #TIP: use «$script_prefix push» to do commit/push with auto-generated commit message
    push | commit | github) commit_and_push ;;

    #TIP: use «$script_prefix history» to show the git history in a compact format
    history) show_history ;;


  env)
    ## leave this default action, it will make it easier to test your script
    #TIP: use «$script_prefix check» to check if this script is ready to execute and what values the options/flags are
    #TIP:> $script_prefix check
    #TIP: use «$script_prefix env» to generate an example .env file
    #TIP:> $script_prefix env > .env
    check_script_settings
    ;;

  update)
    ## leave this default action, it will make it easier to test your script
    #TIP: use «$script_prefix update» to update to the latest version
    #TIP:> $script_prefix check
    update_script_to_latest
    ;;

  *)
    die "action [$action] not recognized"
    ;;
  esac
  log_to_file "[$script_basename] ended after $SECONDS secs"
  #TIP: >>> bash script created with «pforret/bashew»
  #TIP: >>> for bash development, also check out «pforret/setver» and «pforret/progressbar»
}

#####################################################################
## Put your helper scripts here
#####################################################################

check_requirements() {
  git --version >/dev/null 2>&1 || die "ERROR: git is not installed on this machine"
  git status >/dev/null 2>&1 || die "ERROR: this folder [] is not a git repository"
  if [[ $check_in_root -gt 0 ]] ; then
    [[ -d .git ]] || die "ERROR: $script_fname should be run from the git repo root"
  fi
  [[ -f "$script_install_folder/VERSION.md" ]] && script_version=$(cat "$script_install_folder/VERSION.md")
}

get_any_version() {
  local version="0.0.0"
  if [[ -n "$(get_version_md)" ]]; then
    debug "Version from VERSION.md"
    get_version_md
    return 0
  fi
  if [[ -n $(get_version_tag) ]]; then
    debug "Version from git tag"
    get_version_tag
    return 0
  fi
  if [[ -n "$(get_version_composer)" ]]; then
    debug "Version from composer"
    get_version_composer
    return 0
  fi
  if [[ -n "$(get_version_npm)" ]]; then
    debug "Version from npm"
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
    | sed "s/$prefix//" \
    | awk -F. '{printf("%04d.%04d.%04d\n",$1,$2,$3);}' \
    | sort \
    | tail -1 \
    | awk -F. '{printf ("%d.%d.%d",$1 + 0 ,$2 + 0,$3 + 0);}'
  else
    debug "No git tag yet in this repo"
    echo ""
  fi
}

create_version_md(){
    git_version_md="$git_repo_root/VERSION.md"
    if [[ ! -f "$git_version_md" ]] ; then
      repo_version=$(get_any_version)
      echo "$repo_version" > "$git_version_md"
      git add "$git_version_md"
      out "VERSION.md was created (version $repo_version)"
    else
      alert "VERSION.md already exists for this repo $git_repo_root"
    fi
}

get_version_md() {
  local version
  if [[ -f VERSION.md ]]; then
    cat VERSION.md
  else
    debug "No 'VERSION.md' in this folder"
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
        debug "Composer not installed"
        echo ""
      fi
    else
      # no "version" field in composer.json
      debug "No 'version' field in composer.json"
      echo ""
    fi
  else
    # no composer.json in this folder
    debug "No 'composer.json' in this folder"
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
        debug "npm not installed"
      fi
    else
      # no "version" field in package.json
      debug "No 'version' field in package.json"
      echo ""
    fi
  else
    # no package.json in this folder
    debug "No 'package.json' in this folder"
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
    debug "no $env_example in this folder"
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
    printf "$col_grn$char_succ Version in %14s: %s$col_reset\n" "$location" "$version"
  else
    if [[ "$version" == "$first_version" ]] ; then
      printf "$col_grn$char_succ Version in %14s: %s$col_reset\n" "$location" "$version"
    else
      printf "$col_red$char_fail Version in %14s: [%s] != [$first_version]$col_reset\n" "$location" "$version"
    fi
  fi
}

check_versions() {
  first_version=""
  success "$script_prefix check versions:"
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
    success "set version in package.json: $new_version"
    sleep 1
    npm version "$new_version"
    skip_git_tag=1 # npm also creates the tag
    git add package.json
    do_git_push=1
  fi

  ### composer.json
  if [[ $uses_composer -gt 0 ]]; then
    # for PHP repos
    # first change composer.json
    success "set version in composer.json: $new_version"

    sleep 1
    composer config version "$new_version" 2> /dev/null
    git add composer.json
    do_git_push=1
  fi

  ### .env
  if [[ $uses_env -gt 0 ]]; then
    # for Ruby/PHP/bash/...
    success "set version in $env_example: $new_version"
    sleep 1
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
    success "set version in VERSION.md: $new_version"
    sleep 1
    echo "$new_version" >VERSION.md
    git add VERSION.md
    do_git_push=1
  fi

  if [[ $do_git_push -gt 0 ]]; then
    success "commit and push changed files"
    sleep 1
    (git commit -m "setver: set version to $new_version" -m "[skip ci]" && push_if_possible) 2>&1 | grep 'setver'
  fi

  # now create new version tag
  if [[ $skip_git_tag == 0 ]]; then
    success "set git version tag: $prefix$new_version"
    sleep 1
    git tag "$prefix$new_version"
  fi

  # also push tags to github/bitbucket
  if [[ -n "$remote_url" ]] ; then
    success "push tags to $remote_url"
    sleep 1
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
  debug "Commit message = [$default_message]"

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

show_history() {
    trap - INT TERM EXIT
    git log --pretty=format:"%ci ; %ce ; %s" \
    | grep -v "setver: set" \
    | more

}

push_if_possible(){
  local check_remote=""
  check_remote=$(git remote -v | awk '/\(push\)/ {print $2}')
  if [[ -n "$check_remote" ]] ; then
    debug "push to remote [$check_remote]"
    git push
  else
    debug "No remote set - skip git push"
  fi
}
#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################
#####################################################################

# set strict mode -  via http://redsymbol.net/articles/unofficial-bash-strict-mode/
# removed -e because it made basic [[ testing ]] difficult
set -uo pipefail
IFS=$'\n\t'
hash() {
  length=${1:-6}
  if [[ -n $(command -v md5sum) ]]; then
    # regular linux
    md5sum | cut -c1-"$length"
  else
    # macos
    md5 | cut -c1-"$length"
  fi
}

force=0
help=0
verbose=0
#to enable verbose even before option parsing
[[ $# -gt 0 ]] && [[ $1 == "-v" ]] && verbose=1
quiet=0
#to enable quiet even before option parsing
[[ $# -gt 0 ]] && [[ $1 == "-q" ]] && quiet=1

### stdout/stderr output
initialise_output() {
  [[ "${BASH_SOURCE[0]:-}" != "${0}" ]] && sourced=1 || sourced=0
  [[ -t 1 ]] && piped=0 || piped=1 # detect if output is piped
  if [[ $piped -eq 0 ]]; then
    col_reset="\033[0m"
    col_red="\033[1;31m"
    col_grn="\033[1;32m"
    col_ylw="\033[1;33m"
  else
    col_reset=""
    col_red=""
    col_grn=""
    col_ylw=""
  fi

  [[ $(echo -e '\xe2\x82\xac') == '€' ]] && unicode=1 || unicode=0 # detect if unicode is supported
  if [[ $unicode -gt 0 ]]; then
    char_succ="✅"
    char_fail="⛔"
    char_alrt="✴️"
    char_wait="⏳"
    info_icon="🌼"
    config_icon="🌱"
    clean_icon="🧽"
    require_icon="🔌"
  else
    char_succ="OK "
    char_fail="!! "
    char_alrt="?? "
    char_wait="..."
    info_icon="(i)"
    config_icon="[c]"
    clean_icon="[c]"
    require_icon="[r]"
  fi
  error_prefix="${col_red}>${col_reset}"
}

out() {     ((quiet)) && true || printf '%b\n' "$*"; }
debug() {   if ((verbose)); then out "${col_ylw}# $* ${col_reset}" >&2; else true; fi; }
die() {     out "${col_red}${char_fail} $script_basename${col_reset}: $*" >&2 ; tput bel ; safe_exit ; }
alert() {   out "${col_red}${char_alrt}${col_reset}: $*" >&2 ; }
success() { out "${col_grn}${char_succ}${col_reset}  $*"; }
announce() { out "${col_grn}${char_wait}${col_reset}  $*"; sleep 1 ; }
progress() {
  ((quiet)) || (
    local screen_width
    screen_width=$(tput cols 2>/dev/null || echo 80)
    local rest_of_line
    rest_of_line=$((screen_width - 5))

    if flag_set ${piped:-0}; then
      out "$*" >&2
    else
      printf "... %-${rest_of_line}b\r" "$*                                             " >&2
    fi
  )
}

log_to_file() { [[ -n ${log_file:-} ]] && echo "$(date '+%H:%M:%S') | $*" >>"$log_file"; }

### string processing
lower_case() { echo "$*" | tr '[:upper:]' '[:lower:]'; }
upper_case() { echo "$*" | tr '[:lower:]' '[:upper:]'; }

slugify() {
    # slugify <input> <separator>
    # slugify "Jack, Jill & Clémence LTD"      => jack-jill-clemence-ltd
    # slugify "Jack, Jill & Clémence LTD" "_"  => jack_jill_clemence_ltd
    separator="${2:-}"
    [[ -z "$separator" ]] && separator="-"
    # shellcheck disable=SC2020
    echo "$1" |
        tr '[:upper:]' '[:lower:]' |
        tr 'àáâäæãåāçćčèéêëēėęîïííīįìłñńôöòóœøōõßśšûüùúūÿžźż' 'aaaaaaaaccceeeeeeeiiiiiiilnnoooooooosssuuuuuyzzz' |
        awk '{
          gsub(/[\[\]@#$%^&*;,.:()<>!?\/+=_]/," ",$0);
          gsub(/^  */,"",$0);
          gsub(/  *$/,"",$0);
          gsub(/  */,"-",$0);
          gsub(/[^a-z0-9\-]/,"");
          print;
          }' |
        sed "s/-/$separator/g"
}

title_case() {
    # title_case <input> <separator>
    # title_case "Jack, Jill & Clémence LTD"     => JackJillClemenceLtd
    # title_case "Jack, Jill & Clémence LTD" "_" => Jack_Jill_Clemence_Ltd
    separator="${2:-}"
    # shellcheck disable=SC2020
    echo "$1" |
        tr '[:upper:]' '[:lower:]' |
        tr 'àáâäæãåāçćčèéêëēėęîïííīįìłñńôöòóœøōõßśšûüùúūÿžźż' 'aaaaaaaaccceeeeeeeiiiiiiilnnoooooooosssuuuuuyzzz' |
        awk '{ gsub(/[\[\]@#$%^&*;,.:()<>!?\/+=_-]/," ",$0); print $0; }' |
        awk '{
          for (i=1; i<=NF; ++i) {
              $i = toupper(substr($i,1,1)) tolower(substr($i,2))
          };
          print $0;
          }' |
        sed "s/ /$separator/g" |
        cut -c1-50
}

### interactive
confirm() {
  # $1 = question
  flag_set $force && return 0
  read -r -p "$1 [y/N] " -n 1
  echo " "
  [[ $REPLY =~ ^[Yy]$ ]]
}

ask() {
  # $1 = variable name
  # $2 = question
  # $3 = default value
  # not using read -i because that doesn't work on MacOS
  local ANSWER
  read -r -p "$2 ($3) > " ANSWER
  if [[ -z "$ANSWER" ]]; then
    eval "$1=\"$3\""
  else
    eval "$1=\"$ANSWER\""
  fi
}

trap "die \"ERROR \$? after \$SECONDS seconds \n\
\${error_prefix} last command : '\$BASH_COMMAND' \" \
\$(< \$script_install_path awk -v lineno=\$LINENO \
'NR == lineno {print \"\${error_prefix} from line \" lineno \" : \" \$0}')" INT TERM EXIT
# cf https://askubuntu.com/questions/513932/what-is-the-bash-command-variable-good-for

safe_exit() {
  [[ -n "${tmp_file:-}" ]] && [[ -f "$tmp_file" ]] && rm "$tmp_file"
  trap - INT TERM EXIT
  debug "$script_basename finished after $SECONDS seconds"
  exit 0
}

flag_set() { [[ "$1" -gt 0 ]]; }

show_usage() {
  out "Program: ${col_grn}$script_basename $script_version${col_reset} by ${col_ylw}$script_author${col_reset}"
  out "Updated: ${col_grn}$script_modified${col_reset}"
  out "Description: setver but based on bashew"
  echo -n "Usage: $script_basename"
  list_options |
    awk '
  BEGIN { FS="|"; OFS=" "; oneline="" ; fulltext="Flags, options and parameters:"}
  $1 ~ /flag/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-12s: [flag] %s [default: off]",$2,$3,$4) ;
    oneline  = oneline " [-" $2 "]"
    }
  $1 ~ /option/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-12s: [option] %s",$2,$3 " <?>",$4) ;
    if($5!=""){fulltext = fulltext "  [default: " $5 "]"; }
    oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /list/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-12s: [list] %s (array)",$2,$3 " <?>",$4) ;
    fulltext = fulltext "  [default empty]";
    oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /secret/  {
    fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [secret] %s",$2,$3,"?",$4) ;
      oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /param/ {
    if($2 == "1"){
          fulltext = fulltext sprintf("\n    %-17s: [parameter] %s","<"$3">",$4);
          oneline  = oneline " <" $3 ">"
     }
     if($2 == "?"){
          fulltext = fulltext sprintf("\n    %-17s: [parameter] %s (optional)","<"$3">",$4);
          oneline  = oneline " <" $3 "?>"
     }
     if($2 == "n"){
          fulltext = fulltext sprintf("\n    %-17s: [parameters] %s (1 or more)","<"$3">",$4);
          oneline  = oneline " <" $3 " …>"
     }
    }
    END {print oneline; print fulltext}
  '
}

check_last_version(){
  (
  # shellcheck disable=SC2164
  pushd "$script_install_folder" &> /dev/null
  if [[ -d .git ]] ; then
    local remote
    remote="$(git remote -v | grep fetch | awk 'NR == 1 {print $2}')"
    progress "Check for latest version - $remote"
    git remote update &> /dev/null
    if [[ $(git rev-list --count "HEAD...HEAD@{upstream}" 2>/dev/null) -gt 0 ]] ; then
      out "There is a more recent update of this script - run <<$script_prefix update>> to update"
    fi
  fi
  # shellcheck disable=SC2164
  popd &> /dev/null
  )
}

update_script_to_latest(){
  # run in background to avoid problems with modifying a running interpreted script
  (
  sleep 1
  cd "$script_install_folder" && git pull
  ) &
}

show_tips() {
  ((sourced)) && return 0
  # shellcheck disable=SC2016
  grep <"${BASH_SOURCE[0]}" -v '$0' \
  | awk \
      -v green="$col_grn" \
      -v yellow="$col_ylw" \
      -v reset="$col_reset" \
      '
      /TIP: /  {$1=""; gsub(/«/,green); gsub(/»/,reset); print "*" $0}
      /TIP:> / {$1=""; print " " yellow $0 reset}
      ' \
  | awk \
      -v script_basename="$script_basename" \
      -v script_prefix="$script_prefix" \
      '{
      gsub(/\$script_basename/,script_basename);
      gsub(/\$script_prefix/,script_prefix);
      print ;
      }'
}

check_script_settings() {
  if [[ -n $(filter_option_type flag) ]]; then
    out "## ${col_grn}boolean flags${col_reset}:"
    filter_option_type flag |
      while read -r name; do
        if ((piped)); then
          eval "echo \"$name=\$${name:-}\""
        else
          eval "echo -n \"$name=\$${name:-}  \""
        fi
      done
    out " "
    out " "
  fi

  if [[ -n $(filter_option_type option) ]]; then
    out "## ${col_grn}option defaults${col_reset}:"
    filter_option_type option |
      while read -r name; do
        if ((piped)); then
          eval "echo \"$name=\$${name:-}\""
        else
          eval "echo -n \"$name=\$${name:-}  \""
        fi
      done
    out " "
    out " "
  fi

  if [[ -n $(filter_option_type list) ]]; then
    out "## ${col_grn}list options${col_reset}:"
    filter_option_type list |
      while read -r name; do
        if ((piped)); then
          eval "echo \"$name=(\${${name}[@]})\""
        else
          eval "echo -n \"$name=(\${${name}[@]})  \""
        fi
      done
    out " "
    out " "
  fi

  if [[ -n $(filter_option_type param) ]]; then
    if ((piped)); then
      debug "Skip parameters for .env files"
    else
      out "## ${col_grn}parameters${col_reset}:"
      filter_option_type param |
        while read -r name; do
          # shellcheck disable=SC2015
          ((piped)) && eval "echo \"$name=\\\"\${$name:-}\\\"\"" || eval "echo -n \"$name=\\\"\${$name:-}\\\"  \""
        done
      echo " "
    fi
  fi
}

filter_option_type() {
  list_options | grep "$1|" | cut -d'|' -f3 | sort | grep -v '^\s*$'
}

init_options() {
  local init_command
  init_command=$(list_options |
    grep -v "verbose|" |
    awk '
    BEGIN { FS="|"; OFS=" ";}
    $1 ~ /flag/   && $5 == "" {print $3 "=0; "}
    $1 ~ /flag/   && $5 != "" {print $3 "=\"" $5 "\"; "}
    $1 ~ /option/ && $5 == "" {print $3 "=\"\"; "}
    $1 ~ /option/ && $5 != "" {print $3 "=\"" $5 "\"; "}
    $1 ~ /list/ {print $3 "=(); "}
    $1 ~ /secret/ {print $3 "=\"\"; "}
    ')
  if [[ -n "$init_command" ]]; then
    eval "$init_command"
  fi
}

expects_single_params() { list_options | grep 'param|1|' >/dev/null; }
expects_optional_params() { list_options | grep 'param|?|' >/dev/null; }
expects_multi_param() { list_options | grep 'param|n|' >/dev/null; }

parse_options() {
  if [[ $# -eq 0 ]]; then
    show_usage >&2
    safe_exit
  fi

  ## first process all the -x --xxxx flags and options
  while true; do
    # flag <flag> is saved as $flag = 0/1
    # option <option> is saved as $option
    if [[ $# -eq 0 ]]; then
      ## all parameters processed
      break
    fi
    if [[ ! $1 == -?* ]]; then
      ## all flags/options processed
      break
    fi
    local save_option
    save_option=$(list_options |
      awk -v opt="$1" '
        BEGIN { FS="|"; OFS=" ";}
        $1 ~ /flag/   &&  "-"$2 == opt {print $3"=1"}
        $1 ~ /flag/   && "--"$3 == opt {print $3"=1"}
        $1 ~ /option/ &&  "-"$2 == opt {print $3"=$2; shift"}
        $1 ~ /option/ && "--"$3 == opt {print $3"=$2; shift"}
        $1 ~ /list/ &&  "-"$2 == opt {print $3"+=($2); shift"}
        $1 ~ /list/ && "--"$3 == opt {print $3"=($2); shift"}
        $1 ~ /secret/ &&  "-"$2 == opt {print $3"=$2; shift #noshow"}
        $1 ~ /secret/ && "--"$3 == opt {print $3"=$2; shift #noshow"}
        ')
    if [[ -n "$save_option" ]]; then
      if echo "$save_option" | grep shift >>/dev/null; then
        local save_var
        save_var=$(echo "$save_option" | cut -d= -f1)
        debug "$config_icon parameter: ${save_var}=$2"
      else
        debug "$config_icon flag: $save_option"
      fi
      eval "$save_option"
    else
      die "cannot interpret option [$1]"
    fi
    shift
  done

  ((help)) && (
    show_usage
    check_last_version
    out "                                  "
    echo "### TIPS & EXAMPLES"
    show_tips

  ) && safe_exit

  ## then run through the given parameters
  if expects_single_params; then
    single_params=$(list_options | grep 'param|1|' | cut -d'|' -f3)
    list_singles=$(echo "$single_params" | xargs)
    single_count=$(echo "$single_params" | count_words)
    debug "$config_icon Expect : $single_count single parameter(s): $list_singles"
    [[ $# -eq 0 ]] && die "need the parameter(s) [$list_singles]"

    for param in $single_params; do
      [[ $# -eq 0 ]] && die "need parameter [$param]"
      [[ -z "$1" ]] && die "need parameter [$param]"
      debug "$config_icon Assign : $param=$1"
      eval "$param=\"$1\""
      shift
    done
  else
    debug "$config_icon No single params to process"
    single_params=""
    single_count=0
  fi

  if expects_optional_params; then
    optional_params=$(list_options | grep 'param|?|' | cut -d'|' -f3)
    optional_count=$(echo "$optional_params" | count_words)
    debug "$config_icon Expect : $optional_count optional parameter(s): $(echo "$optional_params" | xargs)"

    for param in $optional_params; do
      debug "$config_icon Assign : $param=${1:-}"
      eval "$param=\"${1:-}\""
      shift
    done
  else
    debug "$config_icon No optional params to process"
    optional_params=""
    optional_count=0
  fi

  if expects_multi_param; then
    #debug "Process: multi param"
    multi_count=$(list_options | grep -c 'param|n|')
    multi_param=$(list_options | grep 'param|n|' | cut -d'|' -f3)
    debug "$config_icon Expect : $multi_count multi parameter: $multi_param"
    ((multi_count > 1)) && die "cannot have >1 'multi' parameter: [$multi_param]"
    ((multi_count > 0)) && [[ $# -eq 0 ]] && die "need the (multi) parameter [$multi_param]"
    # save the rest of the params in the multi param
    if [[ -n "$*" ]]; then
      debug "$config_icon Assign : $multi_param=$*"
      eval "$multi_param=( $* )"
    fi
  else
    multi_count=0
    multi_param=""
    [[ $# -gt 0 ]] && die "cannot interpret extra parameters"
  fi
}

require_binary(){
  binary="$1"
  path_binary=$(command -v "$binary" 2>/dev/null)
  [[ -n "$path_binary" ]] && debug "️$require_icon required [$binary] -> $path_binary" && return 0
  #
  words=$(echo "${2:-}" | wc -l)
  case $words in
    0)  install_instructions="$install_package $1";;
    1)  install_instructions="$install_package $2";;
    *)  install_instructions="$2"
  esac
  alert "$script_basename needs [$binary] but it cannot be found"
  alert "1) install package  : $install_instructions"
  alert "2) check path       : export PATH=\"[path of your binary]:\$PATH\""
  die   "Missing program/script [$binary]"
}

folder_prep() {
  if [[ -n "$1" ]]; then
    local folder="$1"
    local max_days=${2:-365}
    if [[ ! -d "$folder" ]]; then
      debug "$clean_icon Create folder : [$folder]"
      mkdir -p "$folder"
    else
      debug "$clean_icon Cleanup folder: [$folder] - delete files older than $max_days day(s)"
      find "$folder" -mtime "+$max_days" -type f -exec rm {} \;
    fi
  fi
}

count_words() { wc -w | awk '{ gsub(/ /,""); print}'; }

recursive_readlink() {
  [[ ! -L "$1" ]] && echo "$1" && return 0
  local file_folder
  local link_folder
  local link_name
  file_folder="$(dirname "$1")"
  # resolve relative to absolute path
  [[ "$file_folder" != /* ]] && link_folder="$(cd -P "$file_folder" &>/dev/null && pwd)"
  local symlink
  symlink=$(readlink "$1")
  link_folder=$(dirname "$symlink")
  link_name=$(basename "$symlink")
  [[ -z "$link_folder" ]] && link_folder="$file_folder"
  [[ "$link_folder" == \.* ]] && link_folder="$(cd -P "$file_folder" && cd -P "$link_folder" &>/dev/null && pwd)"
  debug "$info_icon Symbolic ln: $1 -> [$symlink]"
  recursive_readlink "$link_folder/$link_name"
}

lookup_script_data() {
  readonly script_prefix=$(basename "${BASH_SOURCE[0]}" .sh)
  readonly script_basename=$(basename "${BASH_SOURCE[0]}")
  readonly execution_day=$(date "+%Y-%m-%d")
  #readonly execution_year=$(date "+%Y")

  script_install_path="${BASH_SOURCE[0]}"
  debug "$info_icon Script path: $script_install_path"
  script_install_path=$(recursive_readlink "$script_install_path")
  debug "$info_icon Linked path: $script_install_path"
  readonly script_install_folder="$( cd -P "$( dirname "$script_install_path" )" && pwd )"
  debug "$info_icon In folder  : $script_install_folder"
  if [[ -f "$script_install_path" ]]; then
    script_hash=$(hash <"$script_install_path" 8)
    script_lines=$(awk <"$script_install_path" 'END {print NR}')
  else
    # can happen when script is sourced by e.g. bash_unit
    script_hash="?"
    script_lines="?"
  fi

  # get shell/operating system/versions
  shell_brand="sh"
  shell_version="?"
  [[ -n "${ZSH_VERSION:-}" ]] && shell_brand="zsh" && shell_version="$ZSH_VERSION"
  [[ -n "${BASH_VERSION:-}" ]] && shell_brand="bash" && shell_version="$BASH_VERSION"
  [[ -n "${FISH_VERSION:-}" ]] && shell_brand="fish" && shell_version="$FISH_VERSION"
  [[ -n "${KSH_VERSION:-}" ]] && shell_brand="ksh" && shell_version="$KSH_VERSION"
  debug "$info_icon Shell type : $shell_brand - version $shell_version"

  readonly os_kernel=$(uname -s)
  os_version=$(uname -r)
  os_machine=$(uname -m)
  install_package=""
  case "$os_kernel" in
  CYGWIN* | MSYS* | MINGW*)
    os_name="Windows"
    ;;
  Darwin)
    os_name=$(sw_vers -productName)       # macOS
    os_version=$(sw_vers -productVersion) # 11.1
    install_package="brew install"
    ;;
  Linux | GNU*)
    if [[ $(command -v lsb_release) ]]; then
      # 'normal' Linux distributions
      os_name=$(lsb_release -i)    # Ubuntu
      os_version=$(lsb_release -r) # 20.04
    else
      # Synology, QNAP,
      os_name="Linux"
    fi
    [[ -x /bin/apt-cyg ]] && install_package="apt-cyg install"     # Cygwin
    [[ -x /bin/dpkg ]] && install_package="dpkg -i"                # Synology
    [[ -x /opt/bin/ipkg ]] && install_package="ipkg install"       # Synology
    [[ -x /usr/sbin/pkg ]] && install_package="pkg install"        # BSD
    [[ -x /usr/bin/pacman ]] && install_package="pacman -S"        # Arch Linux
    [[ -x /usr/bin/zypper ]] && install_package="zypper install"   # Suse Linux
    [[ -x /usr/bin/emerge ]] && install_package="emerge"           # Gentoo
    [[ -x /usr/bin/yum ]] && install_package="yum install"         # RedHat RHEL/CentOS/Fedora
    [[ -x /usr/bin/apk ]] && install_package="apk add"             # Alpine
    [[ -x /usr/bin/apt-get ]] && install_package="apt-get install" # Debian
    [[ -x /usr/bin/apt ]] && install_package="apt install"         # Ubuntu
    ;;

  esac
  debug "$info_icon System OS  : $os_name ($os_kernel) $os_version on $os_machine"
  debug "$info_icon Package mgt: $install_package"

  # get last modified date of this script
  script_modified="??"
  [[ "$os_kernel" == "Linux" ]] && script_modified=$(stat -c %y "$script_install_path" 2>/dev/null | cut -c1-16) # generic linux
  [[ "$os_kernel" == "Darwin" ]] && script_modified=$(stat -f "%Sm" "$script_install_path" 2>/dev/null)          # for MacOS

  debug "$info_icon Last modif : $script_modified"
  debug "$info_icon Script ID  : $script_lines lines / md5: $script_hash"
  debug "$info_icon Creation   : $script_created"
  debug "$info_icon Running as : $USER@$HOSTNAME"

  # if run inside a git repo, detect for which remote repo it is
  if git status &>/dev/null; then
    readonly git_repo_remote=$(git remote -v | awk '/(fetch)/ {print $2}')
    debug "$info_icon git remote : $git_repo_remote"
    readonly git_repo_root=$(git rev-parse --show-toplevel)
    debug "$info_icon git folder : $git_repo_root"
  else
    readonly git_repo_root=""
    readonly git_repo_remote=""
  fi

  # get script version from VERSION.md file - which is automatically updated by pforret/setver
  [[ -f "$script_install_folder/VERSION.md" ]] && script_version=$(cat "$script_install_folder/VERSION.md")
  # get script version from git tag file - which is automatically updated by pforret/setver
  [[ -n "$git_repo_root" ]] && [[ -n "$(git tag &>/dev/null)" ]] && script_version=$(git tag --sort=version:refname | tail -1)
}

prep_log_and_temp_dir() {
  tmp_file=""
  log_file=""
  if [[ -n "${tmp_dir:-}" ]]; then
    folder_prep "$tmp_dir" 1
    tmp_file=$(mktemp "$tmp_dir/$execution_day.XXXXXX")
    debug "$config_icon tmp_file: $tmp_file"
    # you can use this temporary file in your program
    # it will be deleted automatically if the program ends without problems
  fi
  if [[ -n "${log_dir:-}" ]]; then
    folder_prep "$log_dir" 30
    log_file="$log_dir/$script_prefix.$execution_day.log"
    debug "$config_icon log_file: $log_file"
  fi
}

import_env_if_any() {
  env_files=("$script_install_folder/.env" "$script_install_folder/$script_prefix.env" "./.env" "./$script_prefix.env")

  for env_file in "${env_files[@]}"; do
    if [[ -f "$env_file" ]]; then
      debug "$config_icon Read config from [$env_file]"
      # shellcheck disable=SC1090
      source "$env_file"
    fi
  done
}

initialise_output  # output settings
lookup_script_data # find installation folder

[[ $run_as_root == 1  ]] && [[ $UID -ne 0 ]] && die "user is $USER, MUST be root to run [$script_basename]"
[[ $run_as_root == -1 ]] && [[ $UID -eq 0 ]] && die "user is $USER, CANNOT be root to run [$script_basename]"

init_options       # set default values for flags & options
import_env_if_any  # overwrite with .env if any

if [[ $sourced -eq 0 ]]; then
  parse_options "$@"    # overwrite with specified options if any
  prep_log_and_temp_dir # clean up debug and temp folder
  main                  # run main program
  safe_exit             # exit and clean up
else
  # just disable the trap, don't execute main
  trap - INT TERM EXIT
fi

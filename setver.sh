#!/bin/bash
if [[ -z $(dirname "$0") ]]; then
  # shellcheck disable=SC2230
  script_install_path=$(which "$0")
else
  # script called with relative/absolute path
  script_install_path="$0"
fi
script_install_path=$(readlink "$script_install_path") # when script was installed with e.g. basher
script_install_folder=$(dirname "$script_install_path")
"$script_install_folder/semver.sh" "${1:-}" "${2:-}" # never more than 2 parameters

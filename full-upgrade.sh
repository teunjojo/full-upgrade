#!/bin/bash
version=1.7

lib="libteunjojo"
[ ! -f "$lib.sh" ] && curl -s -o $lib.sh https://files.teunjojo.com/$lib/latest/$lib.sh && chmod +x $lib.sh
source $lib.sh

function cleanup()
{
tput cnorm
}

trap cleanup EXIT

lineWidth=$(($(tput cols)-10))

# Colors
NOCOLOR="\033[0m"
BLACK="\033[0;30m"
GRAY="\033[1;30m"
BLUE="\033[0;34m"
LIGHT_BLUE="\033[1;34m"
GREEN="\033[0;32m"
LIGHT_GREEN="\033[1;32m"
CYAN="\033[0;36m"
TEAL="\033[1;36m"
RED="\033[0;31m"
PINK="\033[1;31m"
PURPLE="\033[0;35m"
LIGHT_PURPLE="\033[1;35m"
BROWN="\033[0;33m"
YELLOW="\033[1;33m"
LIGHT_GRAY="\033[0;37m"
WHITE="\033[1;37m"

usage()
{
cat << EOF
usage: $0 [OPTION]

This script installs apt updates.

OPTIONS:

    -y, --yes, --assume-yes  Assume "yes" as answer to all prompts and run non-interactively.
    -v, --version            Show version number of $0
    -h, --help               Show this message
EOF
}
while :; do
    case "${1-}" in
    -h | --help) usage
    exit ;;
    -v | --version) echo "$0 v$version"
    exit ;;
    -y | --yes | --assume-yes) assumeYes=1 ;;
    -?*) echo "Unknown option: $1">&2
    usage
    exit 1;;
    *) break ;;
    esac
    shift
  done

trim () {
    local -i maxlen

    # use explaining variables; avoid magic numbers
    str="$*"
    maxlen=$((lineWidth-3))

    # only truncate $str when longer than $maxlen
    if (( "${#str}" > "$maxlen" )); then
      printf "%s%s\n" "${str:0:$maxlen}" "..."
    else
      printf "%s\n" "$str"
    fi
}

if ((EUID)); then
   echo "This script must be run as root" 
   exit 1
fi

tput civis
echo -ne 'Checking for updates... '
(while :; do for c in / - \\ \|; do printf '%s\b' "$c"; sleep .1; done; done) &
apt-get update > /dev/null
u=$(echo -n "$(apt-get -V --no-download -s --fix-missing dist-upgrade | grep '^  .*' | cut -d'(' -f1 | tr -d '\n' | tr -s ' ' | sed 's/\([^ )]\) /\1, /g')")
u=${u:1:-1}
{ printf '%s'; kill $! && wait $!; } 2>/dev/null
echo 'Done'

if [[ $u ]]; then
  echo -e "Update$([[ $(echo "$u"|wc -w) -gt 1 ]]&& echo s) found: $GREEN${u%?}$NOCOLOR"
  if [[ ! $assumeYes ]]; then
    while true; do
      tput cnorm
      read -p "Do you want to continue? [Y/n] " -s -n 1 key
      [[ $key = "" || $key = "y" || $key = "Y" ]] && break
      [[ $key = "n" || $key = "N" ]] && echo -ne "\r\033[0K" && exit
      echo -ne "\r\033[0K"
    done
    tput civis
    echo -ne "\r\033[0K"
  fi

  echo -ne "Upgrading package$([[ $(echo "$u"|wc -w) -gt 1 ]]&& echo s)... "
  apt-get full-upgrade -y > /dev/null 2>&1 &
  pid=$!
  while kill -0 $pid 2> /dev/null; do
    log=$(tail /var/log/apt/term.log -n 1 &)
    if ! [[ $log == Log* ]]; then
      echo -ne "\r\033[0K"
      echo -ne "$(trim "${log/%...}")"
    fi
  sleep .25
  done
  echo -ne "\r\033[0K"
  echo "Upgrading package$([[ $(echo "$u"|wc -w) -gt 1 ]]&& echo s)... Done"
else
  echo 'No updates'
fi

echo -ne 'Cleaning up... '
(while :; do for c in / - \\ \|; do printf '%s\b' "$c"; sleep .1; done; done) &
apt-get autoremove -y >/dev/null 2>&1
apt-get clean -y
{ printf '%s'; kill $! && wait $!; } 2>/dev/null
echo 'Done'

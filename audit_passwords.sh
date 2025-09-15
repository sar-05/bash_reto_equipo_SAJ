#!/usr/bin/env bash

WORDLIST_PATH="./rockyou.txt"

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

is_john_installed(){
  if ! command -v john &>/dev/null; then
    err "John is not installed"
    return 1
  fi
}

get_unshadow(){
  if [[ ! -f /etc/passwd ]]; then
    err "Missing /etc/passwd file"
    return 1
  fi

  if [[ ! -f /etc/shadow ]]; then
    err "Missing /etc/passwd file"
    return 1
  fi

  # Regular users have an ID greater than 1000 and a login shell defined
  sudo unshadow /etc/passwd /etc/shadow \
    | awk --field-separator=':' '$3 >= 1000 && $7 ~ /^(\/(bin|usr\/bin)\/(bash|sh|zsh|fish))$/'
}

get_unshadow_users(){
  get_unshadow | awk --field-separator=':' '$3 >= 1000 && $7 ~ /^(\/(bin|usr\/bin)\/(bash|sh|zsh|fish))$/ {print $1}'
}

get_unshadow_entries(){
  get_unshadow | awk --field-separator=':' '$3 >= 1000 && $7 ~ /^(\/(bin|usr\/bin)\/(bash|sh|zsh|fish))$/'
}

make_john_rip(){
  local wordlist="$1"
  john --wordlist="$wordlist" --format=crypt <(get_unshadow_entries)
}

get_rip_users(){
  users=()

  while IFS= read -r line; do
    # break on the first empty line
    [[ -z "$line" ]] && break 
    # extract up to the first colon
    user="${line%%:*}"
    users+=("$user")
  done < <(john --show <(get_unshadow))

  echo "${users[@]}"
}

get_report(){
  while IFS= read -r user; do
    if grep --quiet "$user" <(get_rip_users); then
      echo "$user has been riped"
    else
      echo "$user hasn't been riped"
    fi
done < <(get_unshadow_users)
}

is_john_installed 
make_john_rip "$WORDLIST_PATH"
get_report

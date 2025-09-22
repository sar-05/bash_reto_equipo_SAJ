#!/usr/bin/env bash

REPORT_PATH=${REPORT_PATH:='./passwords_report'}
LOG_PATH=${LOG_PATH:='./audit_passwords.log'}
LOG_LEVEL=${LOG_LEVEL:='DEBUG'}

err() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S %z')]: $*" | tee --append "$LOG_PATH" >&2
}

warn() {
  if [[ "$LOG_LEVEL" =~ DEBUG|INFO|WARN ]]; then
    echo "[$(date +'+%Y-%m-%d %H:%M:%S %z')]: $*" | tee --append "$LOG_PATH" >&2
  fi
}

inf() {
  if [[ "$LOG_LEVEL" =~ DEBUG|INFO ]]; then
    echo "[$(date +'+%Y-%m-%d %H:%M:%S %z')]: $*" | tee --append "$LOG_PATH" >&2
  fi
}

debug() {
  if [[ "$LOG_LEVEL" == 'DEBUG' ]]; then
    echo "[$(date +'+%Y-%m-%d %H:%M:%S %z')]: $*" | tee --append "$LOG_PATH" >&2
  fi
}

is_wordlist_available(){
  default_path="/usr/share/wordlists/rockyou.txt"
  script_path="./rockyou.txt"
  if [[ -f "$default_path" ]]; then
    inf "Wordlist found in $default_path"
    WORDLIST_PATH="/usr/share/wordlists/rockyou.txt"
  elif [[ -f "$script_path" ]]; then
    inf "Wordlist found in script directory"
    WORDLIST_PATH="./rockyou.txt"
  else
    warn "Unable to find wordlist"
    return 1
  fi
}

is_wget_installed(){
  if ! command -v wget &>/dev/null; then
    err "wget is not installed"
    return 1
  fi
  debug "Found John in PATH"
}

get_wordlist(){
  if is_wget_installed; then
    inf "Getting rockyou.txt wordlist"
    debug "Starting wget request"
    if [[ "$LOG_LEVEL" == DEBUG ]]; then
      wget 'https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt'
    else
      wget --quiet 'https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt'
    fi
  else
    err "Unable to get wordlist from github"
    return 1
  fi
}

is_john_installed(){
  if ! command -v john &>/dev/null; then
    err "John is not installed"
    return 1
  fi
  debug "John found in path"
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
  debug "Trying to unshadow /etc/passwd with /etc/shadow"
  sudo unshadow /etc/passwd /etc/shadow \
    | awk --field-separator=':' '$3 >= 1000 && $7 ~ /^(\/(bin|usr\/bin)\/(bash|sh|zsh|fish))$/'
}

get_unshadow_users(){
  debug "Getting unshadow users"
  get_unshadow | awk --field-separator=':' '$3 >= 1000 && $7 ~ /^(\/(bin|usr\/bin)\/(bash|sh|zsh|fish))$/ {print $1}'
}

get_unshadow_entries(){
  debug "Getting full unshadow entries"
  get_unshadow | awk --field-separator=':' '$3 >= 1000 && $7 ~ /^(\/(bin|usr\/bin)\/(bash|sh|zsh|fish))$/'
}

make_john_rip(){
  local wordlist="$1"
  debug "Starting decryption with john"
  john --wordlist="$wordlist" --format=crypt <(get_unshadow_entries)
}

get_rip_users(){
  debug "Starting parsing of users"
  rip_users=()

  while IFS= read -r line; do
    # break on the first empty line
    [[ -z "$line" ]] && debug "Breaking due to empty line" && break 
    # extract up to the first colon
    user="${line%%:*}"
    debug "Adding $user user to rip_users arrays"
    rip_users+=("$user")
  done < <(john --show <(get_unshadow))

  echo "${rip_users[@]}"
}

get_report(){
  debug "Starting report at $REPORT_PATH"
  echo "PASSWORD     |  " | tee "$REPORT_PATH"
  while IFS= read -r user; do
    if grep --quiet "$user" <(get_rip_users); then
      printf "%10s    | Weak\n" "$user" | tee --append "$REPORT_PATH"
    else
      printf "%10s    | Strong\n" "$user" | tee --append "$REPORT_PATH"
    fi
done < <(get_unshadow_users)
}

main(){
  if ! is_john_installed; then
    exit 1
  fi

  if ! is_wordlist_available; then
    get_wordlist || exit 1
  fi

  make_john_rip "$WORDLIST_PATH"

  get_report
}

main

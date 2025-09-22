#!/usr/bin/env bash

REPROT_PATH="./passwords_report"
LOG_PATH="./audit_passwords.log"
LOG_LEVEL="DEBUG"

err() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S %z')]: $*" | tee -a "$LOG_PATH" >&2
}

warn() {
  if [[ "$LOG_LEVEL" =~ DEBUG|INFO|WARN ]]; then
    echo "[$(date +'+%Y-%m-%d %H:%M:%S %z')]: $*" | tee -a "$LOG_PATH" >&2
  fi
}

info() {
  if [[ "$LOG_LEVEL" =~ DEBUG|INFO ]]; then
    echo "[$(date +'+%Y-%m-%d %H:%M:%S %z')]: $*" | tee -a "$LOG_PATH" >&2
  fi
}

debug() {
  if [[ "$LOG_LEVEL" == 'DEBUG' ]]; then
    echo "[$(date +'+%Y-%m-%d %H:%M:%S %z')]: $*" | tee -a "$LOG_PATH" >&2
  fi
}

is_wordlist_available(){
  if [[ -f "/usr/share/wordlists/rockyou.txt" ]]; then
    info "Wordlist found in default path"
    WORDLIST_PATH="/usr/share/wordlists/rockyou.txt"
  elif [[ -f "./rockyou.txt" ]]; then
    info "Wordlist found in script directory"
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
}

get_wordlist(){
  if is_wget_installed; then
    echo "Getting rockyou.txt wordlist"
    wget --quiet 'https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt'
  else
    err "Unable to get wordlist from github"
  fi
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
  echo "PASSWORD     |  " | tee "$REPROT_PATH"
  while IFS= read -r user; do
    if grep --quiet "$user" <(get_rip_users); then
      printf "%10s    | Weak" "$user" | tee "$REPROT_PATH"
    else
      printf "%10s    | Strong" "$user" | tee "$REPROT_PATH"
    fi
done < <(get_unshadow_users)
}

main(){
  is_john_installed 

  if ! is_wordlist_available; then
    get_wordlist
  fi

  make_john_rip "$WORDLIST_PATH"
  get_report
}

main

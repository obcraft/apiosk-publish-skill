#!/usr/bin/env bash
set -euo pipefail

WALLET_TXT_FILE="${HOME}/.apiosk/wallet.txt"
WALLET_JSON_FILE="${HOME}/.apiosk/wallet.json"

trim() {
  local v="$1"
  # shellcheck disable=SC2001
  echo "$(echo "$v" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
}

lowercase_wallet() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

validate_wallet_format() {
  local wallet="$1"
  [[ "$wallet" =~ ^0x[a-fA-F0-9]{40}$ ]]
}

validate_signature_format() {
  local sig="$1"
  [[ "$sig" =~ ^0x[a-fA-F0-9]{130}$ ]]
}

load_wallet_address() {
  local explicit_wallet="${1:-}"

  if [[ -n "$explicit_wallet" ]]; then
    echo "$explicit_wallet"
    return 0
  fi

  if [[ -f "$WALLET_TXT_FILE" ]]; then
    local from_txt
    from_txt="$(cat "$WALLET_TXT_FILE")"
    from_txt="$(trim "$from_txt")"
    if [[ -n "$from_txt" ]]; then
      echo "$from_txt"
      return 0
    fi
  fi

  if [[ -f "$WALLET_JSON_FILE" ]]; then
    local from_json
    from_json="$(jq -r '.address // empty' "$WALLET_JSON_FILE")"
    from_json="$(trim "$from_json")"
    if [[ -n "$from_json" ]]; then
      echo "$from_json"
      return 0
    fi
  fi

  return 1
}

generate_nonce() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
    return 0
  fi

  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-'
    return 0
  fi

  date +%s%N
}

build_auth_message() {
  local action="$1"
  local resource="$2"
  local wallet="$3"
  local timestamp="$4"
  local nonce="$5"
  local lower_wallet
  lower_wallet="$(lowercase_wallet "$wallet")"

  printf 'Apiosk auth\naction:%s\nwallet:%s\nresource:%s\ntimestamp:%s\nnonce:%s' \
    "$action" "$lower_wallet" "$resource" "$timestamp" "$nonce"
}

prepare_wallet_auth() {
  local action="$1"
  local resource="$2"
  local wallet="$3"
  local explicit_timestamp="${4:-}"
  local explicit_nonce="${5:-}"

  if [[ -n "$explicit_timestamp" ]]; then
    AUTH_TIMESTAMP="$explicit_timestamp"
  else
    AUTH_TIMESTAMP="$(date +%s)"
  fi

  if [[ -n "$explicit_nonce" ]]; then
    AUTH_NONCE="$explicit_nonce"
  else
    AUTH_NONCE="$(generate_nonce)"
  fi

  AUTH_MESSAGE="$(build_auth_message "$action" "$resource" "$wallet" "$AUTH_TIMESTAMP" "$AUTH_NONCE")"
}

set_auth_signature() {
  local explicit_signature="${1:-}"
  local sig

  sig="$(trim "${explicit_signature}")"
  if [[ -z "$sig" ]]; then
    echo "Error: --signature is required for signed wallet auth."
    echo ""
    echo "Sign this exact message with the wallet that owns the listing:"
    echo "----------------------------------------"
    printf '%s\n' "$AUTH_MESSAGE"
    echo "----------------------------------------"
    echo "Then rerun with:"
    echo "  --signature 0x..."
    exit 1
  fi

  if ! validate_signature_format "$sig"; then
    echo "Error: invalid signature format. Expected 65-byte hex signature (0x...)."
    exit 1
  fi

  AUTH_SIGNATURE="$sig"
}

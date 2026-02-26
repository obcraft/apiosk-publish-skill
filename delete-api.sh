#!/usr/bin/env bash
set -euo pipefail

# Apiosk Publisher - Delete API
# Deactivate an API with signed wallet auth.

GATEWAY_URL="https://gateway.apiosk.com"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=auth-utils.sh
source "$SCRIPT_DIR/auth-utils.sh"

SLUG=""
WALLET=""
SIGNATURE=""
TIMESTAMP=""
NONCE=""

print_help() {
  echo "Usage: $0 --slug SLUG [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --slug SLUG              API slug to deactivate (required)"
  echo "  --wallet ADDRESS         Wallet address (optional: defaults from ~/.apiosk/wallet.txt)"
  echo "  --signature HEX          Wallet signature for canonical auth message (required)"
  echo "  --timestamp UNIX         Optional auth timestamp override"
  echo "  --nonce NONCE            Optional auth nonce override"
  echo "  --help                   Show this help"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug)
      SLUG="$2"
      shift 2
      ;;
    --wallet)
      WALLET="$2"
      shift 2
      ;;
    --signature)
      SIGNATURE="$2"
      shift 2
      ;;
    --timestamp)
      TIMESTAMP="$2"
      shift 2
      ;;
    --nonce)
      NONCE="$2"
      shift 2
      ;;
    --help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_help
      exit 1
      ;;
  esac
done

if [[ -z "$SLUG" ]]; then
  echo "Error: --slug is required"
  print_help
  exit 1
fi

WALLET="$(load_wallet_address "$WALLET" || true)"
if [[ -z "$WALLET" ]]; then
  echo "Error: Wallet not found. Provide --wallet or create ~/.apiosk/wallet.txt"
  exit 1
fi

if ! validate_wallet_format "$WALLET"; then
  echo "Error: Invalid wallet address format"
  exit 1
fi

RESOURCE="delete:${SLUG}"
prepare_wallet_auth "delete_api" "$RESOURCE" "$WALLET" "$TIMESTAMP" "$NONCE"
if [[ -z "$SIGNATURE" && -n "${APIOSK_AUTH_SIGNATURE:-}" ]]; then
  SIGNATURE="${APIOSK_AUTH_SIGNATURE}"
fi
set_auth_signature "$SIGNATURE"

echo "Deactivating API '$SLUG'..."
echo ""

RAW_RESPONSE="$(curl -s -w "\n%{http_code}" -X DELETE "$GATEWAY_URL/v1/apis/$SLUG?wallet=$WALLET" \
  -H "x-wallet-address: $WALLET" \
  -H "x-wallet-signature: $AUTH_SIGNATURE" \
  -H "x-wallet-timestamp: $AUTH_TIMESTAMP" \
  -H "x-wallet-nonce: $AUTH_NONCE")"

HTTP_CODE="$(echo "$RAW_RESPONSE" | tail -n1)"
RESPONSE="$(echo "$RAW_RESPONSE" | sed '$d')"

if ! echo "$RESPONSE" | jq empty 2>/dev/null; then
  echo "Gateway returned HTTP $HTTP_CODE"
  echo "$RESPONSE"
  exit 1
fi

SUCCESS="$(echo "$RESPONSE" | jq -r '.success')"

if [[ "$SUCCESS" == "true" ]]; then
  echo "API deactivated successfully."
  echo "$(echo "$RESPONSE" | jq -r '.message')"
else
  echo "Deactivation failed"
  echo "$(echo "$RESPONSE" | jq -r '.message')"
  exit 1
fi

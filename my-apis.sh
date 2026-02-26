#!/usr/bin/env bash
set -euo pipefail

# Apiosk Publisher - My APIs
# List your registered APIs and revenue stats with signed wallet auth.

GATEWAY_URL="https://gateway.apiosk.com"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=auth-utils.sh
source "$SCRIPT_DIR/auth-utils.sh"

WALLET=""
SIGNATURE=""
TIMESTAMP=""
NONCE=""

print_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --wallet ADDRESS         Wallet address (optional: defaults from ~/.apiosk/wallet.txt)"
  echo "  --signature HEX          Wallet signature for canonical auth message (required)"
  echo "  --timestamp UNIX         Optional auth timestamp override"
  echo "  --nonce NONCE            Optional auth nonce override"
  echo "  --help                   Show this help"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

WALLET="$(load_wallet_address "$WALLET" || true)"
if [[ -z "$WALLET" ]]; then
  echo "Error: Wallet not found. Provide --wallet or create ~/.apiosk/wallet.txt"
  exit 1
fi

if ! validate_wallet_format "$WALLET"; then
  echo "Error: Invalid wallet address format"
  exit 1
fi

RESOURCE="mine:${WALLET}"
prepare_wallet_auth "my_apis" "$RESOURCE" "$WALLET" "$TIMESTAMP" "$NONCE"
if [[ -z "$SIGNATURE" && -n "${APIOSK_AUTH_SIGNATURE:-}" ]]; then
  SIGNATURE="${APIOSK_AUTH_SIGNATURE}"
fi
set_auth_signature "$SIGNATURE"

echo "Fetching your APIs..."
echo ""

RAW_RESPONSE="$(curl -s -w "\n%{http_code}" "$GATEWAY_URL/v1/apis/mine?wallet=$WALLET" \
  -H "x-wallet-address: $WALLET" \
  -H "x-wallet-signature: $AUTH_SIGNATURE" \
  -H "x-wallet-timestamp: $AUTH_TIMESTAMP" \
  -H "x-wallet-nonce: $AUTH_NONCE")"

HTTP_CODE="$(echo "$RAW_RESPONSE" | tail -n1)"
RESPONSE="$(echo "$RAW_RESPONSE" | sed '$d')"

if ! echo "$RESPONSE" | jq empty 2>/dev/null; then
  echo "Gateway returned HTTP $HTTP_CODE"
  echo "$RESPONSE"
  if [[ "$HTTP_CODE" == "401" ]]; then
    echo "Auth failed. Check wallet/signature and retry."
  fi
  exit 1
fi

API_COUNT="$(echo "$RESPONSE" | jq '.apis | length')"
TOTAL_EARNINGS="$(echo "$RESPONSE" | jq -r '.total_earnings_usd')"

if [[ "$API_COUNT" -eq 0 ]]; then
  echo "No APIs registered yet."
  echo ""
  echo "Register your first API:"
  echo "  ./register-api.sh --help"
  exit 0
fi

echo "Your APIs ($API_COUNT total)"
echo "Total Earnings: \$$TOTAL_EARNINGS USD"
echo ""

echo "$RESPONSE" | jq -r '.apis[] |
  "----------------------------------------\n" +
  (.name + " (" + .slug + ")\n") +
  ("  Gateway: https://gateway.apiosk.com/" + .slug + "\n") +
  ("  Endpoint: " + .endpoint_url + "\n") +
  ("  Price: $" + (.price_usd|tostring) + "/request\n") +
  ("  Active: " + (.active|tostring) + " | Verified: " + (.verified|tostring) + "\n") +
  ("  Requests: " + (.total_requests|tostring) + "\n") +
  ("  Earned: $" + (.total_earned_usd|tostring) + " USD\n") +
  ("  Pending: $" + (.pending_withdrawal_usd|tostring) + " USD\n")'

echo "----------------------------------------"
echo ""
echo "Update an API: ./update-api.sh --slug SLUG --help"
echo "Delete an API: ./delete-api.sh --slug SLUG --help"

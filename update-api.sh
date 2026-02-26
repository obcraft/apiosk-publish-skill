#!/usr/bin/env bash
set -euo pipefail

# Apiosk Publisher - Update API
# Update your API configuration with signed wallet auth.

GATEWAY_URL="https://gateway.apiosk.com"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=auth-utils.sh
source "$SCRIPT_DIR/auth-utils.sh"

# Default values
SLUG=""
WALLET=""
SIGNATURE=""
TIMESTAMP=""
NONCE=""
ENDPOINT=""
PRICE=""
DESCRIPTION=""
ACTIVE=""

print_help() {
  echo "Usage: $0 --slug SLUG [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --slug SLUG              API slug to update (required)"
  echo "  --wallet ADDRESS         Wallet address (optional: defaults from ~/.apiosk/wallet.txt)"
  echo "  --signature HEX          Wallet signature for canonical auth message (required)"
  echo "  --timestamp UNIX         Optional auth timestamp override"
  echo "  --nonce NONCE            Optional auth nonce override"
  echo "  --endpoint URL           New endpoint URL (HTTPS required)"
  echo "  --price USD              New price per request (0.0001-10.00)"
  echo "  --description TEXT       New description"
  echo "  --active BOOL            Active status (true/false)"
  echo "  --help                   Show this help"
}

# Parse arguments
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
    --endpoint)
      ENDPOINT="$2"
      shift 2
      ;;
    --price)
      PRICE="$2"
      shift 2
      ;;
    --description)
      DESCRIPTION="$2"
      shift 2
      ;;
    --active)
      ACTIVE="$2"
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

if [[ -n "$ENDPOINT" && ! "$ENDPOINT" =~ ^https:// ]]; then
  echo "Error: Endpoint must use HTTPS"
  exit 1
fi

RESOURCE="update:${SLUG}"
prepare_wallet_auth "update_api" "$RESOURCE" "$WALLET" "$TIMESTAMP" "$NONCE"
if [[ -z "$SIGNATURE" && -n "${APIOSK_AUTH_SIGNATURE:-}" ]]; then
  SIGNATURE="${APIOSK_AUTH_SIGNATURE}"
fi
set_auth_signature "$SIGNATURE"

# Build JSON payload (only include provided fields)
PAYLOAD_ARGS=(--arg wallet "$WALLET")
JQ_FIELDS="{ owner_wallet: \$wallet"

if [[ -n "$ENDPOINT" ]]; then
  PAYLOAD_ARGS+=(--arg endpoint "$ENDPOINT")
  JQ_FIELDS+=", endpoint_url: \$endpoint"
fi

if [[ -n "$PRICE" ]]; then
  PAYLOAD_ARGS+=(--argjson price "$PRICE")
  JQ_FIELDS+=", price_usd: \$price"
fi

if [[ -n "$DESCRIPTION" ]]; then
  PAYLOAD_ARGS+=(--arg description "$DESCRIPTION")
  JQ_FIELDS+=", description: \$description"
fi

if [[ -n "$ACTIVE" ]]; then
  ACTIVE_BOOL="false"
  if [[ "$ACTIVE" == "true" || "$ACTIVE" == "1" ]]; then
    ACTIVE_BOOL="true"
  fi
  PAYLOAD_ARGS+=(--argjson active "$ACTIVE_BOOL")
  JQ_FIELDS+=", active: \$active"
fi

JQ_FIELDS+=" }"
PAYLOAD="$(jq -n "${PAYLOAD_ARGS[@]}" "$JQ_FIELDS")"

echo "Updating API '$SLUG'..."
echo ""

RAW_RESPONSE="$(curl -s -w "\n%{http_code}" -X POST "$GATEWAY_URL/v1/apis/$SLUG" \
  -H "Content-Type: application/json" \
  -H "x-wallet-address: $WALLET" \
  -H "x-wallet-signature: $AUTH_SIGNATURE" \
  -H "x-wallet-timestamp: $AUTH_TIMESTAMP" \
  -H "x-wallet-nonce: $AUTH_NONCE" \
  -d "$PAYLOAD")"

HTTP_CODE="$(echo "$RAW_RESPONSE" | tail -n1)"
RESPONSE="$(echo "$RAW_RESPONSE" | sed '$d')"

if ! echo "$RESPONSE" | jq empty 2>/dev/null; then
  echo "Gateway returned HTTP $HTTP_CODE"
  echo "$RESPONSE"
  exit 1
fi

SUCCESS="$(echo "$RESPONSE" | jq -r '.success')"

if [[ "$SUCCESS" == "true" ]]; then
  echo "API updated successfully."
  echo ""
  echo "$(echo "$RESPONSE" | jq -r '.message')"
else
  echo "Update failed"
  echo ""
  echo "$(echo "$RESPONSE" | jq -r '.message')"
  exit 1
fi

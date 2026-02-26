# Apiosk Publish Skill

Publish and manage paid APIs on `https://gateway.apiosk.com`.

## Install

```bash
npx skills add obcraft/apiosk-publish-skill --skill apiosk-publish
```

## Auth Model

Management endpoints require signed wallet auth headers:

- `x-wallet-address`
- `x-wallet-signature`
- `x-wallet-timestamp`
- `x-wallet-nonce`

This skill does not read or store local signing key material.  
You provide signatures via `--signature` (or `APIOSK_AUTH_SIGNATURE`).

If `--signature` is missing, scripts print the exact canonical message to sign.

## Quick Start

```bash
# Register
./register-api.sh \
  --name "My Weather API" \
  --slug "my-weather-api" \
  --endpoint "https://my-api.com/v1" \
  --price 0.01 \
  --description "Real-time weather data" \
  --listing-group datasets \
  --signature 0xYourSignature

# List your APIs
./my-apis.sh --signature 0xYourSignature

# Update
./update-api.sh --slug my-weather-api --price 0.02 --signature 0xYourSignature

# Deactivate
./delete-api.sh --slug my-weather-api --signature 0xYourSignature
```

## Listing Groups

- `api`
- `datasets`
- `compute`

`--listing-group` maps to `category`:

- `api` -> `data`
- `datasets` -> `dataset`
- `compute` -> `compute`

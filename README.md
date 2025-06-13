# Coinbase Sanbox Exchange API

Motoko implementation for integrating with Coinbase Exchange API on the Internet Computer. Enables on-chain trading through Coinbase's sandbox environment.

## Features

- **Coinbase Exchange API**: Professional trading API (not consumer api.coinbase.com).
- **Sandbox Environment**: Testing with `api-public.sandbox.exchange.coinbase.com`.
- **HMAC Authentication**: Base64-decoded secret, HMAC-SHA256 signature generation.
- **Idempotent Proxy**: HTTP requests through proxy canister with Cloudflare Worker.
- **Market & Account Data**: Public market data and authenticated account operations.

## Setup

1. Create Coinbase Exchange sandbox account and generate API keys.
2. **Important**: Whitelist your proxy's static IP address during API key creation.
3. Install `motoko-env` using `npm install motoko-env`.
4. Enter your environment variables into your `.env` file(Be aware of the security risks).
5. Run `npx motoko-env generate`.

## API Functions

### No Auth

- `time()` - Server time.
- `products()` - Trading pairs.
- `getTicker(product_id)` - Real-time ticker.

### Auth Required

- `getAccounts()` - Account balances
- `placeBuyOrder(product_id, funds)` - Market buy order
- `getAccountsDebug()` - Raw text response debugging

## Authentication

Signature = Base64(HMAC-SHA256(base64_decode(secret), timestamp + method + path + body))

Required headers:

- `CB-ACCESS-KEY`
- `CB-ACCESS-SIGN`
- `CB-ACCESS-TIMESTAMP`
- `CB-ACCESS-PASSPHRASE`

## Limitations

- Requires static IP whitelisting.
- Auth required endpoint cannot be called directly without the use of a proxy, this is because the ip address of nodes in the subnet is difficult to determine and whitelist.
- Sandbox environment only (modify `sandbox_host` for production).
- Subject to Coinbase rate limits.

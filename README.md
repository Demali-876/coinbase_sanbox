# Coinbase Sandbox Exchange API

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
4. Enter your environment variables into your `.env` file (Be aware of the security risks).
5. Run `npx motoko-env generate`.
6. Deploy idempotent proxy canister:

   ```bash
   dfx deploy idempotent_proxy_canister --argument '(opt variant { Init = record {
     ecdsa_key_name = "dfx_test_key";
     proxy_token_refresh_interval = 3600;
     subnet_size = 13;
     service_fee = 10_000_000;
   }})'
   ```

7. Configure proxy worker endpoint:

   ```bash
   dfx canister call idempotent_proxy_canister admin_set_agents '(vec {
     record {
       name = "SandboxWorker";
       endpoint = "https://your-worker.workers.dev";
       max_cycles = 30000000000;
       proxy_token = null;
     };
   })'
   ```

8. Add sandbox canister as authorized caller:

   ```bash
   dfx canister call idempotent_proxy_canister admin_add_callers \
     "(vec { principal \"$(dfx canister id sandbox)\" })"
   ```

9. Establish connection with the Coinbase server:

   ```bash
   dfx canister call sandbox time
   ```

   Expected response:

   ```bash
   (
     variant {
       object = vec {
         record { "iso"; variant { string = "2025-06-13T04:34:59.741Z" } };
         record {
           "epoch";
           variant { number = variant { float = 1749789299.741 : float64 } };
         };
       }
     },
   )
   ```

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
- Auth requiring endpoints cannot be called directly on ICP without the use of a proxy, this is because the ip address of nodes in a given subnet is difficult to determine(dynamic) and  making it hard to whitelist.
- Sandbox environment only (modify `sandbox_host` for production).
- Subject to Coinbase rate limits.

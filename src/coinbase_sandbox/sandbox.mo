import IC "ic:aaaaa-aa";
import IdempotentProxy "canister:idempotent_proxy_canister";
import Env "../env";
import Json "mo:json";
import HMAC "mo:hmac";
import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Error "mo:base/Error";
import Int "mo:base/Int";
import { Base64 = Base64Engine; V2 } "mo:base64";

persistent actor Sandbox {

  private let sandbox_host = "api-public.sandbox.exchange.coinbase.com";
  private let sandbox_url = "https://" # sandbox_host;
  private let api_key = Env.api_key;
  private let api_secret = Env.secret; 
  private let passphrase = Env.passphrase;
  transient let base64 = Base64Engine(#v V2, ?false);

  private func decodeResponse(body : Blob) : Json.Json {
    switch (Text.decodeUtf8(body)) {
      case (null) { #string("No response received") };
      case (?text) {
        switch (Json.parse(text)) {
          case (#ok(json)) { json };
          case (#err(e)) { #string("JSON parse error: " # debug_show(e)) };
        }
      }
    }
  };

  func generateSignature(
    timestamp : Text,
    method : Text,
    requestPath : Text,
    body : Text
  ) : Text {
    let prehash = timestamp # method # requestPath # body;
    let msgBytes : [Nat8] = Blob.toArray(Text.encodeUtf8(prehash));
    let secretBytes : [Nat8] = base64.decode(api_secret);
    let hmacDigest : Blob = HMAC.generate(secretBytes, msgBytes.vals(), #sha256);
    let bytedigest = Blob.toArray(hmacDigest);
    base64.encode(#bytes bytedigest);
  };

  public func time() : async Json.Json {
    try {
      let url = sandbox_url # "/time";
      let http_request : IC.http_request_args = {
        url = url;
        max_response_bytes = ?2048;
        headers = [ { name = "Accept"; value = "application/json" } ];
        body = null;
        method = #get;
        transform = null;
      };

      let http_response = await (with cycles = 300_000_000) IC.http_request(http_request);
      decodeResponse(http_response.body)

    } catch (e) {
      #string("HTTP request failed: " # Error.message(e))
    }
  };

  public func products() : async Json.Json {
    try {
      let url = sandbox_url # "/products";
      let http_request : IC.http_request_args = {
        url = url;
        max_response_bytes = ?8192;
        headers = [ { name = "Accept"; value = "application/json" } ];
        body = null;
        method = #get;
        transform = null;
      };

      let http_response = await (with cycles = 300_000_000) IC.http_request(http_request);
      decodeResponse(http_response.body)

    } catch (e) {
      #string("HTTP request failed: " # Error.message(e))
    }
  };

  public func getTicker(product_id : Text) : async Json.Json {
    try {
      let url = sandbox_url # "/products/" # product_id # "/ticker";
      let http_request : IC.http_request_args = {
        url = url;
        max_response_bytes = ?2048;
        headers = [ { name = "Accept"; value = "application/json" } ];
        body = null;
        method = #get;
        transform = null;
      };

      let http_response = await (with cycles = 300_000_000) IC.http_request(http_request);
      decodeResponse(http_response.body)

    } catch (e) {
      #string("HTTP request failed: " # Error.message(e))
    }
  };

  public func getAccounts() : async Json.Json {
    try {
      let timestamp = Int.toText(Time.now() / 1_000_000_000);
      let method = "GET";
      let path = "/accounts";
      let body = "";

      let signature = generateSignature(timestamp, method, path, body);

      let http_request : IC.http_request_args = {
        url = sandbox_url # path;
        max_response_bytes = ?4096;
        headers = [
          { name = "Accept"; value = "application/json" },
          { name = "idempotency-key"; value = "idempotency_key_001" },
          { name = "CB-ACCESS-KEY"; value = api_key },
          { name = "CB-ACCESS-SIGN"; value = signature },
          { name = "CB-ACCESS-TIMESTAMP"; value = timestamp },
          { name = "CB-ACCESS-PASSPHRASE"; value = passphrase }
        ];
        body = null;
        method = #get;
        transform = null;
      };

      let http_response = await (with cycles = 300_000_000) IdempotentProxy.proxy_http_request(http_request);
      decodeResponse(http_response.body)

    } catch (e) {
      #string("HTTP request failed: " # Error.message(e))
    }
  };
  public func placeBuyOrder(product_id : Text, funds : Text) : async Json.Json {
    try {
      let timestamp = Int.toText(Time.now() / 1000000000);
      let method = "POST";
      let path = "/orders";
      let body = "{\"type\":\"market\",\"side\":\"buy\",\"product_id\":\"" # product_id # "\",\"funds\":\"" # funds # "\"}";
      
      let signature = generateSignature(timestamp, method, path, body);
      
      let url = sandbox_url # path;
      let request_headers : [IC.http_header] = [
        { name = "Accept"; value = "application/json" },
        { name = "idempotency-key"; value = "idempotency_key_002"},
        { name = "Content-Type"; value = "application/json" },
        { name = "CB-ACCESS-KEY"; value = api_key },
        { name = "CB-ACCESS-SIGN"; value = signature },
        { name = "CB-ACCESS-TIMESTAMP"; value = timestamp },
        { name = "CB-ACCESS-PASSPHRASE"; value = passphrase }
      ];
      
      let http_request : IC.http_request_args = {
        url = url;
        max_response_bytes = ?2048;
        headers = request_headers;
        body = ?Text.encodeUtf8(body);
        method = #post;
        transform = null;
      };
      
      let http_response : IC.http_request_result = await (with cycles = 300_000_000) IdempotentProxy.proxy_http_request(http_request);
      
      let decoded_json : Json.Json = switch (Text.decodeUtf8(http_response.body)) {
        case (null) { #string("No response received") };
        case (?response_text) {
          switch (Json.parse(response_text)) {
            case (#ok(json)) { json };
            case (#err(e)) {
              #string("Response: " # response_text # " | Parse error: " # debug_show(e))
            };
          };
        };
      };
      
      decoded_json
    } catch (error) {
      #string("HTTP request failed: " # Error.message(error))
    }
  };
  public func getAccountsDebug() : async Text {
  try {
    let timestamp = Int.toText(Time.now() / 1_000_000_000);
    let method = "GET";
    let path = "/accounts";
    let body = "";

    let signature = generateSignature(timestamp, method, path, body);

    let http_request : IC.http_request_args = {
      url = sandbox_url # path;
      max_response_bytes = ?4096;
      headers = [
        { name = "Accept"; value = "application/json" },
        { name = "idempotency-key"; value = "idempotency_key_003"},
        { name = "CB-ACCESS-KEY"; value = api_key },
        { name = "CB-ACCESS-SIGN"; value = signature },
        { name = "CB-ACCESS-TIMESTAMP"; value = timestamp },
        { name = "CB-ACCESS-PASSPHRASE"; value = passphrase }
      ];
      body = null;
      method = #get;
      transform = null;
    };

    let http_response = await (with cycles = 300_000_000) IdempotentProxy.proxy_http_request(http_request);
    
    // Return the raw response as text to see what's being returned
    switch (Text.decodeUtf8(http_response.body)) {
      case (null) { "No response received" };
      case (?text) { "Raw response: " # text };
    }

  } catch (e) {
    "HTTP request failed: " # Error.message(e)
  }
};
};

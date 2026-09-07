# Clover Gemini Founder-Test Proxy

Minimal stateless boundary between the Android Founder build and the paid Google
Gemini Developer API. It stores `GEMINI_API_KEY` only on the server, accepts one
selected image/rendered scanned page, applies size/rate/duplicate controls, requests
canonical JSON, validates the response, and returns token/cost metadata.

Required environment variables:

- `GEMINI_API_KEY`: paid-project key, stored as a server secret;
- `GEMINI_SERVICE_MODE=paid`: refuses to start inference without the paid-mode gate;
- `CLOVER_PROXY_TOKEN`: short-lived Founder-build authorization token;
- optional `CLOVER_MAX_REQUESTS_PER_MINUTE` (default 6).

Deploy with one small Cloud Run service (or an equivalent controlled HTTPS runtime),
Secret Manager injection, restricted ingress as appropriate, request logging with
body logging disabled, and a low maximum-instance/billing cap. The proxy does not use
Files API, caching, Search/Maps grounding, analytics, or persistent payload storage.

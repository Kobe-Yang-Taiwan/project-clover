# Cloud Vision Privacy and Provider Gate

## Current runtime status — dormant / optional research

As of the V0.16R Local Image POC, Cloud Vision is not invoked by the standard
promotional-image import flow and is not a required free/core dependency. The
provider abstraction, proxy and privacy controls remain preserved for internal
benchmarking, a future optional paid capability or explicitly approved research.
No new Gemini infrastructure is deployed by this POC.

## Founder Test selection

| Item | Approved configuration |
|---|---|
| Provider | Google Gemini Developer API |
| Model | `gemini-3.6-flash` |
| Service mode | Paid project with active billing only |
| Network path | Android → Clover HTTPS proxy → Gemini API |
| Training use | Google states Paid Service prompts/images/responses are not used to improve Google products |
| Retention | Limited abuse-monitoring logging applies; normal Paid Service is not claimed as ZDR |
| Deletion | Clover proxy persists no payload; normal Paid API has no Clover-controlled per-request deletion mechanism documented |
| Transport | HTTPS app-to-proxy and proxy-to-Gemini |
| Grounding/tools | Search, Maps and unrelated tools disabled |
| Files/cache | Not used for Founder Test |
| Pricing through 2026-12-31 | US$0.75/M input tokens + US$3.75/M output/thinking tokens |

Official references: [Gemini API Paid Service terms](https://ai.google.dev/gemini-api/terms),
[billing and paid tier](https://ai.google.dev/gemini-api/docs/billing), and
[Gemini 3.6 Flash pricing](https://ai.google.dev/gemini-api/docs/pricing).

## Data minimization and consent

Every cloud request requires the user to tap `同意並開始辨識`. Transmitted data is
one selected promotional image or one rendered scanned PDF page that lacks reliable
native text, plus source/page/retailer hints and extraction/schema instructions.

Never transmitted: coupons, reminders, database, favourites, history, backups,
device file inventory, unrelated files/pages, or reliable native-text PDF pages.
Cancellation sends zero bytes and keeps local/manual fallback available.

## Secret and proxy boundary

`GeminiCloudVisionProvider` speaks only the canonical Clover proxy contract. The
Gemini key is read from server-side `GEMINI_API_KEY`; it is prohibited from Android
source, build defines and APKs. The proxy requires `GEMINI_SERVICE_MODE=paid`, a
short-lived `CLOVER_PROXY_TOKEN`, an 8 MB asset limit, rate limit, duplicate key,
strict response schema and exact model metadata. It does not persist or log raw
images or full model input/output.

The separate `Founder Gemini APK` workflow requires:

- workflow input: deployed HTTPS `/v1/import/analyze` endpoint;
- GitHub `founder-test` environment secret: `CLOVER_VISION_ACCESS_TOKEN`.

The Gemini key belongs only in the proxy runtime/secret manager, never GitHub's APK
build job. Normal CI builds remain cloud-disabled.

## Failure and cost behavior

There is no automatic retry. Timeout, provider mismatch, unpaid mode, invalid JSON/
schema, oversize, duplicate, auth/rate failure or non-2xx response performs one
controlled failure and returns to local OCR/manual review without database mutation.

The proxy returns input/output/total tokens. Clover estimates request cost from the
current approved Standard paid rates and records count, transmitted bytes, tokens,
failures and estimated cost in the in-memory import quality report. Pricing is
time-sensitive and must be rechecked before production release.

## Production hardening still required

Before production enablement: approve proxy hosting/region, access control, log
retention, alerts/spend cap, incident owner, privacy policy/Data Safety wording and
whether an eligible ZDR arrangement is required. Founder Test approval is not a
store-production privacy approval.

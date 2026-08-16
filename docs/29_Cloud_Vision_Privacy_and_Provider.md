# Cloud Vision Privacy and Provider Gate

## Current production state

Provider: **not selected / production disabled**.

| Production disclosure item | Current status |
|---|---|
| Provider/model | Not selected; blocked from production activation |
| Transmitted data | One selected image or one required rendered scanned page |
| Retention | Unknown until provider selection; never assumed safe |
| Model training | Unknown until provider selection; never assumed safe |
| Deletion policy | Unknown until provider selection; never assumed safe |
| Transport | HTTPS required and enforced by configuration validation |
| Estimated cost/image or page | Provider-configured or server-reported; currently unknown |
| Failure behavior | No retry; local fallback and no database mutation |
| Privacy policy impact | Must be reviewed before production activation |

The standard APK contains no provider API key and makes no cloud request. Cloud
vision activates only when all of these build-time values are present:

- `CLOVER_VISION_ENDPOINT` — HTTPS proxy endpoint;
- `CLOVER_VISION_PROVIDER` — provider/model identity;
- `CLOVER_VISION_PRIVACY_DISCLOSURE` — consent text covering retention, training,
  deletion and transport behavior.

An optional short-lived proxy access token may be configured for controlled debug
testing. A permanent upstream model key must never be embedded in the APK.

## Data contract

Transmitted: one user-selected image or one rendered PDF page that lacks reliable
native text, MIME type, page number and retailer hint.

Never transmitted: coupons, reminders, database, history, unrelated files or
native-text PDF pages.

Transport: HTTPS only. HTTP endpoints are rejected.

## Retention/training/deletion gate

Production must not be enabled until the selected provider/proxy documents:

- exact provider and model;
- retention duration and deletion behavior;
- whether input/output is used for model training;
- encryption in transit and proxy logging;
- incident/failure handling;
- pricing and cost alert owner;
- privacy policy/Data Safety impact.

Unknown policy is not interpreted as safe.

## Candidate provider note

An OpenAI API-backed proxy is technically compatible with the canonical contract.
OpenAI states API data is not used for training by default unless opted in, and
standard abuse-monitoring retention may be up to 30 days; eligible customers may
request zero data retention. This is a candidate evaluation, not a production
selection or activation. See the official [OpenAI API data controls](https://developers.openai.com/api/docs/guides/your-data).

## Failure behavior

Timeout, invalid schema, oversize input, duplicate request or non-2xx response
causes one controlled failure. There is no automatic retry. The app falls back to
local OCR and warns that multi-product accuracy may be lower. Existing data remains
unchanged.

## Cost controls

- 8 MB maximum per image/page request;
- one request per asset/page per import operation;
- only pages without reliable native text;
- no automatic retry;
- request count, bytes, failures and estimated/server-reported cost retained in the
  in-memory import quality report, not the coupon database.

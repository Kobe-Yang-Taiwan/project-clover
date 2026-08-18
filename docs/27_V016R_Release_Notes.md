# Project Clover V0.16R / 0.16.1 Release Notes

Status: IMPLEMENTING Local Image POC; not Founder accepted.

Build 19 pivots the standard promotional-image path to local multi-signal region
proposal, independent crop OCR and one-tap missing-product recovery. Normal image
imports make zero cloud requests. Existing Gemini/provider/proxy code remains
dormant for research/future optional use and has not been deleted or deployed.

Build 18 adds the Founder-approved paid Gemini `gemini-3.6-flash` provider and a
small Clover-controlled proxy. The standard CI APK stays cloud-disabled; the
separate Founder workflow enables Gemini only with an HTTPS proxy and protected
short-lived proxy token.

## Import behavior changed

- Native-text PDFs are parsed locally with layout and bounding boxes instead of
  being OCRed as page images.
- Promotional images and image-only PDF pages can use explicitly consented cloud
  product-region vision through a replaceable provider contract.
- Cloud processing is off unless a secure endpoint and privacy disclosure are
  configured; no provider key is embedded in the APK.
- Each cloud field must include visible evidence from the same product region.
- Cross-product evidence rejects the candidate instead of silently mixing fields.
- Native Costco price stacks preserve original／discount／sale relationships when
  the arithmetic and spatial order agree.
- Decimal values are supported; average/unit prices remain distinct from promotion
  totals and conditions.
- Review shows whether cloud or local fallback was used and reports request/byte/
  token/estimated-cost information.

## Safety

Existing manual entry, local storage, reminder, backup/restore and atomic final
validation remain the persistence path. Cloud output is never directly saved.

## Acceptance

Local format, analysis and 120 Flutter tests pass. The local runner has no Android
SDK; GitHub Actions run #91 is the authoritative successful Build 17 Android debug
APK result (artifact `9260093101`). Founder Android Costco/PX Mart/FamilyMart
reruns remain mandatory.

Build 18 standard Android CI passed in run #93. Artifact `9260715239` is intentionally
cloud-disabled; it validates regression/build health but cannot perform the Gemini
Golden Dataset test. A provider-enabled Founder APK must be built by the protected
workflow after the Clover proxy is deployed and configured.

Build 19 QA/CI/APK and real-device POC metrics are recorded only after execution;
Build 18 evidence above remains historical and is not relabelled.

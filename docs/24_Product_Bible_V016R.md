# Product Bible Addendum — V0.16R

## Import promise

Project Clover reconstructs product promotions, not OCR fragments.

`Extract → Route → Segment/Understand → Associate → Reconstruct → Evidence Validate → Review → Import`

## Truth hierarchy

1. Explicit visible field evidence in the same product region.
2. Applicable retailer/page campaign evidence with proven shared scope.
3. User confirmation.
4. Unknown.

Guessing is not a fourth extraction method.

Cloud model output is also evidence, not truth. Provider-specific responses must be
translated at the proxy/provider boundary; the product model, deterministic
validation and persistence gate remain provider-independent.

## Product ownership

One product card owns its name, brand, model, specification, item number, prices
and discount. Shared campaign/date metadata remains shared unless scope evidence
supports inheritance. A field from another region invalidates the candidate.

## Final correctness principle

“100% final imported information correctness” means high-confidence import plus
targeted confirmation plus rejection. It does not mean pretending OCR or a cloud
model is 100% accurate.

## Core economics principle

Any feature whose recurring Founder infrastructure or inference cost grows
linearly with free-user usage must not become mandatory in Clover's free/core
journey without an approved sustainable revenue model. Optional future paid AI
features are not prohibited.

## Almost-no-typing principle

The preferred image experience is automatic local reconstruction for most
products, followed by one tap on any missed product so Clover performs the crop,
OCR and reconstruction. Manual field typing is the fallback, not the target UX.

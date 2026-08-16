# V0.16R Real-world Import Golden Dataset

The committed manifests are the permanent, reviewable source of truth. Original
retailer assets are deliberately not committed because this repository is public
and the advertisements are third-party copyrighted material.

Each external fixture is identified by SHA-256. A local or Founder-device run is
valid only when the selected asset hash matches the manifest. This prevents a
different screenshot or catalogue edition from being reported under the same
metric name.

Required cases:

- `costco_2026_spring.json`: 9-page native-text Costco PDF; page 1 is legal,
  pages 2–9 contain 129 product cards.
- `pxmart_2026_08.json`: phone screenshot with 12 product cards plus shared
  payment campaign banners and phone UI.
- `familymart_founder_failure.json`: Founder failure evidence with 8 visible
  product cards. Only an in-app thumbnail remains in the workspace, so identity
  field scoring is blocked until the original selected image is supplied again.

Do not fill unknown labels from OCR or model output. Ground truth must come from
manual visual verification of the original asset. Automated tests validate the
manifest and deterministic scoring only; Founder Android results remain G7.
Every manifest reserves the complete acceptance metric schema. Values stay `null`
with a pending status until that exact hashed asset is run on Founder Android;
pending values must never be presented as zero or as a passing measurement.

Private fixture placement for local evaluation:

`test/golden_dataset/private/<asset file>`

The `private/` directory is ignored by Git.

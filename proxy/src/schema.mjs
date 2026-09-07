const evidenceSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['text', 'confidence', 'region_id'],
  properties: {
    text: {type: 'string'},
    confidence: {type: 'number', minimum: 0, maximum: 1},
    region_id: {type: 'string'},
    bounds: {
      type: ['object', 'null'],
      additionalProperties: false,
      required: ['left', 'top', 'right', 'bottom'],
      properties: {
        left: {type: 'number', minimum: 0, maximum: 1},
        top: {type: 'number', minimum: 0, maximum: 1},
        right: {type: 'number', minimum: 0, maximum: 1},
        bottom: {type: 'number', minimum: 0, maximum: 1}
      }
    }
  }
};

const evidenced = (valueSchema) => ({
  anyOf: [
    {type: 'null'},
    {
      type: 'object',
      additionalProperties: false,
      required: ['value', 'evidence'],
      properties: {value: valueSchema, evidence: evidenceSchema}
    }
  ]
});

export const canonicalResponseSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['products'],
  properties: {
    products: {
      type: 'array',
      maxItems: 40,
      items: {
        type: 'object',
        additionalProperties: false,
        required: [
          'product_region_id',
          'region_evidence',
          'product_name',
          'merchant',
          'brand',
          'model',
          'specification',
          'item_number',
          'promotional_price',
          'original_price',
          'discount_amount',
          'promotion_condition',
          'valid_from',
          'valid_until',
          'category_hint',
          'notes',
          'uncertain_fields'
        ],
        properties: {
          product_region_id: {type: 'string'},
          region_evidence: evidenceSchema,
          merchant: evidenced({type: 'string'}),
          brand: evidenced({type: 'string'}),
          product_name: evidenced({type: 'string'}),
          model: evidenced({type: 'string'}),
          specification: evidenced({type: 'string'}),
          item_number: evidenced({type: 'string'}),
          promotional_price: evidenced({type: 'number', exclusiveMinimum: 0}),
          original_price: evidenced({type: 'number', exclusiveMinimum: 0}),
          discount_amount: evidenced({type: 'number', exclusiveMinimum: 0}),
          promotion_condition: evidenced({type: 'string'}),
          valid_from: evidenced({type: 'string', format: 'date'}),
          valid_until: evidenced({type: 'string', format: 'date'}),
          category_hint: evidenced({type: 'string'}),
          notes: evidenced({type: 'string'}),
          uncertain_fields: {type: 'array', items: {type: 'string'}, uniqueItems: true}
        }
      }
    }
  }
};

const allowedMimeTypes = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/heic']);
const allowedSources = new Set(['image', 'pdf']);

export function validateCloverRequest(value, maxAssetBytes = 8 * 1024 * 1024) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return 'invalid_body';
  if (value.schema_version !== 'clover.import.v1') return 'invalid_schema_version';
  if (value.task !== 'reconstruct_promotional_product_regions') return 'invalid_task';
  if (!allowedSources.has(value.source_type)) return 'invalid_source_type';
  if (!allowedMimeTypes.has(value.mime_type)) return 'invalid_mime_type';
  if (typeof value.image_base64 !== 'string' || value.image_base64.length === 0) {
    return 'missing_image';
  }
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(value.image_base64)) return 'invalid_image_base64';
  const bytes = Buffer.from(value.image_base64, 'base64');
  if (bytes.length === 0 || bytes.length > maxAssetBytes) return 'asset_size_not_allowed';
  if (value.source_type === 'pdf' && (!Number.isInteger(value.page_number) || value.page_number < 1)) {
    return 'invalid_page_number';
  }
  if (typeof value.retailer_hint !== 'string' || value.retailer_hint.length > 80) {
    return 'invalid_retailer_hint';
  }
  return null;
}

export function validateCanonicalProducts(value) {
  if (!value || typeof value !== 'object' || !Array.isArray(value.products)) {
    return 'missing_products';
  }
  if (value.products.length > 40) return 'too_many_products';
  const ids = new Set();
  for (const product of value.products) {
    if (!product || typeof product !== 'object') return 'invalid_product';
    const id = product.product_region_id;
    if (typeof id !== 'string' || id.trim() === '' || ids.has(id)) {
      return 'invalid_or_duplicate_region_id';
    }
    ids.add(id);
    if (!validEvidence(product.region_evidence, id)) return 'invalid_region_evidence';
    if (!validEvidencedString(product.product_name, id)) return 'invalid_product_name';
    if (!Array.isArray(product.uncertain_fields)) return 'invalid_uncertain_fields';
    for (const key of [
      'merchant', 'brand', 'model', 'specification', 'item_number',
      'promotion_condition', 'valid_from', 'valid_until', 'category_hint', 'notes'
    ]) {
      if (!validOptionalEvidenced(product[key])) return `invalid_${key}`;
    }
    for (const key of ['promotional_price', 'original_price', 'discount_amount']) {
      if (!validOptionalEvidenced(product[key], true)) return `invalid_${key}`;
    }
  }
  return null;
}

function validOptionalEvidenced(value, numeric = false) {
  if (value === null) return true;
  if (!value || typeof value !== 'object') return false;
  if (numeric ? typeof value.value !== 'number' || value.value <= 0 : typeof value.value !== 'string' || value.value.trim() === '') {
    return false;
  }
  return validEvidence(value.evidence);
}

function validEvidencedString(value, regionId) {
  return value && typeof value === 'object' && typeof value.value === 'string' &&
    value.value.trim() !== '' && validEvidence(value.evidence, regionId);
}

function validEvidence(value, expectedRegionId) {
  if (!value || typeof value !== 'object') return false;
  if (typeof value.text !== 'string' || value.text.trim() === '') return false;
  if (typeof value.confidence !== 'number' || value.confidence < 0 || value.confidence > 1) return false;
  if (typeof value.region_id !== 'string' || value.region_id.trim() === '') return false;
  return expectedRegionId === undefined || value.region_id === expectedRegionId;
}

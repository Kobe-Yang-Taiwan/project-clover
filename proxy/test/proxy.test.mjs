import assert from 'node:assert/strict';
import test from 'node:test';
import {buildGeminiRequest, estimateCost} from '../src/gemini.mjs';
import {createCloverProxy} from '../src/server.mjs';
import {validateCanonicalProducts, validateCloverRequest} from '../src/schema.mjs';

const requestBody = {
  schema_version: 'clover.import.v1',
  task: 'reconstruct_promotional_product_regions',
  source_type: 'image',
  page_number: null,
  retailer_hint: 'familymart',
  mime_type: 'image/png',
  image_base64: Buffer.from([1, 2, 3]).toString('base64')
};

const canonical = {
  products: [{
    product_region_id: 'card-1',
    region_evidence: {text: '鮮乳 89元', confidence: 0.98, region_id: 'card-1'},
    merchant: null,
    brand: null,
    product_name: {value: '鮮乳', evidence: {text: '鮮乳', confidence: 0.98, region_id: 'card-1'}},
    model: null,
    specification: null,
    item_number: null,
    promotional_price: {value: 89, evidence: {text: '89元', confidence: 0.98, region_id: 'card-1'}},
    original_price: null,
    discount_amount: null,
    promotion_condition: null,
    valid_from: null,
    valid_until: null,
    category_hint: null,
    notes: null,
    uncertain_fields: ['merchant', 'valid_until']
  }]
};

test('validates only one minimal image/page request', () => {
  assert.equal(validateCloverRequest(requestBody), null);
  assert.equal(validateCloverRequest({...requestBody, mime_type: 'application/pdf'}), 'invalid_mime_type');
  assert.equal(validateCloverRequest({...requestBody, source_type: 'pdf'}), 'invalid_page_number');
  assert.equal(validateCanonicalProducts(canonical), null);
});

test('Gemini request has structured JSON and no tools, files or caching', () => {
  const body = buildGeminiRequest(requestBody);
  assert.equal(body.generationConfig.responseMimeType, 'application/json');
  assert.equal(body.tools, undefined);
  assert.equal(body.cachedContent, undefined);
  assert.deepEqual(body.contents[0].parts[1].inlineData.data, requestBody.image_base64);
});

test('paid proxy protects upstream secret and returns usage/cost only', async () => {
  let upstreamCalls = 0;
  const upstream = async (_url, options) => {
    upstreamCalls += 1;
    assert.equal(options.headers['x-goog-api-key'], 'server-only-gemini-key');
    assert.equal(options.body.includes('server-only-gemini-key'), false);
    return new Response(JSON.stringify({
      candidates: [{content: {parts: [{text: JSON.stringify(canonical)}]}}],
      usageMetadata: {promptTokenCount: 1000, candidatesTokenCount: 200, totalTokenCount: 1200}
    }), {status: 200, headers: {'content-type': 'application/json'}});
  };
  const server = createCloverProxy({
    proxyToken: 'founder-short-lived-token',
    geminiApiKey: 'server-only-gemini-key',
    paidServiceMode: 'paid',
    fetchImpl: upstream
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    const {port} = server.address();
    const response = await fetch(`http://127.0.0.1:${port}/v1/import/analyze`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: 'Bearer founder-short-lived-token',
        'x-clover-request-key': 'unique-founder-image-1'
      },
      body: JSON.stringify(requestBody)
    });
    const value = await response.json();
    assert.equal(response.status, 200);
    assert.equal(value.model, 'gemini-3.6-flash');
    assert.equal(value.service_mode, 'paid');
    assert.equal(value.usage.total_tokens, 1200);
    assert.equal(value.usage.estimated_cost_usd, estimateCost(1000, 200));
    assert.equal(JSON.stringify(value).includes('server-only-gemini-key'), false);
    assert.equal(upstreamCalls, 1);

    const duplicate = await fetch(`http://127.0.0.1:${port}/v1/import/analyze`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: 'Bearer founder-short-lived-token',
        'x-clover-request-key': 'unique-founder-image-1'
      },
      body: JSON.stringify(requestBody)
    });
    assert.equal(duplicate.status, 409);
    assert.equal(upstreamCalls, 1);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('rejects unpaid mode or invalid auth before transmitting bytes', async () => {
  let upstreamCalls = 0;
  for (const configuration of [
    {paidServiceMode: 'free', token: 'founder-short-lived-token'},
    {paidServiceMode: 'paid', token: 'wrong-token'}
  ]) {
    const server = createCloverProxy({
      proxyToken: 'founder-short-lived-token',
      geminiApiKey: 'server-only-gemini-key',
      paidServiceMode: configuration.paidServiceMode,
      fetchImpl: async () => { upstreamCalls += 1; return new Response('{}'); }
    });
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    try {
      const {port} = server.address();
      const response = await fetch(`http://127.0.0.1:${port}/v1/import/analyze`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${configuration.token}`,
          'x-clover-request-key': `blocked-${configuration.paidServiceMode}`
        },
        body: JSON.stringify(requestBody)
      });
      assert.ok(response.status === 401 || response.status === 503);
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  }
  assert.equal(upstreamCalls, 0);
});

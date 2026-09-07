import {canonicalResponseSchema, validateCanonicalProducts} from './schema.mjs';

export const approvedModel = 'gemini-3.6-flash';
export const inputUsdPerMillionTokens = 0.75;
export const outputUsdPerMillionTokens = 3.75;

const extractionPrompt = `Identify independent real promotional product regions in this image.
Return exactly one product object per real promotional product and zero objects for non-products.
Use only text visibly supported inside that product region, except clearly applicable shared merchant,
campaign condition, or validity dates. Never mix adjacent products. A package count, description,
price, ITEM number, disclaimer, legal text, promotion banner, header/footer, mobile status bar, app UI,
or payment campaign is not independently a product. Never fabricate a missing name, brand, price,
original price, discount, date, model, or specification. Use null and list the field name in
uncertain_fields whenever evidence is insufficient. Evidence text must be copied from visible text,
region_id must identify its owning product or an explicit same-page shared region, and bounds use
normalized 0..1 image coordinates. Do not use tools, search, maps, external knowledge, or caching.`;

export function buildGeminiRequest(request) {
  return {
    systemInstruction: {parts: [{text: extractionPrompt}]},
    contents: [{
      role: 'user',
      parts: [
        {text: `Retailer hint: ${request.retailer_hint || 'generic'}. Source: ${request.source_type}. Page: ${request.page_number ?? 'image'}.`},
        {inlineData: {mimeType: request.mime_type, data: request.image_base64}}
      ]
    }],
    generationConfig: {
      temperature: 0,
      responseMimeType: 'application/json',
      responseJsonSchema: canonicalResponseSchema
    }
  };
}

export async function callGemini(request, {apiKey, fetchImpl = fetch}) {
  if (!apiKey) throw new ProxyError(503, 'gemini_api_key_not_configured');
  const response = await fetchImpl(
    `https://generativelanguage.googleapis.com/v1beta/models/${approvedModel}:generateContent`,
    {
      method: 'POST',
      headers: {'content-type': 'application/json', 'x-goog-api-key': apiKey},
      body: JSON.stringify(buildGeminiRequest(request)),
      signal: AbortSignal.timeout(55_000)
    }
  );
  if (!response.ok) throw new ProxyError(502, `gemini_http_${response.status}`);
  const raw = await response.json();
  const text = raw?.candidates?.[0]?.content?.parts?.find((part) => typeof part.text === 'string')?.text;
  if (!text) throw new ProxyError(502, 'gemini_empty_response');
  let canonical;
  try {
    canonical = JSON.parse(text);
  } catch {
    throw new ProxyError(502, 'gemini_invalid_json');
  }
  const schemaError = validateCanonicalProducts(canonical);
  if (schemaError) throw new ProxyError(502, `gemini_invalid_schema:${schemaError}`);
  const inputTokens = integer(raw?.usageMetadata?.promptTokenCount);
  const outputTokens = integer(raw?.usageMetadata?.candidatesTokenCount);
  const totalTokens = integer(raw?.usageMetadata?.totalTokenCount) || inputTokens + outputTokens;
  return {
    provider: 'google-gemini-developer-api',
    model: approvedModel,
    service_mode: 'paid',
    products: canonical.products,
    usage: {
      input_tokens: inputTokens,
      output_tokens: outputTokens,
      total_tokens: totalTokens,
      estimated_cost_usd: estimateCost(inputTokens, outputTokens)
    }
  };
}

export function estimateCost(inputTokens, outputTokens) {
  return inputTokens * inputUsdPerMillionTokens / 1_000_000 +
    outputTokens * outputUsdPerMillionTokens / 1_000_000;
}

function integer(value) {
  return Number.isInteger(value) && value >= 0 ? value : 0;
}

export class ProxyError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

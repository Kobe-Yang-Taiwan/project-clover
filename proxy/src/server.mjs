import {createHash, timingSafeEqual} from 'node:crypto';
import {createServer} from 'node:http';
import {callGemini, ProxyError} from './gemini.mjs';
import {validateCloverRequest} from './schema.mjs';

const maxBodyBytes = 11 * 1024 * 1024;
const maxAssetBytes = 8 * 1024 * 1024;
const duplicateTtlMs = 10 * 60 * 1000;
const rateWindowMs = 60 * 1000;
const maxRequestsPerWindow = Number.parseInt(process.env.CLOVER_MAX_REQUESTS_PER_MINUTE || '6', 10);
const recentRequests = new Map();
const rateBuckets = new Map();

export function createCloverProxy({
  proxyToken = process.env.CLOVER_PROXY_TOKEN,
  geminiApiKey = process.env.GEMINI_API_KEY,
  paidServiceMode = process.env.GEMINI_SERVICE_MODE,
  fetchImpl = fetch,
  now = () => Date.now()
} = {}) {
  return createServer(async (request, response) => {
    response.setHeader('content-type', 'application/json; charset=utf-8');
    if (request.method === 'GET' && request.url === '/health') {
      return send(response, 200, {status: 'ok', provider: 'google-gemini-developer-api', model: 'gemini-3.6-flash'});
    }
    if (request.method !== 'POST' || request.url !== '/v1/import/analyze') {
      return send(response, 404, {error: 'not_found'});
    }
    if (paidServiceMode !== 'paid') return send(response, 503, {error: 'paid_service_required'});
    if (!proxyToken || !authorized(request.headers.authorization, proxyToken)) {
      return send(response, 401, {error: 'unauthorized'});
    }
    const clientKey = createHash('sha256')
      .update(`${request.socket.remoteAddress || 'unknown'}:${proxyToken}`)
      .digest('hex');
    if (!withinRateLimit(clientKey, now())) return send(response, 429, {error: 'rate_limited'});

    try {
      const body = await readJson(request);
      const validationError = validateCloverRequest(body, maxAssetBytes);
      if (validationError) return send(response, 400, {error: validationError});
      const requestKey = request.headers['x-clover-request-key'];
      if (typeof requestKey !== 'string' || requestKey.length < 8 || requestKey.length > 160) {
        return send(response, 400, {error: 'invalid_request_key'});
      }
      purgeOldRequests(now());
      if (recentRequests.has(requestKey)) return send(response, 409, {error: 'duplicate_request_blocked'});
      recentRequests.set(requestKey, now());
      const result = await callGemini(body, {apiKey: geminiApiKey, fetchImpl});
      console.log(JSON.stringify({
        event: 'clover_vision_usage',
        request_key_hash: createHash('sha256').update(requestKey).digest('hex'),
        input_tokens: result.usage.input_tokens,
        output_tokens: result.usage.output_tokens,
        estimated_cost_usd: result.usage.estimated_cost_usd
      }));
      return send(response, 200, result);
    } catch (error) {
      if (error instanceof BodyTooLargeError) return send(response, 413, {error: 'request_too_large'});
      if (error instanceof SyntaxError) return send(response, 400, {error: 'invalid_json'});
      if (error instanceof ProxyError) return send(response, error.status, {error: error.code});
      console.error(JSON.stringify({event: 'clover_vision_failure', code: 'internal_error'}));
      return send(response, 500, {error: 'internal_error'});
    }
  });
}

function authorized(header, expected) {
  if (typeof header !== 'string' || !header.startsWith('Bearer ')) return false;
  const supplied = Buffer.from(header.slice(7));
  const wanted = Buffer.from(expected);
  return supplied.length === wanted.length && timingSafeEqual(supplied, wanted);
}

function withinRateLimit(key, timestamp) {
  const existing = rateBuckets.get(key);
  if (!existing || timestamp - existing.startedAt >= rateWindowMs) {
    rateBuckets.set(key, {startedAt: timestamp, count: 1});
    return true;
  }
  existing.count += 1;
  return existing.count <= maxRequestsPerWindow;
}

function purgeOldRequests(timestamp) {
  for (const [key, createdAt] of recentRequests) {
    if (timestamp - createdAt > duplicateTtlMs) recentRequests.delete(key);
  }
}

async function readJson(request) {
  const chunks = [];
  let total = 0;
  for await (const chunk of request) {
    total += chunk.length;
    if (total > maxBodyBytes) throw new BodyTooLargeError();
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

function send(response, status, body) {
  response.statusCode = status;
  response.end(JSON.stringify(body));
}

class BodyTooLargeError extends Error {}

if (process.argv[1] === new URL(import.meta.url).pathname) {
  const port = Number.parseInt(process.env.PORT || '8080', 10);
  createCloverProxy().listen(port, '0.0.0.0', () => {
    console.log(JSON.stringify({event: 'clover_proxy_started', port}));
  });
}

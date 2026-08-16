import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'coupon_import_models.dart';

class VisionAsset {
  const VisionAsset({
    required this.bytes,
    required this.mimeType,
    required this.sourceType,
    required this.requestKey,
    required this.retailerHint,
    this.pageNumber,
  });

  final Uint8List bytes;
  final String mimeType;
  final ImportSourceType sourceType;
  final String requestKey;
  final String retailerHint;
  final int? pageNumber;
}

class CloudVisionResult {
  const CloudVisionResult({required this.products, required this.usage});

  final List<ReconstructedProduct> products;
  final CloudProcessingUsage usage;
}

abstract class CloudVisionProvider {
  String get providerName;

  String get privacyDisclosure;

  bool get isConfigured;

  Future<CloudVisionResult> analyze(VisionAsset asset);
}

class CloudVisionProviderFactory {
  const CloudVisionProviderFactory._();

  static CloudVisionProvider fromEnvironment({http.Client? client}) =>
      GeminiCloudVisionProvider.fromEnvironment(client: client);
}

class DisabledCloudVisionProvider implements CloudVisionProvider {
  const DisabledCloudVisionProvider();

  @override
  String get providerName => '';

  @override
  String get privacyDisclosure => '';

  @override
  bool get isConfigured => false;

  @override
  Future<CloudVisionResult> analyze(VisionAsset asset) =>
      throw const CloudVisionUnavailableException(
        'cloud_provider_not_configured',
      );
}

/// Provider-neutral HTTPS contract. The endpoint owns model credentials and
/// translates this canonical request into the selected multimodal provider.
/// No API key is embedded in the Android application.
class HttpCloudVisionProvider implements CloudVisionProvider {
  HttpCloudVisionProvider({
    required this.endpoint,
    required this.providerName,
    required this.privacyDisclosure,
    this.bearerToken = '',
    this.maxAssetBytes = 8 * 1024 * 1024,
    this.requestTimeout = const Duration(seconds: 45),
    this.estimatedCostPerRequestUsd = 0,
    http.Client? client,
  }) : _client = client ?? http.Client();

  factory HttpCloudVisionProvider.fromEnvironment({http.Client? client}) {
    const endpoint = String.fromEnvironment('CLOVER_VISION_ENDPOINT');
    const provider = String.fromEnvironment(
      'CLOVER_VISION_PROVIDER',
      defaultValue: 'configurable-proxy',
    );
    const token = String.fromEnvironment('CLOVER_VISION_ACCESS_TOKEN');
    const privacyDisclosure = String.fromEnvironment(
      'CLOVER_VISION_PRIVACY_DISCLOSURE',
    );
    const estimatedCost = String.fromEnvironment(
      'CLOVER_VISION_ESTIMATED_COST_PER_REQUEST_USD',
      defaultValue: '0',
    );
    return HttpCloudVisionProvider(
      endpoint: endpoint,
      providerName: provider,
      privacyDisclosure: privacyDisclosure,
      bearerToken: token,
      estimatedCostPerRequestUsd: double.tryParse(estimatedCost) ?? 0,
      client: client,
    );
  }

  final String endpoint;
  @override
  final String providerName;
  @override
  final String privacyDisclosure;
  final String bearerToken;
  final int maxAssetBytes;
  final Duration requestTimeout;
  final double estimatedCostPerRequestUsd;
  final http.Client _client;
  final Set<String> _submittedRequestKeys = <String>{};

  @override
  bool get isConfigured {
    final uri = Uri.tryParse(endpoint);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        providerName.trim().isNotEmpty &&
        privacyDisclosure.trim().isNotEmpty;
  }

  @override
  Future<CloudVisionResult> analyze(VisionAsset asset) async {
    if (!isConfigured) {
      throw const CloudVisionUnavailableException(
        'cloud_provider_not_configured',
      );
    }
    if (asset.bytes.isEmpty || asset.bytes.length > maxAssetBytes) {
      throw const CloudVisionUnavailableException('asset_size_not_allowed');
    }
    if (!_submittedRequestKeys.add(asset.requestKey)) {
      throw const CloudVisionUnavailableException('duplicate_request_blocked');
    }

    final body = jsonEncode(<String, Object?>{
      'schema_version': 'clover.import.v1',
      'task': 'reconstruct_promotional_product_regions',
      'rules': const <String>[
        'one_real_product_equals_one_product_object',
        'non_product_regions_must_not_be_products',
        'never_invent_missing_fields',
        'each_field_requires_visible_evidence',
        'shared_campaign_text_is_not_a_product_name',
      ],
      'source_type': asset.sourceType.name,
      'page_number': asset.pageNumber,
      'retailer_hint': asset.retailerHint,
      'mime_type': asset.mimeType,
      'image_base64': base64Encode(asset.bytes),
    });
    final headers = <String, String>{
      'content-type': 'application/json',
      'accept': 'application/json',
      'x-clover-request-key': asset.requestKey,
    };
    if (bearerToken.isNotEmpty) {
      headers['authorization'] = 'Bearer $bearerToken';
    }

    http.Response response;
    try {
      response = await _client
          .post(Uri.parse(endpoint), headers: headers, body: body)
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const CloudVisionUnavailableException('cloud_timeout');
    } catch (_) {
      throw const CloudVisionUnavailableException('cloud_network_failure');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudVisionUnavailableException(
        'cloud_http_${response.statusCode}',
      );
    }

    final decoded = _decodeObject(response.body);
    validateResponseMetadata(decoded);
    final productValues = decoded['products'];
    if (productValues is! List<Object?>) {
      throw const CloudVisionUnavailableException('invalid_cloud_schema');
    }
    final products = <ReconstructedProduct>[];
    for (var index = 0; index < productValues.length; index++) {
      final value = productValues[index];
      if (value is! Map<String, Object?>) continue;
      final parsed = _parseProduct(value, asset, index);
      if (parsed != null) products.add(parsed);
    }
    final serverCost = _numberAt(decoded, const [
      'usage',
      'estimated_cost_usd',
    ]);
    final inputTokens = _integerAt(decoded, const ['usage', 'input_tokens']);
    final outputTokens = _integerAt(decoded, const ['usage', 'output_tokens']);
    final totalTokens = _integerAt(decoded, const ['usage', 'total_tokens']);
    return CloudVisionResult(
      products: products,
      usage: CloudProcessingUsage(
        provider: providerName,
        requestCount: 1,
        transmittedBytes: asset.bytes.length,
        estimatedCostUsd: serverCost?.toDouble() ?? estimatedCostPerRequestUsd,
        inputTokenCount: inputTokens ?? 0,
        outputTokenCount: outputTokens ?? 0,
        totalTokenCount:
            totalTokens ?? (inputTokens ?? 0) + (outputTokens ?? 0),
      ),
    );
  }

  void validateResponseMetadata(Map<String, Object?> response) {}

  Map<String, Object?> _decodeObject(String body) {
    try {
      final value = jsonDecode(body);
      if (value is Map<String, Object?>) return value;
    } catch (_) {
      // Converted to a stable provider failure below.
    }
    throw const CloudVisionUnavailableException('invalid_cloud_json');
  }

  ReconstructedProduct? _parseProduct(
    Map<String, Object?> json,
    VisionAsset asset,
    int index,
  ) {
    final regionId =
        _cleanString(json['product_region_id']) ??
        _cleanString(json['region_id']);
    if (regionId == null) return null;
    final productName = _stringField(json['product_name'], asset, regionId);
    final regionEvidence = _evidence(json['region_evidence'], asset, regionId);
    if (productName == null || regionEvidence == null) return null;

    final originalPrice = _intField(json['original_price'], asset, regionId);
    final promotionalPrice = _intField(
      json['promotional_price'] ?? json['promo_price'],
      asset,
      regionId,
    );
    final discount = _intField(json['discount_amount'], asset, regionId);
    return ReconstructedProduct(
      regionId: regionId,
      sourceType: asset.sourceType,
      sourcePage: asset.pageNumber,
      merchant: _stringField(json['merchant'], asset, regionId),
      brand: _stringField(json['brand'], asset, regionId),
      productName: productName,
      model: _stringField(json['model'], asset, regionId),
      specification: _stringField(json['specification'], asset, regionId),
      itemNumber: _stringField(json['item_number'], asset, regionId),
      validFrom: _dateField(json['valid_from'], asset, regionId),
      validUntil: _dateField(json['valid_until'], asset, regionId),
      originalPrice: originalPrice,
      promotionalPrice: promotionalPrice,
      discountAmount: discount,
      promotionCondition: _stringField(
        json['promotion_condition'],
        asset,
        regionId,
      ),
      category: _stringField(
        json['category_hint'] ?? json['category'],
        asset,
        regionId,
      ),
      notes: _stringField(json['notes'], asset, regionId),
      regionEvidence: regionEvidence,
      uncertainFields: _stringList(json['uncertain_fields']),
    );
  }

  List<String> _stringList(Object? value) {
    if (value is! List<Object?>) return const [];
    return value
        .map(_cleanString)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
  }

  EvidencedValue<String>? _stringField(
    Object? value,
    VisionAsset asset,
    String regionId,
  ) {
    if (value is! Map<String, Object?>) return null;
    final parsed = _cleanString(value['value']);
    final evidence = _evidence(value['evidence'], asset, regionId);
    if (parsed == null ||
        evidence == null ||
        !_supportsString(evidence.rawText, parsed)) {
      return null;
    }
    return EvidencedValue(value: parsed, evidence: evidence);
  }

  EvidencedValue<num>? _intField(
    Object? value,
    VisionAsset asset,
    String regionId,
  ) {
    if (value is! Map<String, Object?>) return null;
    final raw = value['value'];
    final parsed = raw is num
        ? raw
        : num.tryParse((raw ?? '').toString().replaceAll(',', ''));
    final evidence = _evidence(value['evidence'], asset, regionId);
    if (parsed == null ||
        parsed <= 0 ||
        evidence == null ||
        !_supportsNumber(evidence.rawText, parsed)) {
      return null;
    }
    return EvidencedValue(value: parsed, evidence: evidence);
  }

  EvidencedValue<DateTime>? _dateField(
    Object? value,
    VisionAsset asset,
    String regionId,
  ) {
    if (value is! Map<String, Object?>) return null;
    final parsed = DateTime.tryParse((value['value'] ?? '').toString());
    final evidence = _evidence(value['evidence'], asset, regionId);
    if (parsed == null ||
        evidence == null ||
        !_supportsDate(evidence.rawText, parsed)) {
      return null;
    }
    return EvidencedValue(
      value: DateTime(parsed.year, parsed.month, parsed.day),
      evidence: evidence,
    );
  }

  FieldEvidence? _evidence(Object? value, VisionAsset asset, String regionId) {
    if (value is! Map<String, Object?>) return null;
    final text = _cleanString(value['text']);
    final confidence = value['confidence'];
    if (text == null || confidence is! num) return null;
    final normalized = confidence.toDouble();
    if (normalized < 0 || normalized > 1) return null;
    return FieldEvidence(
      sourceType: asset.sourceType,
      extractionMethod: ImportExtractionMethod.cloudVision,
      sourcePage: asset.pageNumber,
      regionId: _cleanString(value['region_id']) ?? regionId,
      rawText: text,
      confidence: normalized,
      bounds: _bounds(value['bounds']),
    );
  }

  OcrRegionBounds? _bounds(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final left = value['left'];
    final top = value['top'];
    final right = value['right'];
    final bottom = value['bottom'];
    if (left is! num || top is! num || right is! num || bottom is! num) {
      return null;
    }
    final result = OcrRegionBounds(
      left: left.toDouble(),
      top: top.toDouble(),
      right: right.toDouble(),
      bottom: bottom.toDouble(),
    );
    if (result.left < 0 ||
        result.top < 0 ||
        result.right > 1 ||
        result.bottom > 1 ||
        result.left >= result.right ||
        result.top >= result.bottom) {
      return null;
    }
    return result;
  }

  String? _cleanString(Object? value) {
    final result = (value ?? '').toString().trim();
    return result.isEmpty || result.length > 240 ? null : result;
  }

  bool _supportsString(String evidence, String value) {
    String normalized(String input) =>
        input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]'), '');
    final raw = normalized(evidence);
    final expected = normalized(value);
    return expected.length >= 2 &&
        (raw.contains(expected) || expected.contains(raw));
  }

  bool _supportsNumber(String evidence, num value) {
    final expected = value.toDouble();
    return RegExp(r'[0-9][0-9,]*(?:\.[0-9]+)?')
        .allMatches(evidence)
        .map((match) => num.tryParse(match.group(0)!.replaceAll(',', '')))
        .whereType<num>()
        .any((found) => (found.toDouble() - expected).abs() < 0.001);
  }

  bool _supportsDate(String evidence, DateTime value) {
    final numbers = RegExp(r'\d+').allMatches(evidence).map((match) {
      return int.parse(match.group(0)!);
    }).toList();
    return numbers.contains(value.month) &&
        numbers.contains(value.day) &&
        (numbers.contains(value.year) || numbers.contains(value.year - 1911));
  }

  num? _numberAt(Map<String, Object?> value, List<String> path) {
    Object? current = value;
    for (final key in path) {
      if (current is! Map<String, Object?>) return null;
      current = current[key];
    }
    return current is num ? current : null;
  }

  int? _integerAt(Map<String, Object?> value, List<String> path) {
    final result = _numberAt(value, path);
    if (result == null || result < 0 || result % 1 != 0) return null;
    return result.toInt();
  }

  void dispose() => _client.close();
}

/// Founder-approved adapter for the Clover-controlled Gemini proxy. The
/// upstream API key remains on the proxy; Android receives only canonical
/// Clover JSON and never depends on Gemini SDK-specific response types.
class GeminiCloudVisionProvider extends HttpCloudVisionProvider {
  GeminiCloudVisionProvider({
    required super.endpoint,
    required super.privacyDisclosure,
    required this.paidServiceConfirmed,
    super.bearerToken,
    super.maxAssetBytes,
    super.requestTimeout,
    super.estimatedCostPerRequestUsd,
    super.client,
  }) : super(providerName: providerIdentity);

  factory GeminiCloudVisionProvider.fromEnvironment({http.Client? client}) {
    const endpoint = String.fromEnvironment('CLOVER_VISION_ENDPOINT');
    const token = String.fromEnvironment('CLOVER_VISION_ACCESS_TOKEN');
    const disclosure = String.fromEnvironment(
      'CLOVER_VISION_PRIVACY_DISCLOSURE',
      defaultValue: defaultPrivacyDisclosure,
    );
    const paid = bool.fromEnvironment('CLOVER_GEMINI_PAID_SERVICE');
    return GeminiCloudVisionProvider(
      endpoint: endpoint,
      bearerToken: token,
      privacyDisclosure: disclosure,
      paidServiceConfirmed: paid,
      client: client,
    );
  }

  static const model = 'gemini-3.6-flash';
  static const providerIdentity = 'Google Gemini Developer API / $model';
  static const defaultPrivacyDisclosure =
      '使用 Google Gemini Developer API 付費服務（$model）。Google 依付費服務條款'
      '不使用提示、圖片或回應改善其產品，但會為防止濫用而有限期保留資料；一般付費服務'
      '並非零資料保留。資料以 HTTPS 傳送，Clover proxy 不保存圖片或完整模型輸入輸出。';

  final bool paidServiceConfirmed;

  @override
  bool get isConfigured => paidServiceConfirmed && super.isConfigured;

  @override
  void validateResponseMetadata(Map<String, Object?> response) {
    if (response['provider'] != 'google-gemini-developer-api' ||
        response['model'] != model ||
        response['service_mode'] != 'paid') {
      throw const CloudVisionUnavailableException(
        'gemini_provider_identity_mismatch',
      );
    }
  }
}

class CloudVisionUnavailableException implements Exception {
  const CloudVisionUnavailableException(this.code);

  final String code;

  @override
  String toString() => 'CloudVisionUnavailableException($code)';
}

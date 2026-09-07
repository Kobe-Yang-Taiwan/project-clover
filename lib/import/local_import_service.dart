import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfrx/pdfrx.dart';

import 'cloud_vision_provider.dart';
import 'coupon_import_models.dart';
import 'document_understanding.dart';
import 'local_image_region_proposal.dart';
import 'retailer_adapters.dart';
import 'source_router.dart';

abstract class CouponImportService {
  Future<String?> pickImage();

  Future<String?> pickPdf();

  Future<OcrPageResult> recognizeImage(String path);

  Future<List<OcrPageResult>> recognizePdf(
    String path, {
    required void Function(ImportProgress progress) onProgress,
    required bool Function() isCancelled,
  });
}

abstract class SourceAdaptiveCouponImportService {
  bool get cloudVisionAvailable;

  String get cloudVisionDisclosure;

  Future<PdfSourcePlan> inspectPdf(String path);

  Future<SourceAdaptiveImportResult> analyzeImage(
    String path, {
    required bool allowCloudProcessing,
  });

  Future<SourceAdaptiveImportResult> recoverImageRegion(
    String path, {
    required double normalizedX,
    required double normalizedY,
  });

  Future<SourceAdaptiveImportResult> analyzePdf(
    String path, {
    required bool allowCloudProcessing,
    Future<bool> Function(int pageNumber)? requestCloudPageConsent,
    required void Function(ImportProgress progress) onProgress,
    required bool Function() isCancelled,
  });
}

class LocalCouponImportService
    implements CouponImportService, SourceAdaptiveCouponImportService {
  LocalCouponImportService({
    TextRecognizer? recognizer,
    CloudVisionProvider? cloudVisionProvider,
    RetailerAdapterRegistry adapters = const RetailerAdapterRegistry(),
    ImportSourceRouter sourceRouter = const ImportSourceRouter(),
    DocumentUnderstandingPipeline understanding =
        const DocumentUnderstandingPipeline(),
    LocalImageRegionProposalEngine regionProposal =
        const LocalImageRegionProposalEngine(),
  }) : _recognizer =
           recognizer ?? TextRecognizer(script: TextRecognitionScript.chinese),
       _cloudVisionProvider =
           cloudVisionProvider ?? CloudVisionProviderFactory.fromEnvironment(),
       _adapters = adapters,
       _sourceRouter = sourceRouter,
       _understanding = understanding,
       _regionProposal = regionProposal;

  static const maxFileBytes = 30 * 1024 * 1024;
  static const maxCloudAssetBytes = 8 * 1024 * 1024;
  static const maxPdfPages = 30;
  static const renderedPageWidth = 3000.0;

  final TextRecognizer _recognizer;
  final CloudVisionProvider _cloudVisionProvider;
  final RetailerAdapterRegistry _adapters;
  final ImportSourceRouter _sourceRouter;
  final DocumentUnderstandingPipeline _understanding;
  final LocalImageRegionProposalEngine _regionProposal;
  final Map<String, _PdfInspection> _pdfInspectionCache = {};
  final Map<String, _ImageInspection> _imageInspectionCache = {};

  @override
  bool get cloudVisionAvailable => _cloudVisionProvider.isConfigured;

  @override
  String get cloudVisionDisclosure => _cloudVisionProvider.privacyDisclosure;

  @override
  Future<String?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'heic'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    await _validateSize(path);
    return path;
  }

  @override
  Future<String?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    await _validateSize(path);
    return path;
  }

  @override
  Future<OcrPageResult> recognizeImage(String path) =>
      _localOcr(path, sourceType: ImportSourceType.image, pageNumber: null);

  @override
  Future<List<OcrPageResult>> recognizePdf(
    String path, {
    required void Function(ImportProgress progress) onProgress,
    required bool Function() isCancelled,
  }) async {
    final result = await analyzePdf(
      path,
      allowCloudProcessing: false,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    return result.pages;
  }

  @override
  Future<SourceAdaptiveImportResult> analyzeImage(
    String path, {
    required bool allowCloudProcessing,
  }) async {
    await _validateSize(path);
    final operationId = DateTime.now().microsecondsSinceEpoch;
    final local = await recognizeImage(path);
    final adapter = _adapters.resolve(sourceName: path, text: local.text);
    final proposals = _regionProposal.propose(local, adapter: adapter);
    final sharedLines = _understanding
        .understand(local)
        .sharedBlocks
        .map((block) => block.line)
        .toList();
    _imageInspectionCache.clear();
    _imageInspectionCache[path] = _ImageInspection(
      adapter: adapter,
      regions: proposals,
      sharedLines: sharedLines,
    );
    if (!allowCloudProcessing || !cloudVisionAvailable) {
      final watch = Stopwatch()..start();
      final regionPages = <OcrPageResult>[];
      for (final region in proposals) {
        final page = await _ocrImageRegion(
          path,
          region,
          sharedLines: sharedLines,
        );
        if (page.succeeded) regionPages.add(page);
      }
      watch.stop();
      return SourceAdaptiveImportResult(
        route: _sourceRouter.forImage().route,
        pages: regionPages.isEmpty ? [local] : regionPages,
        products: const [],
        merchantHint: adapter.merchant,
        localImageMetrics: LocalImageProcessingMetrics(
          proposedRegionCount: proposals.length,
          regionOcrCount: regionPages.length,
          processingDuration: local.duration + watch.elapsed,
        ),
      );
    }

    final bytes = await File(path).readAsBytes();
    if (bytes.length > maxCloudAssetBytes) {
      return SourceAdaptiveImportResult(
        route: _sourceRouter.forImage().route,
        pages: [local],
        products: const [],
        cloudUsage: CloudProcessingUsage(
          provider: _cloudVisionProvider.providerName,
          failureCount: 1,
        ),
        localFallbackUsed: true,
      );
    }
    try {
      final result = await _cloudVisionProvider.analyze(
        VisionAsset(
          bytes: bytes,
          mimeType: _imageMimeType(path),
          sourceType: ImportSourceType.image,
          requestKey: _requestKey(path, null, bytes.length, operationId),
          retailerHint: adapter.id,
        ),
      );
      return SourceAdaptiveImportResult(
        route: _sourceRouter.forImage().route,
        pages: [local],
        products: result.products,
        cloudUsage: result.usage,
        merchantHint: adapter.merchant,
        localImageMetrics: LocalImageProcessingMetrics(
          proposedRegionCount: proposals.length,
        ),
      );
    } on CloudVisionUnavailableException {
      return SourceAdaptiveImportResult(
        route: _sourceRouter.forImage().route,
        pages: [local],
        products: const [],
        cloudUsage: CloudProcessingUsage(
          provider: _cloudVisionProvider.providerName,
          failureCount: 1,
        ),
        localFallbackUsed: true,
        merchantHint: adapter.merchant,
      );
    }
  }

  @override
  Future<SourceAdaptiveImportResult> recoverImageRegion(
    String path, {
    required double normalizedX,
    required double normalizedY,
  }) async {
    await _validateSize(path);
    var inspection = _imageInspectionCache[path];
    if (inspection == null) {
      final page = await recognizeImage(path);
      final adapter = _adapters.resolve(sourceName: path, text: page.text);
      final regions = _regionProposal.propose(page, adapter: adapter);
      final sharedLines = _understanding
          .understand(page)
          .sharedBlocks
          .map((block) => block.line)
          .toList();
      inspection = _ImageInspection(
        adapter: adapter,
        regions: regions,
        sharedLines: sharedLines,
      );
      _imageInspectionCache.clear();
      _imageInspectionCache[path] = inspection;
    }
    final region = _regionProposal.recoverAt(
      x: normalizedX.clamp(0.0, 1.0).toDouble(),
      y: normalizedY.clamp(0.0, 1.0).toDouble(),
      existing: inspection.regions,
      adapter: inspection.adapter,
    );
    final watch = Stopwatch()..start();
    final page = await _ocrImageRegion(
      path,
      region,
      sharedLines: inspection.sharedLines,
    );
    watch.stop();
    return SourceAdaptiveImportResult(
      route: ImportRoute.promotionalImage,
      pages: [page],
      products: const [],
      merchantHint: inspection.adapter.merchant,
      localImageMetrics: LocalImageProcessingMetrics(
        proposedRegionCount: 1,
        regionOcrCount: page.succeeded ? 1 : 0,
        recoveryActionCount: 1,
        processingDuration: watch.elapsed,
      ),
    );
  }

  @override
  Future<PdfSourcePlan> inspectPdf(String path) async {
    await _validateSize(path);
    final existing = _pdfInspectionCache[path];
    if (existing != null) return existing.plan;
    await pdfrxFlutterInitialize();
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(path);
      if (document.pages.length > maxPdfPages) {
        throw const ImportLimitException('PDF 最多支援 30 頁，請拆分檔案後再試。');
      }
      final nativePages = <int, OcrPageResult>{};
      final visionPages = <int>[];
      final allText = StringBuffer();
      for (final page in document.pages) {
        final structured = await page.loadStructuredText();
        if (_isReliableNativeText(page, structured)) {
          final result = _nativePageResult(page, structured);
          nativePages[page.pageNumber] = result;
          allText.writeln(result.text);
        } else {
          visionPages.add(page.pageNumber);
        }
      }
      final adapter = _adapters.resolve(
        sourceName: path,
        text: allText.toString(),
      );
      final inspection = _PdfInspection(
        plan: PdfSourcePlan(
          pageCount: document.pages.length,
          nativeTextPages: nativePages.keys.toList()..sort(),
          visionPages: visionPages,
        ),
        nativePages: nativePages,
        adapter: adapter,
      );
      _pdfInspectionCache[path] = inspection;
      return inspection.plan;
    } on ImportLimitException {
      rethrow;
    } catch (_) {
      throw const FormatException('無法讀取 PDF。檔案可能已加密、損壞或格式不支援。');
    } finally {
      await document?.dispose();
    }
  }

  @override
  Future<SourceAdaptiveImportResult> analyzePdf(
    String path, {
    required bool allowCloudProcessing,
    Future<bool> Function(int pageNumber)? requestCloudPageConsent,
    required void Function(ImportProgress progress) onProgress,
    required bool Function() isCancelled,
  }) async {
    final plan = await inspectPdf(path);
    final inspection = _pdfInspectionCache[path]!;
    await pdfrxFlutterInitialize();
    PdfDocument? document;
    final temporaryFiles = <File>[];
    final pages = <OcrPageResult>[];
    final products = <ReconstructedProduct>[];
    var usage = const CloudProcessingUsage();
    var localFallbackUsed = false;
    var cloudWasDeclined = false;
    final operationId = DateTime.now().microsecondsSinceEpoch;
    try {
      document = await PdfDocument.openFile(path);
      onProgress(ImportProgress(completed: 0, total: plan.pageCount));
      for (final page in document.pages) {
        if (isCancelled()) throw const ImportCancelledException();
        final native = inspection.nativePages[page.pageNumber];
        if (native != null) {
          pages.add(native);
        } else {
          final rendered = await _renderPage(page);
          final temporary = File(
            '${Directory.systemTemp.path}/clover-import-${DateTime.now().microsecondsSinceEpoch}-${page.pageNumber}.png',
          );
          temporaryFiles.add(temporary);
          await temporary.writeAsBytes(rendered, flush: true);
          final pageConsent =
              allowCloudProcessing &&
              cloudVisionAvailable &&
              rendered.length <= maxCloudAssetBytes &&
              (requestCloudPageConsent == null ||
                  await requestCloudPageConsent(page.pageNumber));
          if (pageConsent) {
            try {
              final result = await _cloudVisionProvider.analyze(
                VisionAsset(
                  bytes: rendered,
                  mimeType: 'image/png',
                  sourceType: ImportSourceType.pdf,
                  pageNumber: page.pageNumber,
                  requestKey: _requestKey(
                    path,
                    page.pageNumber,
                    rendered.length,
                    operationId,
                  ),
                  retailerHint: inspection.adapter.id,
                ),
              );
              products.addAll(result.products);
              usage += result.usage;
              pages.add(
                OcrPageResult(
                  sourceType: ImportSourceType.pdf,
                  pageNumber: page.pageNumber,
                  text: '',
                  lines: const [],
                  positionedLines: const [],
                  succeeded: true,
                  duration: Duration.zero,
                  extractionMethod: ImportExtractionMethod.cloudVision,
                ),
              );
            } on CloudVisionUnavailableException {
              usage += CloudProcessingUsage(
                provider: _cloudVisionProvider.providerName,
                failureCount: 1,
              );
              localFallbackUsed = true;
              pages.add(
                await _localOcr(
                  temporary.path,
                  sourceType: ImportSourceType.pdf,
                  pageNumber: page.pageNumber,
                ),
              );
            }
          } else {
            if (allowCloudProcessing &&
                cloudVisionAvailable &&
                rendered.length <= maxCloudAssetBytes) {
              cloudWasDeclined = true;
            }
            localFallbackUsed = true;
            pages.add(
              await _localOcr(
                temporary.path,
                sourceType: ImportSourceType.pdf,
                pageNumber: page.pageNumber,
              ),
            );
          }
        }
        onProgress(
          ImportProgress(completed: page.pageNumber, total: plan.pageCount),
        );
      }
      pages.sort((a, b) => (a.pageNumber ?? 0).compareTo(b.pageNumber ?? 0));
      final decision = _sourceRouter.forPdf(plan);
      return SourceAdaptiveImportResult(
        route: decision.route,
        pages: pages,
        products: products,
        cloudUsage: usage,
        cloudWasDeclined:
            cloudWasDeclined ||
            (plan.requiresVision &&
                cloudVisionAvailable &&
                !allowCloudProcessing),
        localFallbackUsed: localFallbackUsed,
      );
    } on ImportCancelledException {
      rethrow;
    } catch (_) {
      throw const FormatException('無法讀取 PDF。檔案可能已加密、損壞或格式不支援。');
    } finally {
      await document?.dispose();
      for (final file in temporaryFiles) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {
          // Temporary cleanup failure must not corrupt user data.
        }
      }
      _pdfInspectionCache.remove(path);
    }
  }

  Future<OcrPageResult> _localOcr(
    String path, {
    required ImportSourceType sourceType,
    required int? pageNumber,
    ProposedImageRegion? sourceRegion,
    List<OcrTextLine> sharedPositionedLines = const [],
  }) async {
    final watch = Stopwatch()..start();
    try {
      final dimensions = await _imageDimensions(path);
      final recognized = await _recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      watch.stop();
      return OcrPageResult(
        sourceType: sourceType,
        pageNumber: pageNumber,
        text: recognized.text,
        lines: recognized.blocks
            .expand((block) => block.lines)
            .map((line) => line.text)
            .toList(),
        positionedLines: _positionedLines(
          recognized,
          imageWidth: dimensions.$1,
          imageHeight: dimensions.$2,
          sourceBounds: sourceRegion?.bounds,
        ),
        succeeded: true,
        duration: watch.elapsed,
        sourceRegionId: sourceRegion?.id,
        sourceBounds: sourceRegion?.bounds,
        sharedPositionedLines: sharedPositionedLines,
      );
    } catch (_) {
      watch.stop();
      return OcrPageResult(
        sourceType: sourceType,
        pageNumber: pageNumber,
        text: '',
        lines: const [],
        succeeded: false,
        failureCode: 'ocr_failed',
        duration: watch.elapsed,
        sourceRegionId: sourceRegion?.id,
        sourceBounds: sourceRegion?.bounds,
        sharedPositionedLines: sharedPositionedLines,
      );
    }
  }

  Future<OcrPageResult> _ocrImageRegion(
    String path,
    ProposedImageRegion region, {
    required List<OcrTextLine> sharedLines,
  }) async {
    final temporary = File(
      '${Directory.systemTemp.path}/clover-region-'
      '${DateTime.now().microsecondsSinceEpoch}-${region.id}.png',
    );
    try {
      final bytes = await _cropImage(path, region.bounds);
      await temporary.writeAsBytes(bytes, flush: true);
      final page = await _localOcr(
        temporary.path,
        sourceType: ImportSourceType.image,
        pageNumber: null,
        sourceRegion: region,
        sharedPositionedLines: sharedLines,
      );
      final structured = _understanding
          .understand(page)
          .toStructuredMarkdown(pageNumber: 1);
      return OcrPageResult(
        sourceType: page.sourceType,
        pageNumber: page.pageNumber,
        text: page.text,
        lines: page.lines,
        succeeded: page.succeeded,
        duration: page.duration,
        failureCode: page.failureCode,
        positionedLines: page.positionedLines,
        extractionMethod: page.extractionMethod,
        structuredRepresentation: structured,
        sourceRegionId: page.sourceRegionId,
        sourceBounds: page.sourceBounds,
        sharedPositionedLines: page.sharedPositionedLines,
      );
    } finally {
      try {
        if (await temporary.exists()) await temporary.delete();
      } catch (_) {
        // Temporary cleanup failure does not affect the import result.
      }
    }
  }

  Future<Uint8List> _cropImage(String path, OcrRegionBounds bounds) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final source = frame.image;
      try {
        final left = (bounds.left * source.width)
            .floor()
            .clamp(0, source.width - 1)
            .toInt();
        final top = (bounds.top * source.height)
            .floor()
            .clamp(0, source.height - 1)
            .toInt();
        final right = (bounds.right * source.width)
            .ceil()
            .clamp(left + 1, source.width)
            .toInt();
        final bottom = (bounds.bottom * source.height)
            .ceil()
            .clamp(top + 1, source.height)
            .toInt();
        final width = right - left;
        final height = bottom - top;
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImageRect(
          source,
          ui.Rect.fromLTRB(
            left.toDouble(),
            top.toDouble(),
            right.toDouble(),
            bottom.toDouble(),
          ),
          ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          ui.Paint(),
        );
        final cropped = await recorder.endRecording().toImage(width, height);
        try {
          final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) throw StateError('crop_encode_failed');
          return data.buffer.asUint8List();
        } finally {
          cropped.dispose();
        }
      } finally {
        source.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  bool _isReliableNativeText(PdfPage page, PdfPageText text) {
    final compact = text.fullText.replaceAll(RegExp(r'\s'), '');
    if (compact.length < 80 || text.fragments.length < 8) return false;
    final identityCharacters = RegExp(
      r'[A-Za-z0-9\u4e00-\u9fff]',
    ).allMatches(compact).length;
    if (identityCharacters / compact.length < 0.55) return false;
    final top = text.fragments
        .map((fragment) => fragment.bounds.top)
        .reduce((a, b) => a > b ? a : b);
    final bottom = text.fragments
        .map((fragment) => fragment.bounds.bottom)
        .reduce((a, b) => a < b ? a : b);
    final verticalCoverage = (top - bottom).abs() / page.height;
    return compact.length >= 300 || verticalCoverage >= 0.20;
  }

  OcrPageResult _nativePageResult(PdfPage page, PdfPageText text) {
    final lines = <OcrTextLine>[];
    for (final fragment in text.fragments) {
      final value = fragment.text.trim();
      if (value.isEmpty) continue;
      final rect = fragment.bounds.toRect(page: page);
      lines.add(
        OcrTextLine(
          text: value,
          left: (rect.left / page.width).clamp(0, 1).toDouble(),
          top: (rect.top / page.height).clamp(0, 1).toDouble(),
          right: (rect.right / page.width).clamp(0, 1).toDouble(),
          bottom: (rect.bottom / page.height).clamp(0, 1).toDouble(),
        ),
      );
    }
    lines.sort((a, b) {
      final vertical = a.top.compareTo(b.top);
      return vertical == 0 ? a.left.compareTo(b.left) : vertical;
    });
    final preliminary = OcrPageResult(
      sourceType: ImportSourceType.pdf,
      pageNumber: page.pageNumber,
      text: text.fullText,
      lines: lines.map((line) => line.text).toList(),
      positionedLines: lines,
      succeeded: true,
      duration: Duration.zero,
      extractionMethod: ImportExtractionMethod.nativePdfText,
    );
    final structured = _understanding
        .understand(preliminary)
        .toStructuredMarkdown(pageNumber: page.pageNumber);
    return OcrPageResult(
      sourceType: preliminary.sourceType,
      pageNumber: preliminary.pageNumber,
      text: preliminary.text,
      lines: preliminary.lines,
      positionedLines: preliminary.positionedLines,
      succeeded: preliminary.succeeded,
      duration: preliminary.duration,
      extractionMethod: preliminary.extractionMethod,
      structuredRepresentation: structured,
    );
  }

  Future<Uint8List> _renderPage(PdfPage page) async {
    final scale = renderedPageWidth / page.width;
    final rendered = await page.render(
      fullWidth: renderedPageWidth,
      fullHeight: page.height * scale,
      backgroundColor: 0xffffffff,
    );
    if (rendered == null) throw StateError('render_failed');
    try {
      final image = await rendered.createImage();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('encode_failed');
        return data.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      rendered.dispose();
    }
  }

  Future<void> _validateSize(String path) async {
    final file = File(path);
    if (!await file.exists()) throw const FormatException('找不到選取的檔案。');
    if (await file.length() > maxFileBytes) {
      throw const ImportLimitException('檔案上限為 30 MB，請縮小或拆分後再試。');
    }
  }

  List<OcrTextLine> _positionedLines(
    RecognizedText recognized, {
    required double imageWidth,
    required double imageHeight,
    OcrRegionBounds? sourceBounds,
  }) {
    final lines = recognized.blocks.expand((block) => block.lines).toList();
    if (lines.isEmpty) return const [];
    if (imageWidth <= 0 || imageHeight <= 0) return const [];
    double mapX(double value) {
      final local = (value / imageWidth).clamp(0, 1).toDouble();
      if (sourceBounds == null) return local;
      return sourceBounds.left +
          local * (sourceBounds.right - sourceBounds.left);
    }

    double mapY(double value) {
      final local = (value / imageHeight).clamp(0, 1).toDouble();
      if (sourceBounds == null) return local;
      return sourceBounds.top +
          local * (sourceBounds.bottom - sourceBounds.top);
    }

    return lines
        .map(
          (line) => OcrTextLine(
            text: line.text,
            left: mapX(line.boundingBox.left),
            top: mapY(line.boundingBox.top),
            right: mapX(line.boundingBox.right),
            bottom: mapY(line.boundingBox.bottom),
          ),
        )
        .toList();
  }

  Future<(double, double)> _imageDimensions(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        return (frame.image.width.toDouble(), frame.image.height.toDouble());
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  String _imageMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  String _requestKey(
    String path,
    int? pageNumber,
    int bytes,
    int operationId,
  ) =>
      '${File(path).lastModifiedSync().millisecondsSinceEpoch}-$bytes-'
      '${pageNumber ?? 0}-$operationId';

  void dispose() {
    _recognizer.close();
    final provider = _cloudVisionProvider;
    if (provider is HttpCloudVisionProvider) provider.dispose();
  }
}

class _PdfInspection {
  const _PdfInspection({
    required this.plan,
    required this.nativePages,
    required this.adapter,
  });

  final PdfSourcePlan plan;
  final Map<int, OcrPageResult> nativePages;
  final RetailerAdapter adapter;
}

class _ImageInspection {
  const _ImageInspection({
    required this.adapter,
    required this.regions,
    required this.sharedLines,
  });

  final RetailerAdapter adapter;
  final List<ProposedImageRegion> regions;
  final List<OcrTextLine> sharedLines;
}

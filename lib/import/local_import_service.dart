import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfx/pdfx.dart';

import 'coupon_import_models.dart';

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

class LocalCouponImportService implements CouponImportService {
  LocalCouponImportService({TextRecognizer? recognizer})
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.chinese);

  static const maxFileBytes = 30 * 1024 * 1024;
  static const maxPdfPages = 30;
  static const renderedPageWidth = 1600.0;

  final TextRecognizer _recognizer;

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
  Future<OcrPageResult> recognizeImage(String path) async {
    final watch = Stopwatch()..start();
    try {
      final recognized = await _recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      watch.stop();
      return OcrPageResult(
        sourceType: ImportSourceType.image,
        pageNumber: null,
        text: recognized.text,
        lines: recognized.blocks
            .expand((block) => block.lines)
            .map((line) => line.text)
            .toList(),
        succeeded: true,
        duration: watch.elapsed,
      );
    } catch (_) {
      watch.stop();
      return OcrPageResult(
        sourceType: ImportSourceType.image,
        pageNumber: null,
        text: '',
        lines: const [],
        succeeded: false,
        failureCode: 'ocr_failed',
        duration: watch.elapsed,
      );
    }
  }

  @override
  Future<List<OcrPageResult>> recognizePdf(
    String path, {
    required void Function(ImportProgress progress) onProgress,
    required bool Function() isCancelled,
  }) async {
    await _validateSize(path);
    PdfDocument? document;
    final temporaryFiles = <File>[];
    try {
      document = await PdfDocument.openFile(path);
      if (document.pagesCount > maxPdfPages) {
        throw const ImportLimitException('PDF 最多支援 30 頁，請拆分檔案後再試。');
      }
      final results = <OcrPageResult>[];
      onProgress(ImportProgress(completed: 0, total: document.pagesCount));
      for (
        var pageNumber = 1;
        pageNumber <= document.pagesCount;
        pageNumber++
      ) {
        if (isCancelled()) throw const ImportCancelledException();
        final watch = Stopwatch()..start();
        PdfPage? page;
        try {
          page = await document.getPage(pageNumber);
          final scale = renderedPageWidth / page.width;
          final rendered = await page.render(
            width: renderedPageWidth,
            height: page.height * scale,
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#ffffff',
          );
          if (rendered == null) throw StateError('render_failed');
          final temporary = File(
            '${Directory.systemTemp.path}/clover-import-${DateTime.now().microsecondsSinceEpoch}-$pageNumber.jpg',
          );
          temporaryFiles.add(temporary);
          await temporary.writeAsBytes(rendered.bytes, flush: true);
          final recognized = await _recognizer.processImage(
            InputImage.fromFilePath(temporary.path),
          );
          watch.stop();
          results.add(
            OcrPageResult(
              sourceType: ImportSourceType.pdf,
              pageNumber: pageNumber,
              text: recognized.text,
              lines: recognized.blocks
                  .expand((block) => block.lines)
                  .map((line) => line.text)
                  .toList(),
              succeeded: true,
              duration: watch.elapsed,
            ),
          );
        } catch (_) {
          watch.stop();
          results.add(
            OcrPageResult(
              sourceType: ImportSourceType.pdf,
              pageNumber: pageNumber,
              text: '',
              lines: const [],
              succeeded: false,
              failureCode: 'page_ocr_failed',
              duration: watch.elapsed,
            ),
          );
        } finally {
          await page?.close();
        }
        onProgress(
          ImportProgress(completed: pageNumber, total: document.pagesCount),
        );
      }
      return results;
    } on ImportCancelledException {
      rethrow;
    } on ImportLimitException {
      rethrow;
    } catch (_) {
      throw const FormatException('無法讀取 PDF。檔案可能已加密、損壞或格式不支援。');
    } finally {
      await document?.close();
      for (final file in temporaryFiles) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {
          // Temporary cleanup failure must not corrupt user data.
        }
      }
    }
  }

  Future<void> _validateSize(String path) async {
    final file = File(path);
    if (!await file.exists()) throw const FormatException('找不到選取的檔案。');
    if (await file.length() > maxFileBytes) {
      throw const ImportLimitException('檔案上限為 30 MB，請縮小或拆分後再試。');
    }
  }

  void dispose() => _recognizer.close();
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class OfferBackupFile {
  const OfferBackupFile({required this.name, required this.content});

  final String name;
  final String content;
}

abstract interface class OfferBackupFileService {
  Future<bool> saveBackup({
    required String fileName,
    required String content,
  });

  Future<OfferBackupFile?> pickBackup();
}

class FilePickerOfferBackupFileService implements OfferBackupFileService {
  static const maximumFileBytes = 5 * 1024 * 1024;

  @override
  Future<bool> saveBackup({
    required String fileName,
    required String content,
  }) async {
    final savedPath = await FilePicker.saveFile(
      dialogTitle: '儲存 Project Clover 備份',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
    return savedPath != null;
  }

  @override
  Future<OfferBackupFile?> pickBackup() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: '選擇 Project Clover 備份',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null) return null;

    final file = result.files.single;
    if (file.size > maximumFileBytes) {
      throw const FormatException('備份檔超過 5 MB 安全上限');
    }
    final bytes = file.bytes;
    if (bytes == null) throw const FormatException('無法讀取備份檔');
    try {
      return OfferBackupFile(
        name: file.name,
        content: utf8.decode(bytes, allowMalformed: false),
      );
    } on FormatException {
      throw const FormatException('備份檔不是有效的文字檔');
    }
  }
}

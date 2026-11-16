import 'dart:io';

import 'package:crypto/crypto.dart';

class MpqFingerprint {
  const MpqFingerprint({
    required this.relativePath,
    required this.sizeBytes,
    required this.sha256,
    this.error,
  });

  final String relativePath;
  final int sizeBytes;
  final String? sha256;
  final String? error;

  bool get succeeded => sha256 != null && error == null;
}

class MpqFingerprintReport {
  const MpqFingerprintReport({
    required this.files,
    required this.scannedAt,
  });

  final List<MpqFingerprint> files;
  final DateTime scannedAt;

  int get successCount => files.where((file) => file.succeeded).length;
  int get errorCount => files.length - successCount;
  int get totalBytes =>
      files.fold<int>(0, (total, file) => total + file.sizeBytes);
}

class MpqChecksumScanner {
  /// Computes streaming SHA-256 fingerprints without loading whole archives
  /// into memory. A fingerprint is not proof of integrity unless compared
  /// with a trusted checksum for the exact same client distribution.
  static Future<MpqFingerprintReport> scan(String dataFolderPath) async {
    final dataFolder = Directory(dataFolderPath);
    if (!await dataFolder.exists()) {
      throw const FileSystemException('Data folder not found.');
    }

    final files = <File>[];
    await for (final entity
        in dataFolder.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          entity.path.toLowerCase().endsWith('.mpq')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));

    final results = <MpqFingerprint>[];
    for (final file in files) {
      final relativePath = file.path
          .substring(dataFolder.path.length)
          .replaceAll(Platform.pathSeparator, '/')
          .replaceFirst('/', '');
      try {
        final size = await file.length();
        final digest = await sha256.bind(file.openRead()).first;
        results.add(MpqFingerprint(
          relativePath: relativePath,
          sizeBytes: size,
          sha256: digest.toString(),
        ));
      } on FileSystemException catch (error) {
        results.add(MpqFingerprint(
          relativePath: relativePath,
          sizeBytes: 0,
          sha256: null,
          error: error.message,
        ));
      }
    }

    return MpqFingerprintReport(
      files: results,
      scannedAt: DateTime.now(),
    );
  }
}

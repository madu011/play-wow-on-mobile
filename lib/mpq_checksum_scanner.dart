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

/// Progress is reported after each archive completes.
class MpqScanProgress {
  const MpqScanProgress({
    required this.completedFiles,
    required this.totalFiles,
    required this.completedBytes,
    required this.totalBytes,
    this.currentFile,
  });

  final int completedFiles;
  final int totalFiles;
  final int completedBytes;
  final int totalBytes;
  final String? currentFile;

  double get fraction =>
      totalFiles == 0 ? 1 : (completedFiles / totalFiles).clamp(0.0, 1.0);
}

/// Cancellation is checked between archives. An archive already being hashed
/// is allowed to finish before cancellation takes effect.
class MpqScanCancellation {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

class MpqFingerprintReport {
  const MpqFingerprintReport({
    required this.files,
    required this.scannedAt,
    required this.duration,
    required this.discoveredFileCount,
    required this.cancelled,
  });

  final List<MpqFingerprint> files;
  final DateTime scannedAt;
  final Duration duration;
  final int discoveredFileCount;
  final bool cancelled;

  int get successCount => files.where((file) => file.succeeded).length;
  int get errorCount => files.length - successCount;
  int get totalBytes =>
      files.fold<int>(0, (total, file) => total + file.sizeBytes);
  int get completedFileCount => files.length;
}

class MpqChecksumScanner {
  /// Computes streaming SHA-256 fingerprints without loading whole archives
  /// into memory. A fingerprint is not proof of integrity unless compared
  /// with a trusted checksum for the exact same client distribution.
  static Future<MpqFingerprintReport> scan(
    String dataFolderPath, {
    void Function(MpqScanProgress progress)? onProgress,
    MpqScanCancellation? cancellation,
  }) async {
    final stopwatch = Stopwatch()..start();
    final dataFolder = Directory(dataFolderPath);
    if (!await dataFolder.exists()) {
      throw const FileSystemException('Data folder not found.');
    }

    final files = <File>[];
    await for (final entity
        in dataFolder.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.mpq')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));

    var totalBytes = 0;
    for (final file in files) {
      try {
        totalBytes += await file.length();
      } on FileSystemException {
        // The individual file will be represented as an error result below.
      }
    }

    final results = <MpqFingerprint>[];
    var completedBytes = 0;
    onProgress?.call(MpqScanProgress(
      completedFiles: 0,
      totalFiles: files.length,
      completedBytes: 0,
      totalBytes: totalBytes,
    ));

    for (final file in files) {
      if (cancellation?.isCancelled ?? false) break;

      final relativePath = file.path
          .substring(dataFolder.path.length)
          .replaceAll(Platform.pathSeparator, '/')
          .replaceFirst('/', '');
      var fileSize = 0;
      try {
        fileSize = await file.length();
        final digest = await sha256.bind(file.openRead()).first;
        results.add(MpqFingerprint(
          relativePath: relativePath,
          sizeBytes: fileSize,
          sha256: digest.toString(),
        ));
      } on FileSystemException catch (error) {
        results.add(MpqFingerprint(
          relativePath: relativePath,
          sizeBytes: fileSize,
          sha256: null,
          error: error.message,
        ));
      }
      completedBytes += fileSize;
      onProgress?.call(MpqScanProgress(
        completedFiles: results.length,
        totalFiles: files.length,
        completedBytes: completedBytes,
        totalBytes: totalBytes,
        currentFile: relativePath,
      ));
    }

    stopwatch.stop();
    return MpqFingerprintReport(
      files: results,
      scannedAt: DateTime.now(),
      duration: stopwatch.elapsed,
      discoveredFileCount: files.length,
      cancelled: cancellation?.isCancelled ?? false,
    );
  }
}

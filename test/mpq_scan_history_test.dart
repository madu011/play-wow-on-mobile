import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/mpq_checksum_scanner.dart';
import 'package:myapp/mpq_scan_history.dart';

void main() {
  test('creates a scan history entry from a completed report', () {
    final report = MpqFingerprintReport(
      scannedAt: DateTime.utc(2026, 11, 16, 12),
      duration: const Duration(seconds: 8),
      discoveredFileCount: 3,
      cancelled: false,
      files: const [
        MpqFingerprint(
          relativePath: 'common.MPQ',
          sizeBytes: 1024,
          sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
        MpqFingerprint(
          relativePath: 'locale.MPQ',
          sizeBytes: 512,
          sha256: null,
          error: 'Read failed',
        ),
      ],
    );

    final entry = MpqScanHistoryEntry.fromReport(report);
    final decoded = MpqScanHistoryEntry.fromJson(entry.toJson());

    expect(decoded.scannedAt, report.scannedAt);
    expect(decoded.durationMs, 8000);
    expect(decoded.discoveredFiles, 3);
    expect(decoded.completedFiles, 2);
    expect(decoded.successCount, 1);
    expect(decoded.errorCount, 1);
    expect(decoded.totalBytes, 1536);
    expect(decoded.cancelled, isFalse);
  });

  test('preserves cancelled status in history entry', () {
    final report = MpqFingerprintReport(
      scannedAt: DateTime.utc(2026, 11, 16, 13),
      duration: const Duration(milliseconds: 250),
      discoveredFileCount: 4,
      cancelled: true,
      files: const [],
    );

    final entry = MpqScanHistoryEntry.fromReport(report);
    final decoded = MpqScanHistoryEntry.fromJson(entry.toJson());

    expect(decoded.cancelled, isTrue);
    expect(decoded.completedFiles, 0);
    expect(decoded.discoveredFiles, 4);
  });

  test('compares latest scan summary against an older scan', () {
    final older = MpqScanHistoryEntry(
      scannedAt: DateTime.utc(2026, 11, 15),
      durationMs: 5000,
      discoveredFiles: 4,
      completedFiles: 4,
      successCount: 3,
      errorCount: 1,
      totalBytes: 2048,
      cancelled: false,
    );
    final latest = MpqScanHistoryEntry(
      scannedAt: DateTime.utc(2026, 11, 16),
      durationMs: 7000,
      discoveredFiles: 5,
      completedFiles: 5,
      successCount: 5,
      errorCount: 0,
      totalBytes: 4096,
      cancelled: false,
    );

    final comparison = MpqScanComparison.between(latest, older);

    expect(comparison.hashedDelta, 2);
    expect(comparison.errorDelta, -1);
    expect(comparison.completedDelta, 1);
    expect(comparison.discoveredDelta, 1);
    expect(comparison.bytesDelta, 2048);
    expect(comparison.durationDeltaMs, 2000);
  });

  test('supports negative changes in scan metrics', () {
    final older = MpqScanHistoryEntry(
      scannedAt: DateTime.utc(2026, 11, 15),
      durationMs: 9000,
      discoveredFiles: 6,
      completedFiles: 6,
      successCount: 6,
      errorCount: 0,
      totalBytes: 8192,
      cancelled: false,
    );
    final latest = MpqScanHistoryEntry(
      scannedAt: DateTime.utc(2026, 11, 16),
      durationMs: 4000,
      discoveredFiles: 5,
      completedFiles: 4,
      successCount: 3,
      errorCount: 1,
      totalBytes: 4096,
      cancelled: true,
    );

    final comparison = MpqScanComparison.between(latest, older);

    expect(comparison.hashedDelta, -3);
    expect(comparison.errorDelta, 1);
    expect(comparison.completedDelta, -2);
    expect(comparison.discoveredDelta, -1);
    expect(comparison.bytesDelta, -4096);
    expect(comparison.durationDeltaMs, -5000);
  });

}

import 'dart:convert';

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

    expect(decoded.scannedAt.millisecondsSinceEpoch,
        report.scannedAt.millisecondsSinceEpoch);
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


  test('stores and restores detailed MPQ fingerprints', () {
    final entry = MpqScanHistoryEntry(
      scannedAt: DateTime.utc(2026, 11, 16, 14),
      durationMs: 1200,
      discoveredFiles: 2,
      completedFiles: 2,
      successCount: 1,
      errorCount: 1,
      totalBytes: 300,
      cancelled: false,
      fingerprints: const [
        MpqFingerprint(
          relativePath: 'common.MPQ',
          sizeBytes: 200,
          sha256: 'abc',
        ),
        MpqFingerprint(
          relativePath: 'locale.MPQ',
          sizeBytes: 100,
          sha256: null,
          error: 'Read failed',
        ),
      ],
    );

    final decoded = MpqScanHistoryEntry.fromJson(entry.toJson());

    expect(decoded.fingerprints, hasLength(2));
    expect(decoded.fingerprints.first.relativePath, 'common.MPQ');
    expect(decoded.fingerprints.first.sha256, 'abc');
    expect(decoded.fingerprints.last.error, 'Read failed');
  });

  test('supports old history entries without fingerprint snapshots', () {
    final decoded = MpqScanHistoryEntry.fromJson({
      'scannedAt': DateTime.utc(2026, 11, 16).millisecondsSinceEpoch,
      'durationMs': 100,
      'discoveredFiles': 1,
      'completedFiles': 1,
      'successCount': 1,
      'errorCount': 0,
      'totalBytes': 64,
      'cancelled': false,
    });

    expect(decoded.fingerprints, isEmpty);
  });

  test('detects changed, added, missing, unreadable and unchanged files', () {
    MpqFingerprint file(String path, String hash, {int size = 10}) =>
        MpqFingerprint(relativePath: path, sizeBytes: size, sha256: hash);

    final previous = MpqScanHistoryEntry(
      scannedAt: DateTime.utc(2026, 11, 15),
      durationMs: 1000,
      discoveredFiles: 4,
      completedFiles: 4,
      successCount: 3,
      errorCount: 1,
      totalBytes: 40,
      cancelled: false,
      fingerprints: [
        file('same.MPQ', 'same'),
        file('changed.MPQ', 'old'),
        file('missing.MPQ', 'gone'),
        const MpqFingerprint(
          relativePath: 'error.MPQ',
          sizeBytes: 10,
          sha256: null,
          error: 'Permission denied',
        ),
      ],
    );
    final latest = MpqScanHistoryEntry(
      scannedAt: DateTime.utc(2026, 11, 16),
      durationMs: 900,
      discoveredFiles: 4,
      completedFiles: 4,
      successCount: 3,
      errorCount: 1,
      totalBytes: 40,
      cancelled: false,
      fingerprints: [
        file('same.MPQ', 'same'),
        file('changed.MPQ', 'new'),
        file('added.MPQ', 'new-file'),
        const MpqFingerprint(
          relativePath: 'error.MPQ',
          sizeBytes: 10,
          sha256: null,
          error: 'Read failed',
        ),
      ],
    );

    final comparison = MpqDetailedComparison.between(latest, previous);

    expect(comparison.count(MpqFileChangeType.unchanged), 1);
    expect(comparison.count(MpqFileChangeType.changed), 1);
    expect(comparison.count(MpqFileChangeType.added), 1);
    expect(comparison.count(MpqFileChangeType.missing), 1);
    expect(comparison.count(MpqFileChangeType.unreadable), 1);
  });


  test('does not label unscanned files as missing after a cancelled scan', () {
    final old = MpqScanHistoryEntry(
      scannedAt: DateTime.utc(2026, 11, 15),
      durationMs: 1000,
      discoveredFiles: 2,
      completedFiles: 2,
      successCount: 2,
      errorCount: 0,
      totalBytes: 20,
      cancelled: false,
      fingerprints: const [
        MpqFingerprint(relativePath: 'one.MPQ', sizeBytes: 10, sha256: 'one'),
        MpqFingerprint(relativePath: 'two.MPQ', sizeBytes: 10, sha256: 'two'),
      ],
    );
    final partial = MpqScanHistoryEntry(
      scannedAt: DateTime.utc(2026, 11, 16),
      durationMs: 500,
      discoveredFiles: 2,
      completedFiles: 1,
      successCount: 1,
      errorCount: 0,
      totalBytes: 10,
      cancelled: true,
      fingerprints: const [
        MpqFingerprint(relativePath: 'one.MPQ', sizeBytes: 10, sha256: 'one'),
      ],
    );

    final comparison = MpqDetailedComparison.between(partial, old);

    expect(comparison.count(MpqFileChangeType.unchanged), 1);
    expect(comparison.count(MpqFileChangeType.unverified), 1);
    expect(comparison.count(MpqFileChangeType.missing), 0);
  });


  test('exports and imports a versioned scan history archive', () {
    final entry = MpqScanHistoryEntry(
      scannedAt: DateTime.utc(2026, 11, 16, 15),
      durationMs: 2500,
      discoveredFiles: 1,
      completedFiles: 1,
      successCount: 1,
      errorCount: 0,
      totalBytes: 2048,
      cancelled: false,
      fingerprints: const [
        MpqFingerprint(
          relativePath: 'common.MPQ',
          sizeBytes: 2048,
          sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      ],
    );

    final encoded = MpqScanHistoryArchive.encode(
      [entry],
      exportedAt: DateTime.utc(2026, 11, 16, 16),
    );
    final decoded = MpqScanHistoryArchive.decode(encoded);

    expect(decoded, hasLength(1));
    expect(decoded.single.id, entry.id);
    expect(decoded.single.fingerprints.single.sha256,
        entry.fingerprints.single.sha256);
  });

  test('sorts imported scans newest first and ignores duplicate ids', () {
    MpqScanHistoryEntry entry(DateTime time) => MpqScanHistoryEntry(
          scannedAt: time,
          durationMs: 100,
          discoveredFiles: 0,
          completedFiles: 0,
          successCount: 0,
          errorCount: 0,
          totalBytes: 0,
          cancelled: false,
        );

    final older = entry(DateTime.utc(2026, 11, 15));
    final newer = entry(DateTime.utc(2026, 11, 16));
    final decoded = MpqScanHistoryArchive.decode(
      MpqScanHistoryArchive.encode([older, newer, older]),
    );

    expect(decoded, hasLength(2));
    expect(decoded.first.id, newer.id);
    expect(decoded.last.id, older.id);
  });

  test('rejects an unsupported scan history archive format', () {
    expect(
      () => MpqScanHistoryArchive.decode(
        '{"format":"unknown","version":1,"entries":[]}',
      ),
      throwsFormatException,
    );
  });

  test('rejects malformed fingerprint hashes in imported archives', () {
    final invalid = {
      'format': MpqScanHistoryArchive.format,
      'version': MpqScanHistoryArchive.version,
      'entries': [
        {
          'scannedAt': DateTime.utc(2026, 11, 16).millisecondsSinceEpoch,
          'durationMs': 1,
          'discoveredFiles': 1,
          'completedFiles': 1,
          'successCount': 1,
          'errorCount': 0,
          'totalBytes': 10,
          'cancelled': false,
          'fingerprints': [
            {
              'relativePath': 'bad.MPQ',
              'sizeBytes': 10,
              'sha256': 'not-a-sha256',
              'error': null,
            }
          ],
        }
      ],
    };
    expect(
      () => MpqScanHistoryArchive.decode(jsonEncode(invalid)),
      throwsFormatException,
    );
  });

}

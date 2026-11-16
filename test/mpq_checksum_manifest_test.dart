import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/mpq_checksum_manifest.dart';
import 'package:myapp/mpq_checksum_scanner.dart';

void main() {
  test('encodes and decodes a manifest', () {
    final report = MpqFingerprintReport(
      scannedAt: DateTime.utc(2026, 11, 16),
      files: const [
        MpqFingerprint(
          relativePath: 'common.MPQ',
          sizeBytes: 3,
          sha256: 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        ),
      ],
    );
    final manifest = MpqChecksumManifest.fromReport(report);
    final decoded = MpqChecksumManifest.decode(manifest.encode());

    expect(decoded.entries, hasLength(1));
    expect(decoded.entries.single.path, 'common.MPQ');
    expect(decoded.entries.single.sizeBytes, 3);
    expect(decoded.entries.single.sha256, manifest.entries.single.sha256);
  });

  test('compares unchanged, changed, added and missing archives', () {
    const hashA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const hashB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final baseline = MpqChecksumManifest(
      createdAt: DateTime.utc(2026),
      entries: const [
        MpqManifestEntry(path: 'same.MPQ', sizeBytes: 1, sha256: hashA),
        MpqManifestEntry(path: 'changed.MPQ', sizeBytes: 1, sha256: hashA),
        MpqManifestEntry(path: 'missing.MPQ', sizeBytes: 1, sha256: hashA),
      ],
    );
    final current = MpqFingerprintReport(
      scannedAt: DateTime.utc(2026, 11, 17),
      files: const [
        MpqFingerprint(
          relativePath: 'same.MPQ', sizeBytes: 1, sha256: hashA),
        MpqFingerprint(
          relativePath: 'changed.MPQ', sizeBytes: 2, sha256: hashB),
        MpqFingerprint(
          relativePath: 'added.MPQ', sizeBytes: 1, sha256: hashA),
      ],
    );

    final comparison = baseline.compare(current);
    expect(comparison.count(MpqManifestStatus.unchanged), 1);
    expect(comparison.count(MpqManifestStatus.changed), 1);
    expect(comparison.count(MpqManifestStatus.added), 1);
    expect(comparison.count(MpqManifestStatus.missing), 1);
  });

  test('rejects invalid hashes and duplicate paths', () {
    expect(
      () => MpqChecksumManifest.decode(
        '{"schemaVersion":1,"createdAt":"2026-11-16T00:00:00Z",'
        '"entries":[{"path":"x.MPQ","sizeBytes":1,"sha256":"bad"}]}',
      ),
      throwsFormatException,
    );
    expect(
      () => MpqChecksumManifest.decode(
        '{"schemaVersion":1,"createdAt":"2026-11-16T00:00:00Z",'
        '"entries":['
        '{"path":"x.MPQ","sizeBytes":1,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},'
        '{"path":"x.MPQ","sizeBytes":1,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}',
      ),
      throwsFormatException,
    );
  });
}

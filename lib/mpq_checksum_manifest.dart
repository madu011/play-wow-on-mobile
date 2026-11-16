import 'dart:convert';

import 'mpq_checksum_scanner.dart';

class MpqManifestEntry {
  const MpqManifestEntry({
    required this.path,
    required this.sizeBytes,
    required this.sha256,
  });

  final String path;
  final int sizeBytes;
  final String sha256;

  Map<String, Object> toJson() => {
        'path': path,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
      };

  factory MpqManifestEntry.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid manifest entry.');
    }
    final path = value['path'];
    final size = value['sizeBytes'];
    final hash = value['sha256'];
    if (path is! String ||
        path.isEmpty ||
        size is! int ||
        size < 0 ||
        hash is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('Manifest entry has invalid fields.');
    }
    return MpqManifestEntry(
      path: path,
      sizeBytes: size,
      sha256: hash.toLowerCase(),
    );
  }
}

class MpqChecksumManifest {
  const MpqChecksumManifest({
    required this.createdAt,
    required this.entries,
  });

  static const schemaVersion = 1;
  final DateTime createdAt;
  final List<MpqManifestEntry> entries;

  factory MpqChecksumManifest.fromReport(MpqFingerprintReport report) {
    final entries = report.files
        .where((file) => file.succeeded)
        .map((file) => MpqManifestEntry(
              path: file.relativePath,
              sizeBytes: file.sizeBytes,
              sha256: file.sha256!,
            ))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return MpqChecksumManifest(
      createdAt: report.scannedAt,
      entries: entries,
    );
  }

  Map<String, Object> toJson() => {
        'schemaVersion': schemaVersion,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'manifestType': 'user-created-local-baseline',
        'entries': entries.map((entry) => entry.toJson()).toList(),
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory MpqChecksumManifest.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != schemaVersion ||
        decoded['entries'] is! List ||
        decoded['createdAt'] is! String) {
      throw const FormatException('Unsupported or invalid MPQ manifest.');
    }
    final createdAt = DateTime.tryParse(decoded['createdAt'] as String);
    if (createdAt == null) {
      throw const FormatException('Manifest date is invalid.');
    }
    final entries = (decoded['entries'] as List)
        .map(MpqManifestEntry.fromJson)
        .toList();
    final paths = entries.map((entry) => entry.path).toSet();
    if (paths.length != entries.length) {
      throw const FormatException('Manifest contains duplicate file paths.');
    }
    return MpqChecksumManifest(
      createdAt: createdAt.toLocal(),
      entries: entries,
    );
  }

  MpqManifestComparison compare(MpqFingerprintReport current) {
    final scanned = {
      for (final file in current.files.where((file) => file.succeeded))
        file.relativePath: file
    };
    final results = <MpqManifestDifference>[];
    for (final entry in entries) {
      final file = scanned.remove(entry.path);
      if (file == null) {
        results.add(MpqManifestDifference(
          path: entry.path,
          status: MpqManifestStatus.missing,
        ));
      } else if (file.sha256 != entry.sha256 ||
          file.sizeBytes != entry.sizeBytes) {
        results.add(MpqManifestDifference(
          path: entry.path,
          status: MpqManifestStatus.changed,
        ));
      } else {
        results.add(MpqManifestDifference(
          path: entry.path,
          status: MpqManifestStatus.unchanged,
        ));
      }
    }
    for (final file in scanned.values) {
      results.add(MpqManifestDifference(
        path: file.relativePath,
        status: MpqManifestStatus.added,
      ));
    }
    results.sort((a, b) {
      final byStatus = a.status.index.compareTo(b.status.index);
      return byStatus != 0 ? byStatus : a.path.compareTo(b.path);
    });
    return MpqManifestComparison(results);
  }
}

enum MpqManifestStatus { changed, missing, added, unchanged }

class MpqManifestDifference {
  const MpqManifestDifference({required this.path, required this.status});
  final String path;
  final MpqManifestStatus status;
}

class MpqManifestComparison {
  const MpqManifestComparison(this.differences);
  final List<MpqManifestDifference> differences;

  int count(MpqManifestStatus status) =>
      differences.where((item) => item.status == status).length;
}

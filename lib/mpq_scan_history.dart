// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mpq_checksum_scanner.dart';

class MpqScanHistoryEntry {
  const MpqScanHistoryEntry({
    required this.scannedAt,
    required this.durationMs,
    required this.discoveredFiles,
    required this.completedFiles,
    required this.successCount,
    required this.errorCount,
    required this.totalBytes,
    required this.cancelled,
    this.fingerprints = const [],
  });

  final DateTime scannedAt;
  final int durationMs;
  final int discoveredFiles;
  final int completedFiles;
  final int successCount;
  final int errorCount;
  final int totalBytes;
  final bool cancelled;
  final List<MpqFingerprint> fingerprints;

  factory MpqScanHistoryEntry.fromReport(MpqFingerprintReport report) =>
      MpqScanHistoryEntry(
        scannedAt: report.scannedAt,
        durationMs: report.duration.inMilliseconds,
        discoveredFiles: report.discoveredFileCount,
        completedFiles: report.completedFileCount,
        successCount: report.successCount,
        errorCount: report.errorCount,
        totalBytes: report.totalBytes,
        cancelled: report.cancelled,
        fingerprints: report.files,
      );

  factory MpqScanHistoryEntry.fromJson(Map<String, dynamic> json) {
    return MpqScanHistoryEntry(
      scannedAt: DateTime.fromMillisecondsSinceEpoch(json['scannedAt'] as int),
      durationMs: json['durationMs'] as int,
      discoveredFiles: json['discoveredFiles'] as int,
      completedFiles: json['completedFiles'] as int,
      successCount: json['successCount'] as int,
      errorCount: json['errorCount'] as int,
      totalBytes: json['totalBytes'] as int,
      cancelled: json['cancelled'] as bool,
      fingerprints: (json['fingerprints'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => MpqFingerprint(
                relativePath: item['relativePath'] as String,
                sizeBytes: item['sizeBytes'] as int,
                sha256: item['sha256'] as String?,
                error: item['error'] as String?,
              ))
          .toList(growable: false),
    );
  }

  Map<String, Object> toJson() => {
        'scannedAt': scannedAt.millisecondsSinceEpoch,
        'durationMs': durationMs,
        'discoveredFiles': discoveredFiles,
        'completedFiles': completedFiles,
        'successCount': successCount,
        'errorCount': errorCount,
        'totalBytes': totalBytes,
        'cancelled': cancelled,
        'fingerprints': fingerprints
            .map((file) => {
                  'relativePath': file.relativePath,
                  'sizeBytes': file.sizeBytes,
                  'sha256': file.sha256,
                  'error': file.error,
                })
            .toList(),
      };

  String get id => scannedAt.microsecondsSinceEpoch.toString();
}

class MpqScanHistoryArchive {
  static const format = 'azeroth-mpq-scan-history';
  static const version = 1;

  static String encode(List<MpqScanHistoryEntry> entries, {DateTime? exportedAt}) =>
      const JsonEncoder.withIndent('  ').convert({
        'format': format,
        'version': version,
        'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'entries': entries.map((entry) => entry.toJson()).toList(),
      });

  static List<MpqScanHistoryEntry> decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != format ||
        decoded['version'] != version ||
        decoded['entries'] is! List) {
      throw const FormatException('Unsupported or invalid MPQ scan history file.');
    }
    final entries = <MpqScanHistoryEntry>[];
    final seen = <String>{};
    for (final item in decoded['entries'] as List) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid scan history entry.');
      }
      final entry = MpqScanHistoryEntry.fromJson(item);
      if (entry.durationMs < 0 || entry.discoveredFiles < 0 ||
          entry.completedFiles < 0 || entry.successCount < 0 ||
          entry.errorCount < 0 || entry.totalBytes < 0 ||
          (entry.fingerprints.isNotEmpty &&
              entry.completedFiles != entry.fingerprints.length)) {
        throw const FormatException('Scan history entry contains invalid counts.');
      }
      for (final fingerprint in entry.fingerprints) {
        if (fingerprint.relativePath.isEmpty || fingerprint.sizeBytes < 0 ||
            (fingerprint.sha256 != null &&
                !RegExp(r'^[a-fA-F0-9]{64}(fingerprint.sha256!))) {
          throw const FormatException('Scan history contains an invalid fingerprint.');
        }
      }
      if (seen.add(entry.id)) entries.add(entry);
    }
    entries.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return entries;
  }
}

enum MpqFileChangeType { unchanged, changed, added, missing, unreadable, unverified }

class MpqFileChange {
  const MpqFileChange({
    required this.path,
    required this.type,
    this.previous,
    this.latest,
  });

  final String path;
  final MpqFileChangeType type;
  final MpqFingerprint? previous;
  final MpqFingerprint? latest;
}

class MpqDetailedComparison {
  const MpqDetailedComparison({
    required this.changes,
  });

  final List<MpqFileChange> changes;

  int count(MpqFileChangeType type) =>
      changes.where((change) => change.type == type).length;

  factory MpqDetailedComparison.between(
    MpqScanHistoryEntry latest,
    MpqScanHistoryEntry previous,
  ) {
    final oldFiles = {for (final file in previous.fingerprints) file.relativePath: file};
    final newFiles = {for (final file in latest.fingerprints) file.relativePath: file};
    final paths = {...oldFiles.keys, ...newFiles.keys}.toList()..sort();
    final changes = <MpqFileChange>[];

    for (final path in paths) {
      final oldFile = oldFiles[path];
      final newFile = newFiles[path];
      MpqFileChangeType type;
      if (oldFile == null) {
        if (previous.cancelled) {
          type = MpqFileChangeType.unverified;
        } else {
          type = newFile!.succeeded
              ? MpqFileChangeType.added
              : MpqFileChangeType.unreadable;
        }
      } else if (newFile == null) {
        type = latest.cancelled
            ? MpqFileChangeType.unverified
            : MpqFileChangeType.missing;
      } else if (!oldFile.succeeded || !newFile.succeeded) {
        type = MpqFileChangeType.unreadable;
      } else if (oldFile.sha256 != newFile.sha256 ||
          oldFile.sizeBytes != newFile.sizeBytes) {
        type = MpqFileChangeType.changed;
      } else {
        type = MpqFileChangeType.unchanged;
      }
      changes.add(MpqFileChange(
        path: path,
        type: type,
        previous: oldFile,
        latest: newFile,
      ));
    }
    return MpqDetailedComparison(changes: changes);
  }
}

class MpqScanComparison {
  const MpqScanComparison({
    required this.latest,
    required this.previous,
  });

  final MpqScanHistoryEntry latest;
  final MpqScanHistoryEntry previous;

  int get hashedDelta => latest.successCount - previous.successCount;
  int get errorDelta => latest.errorCount - previous.errorCount;
  int get completedDelta => latest.completedFiles - previous.completedFiles;
  int get discoveredDelta => latest.discoveredFiles - previous.discoveredFiles;
  int get bytesDelta => latest.totalBytes - previous.totalBytes;
  int get durationDeltaMs => latest.durationMs - previous.durationMs;

  static MpqScanComparison between(
    MpqScanHistoryEntry latest,
    MpqScanHistoryEntry previous,
  ) =>
      MpqScanComparison(latest: latest, previous: previous);
}

class MpqScanHistory extends StatefulWidget {
  const MpqScanHistory({
    super.key,
    required this.folderPath,
    required this.report,
  });

  final String folderPath;
  final MpqFingerprintReport report;

  @override
  State<MpqScanHistory> createState() => _MpqScanHistoryState();
}

class _MpqScanHistoryState extends State<MpqScanHistory> {
  static const _maxEntries = 20;
  static const _maxDetailedSnapshots = 5;
  static const _gold = Color(0xFFE2B45D);
  static const _muted = Color(0xFF9AA8BC);

  List<MpqScanHistoryEntry> _entries = [];
  bool _loading = true;
  String? _error;
  String? _comparisonEntryId;

  String get _key => 'mpq_scan_history_${sha256.convert(utf8.encode(widget.folderPath))}';

  @override
  void initState() {
    super.initState();
    _loadAndRecord();
  }

  @override
  void didUpdateWidget(covariant MpqScanHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderPath != widget.folderPath) {
      _loadAndRecord();
    } else if (oldWidget.report.scannedAt != widget.report.scannedAt) {
      _recordCurrentReport();
    }
  }

  Future<void> _loadAndRecord() async {
    setState(() {
      _loading = true;
      _error = null;
      _entries = [];
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final loaded = <MpqScanHistoryEntry>[];
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          throw const FormatException('Scan history must be a list.');
        }
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            loaded.add(MpqScanHistoryEntry.fromJson(item));
          }
        }
      }
      final current = MpqScanHistoryEntry.fromReport(widget.report);
      if (!loaded.any((entry) => entry.id == current.id)) {
        loaded.insert(0, current);
      }
      if (loaded.length > _maxEntries) {
        loaded.removeRange(_maxEntries, loaded.length);
      }
      _trimDetailedSnapshots(loaded);
      await prefs.setString(
        _key,
        jsonEncode(loaded.map((entry) => entry.toJson()).toList()),
      );
      if (!mounted) return;
      setState(() {
        _entries = loaded;
        _comparisonEntryId = loaded.length > 1 ? loaded[1].id : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save scan history: $error';
        _loading = false;
      });
    }
  }

  Future<void> _recordCurrentReport() async {
    final current = MpqScanHistoryEntry.fromReport(widget.report);
    final updated = [
      current,
      ..._entries.where((entry) => entry.id != current.id),
    ].take(_maxEntries).toList();
    _trimDetailedSnapshots(updated);
    setState(() {
      _entries = updated;
      if (_comparisonEntryId == null ||
          !updated.any((entry) => entry.id == _comparisonEntryId)) {
        _comparisonEntryId = updated.length > 1 ? updated[1].id : null;
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(updated.map((entry) => entry.toJson()).toList()),
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save scan history: $error');
    }
  }

  void _trimDetailedSnapshots(List<MpqScanHistoryEntry> entries) {
    var retained = 0;
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (entry.fingerprints.isEmpty) continue;
      retained++;
      if (retained > _maxDetailedSnapshots) {
        entries[index] = MpqScanHistoryEntry(
          scannedAt: entry.scannedAt,
          durationMs: entry.durationMs,
          discoveredFiles: entry.discoveredFiles,
          completedFiles: entry.completedFiles,
          successCount: entry.successCount,
          errorCount: entry.errorCount,
          totalBytes: entry.totalBytes,
          cancelled: entry.cancelled,
        );
      }
    }
  }

  String _bytes(int value) {
    if (value >= 1024 * 1024 * 1024) {
      return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '$value B';
  }

  Widget _buildDetailedComparison(MpqDetailedComparison comparison) {
    final changed = comparison.changes
        .where((item) => item.type != MpqFileChangeType.unchanged)
        .toList();
    final labels = {
      MpqFileChangeType.changed: 'CHANGED',
      MpqFileChangeType.added: 'ADDED',
      MpqFileChangeType.missing: 'MISSING',
      MpqFileChangeType.unreadable: 'READ ERROR',
      MpqFileChangeType.unchanged: 'UNCHANGED',
      MpqFileChangeType.unverified: 'NOT VERIFIED',
    };
    final colors = {
      MpqFileChangeType.changed: Colors.orangeAccent,
      MpqFileChangeType.added: Colors.greenAccent,
      MpqFileChangeType.missing: Colors.redAccent,
      MpqFileChangeType.unreadable: Colors.deepOrangeAccent,
      MpqFileChangeType.unchanged: _muted,
      MpqFileChangeType.unverified: _muted,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PER-FILE DIFFERENCES',
            style: TextStyle(
                color: _gold, fontSize: 9, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: [
            _changeBadge('Changed', comparison.count(MpqFileChangeType.changed), Colors.orangeAccent),
            _changeBadge('Added', comparison.count(MpqFileChangeType.added), Colors.greenAccent),
            _changeBadge('Missing', comparison.count(MpqFileChangeType.missing), Colors.redAccent),
            _changeBadge('Read errors', comparison.count(MpqFileChangeType.unreadable), Colors.deepOrangeAccent),
            _changeBadge('Unchanged', comparison.count(MpqFileChangeType.unchanged), _muted),
            _changeBadge('Unverified', comparison.count(MpqFileChangeType.unverified), _muted),
          ],
        ),
        const SizedBox(height: 6),
        if (changed.isEmpty)
          const Text('No file differences detected.',
              style: TextStyle(color: Colors.greenAccent, fontSize: 9))
        else ...[
          ...changed.take(50).map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        labels[item.type]!,
                        style: TextStyle(
                            color: colors[item.type],
                            fontSize: 8,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                    Expanded(
                      child: Text(item.path,
                          style: const TextStyle(color: Colors.white70, fontSize: 8)),
                    ),
                  ],
                ),
              )),
          if (changed.length > 50)
            Text(
              'Showing first 50 of ${changed.length} differences.',
              style: const TextStyle(color: _muted, fontSize: 8),
            ),
        ],
      ],
    );
  }

  Widget _changeBadge(String label, int count, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.45)),
          color: color.withOpacity(0.08),
        ),
        child: Text('$label: $count',
            style: TextStyle(
                color: color, fontSize: 8, fontWeight: FontWeight.w800)),
      );

  Widget _buildComparisonSelector() {
    final previousEntries = _entries.skip(1).toList();
    final selected = previousEntries.any((entry) => entry.id == _comparisonEntryId)
        ? _comparisonEntryId
        : previousEntries.first.id;
    final previous = previousEntries.firstWhere((entry) => entry.id == selected);
    final comparison = MpqScanComparison.between(_entries.first, previous);

    String signed(int value) => value > 0 ? '+$value' : '$value';
    String signedBytes(int value) =>
        '${value > 0 ? '+' : value < 0 ? '-' : ''}${_bytes(value.abs())}';
    String signedDuration(int value) {
      final seconds = value.abs() / 1000;
      final prefix = value > 0 ? '+' : value < 0 ? '-' : '';
      return '$prefix${seconds.toStringAsFixed(1)} sec';
    }

    Widget metric(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      color: _muted, fontSize: 8, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF172235),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF344158)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('COMPARE WITH LATEST SCAN',
              style: TextStyle(
                  color: _gold, fontSize: 9, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            value: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              border: OutlineInputBorder(),
            ),
            dropdownColor: const Color(0xFF172235),
            style: const TextStyle(color: Colors.white, fontSize: 10),
            items: previousEntries
                .map((entry) => DropdownMenuItem<String>(
                      value: entry.id,
                      child: Text(entry.scannedAt.toLocal().toString(),
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _comparisonEntryId = value),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              metric('Hashed Δ', signed(comparison.hashedDelta)),
              metric('Errors Δ', signed(comparison.errorDelta)),
              metric('Files Δ', signed(comparison.completedDelta)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              metric('Data Δ', signedBytes(comparison.bytesDelta)),
              metric('Time Δ', signedDuration(comparison.durationDeltaMs)),
              metric('Found Δ', signed(comparison.discoveredDelta)),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Latest scan compared with the selected older scan. Positive time means the latest scan took longer.',
            style: const TextStyle(color: _muted, fontSize: 8, height: 1.35),
          ),
          const SizedBox(height: 9),
          if (_entries.first.fingerprints.isEmpty ||
              previous.fingerprints.isEmpty)
            const Text(
              'Per-file comparison is unavailable for this scan. Older history entries created before detailed snapshots may contain summary data only.',
              style: TextStyle(color: _muted, fontSize: 8, height: 1.35),
            )
          else
            _buildDetailedComparison(
              MpqDetailedComparison.between(_entries.first, previous),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101725),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF344158)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        iconColor: _gold,
        collapsedIconColor: _muted,
        title: const Text(
          'MPQ SCAN HISTORY',
          style: TextStyle(
              color: _gold, fontSize: 10, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          _loading ? 'Saving current scan...' : '${_entries.length} recent scans · newest first',
          style: const TextStyle(color: _muted, fontSize: 9),
        ),
        children: [
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 9))
          else if (_entries.isEmpty)
            const Text('No scan history yet.',
                style: TextStyle(color: _muted, fontSize: 9))
          else ...[
            if (_entries.length > 1) _buildComparisonSelector(),
            ..._entries.asMap().entries.map((item) {
              final index = item.key;
              final entry = item.value;
              final status = entry.cancelled ? 'CANCELLED' : 'COMPLETED';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${index + 1}. ${entry.scannedAt.toLocal()}',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          status,
                          style: TextStyle(
                            color: entry.cancelled
                                ? Colors.orangeAccent
                                : Colors.greenAccent,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.successCount} hashed · ${entry.errorCount} errors · ${entry.completedFiles}/${entry.discoveredFiles} files',
                      style: const TextStyle(color: _muted, fontSize: 9),
                    ),
                    Text(
                      '${_bytes(entry.totalBytes)} · ${(entry.durationMs / 1000).toStringAsFixed(1)} sec',
                      style: const TextStyle(color: _muted, fontSize: 9),
                    ),
                    if (index != _entries.length - 1)
                      const Divider(color: Color(0xFF263448), height: 12),
                  ],
                ),
              );
            }),
          ],
          const Text(
            'History stores scan summaries only. It does not store MPQ contents or the full SHA-256 list.',
            style: TextStyle(color: _muted, fontSize: 8, height: 1.35),
          ),
        ],
      ),
    );
  }
}
).hasMatch(fingerprint.sha256!))) {
          throw const FormatException('Scan history contains an invalid fingerprint.');
        }
      }
      if (seen.add(entry.id)) entries.add(entry);
    }
    entries.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return entries;
  }
}

enum MpqFileChangeType { unchanged, changed, added, missing, unreadable, unverified }

class MpqFileChange {
  const MpqFileChange({
    required this.path,
    required this.type,
    this.previous,
    this.latest,
  });

  final String path;
  final MpqFileChangeType type;
  final MpqFingerprint? previous;
  final MpqFingerprint? latest;
}

class MpqDetailedComparison {
  const MpqDetailedComparison({
    required this.changes,
  });

  final List<MpqFileChange> changes;

  int count(MpqFileChangeType type) =>
      changes.where((change) => change.type == type).length;

  factory MpqDetailedComparison.between(
    MpqScanHistoryEntry latest,
    MpqScanHistoryEntry previous,
  ) {
    final oldFiles = {for (final file in previous.fingerprints) file.relativePath: file};
    final newFiles = {for (final file in latest.fingerprints) file.relativePath: file};
    final paths = {...oldFiles.keys, ...newFiles.keys}.toList()..sort();
    final changes = <MpqFileChange>[];

    for (final path in paths) {
      final oldFile = oldFiles[path];
      final newFile = newFiles[path];
      MpqFileChangeType type;
      if (oldFile == null) {
        if (previous.cancelled) {
          type = MpqFileChangeType.unverified;
        } else {
          type = newFile!.succeeded
              ? MpqFileChangeType.added
              : MpqFileChangeType.unreadable;
        }
      } else if (newFile == null) {
        type = latest.cancelled
            ? MpqFileChangeType.unverified
            : MpqFileChangeType.missing;
      } else if (!oldFile.succeeded || !newFile.succeeded) {
        type = MpqFileChangeType.unreadable;
      } else if (oldFile.sha256 != newFile.sha256 ||
          oldFile.sizeBytes != newFile.sizeBytes) {
        type = MpqFileChangeType.changed;
      } else {
        type = MpqFileChangeType.unchanged;
      }
      changes.add(MpqFileChange(
        path: path,
        type: type,
        previous: oldFile,
        latest: newFile,
      ));
    }
    return MpqDetailedComparison(changes: changes);
  }
}

class MpqScanComparison {
  const MpqScanComparison({
    required this.latest,
    required this.previous,
  });

  final MpqScanHistoryEntry latest;
  final MpqScanHistoryEntry previous;

  int get hashedDelta => latest.successCount - previous.successCount;
  int get errorDelta => latest.errorCount - previous.errorCount;
  int get completedDelta => latest.completedFiles - previous.completedFiles;
  int get discoveredDelta => latest.discoveredFiles - previous.discoveredFiles;
  int get bytesDelta => latest.totalBytes - previous.totalBytes;
  int get durationDeltaMs => latest.durationMs - previous.durationMs;

  static MpqScanComparison between(
    MpqScanHistoryEntry latest,
    MpqScanHistoryEntry previous,
  ) =>
      MpqScanComparison(latest: latest, previous: previous);
}

class MpqScanHistory extends StatefulWidget {
  const MpqScanHistory({
    super.key,
    required this.folderPath,
    required this.report,
  });

  final String folderPath;
  final MpqFingerprintReport report;

  @override
  State<MpqScanHistory> createState() => _MpqScanHistoryState();
}

class _MpqScanHistoryState extends State<MpqScanHistory> {
  static const _maxEntries = 20;
  static const _maxDetailedSnapshots = 5;
  static const _gold = Color(0xFFE2B45D);
  static const _muted = Color(0xFF9AA8BC);

  List<MpqScanHistoryEntry> _entries = [];
  bool _loading = true;
  String? _error;
  String? _comparisonEntryId;

  String get _key => 'mpq_scan_history_${sha256.convert(utf8.encode(widget.folderPath))}';

  @override
  void initState() {
    super.initState();
    _loadAndRecord();
  }

  @override
  void didUpdateWidget(covariant MpqScanHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderPath != widget.folderPath) {
      _loadAndRecord();
    } else if (oldWidget.report.scannedAt != widget.report.scannedAt) {
      _recordCurrentReport();
    }
  }

  Future<void> _loadAndRecord() async {
    setState(() {
      _loading = true;
      _error = null;
      _entries = [];
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final loaded = <MpqScanHistoryEntry>[];
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          throw const FormatException('Scan history must be a list.');
        }
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            loaded.add(MpqScanHistoryEntry.fromJson(item));
          }
        }
      }
      final current = MpqScanHistoryEntry.fromReport(widget.report);
      if (!loaded.any((entry) => entry.id == current.id)) {
        loaded.insert(0, current);
      }
      if (loaded.length > _maxEntries) {
        loaded.removeRange(_maxEntries, loaded.length);
      }
      _trimDetailedSnapshots(loaded);
      await prefs.setString(
        _key,
        jsonEncode(loaded.map((entry) => entry.toJson()).toList()),
      );
      if (!mounted) return;
      setState(() {
        _entries = loaded;
        _comparisonEntryId = loaded.length > 1 ? loaded[1].id : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save scan history: $error';
        _loading = false;
      });
    }
  }

  Future<void> _recordCurrentReport() async {
    final current = MpqScanHistoryEntry.fromReport(widget.report);
    final updated = [
      current,
      ..._entries.where((entry) => entry.id != current.id),
    ].take(_maxEntries).toList();
    _trimDetailedSnapshots(updated);
    setState(() {
      _entries = updated;
      if (_comparisonEntryId == null ||
          !updated.any((entry) => entry.id == _comparisonEntryId)) {
        _comparisonEntryId = updated.length > 1 ? updated[1].id : null;
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(updated.map((entry) => entry.toJson()).toList()),
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save scan history: $error');
    }
  }

  void _trimDetailedSnapshots(List<MpqScanHistoryEntry> entries) {
    var retained = 0;
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (entry.fingerprints.isEmpty) continue;
      retained++;
      if (retained > _maxDetailedSnapshots) {
        entries[index] = MpqScanHistoryEntry(
          scannedAt: entry.scannedAt,
          durationMs: entry.durationMs,
          discoveredFiles: entry.discoveredFiles,
          completedFiles: entry.completedFiles,
          successCount: entry.successCount,
          errorCount: entry.errorCount,
          totalBytes: entry.totalBytes,
          cancelled: entry.cancelled,
        );
      }
    }
  }

  String _bytes(int value) {
    if (value >= 1024 * 1024 * 1024) {
      return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '$value B';
  }

  Widget _buildDetailedComparison(MpqDetailedComparison comparison) {
    final changed = comparison.changes
        .where((item) => item.type != MpqFileChangeType.unchanged)
        .toList();
    final labels = {
      MpqFileChangeType.changed: 'CHANGED',
      MpqFileChangeType.added: 'ADDED',
      MpqFileChangeType.missing: 'MISSING',
      MpqFileChangeType.unreadable: 'READ ERROR',
      MpqFileChangeType.unchanged: 'UNCHANGED',
      MpqFileChangeType.unverified: 'NOT VERIFIED',
    };
    final colors = {
      MpqFileChangeType.changed: Colors.orangeAccent,
      MpqFileChangeType.added: Colors.greenAccent,
      MpqFileChangeType.missing: Colors.redAccent,
      MpqFileChangeType.unreadable: Colors.deepOrangeAccent,
      MpqFileChangeType.unchanged: _muted,
      MpqFileChangeType.unverified: _muted,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PER-FILE DIFFERENCES',
            style: TextStyle(
                color: _gold, fontSize: 9, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: [
            _changeBadge('Changed', comparison.count(MpqFileChangeType.changed), Colors.orangeAccent),
            _changeBadge('Added', comparison.count(MpqFileChangeType.added), Colors.greenAccent),
            _changeBadge('Missing', comparison.count(MpqFileChangeType.missing), Colors.redAccent),
            _changeBadge('Read errors', comparison.count(MpqFileChangeType.unreadable), Colors.deepOrangeAccent),
            _changeBadge('Unchanged', comparison.count(MpqFileChangeType.unchanged), _muted),
            _changeBadge('Unverified', comparison.count(MpqFileChangeType.unverified), _muted),
          ],
        ),
        const SizedBox(height: 6),
        if (changed.isEmpty)
          const Text('No file differences detected.',
              style: TextStyle(color: Colors.greenAccent, fontSize: 9))
        else ...[
          ...changed.take(50).map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        labels[item.type]!,
                        style: TextStyle(
                            color: colors[item.type],
                            fontSize: 8,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                    Expanded(
                      child: Text(item.path,
                          style: const TextStyle(color: Colors.white70, fontSize: 8)),
                    ),
                  ],
                ),
              )),
          if (changed.length > 50)
            Text(
              'Showing first 50 of ${changed.length} differences.',
              style: const TextStyle(color: _muted, fontSize: 8),
            ),
        ],
      ],
    );
  }

  Widget _changeBadge(String label, int count, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.45)),
          color: color.withOpacity(0.08),
        ),
        child: Text('$label: $count',
            style: TextStyle(
                color: color, fontSize: 8, fontWeight: FontWeight.w800)),
      );

  Widget _buildComparisonSelector() {
    final previousEntries = _entries.skip(1).toList();
    final selected = previousEntries.any((entry) => entry.id == _comparisonEntryId)
        ? _comparisonEntryId
        : previousEntries.first.id;
    final previous = previousEntries.firstWhere((entry) => entry.id == selected);
    final comparison = MpqScanComparison.between(_entries.first, previous);

    String signed(int value) => value > 0 ? '+$value' : '$value';
    String signedBytes(int value) =>
        '${value > 0 ? '+' : value < 0 ? '-' : ''}${_bytes(value.abs())}';
    String signedDuration(int value) {
      final seconds = value.abs() / 1000;
      final prefix = value > 0 ? '+' : value < 0 ? '-' : '';
      return '$prefix${seconds.toStringAsFixed(1)} sec';
    }

    Widget metric(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      color: _muted, fontSize: 8, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF172235),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF344158)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('COMPARE WITH LATEST SCAN',
              style: TextStyle(
                  color: _gold, fontSize: 9, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            value: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              border: OutlineInputBorder(),
            ),
            dropdownColor: const Color(0xFF172235),
            style: const TextStyle(color: Colors.white, fontSize: 10),
            items: previousEntries
                .map((entry) => DropdownMenuItem<String>(
                      value: entry.id,
                      child: Text(entry.scannedAt.toLocal().toString(),
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _comparisonEntryId = value),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              metric('Hashed Δ', signed(comparison.hashedDelta)),
              metric('Errors Δ', signed(comparison.errorDelta)),
              metric('Files Δ', signed(comparison.completedDelta)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              metric('Data Δ', signedBytes(comparison.bytesDelta)),
              metric('Time Δ', signedDuration(comparison.durationDeltaMs)),
              metric('Found Δ', signed(comparison.discoveredDelta)),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Latest scan compared with the selected older scan. Positive time means the latest scan took longer.',
            style: const TextStyle(color: _muted, fontSize: 8, height: 1.35),
          ),
          const SizedBox(height: 9),
          if (_entries.first.fingerprints.isEmpty ||
              previous.fingerprints.isEmpty)
            const Text(
              'Per-file comparison is unavailable for this scan. Older history entries created before detailed snapshots may contain summary data only.',
              style: TextStyle(color: _muted, fontSize: 8, height: 1.35),
            )
          else
            _buildDetailedComparison(
              MpqDetailedComparison.between(_entries.first, previous),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101725),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF344158)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        iconColor: _gold,
        collapsedIconColor: _muted,
        title: const Text(
          'MPQ SCAN HISTORY',
          style: TextStyle(
              color: _gold, fontSize: 10, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          _loading ? 'Saving current scan...' : '${_entries.length} recent scans · newest first',
          style: const TextStyle(color: _muted, fontSize: 9),
        ),
        children: [
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 9))
          else if (_entries.isEmpty)
            const Text('No scan history yet.',
                style: TextStyle(color: _muted, fontSize: 9))
          else ...[
            if (_entries.length > 1) _buildComparisonSelector(),
            ..._entries.asMap().entries.map((item) {
              final index = item.key;
              final entry = item.value;
              final status = entry.cancelled ? 'CANCELLED' : 'COMPLETED';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${index + 1}. ${entry.scannedAt.toLocal()}',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          status,
                          style: TextStyle(
                            color: entry.cancelled
                                ? Colors.orangeAccent
                                : Colors.greenAccent,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.successCount} hashed · ${entry.errorCount} errors · ${entry.completedFiles}/${entry.discoveredFiles} files',
                      style: const TextStyle(color: _muted, fontSize: 9),
                    ),
                    Text(
                      '${_bytes(entry.totalBytes)} · ${(entry.durationMs / 1000).toStringAsFixed(1)} sec',
                      style: const TextStyle(color: _muted, fontSize: 9),
                    ),
                    if (index != _entries.length - 1)
                      const Divider(color: Color(0xFF263448), height: 12),
                  ],
                ),
              );
            }),
          ],
          const Text(
            'History stores scan summaries only. It does not store MPQ contents or the full SHA-256 list.',
            style: TextStyle(color: _muted, fontSize: 8, height: 1.35),
          ),
        ],
      ),
    );
  }
}

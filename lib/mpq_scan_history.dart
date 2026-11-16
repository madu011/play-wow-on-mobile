import 'dart:convert';

import 'package:crypto/crypto.dart';
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
  });

  final DateTime scannedAt;
  final int durationMs;
  final int discoveredFiles;
  final int completedFiles;
  final int successCount;
  final int errorCount;
  final int totalBytes;
  final bool cancelled;

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
      };

  String get id => scannedAt.microsecondsSinceEpoch.toString();
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
  static const _gold = Color(0xFFE2B45D);
  static const _muted = Color(0xFF9AA8BC);

  List<MpqScanHistoryEntry> _entries = [];
  bool _loading = true;
  String? _error;

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
      await prefs.setString(
        _key,
        jsonEncode(loaded.map((entry) => entry.toJson()).toList()),
      );
      if (!mounted) return;
      setState(() {
        _entries = loaded;
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
    setState(() => _entries = updated);
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
          else
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
          const Text(
            'History stores scan summaries only. It does not store MPQ contents or the full SHA-256 list.',
            style: TextStyle(color: _muted, fontSize: 8, height: 1.35),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mpq_checksum_scanner.dart';
import 'mpq_checksum_manifest.dart';

class MpqManifestManager extends StatefulWidget {
  const MpqManifestManager({
    super.key,
    required this.folderPath,
    required this.report,
  });

  final String folderPath;
  final MpqFingerprintReport report;

  @override
  State<MpqManifestManager> createState() => _MpqManifestManagerState();
}

class _MpqManifestManagerState extends State<MpqManifestManager> {
  MpqChecksumManifest? _manifest;
  bool _loading = true;
  String? _message;

  String get _storageKey => 'mpq_manifest_${widget.folderPath.hashCode}';

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  @override
  void didUpdateWidget(covariant MpqManifestManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderPath != widget.folderPath) _loadLocal();
  }

  Future<void> _loadLocal() async {
    setState(() {
      _loading = true;
      _manifest = null;
    });
    final prefs = await SharedPreferences.getInstance();
    final source = prefs.getString(_storageKey);
    MpqChecksumManifest? loaded;
    if (source != null) {
      try {
        loaded = MpqChecksumManifest.decode(source);
      } catch (_) {
        await prefs.remove(_storageKey);
        _message = 'Saved manifest was invalid and has been cleared.';
      }
    }
    if (!mounted) return;
    setState(() {
      _manifest = loaded;
      _loading = false;
    });
  }

  Future<void> _saveBaseline() async {
    final manifest = MpqChecksumManifest.fromReport(widget.report);
    if (manifest.entries.isEmpty) {
      _notify('No successful MPQ hashes to save.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, manifest.encode());
    if (!mounted) return;
    setState(() {
      _manifest = manifest;
      _message = 'Baseline saved on this device.';
    });
  }

  Future<void> _exportManifest() async {
    final manifest = _manifest;
    if (manifest == null) return;
    try {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Export MPQ checksum manifest',
        fileName: 'azeroth-mpq-manifest.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(manifest.encode())),
      );
    } catch (error) {
      _notify('Export failed: $error');
    }
  }

  Future<void> _importManifest() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        throw const FormatException('Could not read selected JSON file.');
      }
      final manifest = MpqChecksumManifest.decode(utf8.decode(bytes));
      if (manifest.entries.isEmpty) {
        throw const FormatException('Manifest contains no valid hashes.');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, manifest.encode());
      if (!mounted) return;
      setState(() {
        _manifest = manifest;
        _message = 'Manifest imported and saved for this game folder.';
      });
    } catch (error) {
      _notify('Import failed: $error');
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFF9AA8BC);
    const gold = Color(0xFFE2B45D);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(),
      );
    }
    final comparison = _manifest?.compare(widget.report);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF101725),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF344158)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: gold, size: 17),
              SizedBox(width: 7),
              Text('CHECKSUM MANIFEST',
                  style: TextStyle(
                      color: gold, fontSize: 10, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _manifest == null
                ? 'No local baseline saved for this game folder.'
                : 'Baseline: ${_manifest!.entries.length} files · '
                    '${_manifest!.createdAt.toLocal()}',
            style: const TextStyle(color: muted, fontSize: 9),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton(
                onPressed: _saveBaseline,
                child: const Text('SAVE BASELINE'),
              ),
              OutlinedButton(
                onPressed: _importManifest,
                child: const Text('IMPORT JSON'),
              ),
              OutlinedButton(
                onPressed: _manifest == null ? null : _exportManifest,
                child: const Text('EXPORT JSON'),
              ),
            ],
          ),
          if (comparison != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 5,
              children: [
                _count('Unchanged', comparison.count(MpqManifestStatus.unchanged),
                    Colors.greenAccent),
                _count('Changed', comparison.count(MpqManifestStatus.changed),
                    Colors.orangeAccent),
                _count('Added', comparison.count(MpqManifestStatus.added),
                    Colors.lightBlueAccent),
                _count('Missing', comparison.count(MpqManifestStatus.missing),
                    Colors.redAccent),
              ],
            ),
            const SizedBox(height: 6),
            ...comparison.differences
                .where((item) => item.status != MpqManifestStatus.unchanged)
                .map((item) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${item.status.name.toUpperCase()}: ${item.path}',
                        style: const TextStyle(color: muted, fontSize: 9),
                      ),
                    )),
          ],
          if (_message != null) ...[
            const SizedBox(height: 6),
            Text(_message!,
                style: const TextStyle(color: gold, fontSize: 9)),
          ],
          const SizedBox(height: 7),
          const Text(
            'This is a user-created snapshot, not an official Blizzard checksum list. A baseline made from an already modified or damaged client cannot prove the client is original.',
            style: TextStyle(color: muted, fontSize: 9, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _count(String label, int count, Color color) => Text(
        '$label: $count',
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w700),
      );
}

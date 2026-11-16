// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mpq_checksum_scanner.dart';
import 'mpq_checksum_manifest.dart';

class _SavedMpqBaseline {
  const _SavedMpqBaseline({required this.name, required this.manifest});

  final String name;
  final MpqChecksumManifest manifest;

  Map<String, Object> toJson() => {
        'name': name,
        'manifest': manifest.toJson(),
      };

  factory _SavedMpqBaseline.fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['name'] is! String) {
      throw const FormatException('Invalid saved baseline entry.');
    }
    final name = (value['name'] as String).trim();
    if (name.isEmpty) throw const FormatException('Baseline name is empty.');
    return _SavedMpqBaseline(
      name: name,
      manifest: MpqChecksumManifest.decode(jsonEncode(value['manifest'])),
    );
  }
}

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
  List<_SavedMpqBaseline> _baselines = [];
  String? _selectedName;
  bool _loading = true;
  String? _message;

  String get _storageKey =>
      'mpq_manifest_library_${sha256.convert(utf8.encode(widget.folderPath))}';

  _SavedMpqBaseline? get _selected {
    for (final item in _baselines) {
      if (item.name == _selectedName) return item;
    }
    return null;
  }

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
      _baselines = [];
      _selectedName = null;
    });
    final prefs = await SharedPreferences.getInstance();
    final source = prefs.getString(_storageKey);
    final loaded = <_SavedMpqBaseline>[];
    if (source != null) {
      try {
        final decoded = jsonDecode(source);
        if (decoded is! List) {
          throw const FormatException('Baseline library must be a list.');
        }
        for (final item in decoded) {
          loaded.add(_SavedMpqBaseline.fromJson(item));
        }
      } catch (_) {
        await prefs.remove(_storageKey);
        _message = 'Saved baseline library was invalid and has been cleared.';
      }
    }
    if (!mounted) return;
    setState(() {
      _baselines = loaded;
      _selectedName = loaded.isEmpty ? null : loaded.first.name;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_baselines.map((item) => item.toJson()).toList()),
    );
  }

  Future<String?> _askName({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 48,
          decoration: const InputDecoration(
            labelText: 'Baseline name',
            hintText: 'Clean install, backup before update...',
          ),
          onSubmitted: (value) =>
              Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return null;
    return result.trim();
  }

  Future<void> _saveBaseline() async {
    final manifest = MpqChecksumManifest.fromReport(widget.report);
    if (manifest.entries.isEmpty) {
      _notify('No successful MPQ hashes to save.');
      return;
    }
    final name = await _askName(title: 'Save new baseline');
    if (name == null || !mounted) return;
    if (_baselines.any((item) => item.name.toLowerCase() == name.toLowerCase())) {
      _notify('A baseline with this name already exists. Choose another name.');
      return;
    }
    setState(() {
      _baselines = [
        ..._baselines,
        _SavedMpqBaseline(name: name, manifest: manifest),
      ];
      _selectedName = name;
      _message = 'Baseline "$name" saved on this device.';
    });
    await _persist();
  }

  Future<void> _exportManifest() async {
    final selected = _selected;
    if (selected == null) return;
    try {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Export MPQ checksum baseline',
        fileName: 'azeroth-mpq-${selected.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(selected.manifest.encode())),
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
      if (!mounted) return;
      final name = await _askName(title: 'Name imported baseline');
      if (name == null || !mounted) return;
      if (_baselines.any((item) => item.name.toLowerCase() == name.toLowerCase())) {
        _notify('A baseline with this name already exists. Choose another name.');
        return;
      }
      setState(() {
        _baselines = [
          ..._baselines,
          _SavedMpqBaseline(name: name, manifest: manifest),
        ];
        _selectedName = name;
        _message = 'Imported "$name" and saved it for this game folder.';
      });
      await _persist();
    } catch (error) {
      _notify('Import failed: $error');
    }
  }

  Future<void> _deleteSelected() async {
    final selected = _selected;
    if (selected == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete baseline?'),
        content: Text('Remove "${selected.name}" from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _baselines = _baselines.where((item) => item.name != selected.name).toList();
      _selectedName = _baselines.isEmpty ? null : _baselines.first.name;
      _message = 'Baseline deleted.';
    });
    await _persist();
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
    final selected = _selected;
    final comparison = selected?.manifest.compare(widget.report);
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
              Text('CHECKSUM BASELINE LIBRARY',
                  style: TextStyle(
                      color: gold, fontSize: 10, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${_baselines.length} saved baseline(s) for this game folder',
            style: const TextStyle(color: muted, fontSize: 9),
          ),
          if (_baselines.isNotEmpty) ...[
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              value: _selectedName,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select baseline',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: _baselines
                  .map((item) => DropdownMenuItem(
                        value: item.name,
                        child: Text(item.name,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedName = value),
            ),
            if (selected != null) ...[
              const SizedBox(height: 5),
              Text(
                '${selected.manifest.entries.length} files · ${selected.manifest.createdAt.toLocal()}',
                style: const TextStyle(color: muted, fontSize: 9),
              ),
            ],
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: Text('No saved baselines yet. Save one after scanning MPQ files.',
                  style: TextStyle(color: muted, fontSize: 10)),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton(
                onPressed: _saveBaseline,
                child: const Text('SAVE NEW'),
              ),
              OutlinedButton(
                onPressed: _importManifest,
                child: const Text('IMPORT JSON'),
              ),
              OutlinedButton(
                onPressed: selected == null ? null : _exportManifest,
                child: const Text('EXPORT'),
              ),
              OutlinedButton(
                onPressed: selected == null ? null : _deleteSelected,
                child: const Text('DELETE'),
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
            'These are user-created snapshots, not official Blizzard checksums. A baseline from an already modified or damaged client cannot prove that the client is original.',
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

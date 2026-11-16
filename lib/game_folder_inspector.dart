import 'dart:io';

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import 'wow_client_version.dart';
import 'mpq_checksum_scanner.dart';
import 'mpq_manifest_manager.dart';
import 'mpq_scan_history.dart';

const _inspectorGold = Color(0xFFE2B45D);
const _inspectorMuted = Color(0xFF9AA8BC);

bool _isLocaleFolder(String value) =>
    value.length == 4 &&
    value.substring(0, 2).toLowerCase() == value.substring(0, 2) &&
    value.substring(2).toUpperCase() == value.substring(2);

class GameFolderReport {
  const GameFolderReport({
    required this.folderExists,
    required this.executableFound,
    required this.dataFolderFound,
    required this.localeFolders,
    required this.realmlistFiles,
    required this.archiveCount,
    required this.executableInfo,
    required this.dataArchiveCount,
    required this.emptyArchiveFiles,
    required this.missingCoreArchives,
    required this.totalArchiveBytes,
    required this.notes,
  });

  final bool folderExists;
  final bool executableFound;
  final bool dataFolderFound;
  final List<String> localeFolders;
  final List<String> realmlistFiles;
  final int archiveCount;
  final WowExecutableInfo? executableInfo;
  final int dataArchiveCount;
  final List<String> emptyArchiveFiles;
  final List<String> missingCoreArchives;
  final int totalArchiveBytes;
  final List<String> notes;

  int get passedChecks =>
      (folderExists ? 1 : 0) +
      (executableFound ? 1 : 0) +
      (dataFolderFound ? 1 : 0) +
      (localeFolders.isNotEmpty ? 1 : 0);

  bool get looksLikeWowFolder =>
      folderExists && executableFound && dataFolderFound;

  static Future<GameFolderReport> inspect(String path) async {
    final root = Directory(path);
    if (!await root.exists()) {
      return const GameFolderReport(
        folderExists: false,
        executableFound: false,
        dataFolderFound: false,
        localeFolders: [],
        realmlistFiles: [],
        archiveCount: 0,
        executableInfo: null,
        dataArchiveCount: 0,
        emptyArchiveFiles: [],
        missingCoreArchives: ['common.MPQ', 'common-2.MPQ', 'expansion.MPQ', 'lichking.MPQ'],
        totalArchiveBytes: 0,
        notes: ['Selected folder is no longer accessible.'],
      );
    }

    final rootEntries = await root
        .list(followLinks: false)
        .toList();
    final rootNames = rootEntries
        .map((entity) => entity.path.split(Platform.pathSeparator).last.toLowerCase())
        .toSet();
    final executableName = rootNames.contains('wow.exe')
        ? 'Wow.exe'
        : rootNames.contains('wow-64.exe')
            ? 'Wow-64.exe'
            : null;
    final executableFound = executableName != null;
    final executableInfo = executableName == null
        ? null
        : await WowExecutableInfo.inspect(File('${root.path}/$executableName'));
    final data = Directory('${root.path}/Data');
    final dataFolderFound = await data.exists();

    final locales = <String>[];
    final realmlists = <String>[];
    var archives = 0;
    var totalArchiveBytes = 0;
    final emptyArchives = <String>[];
    final dataMpqNames = <String>{};
    const coreArchives = [
      'common.mpq',
      'common-2.mpq',
      'expansion.mpq',
      'lichking.mpq',
    ];

    if (dataFolderFound) {
      await for (final entity in data.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final relativePath = entity.path.substring(data.path.length)
            .replaceAll(Platform.pathSeparator, '/')
            .replaceFirst('/', '');
        final segments = relativePath.split('/');
        final name = segments.isEmpty ? relativePath : segments.last;
        if (name.toLowerCase() == 'realmlist.wtf' &&
            segments.length > 1 && _isLocaleFolder(segments.first)) {
          realmlists.add(relativePath);
        }
        if (name.toLowerCase().endsWith('.mpq')) {
          archives++;
          dataMpqNames.add(name.toLowerCase());
          final size = await entity.length();
          totalArchiveBytes += size;
          if (size == 0) emptyArchives.add(relativePath);
        }
      }
      await for (final entity in data.list(followLinks: false)) {
        if (entity is Directory) {
          final locale = entity.path.split(Platform.pathSeparator).last;
          if (_isLocaleFolder(locale)) locales.add(locale);
        }
      }
    }
    final missingCoreArchives =
        coreArchives.where((name) => !dataMpqNames.contains(name)).toList();
    locales.sort();
    realmlists.sort();
    final notes = <String>[];
    if (!executableFound) notes.add('Wow.exe was not found in the selected folder.');
    if (!dataFolderFound) notes.add('Data/ folder was not found.');
    if (dataFolderFound && locales.isEmpty) {
      notes.add('No standard locale folder (for example enUS or enGB) was found.');
    }
    if (realmlists.isEmpty) {
      notes.add('No existing realmlist.wtf was found in the detected locale folders.');
    }
    if (archives == 0) {
      notes.add('No MPQ archives were found in the detected locale folders.');
    }
    if (notes.isEmpty) notes.add('Basic folder structure looks present.');

    return GameFolderReport(
      folderExists: true,
      executableFound: executableFound,
      dataFolderFound: dataFolderFound,
      localeFolders: locales,
      realmlistFiles: realmlists,
      archiveCount: archives,
      executableInfo: executableInfo,
      dataArchiveCount: archives,
      emptyArchiveFiles: emptyArchives..sort(),
      missingCoreArchives: missingCoreArchives,
      totalArchiveBytes: totalArchiveBytes,
      notes: notes,
    );
  }
}

class GameFolderInspector extends StatefulWidget {
  const GameFolderInspector({
    super.key,
    required this.folderPath,
  });

  final String folderPath;

  @override
  State<GameFolderInspector> createState() => _GameFolderInspectorState();
}

class _GameFolderInspectorState extends State<GameFolderInspector> {
  late Future<GameFolderReport> _report;
  Future<MpqFingerprintReport>? _checksumFuture;
  MpqScanProgress? _scanProgress;
  MpqScanCancellation? _scanCancellation;
  bool _isChecksumScanning = false;

  void _startChecksumScan() {
    final cancellation = MpqScanCancellation();
    setState(() {
      _scanProgress = null;
      _scanCancellation = cancellation;
      _isChecksumScanning = true;
      _checksumFuture = MpqChecksumScanner.scan(
        '${widget.folderPath}/Data',
        cancellation: cancellation,
        onProgress: (progress) {
          if (mounted && identical(_scanCancellation, cancellation)) {
            setState(() => _scanProgress = progress);
          }
        },
      );
    });
    _checksumFuture!.then<void>(
      (_) {
        if (mounted && identical(_scanCancellation, cancellation)) {
          setState(() => _isChecksumScanning = false);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (mounted && identical(_scanCancellation, cancellation)) {
          setState(() => _isChecksumScanning = false);
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _report = GameFolderReport.inspect(widget.folderPath);
  }

  @override
  void didUpdateWidget(covariant GameFolderInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderPath != widget.folderPath) {
      _scanCancellation?.cancel();
      _report = GameFolderReport.inspect(widget.folderPath);
      _checksumFuture = null;
      _scanProgress = null;
      _scanCancellation = null;
      _isChecksumScanning = false;
    }
  }

  void _refresh() {
    _scanCancellation?.cancel();
    setState(() {
      _report = GameFolderReport.inspect(widget.folderPath);
      _checksumFuture = null;
      _scanProgress = null;
      _scanCancellation = null;
      _isChecksumScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF141C2B),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF263448)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: _inspectorGold),
              const SizedBox(width: 9),
              const Expanded(
                child: Text('GAME FOLDER INSPECTOR',
                    style: TextStyle(
                        color: _inspectorGold,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
              ),
              IconButton(
                tooltip: 'Scan folder again',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, color: _inspectorMuted),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            widget.folderPath,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _inspectorMuted, fontSize: 10),
          ),
          const SizedBox(height: 12),
          FutureBuilder<GameFolderReport>(
            future: _report,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Text('Could not inspect this folder. Check access permissions.',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 12));
              }
              final report = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _checkRow('Selected folder exists', report.folderExists),
                  _checkRow('Wow.exe / Wow-64.exe', report.executableFound),
                  if (report.executableInfo != null) ...[
                    _checkRow(
                      'Windows executable format',
                      report.executableInfo!.isPortableExecutable,
                      detail: report.executableInfo!.architecture,
                    ),
                    _checkRow(
                      'WotLK 3.3.5a build marker',
                      report.executableInfo!.possible335a,
                      detail: report.executableInfo!.versionMarker ??
                          'Not identified',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 24, top: 2),
                      child: Text(
                        '${report.executableInfo!.optionalHeader} · ${report.executableInfo!.buildAssessment}',
                        style: const TextStyle(
                            color: _inspectorMuted, fontSize: 9, height: 1.3),
                      ),
                    ),
                  ],
                  _checkRow('Data folder', report.dataFolderFound),
                  _checkRow('Locale folders', report.localeFolders.isNotEmpty,
                      detail: report.localeFolders.isEmpty
                          ? 'None detected'
                          : report.localeFolders.join(', ')),
                  _checkRow('Realmlist files', report.realmlistFiles.isNotEmpty,
                      detail: report.realmlistFiles.isEmpty
                          ? 'Not found'
                          : report.realmlistFiles.join(', ')),
                  _checkRow('MPQ archives', report.archiveCount > 0,
                      detail: '${report.archiveCount} found'),
                  const SizedBox(height: 12),
                  const Text(
                    'GAME DATA INTEGRITY',
                    style: TextStyle(
                        color: _inspectorGold,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 5),
                  _checkRow(
                    'MPQ files scanned',
                    report.dataArchiveCount > 0,
                    detail: '${report.dataArchiveCount} files',
                  ),
                  _checkRow(
                    'No empty MPQ archives',
                    report.emptyArchiveFiles.isEmpty,
                    detail: report.emptyArchiveFiles.isEmpty
                        ? 'No zero-byte files'
                        : '${report.emptyArchiveFiles.length} empty',
                  ),
                  _checkRow(
                    'Core archive names',
                    report.missingCoreArchives.isEmpty,
                    detail: report.missingCoreArchives.isEmpty
                        ? 'All detected'
                        : '${report.missingCoreArchives.length} not found',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 2),
                    child: Text(
                      'MPQ total size: ${_formatBytes(report.totalArchiveBytes)}',
                      style: const TextStyle(
                          color: _inspectorMuted, fontSize: 9),
                    ),
                  ),
                  if (report.emptyArchiveFiles.isNotEmpty ||
                      report.missingCoreArchives.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    ...report.emptyArchiveFiles.map((file) => Text(
                          'Empty: $file',
                          style: const TextStyle(
                              color: Colors.orangeAccent, fontSize: 9),
                        )),
                    if (report.missingCoreArchives.isNotEmpty)
                      Text(
                        'Not detected by name: ${report.missingCoreArchives.join(', ')}',
                        style: const TextStyle(
                            color: _inspectorMuted, fontSize: 9),
                      ),
                  ],
                  const SizedBox(height: 5),
                  const Text(
                    'This checks file presence and size only. It does not validate MPQ contents or checksums; core archive names can vary by client distribution.',
                    style: TextStyle(
                        color: _inspectorMuted, fontSize: 9, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _isChecksumScanning ? null : _startChecksumScan,
                      icon: const Icon(Icons.fingerprint, size: 16),
                      label: const Text('CALCULATE SHA-256 FINGERPRINTS'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _inspectorGold,
                        side: const BorderSide(color: Color(0xFF66522E)),
                        textStyle: const TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  if (_checksumFuture != null)
                    FutureBuilder<MpqFingerprintReport>(
                      future: _checksumFuture,
                      builder: (context, checksumSnapshot) {
                        if (checksumSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          final progress = _scanProgress;
                          final fraction = progress?.fraction;
                          final percent =
                              fraction == null ? 0 : (fraction * 100).round();
                          final cancellationRequested =
                              _scanCancellation?.isCancelled ?? false;
                          return Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        progress == null
                                            ? 'Finding MPQ archives...'
                                            : 'Hashing $percent% · ${progress.completedFiles}/${progress.totalFiles} files',
                                        style: const TextStyle(
                                            color: _inspectorMuted,
                                            fontSize: 10),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: cancellationRequested
                                          ? null
                                          : () => _scanCancellation?.cancel(),
                                      icon: const Icon(Icons.stop, size: 14),
                                      label: Text(cancellationRequested
                                          ? 'STOPPING'
                                          : 'CANCEL'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.orangeAccent,
                                        textStyle: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: fraction,
                                  minHeight: 5,
                                  backgroundColor: const Color(0xFF263448),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          _inspectorGold),
                                ),
                                if (progress?.currentFile != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(
                                      progress!.currentFile!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: _inspectorMuted,
                                          fontSize: 9),
                                    ),
                                  ),
                                const Text(
                                  'Cancel takes effect after the current archive finishes hashing.',
                                  style: TextStyle(
                                      color: _inspectorMuted,
                                      fontSize: 9),
                                ),
                              ],
                            ),
                          );
                        }
                        if (checksumSnapshot.hasError ||
                            !checksumSnapshot.hasData) {
                          return const Text(
                            'Could not calculate fingerprints. Check file access.',
                            style: TextStyle(
                                color: Colors.orangeAccent, fontSize: 10),
                          );
                        }
                        final fingerprints = checksumSnapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 7),
                            Text(
                              '${fingerprints.successCount} hashed · ${fingerprints.errorCount} errors',
                              style: const TextStyle(
                                  color: _inspectorGold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${fingerprints.cancelled ? "Cancelled" : "Completed"} · ${fingerprints.completedFileCount}/${fingerprints.discoveredFileCount} files · ${_formatBytes(fingerprints.totalBytes)} · ${(fingerprints.duration.inMilliseconds / 1000).toStringAsFixed(1)} sec',
                                style: const TextStyle(
                                    color: _inspectorMuted, fontSize: 9),
                              ),
                            ),
                            ...fingerprints.files.map((fingerprint) =>
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fingerprint.relativePath,
                                        style: const TextStyle(
                                            color: _inspectorMuted,
                                            fontSize: 9),
                                      ),
                                      SelectableText(
                                        fingerprint.sha256 ??
                                            'Error: ${fingerprint.error}',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 9,
                                            fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                )),
                            const SizedBox(height: 5),
                            const Text(
                              'These are fingerprints of the current files. They only confirm integrity when compared with a trusted checksum from the same client release.',
                              style: TextStyle(
                                  color: _inspectorMuted,
                                  fontSize: 9,
                                  height: 1.35),
                            ),
                            MpqManifestManager(
                              folderPath: widget.folderPath,
                              report: fingerprints,
                            ),
                            MpqScanHistory(
                              folderPath: widget.folderPath,
                              report: fingerprints,
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 9),
                  ...report.notes.map((note) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• $note',
                            style: const TextStyle(
                                color: _inspectorMuted, fontSize: 10)),
                      )),
                  if (report.looksLikeWowFolder) ...[
                    const SizedBox(height: 9),
                    const Text(
                      'Basic structure detected. Version markers are heuristic only; this scan does not verify file integrity or runtime compatibility.',
                      style: TextStyle(
                          color: _inspectorGold, fontSize: 10, height: 1.4),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  Widget _checkRow(String label, bool passed, {String? detail}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(passed ? Icons.check_circle : Icons.warning_amber_rounded,
                color: passed ? Colors.greenAccent : Colors.orangeAccent,
                size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            if (detail != null)
              Flexible(
                child: Text(detail,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        color: _inspectorMuted, fontSize: 9)),
              ),
          ],
        ),
      );
}

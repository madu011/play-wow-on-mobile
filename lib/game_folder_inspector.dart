import 'dart:io';

import 'package:flutter/material.dart';

import 'wow_client_version.dart';

const _inspectorGold = Color(0xFFE2B45D);
const _inspectorMuted = Color(0xFF9AA8BC);

class GameFolderReport {
  const GameFolderReport({
    required this.folderExists,
    required this.executableFound,
    required this.dataFolderFound,
    required this.localeFolders,
    required this.realmlistFiles,
    required this.archiveCount,
    required this.executableInfo,
    required this.notes,
  });

  final bool folderExists;
  final bool executableFound;
  final bool dataFolderFound;
  final List<String> localeFolders;
  final List<String> realmlistFiles;
  final int archiveCount;
  final WowExecutableInfo? executableInfo;
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

    if (dataFolderFound) {
      await for (final entity in data.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final locale = entity.path.split(Platform.pathSeparator).last;
        if (!RegExp(r'^[a-zA-Z]{2}[A-Z]{2}$').hasMatch(locale)) continue;
        locales.add(locale);
        final localeFiles = await entity.list(followLinks: false).toList();
        for (final file in localeFiles) {
          final name = file.path.split(Platform.pathSeparator).last;
          if (name.toLowerCase() == 'realmlist.wtf') {
            realmlists.add('${locale}/realmlist.wtf');
          }
          if (name.toLowerCase().endsWith('.mpq')) archives++;
        }
      }
    }

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

  @override
  void initState() {
    super.initState();
    _report = GameFolderReport.inspect(widget.folderPath);
  }

  @override
  void didUpdateWidget(covariant GameFolderInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderPath != widget.folderPath) {
      _report = GameFolderReport.inspect(widget.folderPath);
    }
  }

  void _refresh() {
    setState(() => _report = GameFolderReport.inspect(widget.folderPath));
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

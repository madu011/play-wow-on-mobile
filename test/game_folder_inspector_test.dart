import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/game_folder_inspector.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('azeroth-folder-test-');
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('detects the basic WoW folder structure', () async {
    await File('${temporaryDirectory.path}/Wow.exe').writeAsString('test');
    final locale = Directory('${temporaryDirectory.path}/Data/enUS');
    await locale.create(recursive: true);
    await File('${locale.path}/realmlist.wtf').writeAsString(
      'SET realmlist example.invalid',
    );
    await File('${locale.path}/locale-enUS.MPQ').writeAsString('test');
    await File('${locale.path}/patch-enUS.MPQ').writeAsString('test');

    final report = await GameFolderReport.inspect(temporaryDirectory.path);

    expect(report.looksLikeWowFolder, isTrue);
    expect(report.executableFound, isTrue);
    expect(report.dataFolderFound, isTrue);
    expect(report.localeFolders, contains('enUS'));
    expect(report.realmlistFiles, contains('enUS/realmlist.wtf'));
    expect(report.archiveCount, 2);
  });

  test('reports missing game files and folders', () async {
    final report = await GameFolderReport.inspect(temporaryDirectory.path);

    expect(report.folderExists, isTrue);
    expect(report.executableFound, isFalse);
    expect(report.dataFolderFound, isFalse);
    expect(report.looksLikeWowFolder, isFalse);
    expect(report.notes, isNotEmpty);
  });

  test('reports a folder path that no longer exists', () async {
    final missingPath = '${temporaryDirectory.path}/deleted-folder';
    final report = await GameFolderReport.inspect(missingPath);

    expect(report.folderExists, isFalse);
    expect(report.notes, contains('Selected folder is no longer accessible.'));
  });
}

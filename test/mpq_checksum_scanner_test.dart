import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/mpq_checksum_scanner.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('azeroth-mpq-hash-');
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('calculates a known SHA-256 fingerprint', () async {
    final data = Directory('${temporaryDirectory.path}/Data');
    await data.create();
    await File('${data.path}/sample.MPQ').writeAsString('abc');

    final report = await MpqChecksumScanner.scan(data.path);

    expect(report.files, hasLength(1));
    expect(report.successCount, 1);
    expect(report.errorCount, 0);
    expect(
      report.files.single.sha256,
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(report.files.single.sizeBytes, 3);
  });

  test('scans nested archives and ignores non-MPQ files', () async {
    final data = Directory('${temporaryDirectory.path}/Data');
    final locale = Directory('${data.path}/enUS');
    await locale.create(recursive: true);
    await File('${locale.path}/locale-enUS.MPQ').writeAsString('archive');
    await File('${data.path}/readme.txt').writeAsString('not an archive');

    final report = await MpqChecksumScanner.scan(data.path);

    expect(report.files, hasLength(1));
    expect(report.files.single.relativePath, 'enUS/locale-enUS.MPQ');
    expect(report.successCount, 1);
  });

  test('throws a clear file system error when Data folder is missing',
      () async {
    await expectLater(
      MpqChecksumScanner.scan('${temporaryDirectory.path}/missing'),
      throwsA(isA<FileSystemException>()),
    );
  });
}

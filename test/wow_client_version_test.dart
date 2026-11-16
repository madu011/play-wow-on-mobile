import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/wow_client_version.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('azeroth-pe-test-');
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('reads PE32 x86 metadata and detects the 3.3.5.12340 marker', () async {
    final bytes = Uint8List(512);
    final data = ByteData.sublistView(bytes);
    bytes[0] = 0x4D;
    bytes[1] = 0x5A;
    data.setUint32(0x3C, 128, Endian.little);
    bytes[128] = 0x50;
    bytes[129] = 0x45;
    data.setUint16(132, 0x014C, Endian.little);
    data.setUint16(152, 0x010B, Endian.little);
    final marker = '3.3.5.12340'.codeUnits;
    bytes.setRange(256, 256 + marker.length, marker);

    final file = File('${temporaryDirectory.path}/Wow.exe');
    await file.writeAsBytes(bytes);

    final info = await WowExecutableInfo.inspect(file);

    expect(info.isPortableExecutable, isTrue);
    expect(info.architecture, 'x86 (32-bit)');
    expect(info.optionalHeader, 'PE32');
    expect(info.versionMarker, '3.3.5.12340');
    expect(info.possible335a, isTrue);
  });

  test('recognizes an invalid executable without throwing', () async {
    final file = File('${temporaryDirectory.path}/not-wow.exe');
    await file.writeAsString('not a PE file');

    final info = await WowExecutableInfo.inspect(file);

    expect(info.isPortableExecutable, isFalse);
    expect(info.architecture, 'Unknown');
    expect(info.possible335a, isFalse);
  });

  test('does not claim a build when no known marker exists', () async {
    final bytes = Uint8List(512);
    final data = ByteData.sublistView(bytes);
    bytes[0] = 0x4D;
    bytes[1] = 0x5A;
    data.setUint32(0x3C, 128, Endian.little);
    bytes[128] = 0x50;
    bytes[129] = 0x45;
    data.setUint16(132, 0x014C, Endian.little);
    data.setUint16(152, 0x010B, Endian.little);

    final file = File('${temporaryDirectory.path}/Wow.exe');
    await file.writeAsBytes(bytes);

    final info = await WowExecutableInfo.inspect(file);

    expect(info.isPortableExecutable, isTrue);
    expect(info.versionMarker, isNull);
    expect(info.buildAssessment, contains('not identified'));
  });
}

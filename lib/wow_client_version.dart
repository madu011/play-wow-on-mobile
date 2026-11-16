import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class WowExecutableInfo {
  const WowExecutableInfo({
    required this.isPortableExecutable,
    required this.machine,
    required this.architecture,
    required this.optionalHeader,
    required this.versionMarker,
    required this.buildAssessment,
    required this.fileSize,
  });

  final bool isPortableExecutable;
  final int? machine;
  final String architecture;
  final String optionalHeader;
  final String? versionMarker;
  final String buildAssessment;
  final int fileSize;

  bool get possible335a => versionMarker == '3.3.5.12340';

  static Future<WowExecutableInfo> inspect(File file) async {
    if (!await file.exists()) {
      throw const FileSystemException('Executable file not found.');
    }

    final handle = await file.open();
    try {
      final length = await handle.length();
      final header = await handle.read(4096);
      if (header.length < 64 || header[0] != 0x4D || header[1] != 0x5A) {
        return WowExecutableInfo(
          isPortableExecutable: false,
          machine: null,
          architecture: 'Unknown',
          optionalHeader: 'Unknown',
          versionMarker: null,
          buildAssessment: 'Not a valid Windows PE executable',
          fileSize: length,
        );
      }

      final headerData = ByteData.sublistView(Uint8List.fromList(header));
      final peOffset = headerData.getUint32(0x3C, Endian.little);
      if (peOffset + 26 > header.length ||
          header[peOffset] != 0x50 ||
          header[peOffset + 1] != 0x45 ||
          header[peOffset + 2] != 0 ||
          header[peOffset + 3] != 0) {
        return WowExecutableInfo(
          isPortableExecutable: false,
          machine: null,
          architecture: 'Unknown',
          optionalHeader: 'Unknown',
          versionMarker: null,
          buildAssessment: 'PE header not found or incomplete',
          fileSize: length,
        );
      }

      final machine = headerData.getUint16(peOffset + 4, Endian.little);
      final optionalMagic =
          headerData.getUint16(peOffset + 24, Endian.little);
      final architecture = switch (machine) {
        0x014C => 'x86 (32-bit)',
        0x8664 => 'x64 (64-bit)',
        0x01C0 || 0x01C4 => 'ARM',
        _ => 'Unknown (0x${machine.toRadixString(16)})',
      };
      final optionalHeader = switch (optionalMagic) {
        0x010B => 'PE32',
        0x020B => 'PE32+',
        _ => 'Unknown',
      };

      final marker = await _findVersionMarker(handle, length);
      final assessment = marker == '3.3.5.12340'
          ? 'Possible WotLK 3.3.5a build 12340 marker found'
          : marker == null
              ? 'Build not identified from scanned version strings'
              : 'Version marker found: $marker';

      return WowExecutableInfo(
        isPortableExecutable: true,
        machine: machine,
        architecture: architecture,
        optionalHeader: optionalHeader,
        versionMarker: marker,
        buildAssessment: assessment,
        fileSize: length,
      );
    } finally {
      await handle.close();
    }
  }

  static Future<String?> _findVersionMarker(
    RandomAccessFile handle,
    int length,
  ) async {
    const markers = ['3.3.5.12340', '3.3.5a', '3,3,5,12340'];
    final ascii = markers.map((value) => utf8.encode(value)).toList();
    final wide = markers
        .map((value) => value.codeUnits.expand((unit) => [unit, 0]).toList())
        .toList();
    const chunkSize = 64 * 1024;
    const overlap = 128;
    var position = 0;
    var carry = <int>[];

    while (position < length) {
      await handle.setPosition(position);
      final chunk = await handle.read(
        (length - position) > chunkSize ? chunkSize : length - position,
      );
      if (chunk.isEmpty) break;
      final bytes = [...carry, ...chunk];

      for (var i = 0; i < markers.length; i++) {
        if (_contains(bytes, ascii[i]) || _contains(bytes, wide[i])) {
          return markers[i] == '3,3,5,12340' ? '3.3.5.12340' : markers[i];
        }
      }

      carry = bytes.length > overlap
          ? bytes.sublist(bytes.length - overlap)
          : bytes;
      position += chunk.length;
    }
    return null;
  }

  static bool _contains(List<int> source, List<int> pattern) {
    if (pattern.isEmpty || source.length < pattern.length) return false;
    for (var i = 0; i <= source.length - pattern.length; i++) {
      var matched = true;
      for (var j = 0; j < pattern.length; j++) {
        if (source[i + j] != pattern[j]) {
          matched = false;
          break;
        }
      }
      if (matched) return true;
    }
    return false;
  }
}

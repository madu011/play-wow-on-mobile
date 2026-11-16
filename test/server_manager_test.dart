import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/server_manager.dart';

void main() {
  group('ServerProfile.parse', () {
    test('parses a standard SET realmlist command', () {
      final profile = ServerProfile.parse('SET realmlist "logon.example.com"');
      expect(profile, isNotNull);
      expect(profile!.host, 'logon.example.com');
      expect(profile.port, 3724);
      expect(profile.realmlistLine, 'SET realmlist "logon.example.com"');
    });

    test('parses a command with an explicit port', () {
      final profile = ServerProfile.parse('set realmlist realm.example.com:8085');
      expect(profile, isNotNull);
      expect(profile!.host, 'realm.example.com');
      expect(profile.port, 8085);
      expect(profile.realmlistLine, 'SET realmlist "realm.example.com:8085"');
    });

    test('parses a URL and uses its explicit port', () {
      final profile = ServerProfile.parse('https://realm.example.com:4444/path');
      expect(profile, isNotNull);
      expect(profile!.host, 'realm.example.com');
      expect(profile.port, 4444);
    });

    test('uses the optional display name', () {
      final profile = ServerProfile.parse(
        'set realmlist logon.example.com',
        displayName: 'My Realm',
      );
      expect(profile!.name, 'My Realm');
    });

    test('rejects empty input and invalid ports', () {
      expect(ServerProfile.parse(''), isNull);
      expect(ServerProfile.parse('realm.example.com:70000'), isNull);
    });
  });


  group('RealmDiagnosticReport', () {
    test('shows successful DNS and TCP timings', () {
      const report = RealmDiagnosticReport(
        dnsSucceeded: true,
        addresses: ['192.0.2.10'],
        dnsMilliseconds: 12,
        tcpSucceeded: true,
        tcpMilliseconds: 35,
      );

      expect(report.displayLines.first, contains('DNS: Resolved'));
      expect(report.displayLines[1], 'Address: 192.0.2.10');
      expect(report.displayLines[2], contains('Connected'));
      expect(report.displayLines.last, contains('does not confirm WoW login'));
    });

    test('shows DNS failure details without a TCP timing', () {
      const report = RealmDiagnosticReport(
        dnsSucceeded: false,
        addresses: [],
        dnsMilliseconds: 5000,
        tcpSucceeded: false,
        tcpMilliseconds: null,
        error: 'Connection timed out.',
      );

      expect(report.displayLines.first, contains('DNS: Failed'));
      expect(report.displayLines.last, 'Details: Connection timed out.');
    });
  });

  group('ServerProfile backup', () {
    test('encodes and decodes saved profiles', () {
      const profiles = [
        ServerProfile(name: 'My Realm', host: 'realm.example.com', port: 3724),
        ServerProfile(name: 'Test Realm', host: 'test.example.com', port: 8085),
      ];
      final backup = ServerProfile.encodeProfiles(profiles);
      final restored = ServerProfile.decodeProfiles(backup);

      expect(restored, hasLength(2));
      expect(restored.first.name, 'My Realm');
      expect(restored.last.port, 8085);
    });

    test('ignores duplicate host and port entries in a backup', () {
      final backup = '''
      {
        "format": "azeroth-mobile-realms",
        "version": 1,
        "profiles": [
          {"name":"One","host":"realm.example.com","port":3724},
          {"name":"Duplicate","host":"realm.example.com","port":3724}
        ]
      }
      ''';

      final restored = ServerProfile.decodeProfiles(backup);
      expect(restored, hasLength(1));
      expect(restored.single.name, 'One');
    });

    test('rejects unsupported backup formats and invalid ports', () {
      expect(
        () => ServerProfile.decodeProfiles('{"format":"other","version":1,"profiles":[]}'),
        throwsFormatException,
      );
      expect(
        () => ServerProfile.decodeProfiles('''
          {"format":"azeroth-mobile-realms","version":1,
           "profiles":[{"name":"Bad","host":"realm.example.com","port":70000}]}
        '''),
        throwsFormatException,
      );
    });
  });
}
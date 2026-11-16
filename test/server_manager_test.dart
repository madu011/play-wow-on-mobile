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
}
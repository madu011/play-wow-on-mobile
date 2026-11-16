import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _serverGold = Color(0xFFE2B45D);
const _serverPanel = Color(0xFF141C2B);
const _serverMuted = Color(0xFF9AA8BC);

class ServerProfile {
  const ServerProfile({
    required this.name,
    required this.host,
    required this.port,
  });

  final String name;
  final String host;
  final int port;

  String get key => '$host:$port';

  String get realmlistLine =>
      port == 3724 ? 'SET realmlist "$host"' : 'SET realmlist "$host:$port"';

  Map<String, dynamic> toJson() => {
        'name': name,
        'host': host,
        'port': port,
      };

  factory ServerProfile.fromJson(Map<String, dynamic> json) => ServerProfile(
        name: json['name'] as String,
        host: json['host'] as String,
        port: json['port'] as int? ?? 3724,
      );

  static ServerProfile? parse(String input, {String? displayName}) {
    var value = input.trim();
    if (value.isEmpty) return null;

    value = value.replaceFirst(
      RegExp(r'^set\s+realmlist\s+', caseSensitive: false),
      '',
    ).trim();
    value = value.replaceAll(RegExp(r'''^['"]|['"]$'''), '').trim();

    String host;
    var port = 3724;

    final uriCandidate = value.contains('://') ? value : 'tcp://$value';
    final uri = Uri.tryParse(uriCandidate);
    if (uri != null && uri.host.isNotEmpty) {
      host = uri.host;
      if (uri.hasPort) port = uri.port;
    } else {
      host = value.split(RegExp(r'[/\s]')).first;
      final match = RegExp(r'^(.+):(\d+)$').firstMatch(host);
      if (match != null) {
        host = match.group(1)!;
        port = int.tryParse(match.group(2)!) ?? 3724;
      }
    }

    host = host.trim().replaceAll(RegExp(r'\.$'), '');
    if (host.isEmpty || port < 1 || port > 65535) return null;
    if (!RegExp(r'^[a-zA-Z0-9.\-:]+$').hasMatch(host)) return null;

    return ServerProfile(
      name: (displayName?.trim().isNotEmpty ?? false)
          ? displayName!.trim()
          : host,
      host: host,
      port: port,
    );
  }
}

class ServerManagerCard extends StatefulWidget {
  const ServerManagerCard({
    super.key,
    required this.onServerSelected,
  });

  final ValueChanged<ServerProfile> onServerSelected;

  @override
  State<ServerManagerCard> createState() => _ServerManagerCardState();
}

class _ServerManagerCardState extends State<ServerManagerCard> {
  static const _profilesKey = 'azeroth_server_profiles_v1';
  static const _selectedKey = 'azeroth_selected_server_v1';

  final _nameController = TextEditingController();
  final _realmlistController = TextEditingController();
  List<ServerProfile> _profiles = [];
  String? _selectedProfileKey;
  bool _loading = true;
  String? _inputError;
  final Set<String> _testingKeys = {};
  final Map<String, String> _connectionResults = {};

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _realmlistController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    final selected = prefs.getString(_selectedKey);
    final List<ServerProfile> loaded = [];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded) {
          loaded.add(ServerProfile.fromJson(
              Map<String, dynamic>.from(item as Map)));
        }
      } catch (_) {
        // Ignore an invalid old profile record instead of blocking the launcher.
      }
    }
    if (!mounted) return;
    setState(() {
      _profiles = loaded;
      _selectedProfileKey = selected;
      _loading = false;
    });
    ServerProfile? match;
    for (final profile in loaded) {
      if (profile.key == selected || profile.host == selected) {
        match = profile;
        break;
      }
    }
    if (match != null) {
      if (selected != match.key) {
        await prefs.setString(_selectedKey, match.key);
      }
      widget.onServerSelected(match);
    }
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profilesKey,
      jsonEncode(_profiles.map((profile) => profile.toJson()).toList()),
    );
  }

  Future<void> _addProfile() async {
    final profile = ServerProfile.parse(
      _realmlistController.text,
      displayName: _nameController.text,
    );
    if (profile == null) {
      setState(() => _inputError =
          'Paste a realmlist line or server hostname, for example: set realmlist logon.example.com');
      return;
    }
    if (_profiles.any((p) => p.host == profile.host && p.port == profile.port)) {
      setState(() => _inputError = 'This server is already saved.');
      return;
    }
    setState(() {
      _profiles = [..._profiles, profile];
      _inputError = null;
      _nameController.clear();
      _realmlistController.clear();
    });
    await _saveProfiles();
    await _selectProfile(profile);
  }

  Future<void> _selectProfile(ServerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, profile.key);
    if (!mounted) return;
    setState(() => _selectedProfileKey = profile.key);
    widget.onServerSelected(profile);
  }

  Future<void> _testConnection(ServerProfile profile) async {
    setState(() {
      _testingKeys.add(profile.key);
      _connectionResults.remove(profile.key);
    });
    Socket? socket;
    try {
      socket = await Socket.connect(
        profile.host,
        profile.port,
        timeout: const Duration(seconds: 5),
      );
      if (!mounted) return;
      setState(() => _connectionResults[profile.key] = 'TCP connection successful');
    } catch (_) {
      if (!mounted) return;
      setState(() => _connectionResults[profile.key] = 'Could not reach this address and port');
    } finally {
      socket?.destroy();
      if (mounted) setState(() => _testingKeys.remove(profile.key));
    }
  }
  Future<void> _deleteProfile(ServerProfile profile) async {
    setState(() {
      _profiles = _profiles
          .where((p) => !(p.host == profile.host && p.port == profile.port))
          .toList();
      if (_selectedProfileKey == profile.key) _selectedProfileKey = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await _saveProfiles();
    if (_selectedProfileKey == null) await prefs.remove(_selectedKey);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _serverPanel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF263448)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.public, color: _serverGold),
              SizedBox(width: 9),
              Expanded(
                child: Text('SAVED REALMS',
                    style: TextStyle(
                        color: _serverGold,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1)),
              ),
              Text('AUTO SETUP',
                  style: TextStyle(
                      color: _serverMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Server name (optional)',
              hintText: 'Warmane, another WotLK server...',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _realmlistController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Paste realmlist line or hostname',
              hintText: 'set realmlist logon.example.com',
              prefixIcon: Icon(Icons.link, color: _serverGold),
              isDense: true,
            ),
            onChanged: (_) {
              if (_inputError != null) setState(() => _inputError = null);
            },
          ),
          if (_inputError != null) ...[
            const SizedBox(height: 7),
            Text(_inputError!,
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _addProfile,
              icon: const Icon(Icons.add),
              label: const Text('ADD SERVER'),
              style: FilledButton.styleFrom(
                backgroundColor: _serverGold,
                foregroundColor: const Color(0xFF17120A),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF293448)),
          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator()))
          else if (_profiles.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No saved servers yet. Add a realmlist above.',
                  style: TextStyle(color: _serverMuted, fontSize: 12)),
            )
          else
            ..._profiles.map((profile) {
              final selected = _selectedProfileKey == profile.key;
              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? _serverGold.withValues(alpha: .10)
                      : const Color(0xFF0D1420),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected
                          ? _serverGold.withValues(alpha: .65)
                          : const Color(0xFF293448)),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    selected ? Icons.check_circle : Icons.dns,
                    color: selected ? _serverGold : _serverMuted,
                  ),
                  title: Text(profile.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(profile.realmlistLine,
                          style: const TextStyle(color: _serverMuted, fontSize: 10)),
                      if (_connectionResults.containsKey(profile.key))
                        Text(
                          _connectionResults[profile.key]!,
                          style: TextStyle(
                            color: _connectionResults[profile.key] == 'TCP connection successful'
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                  onTap: () => _selectProfile(profile),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Test server connection',
                        onPressed: _testingKeys.contains(profile.key)
                            ? null
                            : () => _testConnection(profile),
                        icon: _testingKeys.contains(profile.key)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering,
                                color: _serverGold, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Remove server',
                        icon: const Icon(Icons.delete_outline,
                            color: _serverMuted, size: 20),
                        onPressed: () => _deleteProfile(profile),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 4),
          const Text(
            'The realmlist hostname is detected automatically. If the line does not include a port, the standard WoW authentication port (3724) is assumed. Some servers may require additional settings.',
            style: TextStyle(color: _serverMuted, fontSize: 10, height: 1.4),
          ),
        ],
      ),
    );
  }
}

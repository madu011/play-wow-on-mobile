// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'server_manager.dart';
import 'game_folder_inspector.dart';

void main() => runApp(const AzerothApp());

const bg = Color(0xFF090D16);
const panel = Color(0xFF141C2B);
const gold = Color(0xFFE2B45D);
const muted = Color(0xFF9AA8BC);

class AzerothApp extends StatelessWidget {
  const AzerothApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WOW LK',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: gold,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: const LauncherPage(),
      );
}

class LauncherPage extends StatefulWidget {
  const LauncherPage({super.key});

  @override
  State<LauncherPage> createState() => _LauncherPageState();
}

class _LauncherPageState extends State<LauncherPage> {
  String? gameFolder;
  ServerProfile? selectedServer;
  bool lowGraphics = true;
  bool showTouchControls = true;
  String? gameTreeUri;
  int selectedNavTab = 0;
  final GlobalKey _gameSectionKey = GlobalKey();
  final GlobalKey _serverSectionKey = GlobalKey();
  final GlobalKey _toolsSectionKey = GlobalKey();
  static const _storageChannel = MethodChannel('wow.lk/storage');

  @override
  void initState() {
    super.initState();
    _loadSavedGameAccess();
  }

  Future<void> _loadSavedGameAccess() async {
    try {
      final uri = await _storageChannel.invokeMethod<String>('getSavedGameTreeUri');
      if (mounted && uri != null) setState(() => gameTreeUri = uri);
    } catch (_) {}
  }

  Future<void> _requestGameFolderAccess() async {
    try {
      final uri = await _storageChannel.invokeMethod<String>('pickGameFolderTree');
      if (!mounted || uri == null) return;
      setState(() => gameTreeUri = uri);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game folder write access granted.')),
      );
      final profile = selectedServer;
      if (profile != null) await applyRealmToGameFolder(profile);
    } on PlatformException catch (error) {
      if (mounted) showInfo('Folder access not granted', error.message ?? 'Please select the WoW game folder.');
    }
  }

  Future<void> chooseGameFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select your WoW 3.3.5a folder',
    );
    if (result != null && mounted) {
      setState(() => gameFolder = result);
      final profile = selectedServer;
      if (profile != null) await applyRealmToGameFolder(profile);
    }
  }


  Future<void> applyRealmToGameFolder(ServerProfile profile) async {
    final treeUri = gameTreeUri;
    if (treeUri == null) {
      showInfo(
        'Grant game folder access',
        'Android requires you to select the WoW game folder using the system folder picker before WOW LK can update Data/<locale>/realmlist.wtf. Tap GRANT WRITE ACCESS and select the same game folder.',
      );
      return;
    }
    try {
      final written = await _storageChannel.invokeMethod<bool>(
        'writeRealmlist',
        {'treeUri': treeUri, 'content': '${profile.realmlistLine}\\n'},
      );
      if (!mounted) return;
      if (written == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Realm applied: ${profile.name}')),
        );
      } else {
        showInfo('Could not update realmlist', 'The selected folder does not contain a WoW Data folder. Please grant access to the main game folder.');
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      showInfo('Could not update realmlist', error.message ?? 'Android could not write the realmlist file.');
    } catch (error) {
      if (!mounted) return;
      showInfo('Could not update realmlist', 'Details: $error');
    }
  }
  void _jumpToSection(int index, GlobalKey key) {
    setState(() => selectedNavTab = index);
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
        alignment: .04,
      );
    }
  }

  void showInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panel,
        title: Text(title, style: const TextStyle(color: gold)),
        content: Text(message, style: const TextStyle(color: muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: gold.withValues(alpha: .45)),
                  ),
                  child: const Icon(Icons.shield_moon, color: gold, size: 29),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WOW LK',
                          style: TextStyle(
                              color: gold,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2)),
                      Text('WRATH OF THE LICH KING · 3.3.5a',
                          style: TextStyle(color: muted, fontSize: 10)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => showInfo(
                    'About WOW LK',
                    'A community launcher prototype. The Windows game runtime and graphics compatibility layer are not bundled in this first build.',
                  ),
                  icon: const Icon(Icons.info_outline, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _classicTabStrip(),
            const SizedBox(height: 18),
            Container(
              height: 176,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF263750), Color(0xFF101827), Color(0xFF392A25)],
                ),
                border: Border.all(color: gold.withValues(alpha: .35)),
              ),
              child: Stack(
                children: [
                  Positioned(right: 18, top: 15,
                    child: Icon(Icons.ac_unit, size: 118,
                        color: Colors.white.withValues(alpha: .07))),
                  const Positioned(
                    left: 20, bottom: 20, right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YOUR ADVENTURE', style: TextStyle(
                            color: Colors.white, fontSize: 25,
                            fontWeight: FontWeight.w900, letterSpacing: 1)),
                        Text('BEGINS IN NORTHREND',
                            style: TextStyle(color: gold, fontSize: 12,
                                letterSpacing: 2, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Container(key: _gameSectionKey, child: _sectionTitle('GAME CLIENT')),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.folder_open, color: gold),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('WoW game folder',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                    _status(gameFolder == null ? 'NOT SELECTED' : 'SELECTED',
                        gameFolder == null ? Colors.orangeAccent : Colors.greenAccent),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    gameFolder ?? 'Choose the folder containing Wow.exe and Data/',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: chooseGameFolder,
                    icon: const Icon(Icons.drive_folder_upload),
                    label: const Text('IMPORT GAME FOLDER'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: gold,
                      side: const BorderSide(color: gold),
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _requestGameFolderAccess,
                    icon: const Icon(Icons.folder_shared_outlined),
                    label: Text(gameTreeUri == null ? 'GRANT WRITE ACCESS' : 'RESELECT WRITE ACCESS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: gold,
                      side: BorderSide(color: gold.withValues(alpha: .65)),
                      minimumSize: const Size.fromHeight(42),
                    ),
                  ),
                  Text(
                    gameTreeUri == null
                        ? 'Select the same game folder in Android’s system picker to allow safe realmlist updates.'
                        : 'Android folder write access is saved.',
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            if (gameFolder != null) ...[
              const SizedBox(height: 16),
              GameFolderInspector(folderPath: gameFolder!, treeUri: gameTreeUri),
            ],
            const SizedBox(height: 20),
            Container(key: _serverSectionKey, child: _sectionTitle('SERVER MANAGER')),
            ServerManagerCard(
              onServerSelected: (profile) {
                setState(() => selectedServer = profile);
                if (profile != null && gameFolder != null) {
                  applyRealmToGameFolder(profile);
                }
              },
            ),
            const SizedBox(height: 20),
            Container(key: _toolsSectionKey, child: _sectionTitle('PERFORMANCE & CONTROLS')),
            _panel(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: gold,
                    title: const Text('Low graphics mode'),
                    subtitle: const Text('Recommended for initial testing',
                        style: TextStyle(color: muted, fontSize: 11)),
                    value: lowGraphics,
                    onChanged: (v) => setState(() => lowGraphics = v),
                  ),
                  const Divider(color: Color(0xFF293448)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: gold,
                    title: const Text('Touch control overlay'),
                    subtitle: const Text('Virtual buttons and movement controls',
                        style: TextStyle(color: muted, fontSize: 11)),
                    value: showTouchControls,
                    onChanged: (v) => setState(() => showTouchControls = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 58,
              child: FilledButton.icon(
                onPressed: () => showInfo(
                  'Runtime not ready',
                  'The game runtime is not ready yet. Selected realm: ${selectedServer?.name ?? 'None'}. Realmlist: ${selectedServer?.realmlistLine ?? 'Not selected'}. Realm profiles are saved locally, but applying the selected realmlist to the game folder and launching the game still need runtime integration.',
                ),
                icon: const Icon(Icons.play_arrow, size: 28),
                label: const Text('PLAY WORLD OF WARCRAFT',
                    style: TextStyle(fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
                style: FilledButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: const Color(0xFF17120A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            const SizedBox(height: 13),
            const Center(
              child: Text('LAUNCHER PREVIEW · GAME ENGINE INTEGRATION PENDING',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 9, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classicTabStrip() {
    final tabs = [
      ('GAME', Icons.shield_outlined, _gameSectionKey),
      ('REALMS', Icons.public, _serverSectionKey),
      ('OPTIONS', Icons.settings, _toolsSectionKey),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF17130F),
        border: Border.all(color: const Color(0xFF76572E), width: 1.2),
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _jumpToSection(i, tabs[i].$3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: selectedNavTab == i
                          ? const LinearGradient(colors: [Color(0xFF80602F), Color(0xFF49351D)])
                          : null,
                      color: selectedNavTab == i ? null : const Color(0xFF211B16),
                      border: Border.all(
                        color: selectedNavTab == i ? const Color(0xFFE5BD70) : const Color(0xFF59452D),
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tabs[i].$2, size: 16, color: selectedNavTab == i ? const Color(0xFFFFE3A5) : muted),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            tabs[i].$1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selectedNavTab == i ? const Color(0xFFFFE3A5) : muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Text(text, style: const TextStyle(
            color: gold, fontSize: 11, fontWeight: FontWeight.w800,
            letterSpacing: 1.5)),
      );

  Widget _panel({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFF263448)),
        ),
        child: child,
      );

  Widget _status(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.bold)),
      );
}

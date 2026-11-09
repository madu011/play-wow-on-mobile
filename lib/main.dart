import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
        title: 'Azeroth Mobile',
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
  final serverController = TextEditingController();
  bool lowGraphics = true;
  bool showTouchControls = true;

  @override
  void dispose() {
    serverController.dispose();
    super.dispose();
  }

  Future<void> chooseGameFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select your WoW 3.3.5a folder',
    );
    if (result != null && mounted) {
      setState(() => gameFolder = result);
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
                      Text('AZEROTH MOBILE',
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
                    'About Azeroth Mobile',
                    'A community launcher prototype. The Windows game runtime and graphics compatibility layer are not bundled in this first build.',
                  ),
                  icon: const Icon(Icons.info_outline, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 26),
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
            _sectionTitle('GAME CLIENT'),
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
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('SERVER'),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Realmlist / server address',
                      style: TextStyle(color: muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: serverController,
                    decoration: InputDecoration(
                      hintText: 'logon.example-server.com',
                      filled: true,
                      fillColor: bg,
                      prefixIcon: const Icon(Icons.dns, color: gold),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text('Enter the address provided by your server.',
                      style: TextStyle(color: muted, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('PERFORMANCE & CONTROLS'),
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
                  'The launcher interface is in place, but the ARM64 Windows compatibility runtime and Mali graphics backend still need to be integrated and tested. This button does not launch WoW yet.',
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

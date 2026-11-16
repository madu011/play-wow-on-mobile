// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          colorScheme: ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark)
              .copyWith(primary: gold, secondary: const Color(0xFFB58A43), surface: const Color(0xFF171A20)),
          useMaterial3: true,
          fontFamily: 'Roboto',
          outlinedButtonTheme: OutlinedButtonThemeData(style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(Color(0xFFF1D18B)),
            backgroundColor: const WidgetStatePropertyAll(Color(0xE916171B)),
            side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFF9A763B), width: 1.2)),
            shape: WidgetStatePropertyAll(BeveledRectangleBorder(borderRadius: BorderRadius.circular(5))),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 11)),
            minimumSize: const WidgetStatePropertyAll(Size(44, 42)),
            textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: .45)),
            overlayColor: const WidgetStatePropertyAll(Color(0x33E2B45D)),
            elevation: const WidgetStatePropertyAll(3),
          )),
          filledButtonTheme: FilledButtonThemeData(style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(Color(0xFFF5D995)),
            backgroundColor: const WidgetStatePropertyAll(Color(0xFF29231A)),
            side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFFB58A43), width: 1.3)),
            shape: WidgetStatePropertyAll(BeveledRectangleBorder(borderRadius: BorderRadius.circular(5))),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 15, vertical: 12)),
            textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: .7)),
            overlayColor: const WidgetStatePropertyAll(Color(0x44E2B45D)),
            elevation: const WidgetStatePropertyAll(3),
          )),
          elevatedButtonTheme: ElevatedButtonThemeData(style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(Color(0xFFF5D995)),
            backgroundColor: const WidgetStatePropertyAll(Color(0xFF29231A)),
            side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFFB58A43), width: 1.2)),
            shape: WidgetStatePropertyAll(BeveledRectangleBorder(borderRadius: BorderRadius.circular(5))),
            textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w800, fontSize: 11)),
            elevation: const WidgetStatePropertyAll(3),
          )),
          textButtonTheme: TextButtonThemeData(style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(Color(0xFFE8C77D)),
            backgroundColor: const WidgetStatePropertyAll(Color(0x66181716)),
            shape: WidgetStatePropertyAll(BeveledRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: Color(0xFF70552F), width: .8))),
            textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 10)),
            overlayColor: const WidgetStatePropertyAll(Color(0x33E2B45D)),
          )),
          iconButtonTheme: IconButtonThemeData(style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(Color(0xFFF0CE80)),
            backgroundColor: const WidgetStatePropertyAll(Color(0xDD17191E)),
            side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFF806333), width: 1)),
            shape: WidgetStatePropertyAll(BeveledRectangleBorder(borderRadius: BorderRadius.circular(4))),
            overlayColor: const WidgetStatePropertyAll(Color(0x44E2B45D)),
          )),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? gold : const Color(0xFF9A9A9A)),
            trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xFF6F542C) : const Color(0xFF30343B)),
          ),
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
  bool automaticGraphics = true;
  String graphicsPreset = 'Auto';
  String? gameTreeUri;
  List<String> gameLocales = [];
  String? selectedLocale;
  int selectedNavTab = 0;
  Map<String, dynamic> deviceInfo = {};
  bool deviceScanComplete = false;
  final GlobalKey _gameSectionKey = GlobalKey();
  final GlobalKey _serverSectionKey = GlobalKey();
  final GlobalKey _toolsSectionKey = GlobalKey();
  static const _storageChannel = MethodChannel('wow.lk/storage');

  @override
  void initState() {
    super.initState();
    _loadSavedGameAccess();
    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        automaticGraphics = prefs.getBool('automatic_graphics') ?? true;
        graphicsPreset = prefs.getString('graphics_preset') ?? 'Auto';
        lowGraphics = prefs.getBool('low_graphics') ?? true;
        showTouchControls = prefs.getBool('show_touch_controls') ?? true;
      });
    } catch (_) {
    }
    await _detectDevice();
  }

  Future<void> _savePerformanceSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('automatic_graphics', automaticGraphics);
      await prefs.setString('graphics_preset', graphicsPreset);
      await prefs.setBool('low_graphics', lowGraphics);
      await prefs.setBool('show_touch_controls', showTouchControls);
    } catch (_) {
      if (mounted) {
        showInfo('Settings not saved',
            'The preferences could not be saved on this device. Your current selections remain active until the app closes.');
      }
    }
  }


  Future<void> _detectDevice() async {
    try {
      final info = await _storageChannel.invokeMapMethod<String, dynamic>('getDeviceInfo');
      if (!mounted || info == null) return;
      setState(() {
        deviceInfo = info;
        deviceScanComplete = true;
        // Auto mode selects a conservative starting toggle from the estimated profile.
        if (automaticGraphics) {
          final estimate = _devicePerformanceEstimate(info);
          final score = int.tryParse((estimate['score'] ?? '').split('/').first) ?? 0;
          lowGraphics = score < 82;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { deviceScanComplete = true; deviceInfo = {'error': error.toString()}; });
    }
  }

  Map<String, String> _devicePerformanceEstimate(Map<String, dynamic> info) {
    final ramMb = (info['totalRamMb'] as num?)?.toInt() ?? 0;
    final cores = (info['cpuCores'] as num?)?.toInt() ?? 0;
    final renderer = (info['gpuRenderer'] ?? '').toString().toLowerCase();
    final vendor = (info['gpuVendor'] ?? '').toString().toLowerCase();
    final gpu = '$vendor $renderer';
    if (ramMb <= 0 || cores <= 0) {
      return {'level': 'Not enough device data', 'score': '—', 'basis': 'Waiting for RAM and CPU information'};
    }

    var score = 0;
    score += ramMb >= 8000 ? 35 : ramMb >= 6000 ? 28 : ramMb >= 4000 ? 19 : 10;
    score += cores >= 8 ? 30 : cores >= 6 ? 24 : cores >= 4 ? 17 : 9;

    if (gpu.contains('mali') || gpu.contains('adreno') ||
        gpu.contains('powervr') || gpu.contains('vivante')) {
      score += 25;
    } else if (renderer.isNotEmpty && renderer != 'unavailable' && renderer != 'unknown') {
      score += 18;
    } else {
      score += 8;
    }

    final gles = (info['graphicsApi'] ?? '').toString().toLowerCase();
    final vulkan = (info['vulkanVersion'] ?? '').toString();
    if (vulkan.contains('.') && !vulkan.toLowerCase().contains('not reported')) {
      score += 10;
    } else if (gles.contains('0x3') || gles.contains('0x2')) {
      score += 6;
    }

    final level = score >= 82 ? 'High (estimated)' :
        score >= 62 ? 'Medium (estimated)' : 'Low (estimated)';
    return {
      'level': level,
      'score': '$score/100',
      'basis': 'Heuristic estimate from RAM, CPU cores and reported graphics features; not a game benchmark',
    };
  }

  Map<String, String> _recommendedGraphicsSettings(Map<String, dynamic> info) {
    final estimate = _devicePerformanceEstimate(info);
    final scoreText = estimate['score'] ?? '';
    final score = int.tryParse(scoreText.split('/').first) ?? 0;
    final renderer = (info['gpuRenderer'] ?? '').toString().toLowerCase();
    final isMali = renderer.contains('mali') ||
        (info['gpuVendor'] ?? '').toString().toLowerCase().contains('arm');
    if (score == 0) {
      return {
        'quality': 'Safe / minimum',
        'resolution': 'Start at 800×600 equivalent',
        'effects': 'Keep effects and shadows low',
        'frameRate': 'Use a stable 30 FPS target',
      };
    }
    if (score >= 82) {
      return {
        'quality': 'Medium (start here)',
        'resolution': 'Start at native or 100%',
        'effects': 'Medium effects; test shadows separately',
        'frameRate': 'Try 30 FPS first; raise only after testing',
      };
    }
    if (score >= 62) {
      return {
        'quality': isMali ? 'Low–Medium (Mali-safe start)' : 'Low–Medium',
        'resolution': 'Start at 75–85%',
        'effects': 'Low shadows and effects',
        'frameRate': 'Stable 30 FPS target',
      };
    }
    return {
      'quality': 'Low',
      'resolution': 'Start at 65–75%',
      'effects': 'Disable or minimize shadows and effects',
      'frameRate': 'Stable 25–30 FPS target',
    };
  }

  String _effectiveGraphicsPreset() {
    if (automaticGraphics || graphicsPreset == 'Auto') {
      final score = int.tryParse((_devicePerformanceEstimate(deviceInfo)['score'] ?? '').split('/').first) ?? 0;
      return score >= 82 ? 'Medium' : score >= 62 ? 'Low–Medium' : 'Low';
    }
    return graphicsPreset;
  }

  Map<String, String> _graphicsPresetDetails() {
    switch (_effectiveGraphicsPreset()) {
      case 'High':
        return {'Resolution': '100%', 'Effects': 'Medium; test one effect at a time', 'Shadows': 'Low–Medium'};
      case 'Medium':
        return {'Resolution': '90–100%', 'Effects': 'Medium', 'Shadows': 'Low'};
      case 'Low–Medium':
        return {'Resolution': '75–85%', 'Effects': 'Low', 'Shadows': 'Off / Low'};
      default:
        return {'Resolution': '65–75%', 'Effects': 'Low / Minimum', 'Shadows': 'Off'};
    }
  }

  String _recommendedGraphicsProfile(Map<String, dynamic> info) {
    final renderer = (info['gpuRenderer'] ?? '').toString().toLowerCase();
    final vendor = (info['gpuVendor'] ?? '').toString().toLowerCase();
    final combined = '$vendor $renderer';
    if (combined.contains('mali')) {
      return 'Mali • OpenGL ES conservative profile';
    }
    if (combined.contains('adreno') || combined.contains('qualcomm')) {
      return 'Adreno • OpenGL ES compatibility profile';
    }
    if (combined.contains('powervr')) {
      return 'PowerVR • OpenGL ES compatibility profile';
    }
    if (combined.contains('vivante')) {
      return 'Vivante • OpenGL ES conservative profile';
    }
    if (renderer.isEmpty || renderer == 'unavailable' || renderer == 'unknown') {
      return 'Generic • OpenGL ES fallback (GPU not identified)';
    }
    return 'Generic • OpenGL ES compatibility profile';
  }

  Future<void> _loadSavedGameAccess() async {
    try {
      final uri = await _storageChannel.invokeMethod<String>('getSavedGameTreeUri');
      if (mounted && uri != null) {
        setState(() { gameTreeUri = uri; gameFolder = 'Android selected WoW folder'; });
        await _refreshGameLocales();
      }
    } catch (_) {}
  }

  Future<void> _requestGameFolderAccess() async {
    try {
      final uri = await _storageChannel.invokeMethod<String>('pickGameFolderTree');
      if (!mounted || uri == null) return;
      setState(() { gameTreeUri = uri; gameFolder = 'Android selected WoW folder'; selectedLocale = null; });
      await _refreshGameLocales();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game folder write access granted.')),
      );
      final profile = selectedServer;
      if (profile != null) await applyRealmToGameFolder(profile);
    } on PlatformException catch (error) {
      if (mounted) showInfo('Folder access not granted', error.message ?? 'Please select the WoW game folder.');
    }
  }


  Future<void> _refreshGameLocales() async {
    final treeUri = gameTreeUri;
    if (treeUri == null) return;
    try {
      final scan = await _storageChannel.invokeMapMethod<String, dynamic>('scanGameTree', {'treeUri': treeUri});
      final locales = (scan?['localeFolders'] as List? ?? const []).cast<String>();
      if (!mounted) return;
      setState(() {
        gameLocales = locales;
        if (selectedLocale != null && !locales.contains(selectedLocale)) selectedLocale = null;
        if (locales.length == 1) selectedLocale = locales.first;
      });
    } catch (_) {
      if (mounted) setState(() => gameLocales = []);
    }
  }

  Future<String?> _chooseGameLocale() async {
    if (gameLocales.isEmpty) await _refreshGameLocales();
    if (!mounted || gameLocales.isEmpty) return null;
    if (gameLocales.length == 1) return gameLocales.first;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: panel,
        title: const Text('Choose game language', style: TextStyle(color: gold)),
        children: gameLocales.map((locale) => SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, locale),
          child: Text(locale, style: const TextStyle(color: Colors.white)),
        )).toList(),
      ),
    );
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
      final locale = selectedLocale ?? await _chooseGameLocale();
      if (locale == null) {
        if (mounted) showInfo('Choose a game language', 'No supported locale folder was found, or no language was selected. Check that the selected folder is the main WoW folder and contains Data/enUS or another locale folder.');
        return;
      }
      if (mounted && selectedLocale != locale) setState(() => selectedLocale = locale);
      final written = await _storageChannel.invokeMethod<bool>(
        'writeRealmlist',
        {'treeUri': treeUri, 'content': '${profile.realmlistLine}\n', 'localeName': locale},
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
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _IcecrownBackgroundPainter()),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66202E49),
                    Color(0xAA080D18),
                    Color(0xE6090D16),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
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
            _sectionTitle('DEVICE DETECTION'),
            _deviceInfoPanel(),
            const SizedBox(height: 20),
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
                    onPressed: _requestGameFolderAccess,
                    icon: const Icon(Icons.drive_folder_upload),
                    label: const Text('SELECT WOW GAME FOLDER'),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.tune, color: gold),
                    const SizedBox(width: 9),
                    const Expanded(child: Text('GRAPHICS CONFIGURATION',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                    _status(automaticGraphics ? 'AUTO' : 'MANUAL',
                        automaticGraphics ? Colors.greenAccent : Colors.orangeAccent),
                  ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: graphicsPreset,
                    decoration: const InputDecoration(
                      labelText: 'Graphics preset',
                      helperText: 'Starting recommendation only; not applied to WoW yet',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Auto', child: Text('Automatic recommendation')),
                      DropdownMenuItem(value: 'Low', child: Text('Low')),
                      DropdownMenuItem(value: 'Low–Medium', child: Text('Low–Medium')),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'High', child: Text('High')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        graphicsPreset = value;
                        automaticGraphics = value == 'Auto';
                        if (value != 'Auto') {
                          lowGraphics = value == 'Low' || value == 'Low–Medium';
                        } else {
                          final score = int.tryParse((_devicePerformanceEstimate(deviceInfo)['score'] ?? '').split('/').first) ?? 0;
                          lowGraphics = score < 82;
                        }
                      });
                      _savePerformanceSettings();
                    },
                  ),
                  const SizedBox(height: 12),
                  for (final entry in _graphicsPresetDetails().entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        SizedBox(width: 92, child: Text(entry.key.toUpperCase(),
                            style: const TextStyle(color: muted, fontSize: 10))),
                        Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 12))),
                      ]),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Values are suggested starting points. They will not affect the game until a compatible runtime is integrated.',
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                  const Divider(color: Color(0xFF293448)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: gold,
                    title: const Text('Automatic graphics profile'),
                    subtitle: const Text('Choose a starting profile from detected hardware',
                        style: TextStyle(color: muted, fontSize: 11)),
                    value: automaticGraphics,
                    onChanged: (v) {
                      setState(() {
                        automaticGraphics = v;
                        graphicsPreset = v ? 'Auto' : 'Low';
                        if (v && deviceScanComplete) {
                          final score = int.tryParse((_devicePerformanceEstimate(deviceInfo)['score'] ?? '').split('/').first) ?? 0;
                          lowGraphics = score < 82;
                        }
                      });
                      _savePerformanceSettings();
                    },
                  ),
                  const Divider(color: Color(0xFF293448)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: gold,
                    title: const Text('Low graphics mode'),
                    subtitle: Text(
                      automaticGraphics ? 'Controlled by automatic profile' : 'Manual override enabled',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                    value: lowGraphics,
                    onChanged: automaticGraphics ? null : (v) {
                      setState(() {
                        lowGraphics = v;
                        graphicsPreset = v ? 'Low' : 'Medium';
                      });
                      _savePerformanceSettings();
                    },
                  ),
                  const Divider(color: Color(0xFF293448)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: gold,
                    title: const Text('Touch control overlay'),
                    subtitle: const Text('Virtual buttons and movement controls',
                        style: TextStyle(color: muted, fontSize: 11)),
                    value: showTouchControls,
                    onChanged: (v) {
                      setState(() => showTouchControls = v);
                      _savePerformanceSettings();
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          automaticGraphics = true;
                          graphicsPreset = 'Auto';
                          if (deviceScanComplete) {
                            final score = int.tryParse((_devicePerformanceEstimate(deviceInfo)['score'] ?? '').split('/').first) ?? 0;
                            lowGraphics = score < 82;
                          }
                          showTouchControls = true;
                        });
                        _savePerformanceSettings();
                      },
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('Restore recommended settings'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 58,
              child: FilledButton.icon(
                onPressed: () async {
                  try {
                    await _storageChannel.invokeMethod<bool>('openNativeGameLauncher');
                  } on PlatformException catch (error) {
                    if (mounted) {
                      showInfo(
                        'Game engine unavailable',
                        'The native WoW engine could not be opened: ${error.message ?? error.code}',
                      );
                    }
                  } on MissingPluginException {
                    if (mounted) {
                      showInfo(
                        'Game engine unavailable',
                        'This companion screen must run inside the integrated WOW LK Android app.',
                      );
                    }
                  }
                },
                icon: const Icon(Icons.play_arrow, size: 28),
                label: const Text('OPEN GAME ENGINE',
                    style: TextStyle(fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF29231A),
                  foregroundColor: const Color(0xFFFFE2A1),
                  side: const BorderSide(color: Color(0xFFE0B75E), width: 1.5),
                  shape: BeveledRectangleBorder(borderRadius: BorderRadius.circular(5)),
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
        ],
      ),
    );
  }

  String _deviceReportText() {
    final estimate = _devicePerformanceEstimate(deviceInfo);
    final settings = _recommendedGraphicsSettings(deviceInfo);
    final rows = <String, String>{
      'Device': '${deviceInfo['manufacturer'] ?? ''} ${deviceInfo['model'] ?? ''}'.trim(),
      'Android': deviceInfo['androidVersion']?.toString() ?? 'Unknown',
      'CPU cores': deviceInfo['cpuCores']?.toString() ?? 'Unknown',
      'RAM MB': deviceInfo['totalRamMb']?.toString() ?? 'Unknown',
      'GPU vendor': deviceInfo['gpuVendor']?.toString() ?? 'Unknown',
      'GPU renderer': deviceInfo['gpuRenderer']?.toString() ?? 'Unknown',
      'OpenGL ES': deviceInfo['openGlVersion']?.toString() ?? 'Unknown',
      'Vulkan API': deviceInfo['vulkanVersion']?.toString() ?? 'Unknown',
      'Performance estimate': '${estimate['level']} (${estimate['score']})',
      'Graphics profile': _recommendedGraphicsProfile(deviceInfo),
      'Suggested quality': settings['quality'] ?? 'Unknown',
      'Suggested resolution': settings['resolution'] ?? 'Unknown',
      'Suggested effects': settings['effects'] ?? 'Unknown',
      'Suggested frame rate': settings['frameRate'] ?? 'Unknown',
    };
    return 'WOW LK — DEVICE & GRAPHICS REPORT\\n'
        '${rows.entries.map((entry) => '${entry.key}: ${entry.value}').join('\\n')}'
        '\\n\\nNote: estimates are heuristic only. No WoW runtime benchmark has been performed.';
  }

  Widget _deviceInfoPanel() {
    final info = deviceInfo;
    final ram = info['totalRamMb'] is num
        ? '${((info['totalRamMb'] as num) / 1024).toStringAsFixed(1)} GB'
        : 'Checking…';
    final rows = <(String, String)>[
      ('Device', '${info['manufacturer'] ?? 'Detecting'} ${info['model'] ?? ''}'.trim()),
      ('Android', info['androidVersion']?.toString() ?? 'Detecting'),
      ('CPU', info['cpuCores'] == null ? 'Detecting' : '${info['cpuCores']} cores'),
      ('RAM', ram),
      ('Architecture', (info['supportedAbis'] as List?)?.join(', ') ?? 'Detecting'),
      ('GPU Vendor', info['gpuVendor']?.toString() ?? 'Detecting'),
      ('GPU Renderer', info['gpuRenderer']?.toString() ?? 'Detecting'),
      ('Graphics Profile', _recommendedGraphicsProfile(info)),
      ('Performance Estimate', '${_devicePerformanceEstimate(info)['level']} • ${_devicePerformanceEstimate(info)['score']}'),
      ('Suggested Quality', _recommendedGraphicsSettings(info)['quality']!),
      ('Suggested Resolution', _recommendedGraphicsSettings(info)['resolution']!),
      ('Effects', _recommendedGraphicsSettings(info)['effects']!),
      ('Frame Rate Target', _recommendedGraphicsSettings(info)['frameRate']!),
      ('OpenGL ES', info['openGlVersion']?.toString() ?? 'Checking…'),
      ('Vulkan API', info['vulkanVersion']?.toString() ?? 'Checking…'),
      ('Vulkan Level', info['vulkanLevel']?.toString() ?? 'Checking…'),
      ('Graphics API', info['graphicsApi']?.toString() ?? 'Checking support…'),
      ('Screen', info['screenResolution']?.toString() ?? 'Detecting'),
    ];
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.phonelink_setup, color: gold),
            const SizedBox(width: 9),
            const Expanded(child: Text('Automatic hardware scan',
                style: TextStyle(fontWeight: FontWeight.bold))),
            _status(deviceScanComplete ? 'SCANNED' : 'SCANNING',
                deviceScanComplete ? Colors.greenAccent : Colors.orangeAccent),
          ]),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 104, child: Text(row.$1,
                    style: const TextStyle(color: muted, fontSize: 12))),
                Expanded(child: Text(row.$2,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
            ),
          const SizedBox(height: 8),
          Text(
            info['error']?.toString() ??
                (deviceScanComplete
                    ? 'Suggested graphics values are starting points only. They are not applied to the game; verify performance in a real runtime before increasing quality.'
                    : 'Reading device information directly from Android…'),
            style: const TextStyle(color: muted, fontSize: 10),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _detectDevice,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('RESCAN DEVICE'),
              ),
              TextButton.icon(
                onPressed: deviceScanComplete
                    ? () async {
                        await Clipboard.setData(ClipboardData(text: _deviceReportText()));
                        if (mounted) showInfo('Report copied', 'Device and graphics report copied to clipboard.');
                      }
                    : null,
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('COPY REPORT'),
              ),
            ],
          ),
        ],
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

/// Atmospheric, original Icecrown-inspired backdrop drawn locally so the
/// launcher does not depend on remote images or large bundled artwork.
class _IcecrownBackgroundPainter extends CustomPainter {
  const _IcecrownBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF182B46), Color(0xFF101A2B), Color(0xFF070B13)],
    ).createShader(bounds));

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0x665CA9E8), const Color(0x005CA9E8)],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * .52, size.height * .34),
        radius: size.width * .62,
      ));
    canvas.drawRect(bounds, glow);

    final farPaint = Paint()..color = const Color(0xFF263D59);
    final midPaint = Paint()..color = const Color(0xFF172A43);
    final ridge = Path()
      ..moveTo(0, size.height * .56)
      ..lineTo(size.width * .13, size.height * .39)
      ..lineTo(size.width * .22, size.height * .50)
      ..lineTo(size.width * .37, size.height * .30)
      ..lineTo(size.width * .49, size.height * .49)
      ..lineTo(size.width * .63, size.height * .34)
      ..lineTo(size.width * .78, size.height * .51)
      ..lineTo(size.width * .91, size.height * .37)
      ..lineTo(size.width, size.height * .48)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(ridge, farPaint);
    final foreground = Path()
      ..moveTo(0, size.height * .72)
      ..lineTo(size.width * .18, size.height * .60)
      ..lineTo(size.width * .35, size.height * .70)
      ..lineTo(size.width * .55, size.height * .57)
      ..lineTo(size.width * .75, size.height * .69)
      ..lineTo(size.width, size.height * .59)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(foreground, Paint()..color = const Color(0xFF0B1422));

    final towers = <(double, double, double)>[
      (.08, .50, .20), (.24, .39, .27), (.76, .42, .25),
      (.91, .48, .21), (.52, .25, .37),
    ];
    for (final tower in towers) {
      final x = size.width * tower.$1;
      final base = size.height * tower.$2;
      final h = size.height * tower.$3;
      final w = size.width * .055;
      final path = Path()
        ..moveTo(x - w, base)
        ..lineTo(x - w * .58, base - h * .72)
        ..lineTo(x, base - h)
        ..lineTo(x + w * .58, base - h * .72)
        ..lineTo(x + w, base)
        ..close();
      canvas.drawPath(path, midPaint);
      final iceEdge = Paint()
        ..color = const Color(0x6679B8E8)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, iceEdge);
      canvas.drawLine(Offset(x, base - h), Offset(x, base - h * .35),
          Paint()..color = const Color(0x557FC8F4)..strokeWidth = 1.5);
    }

    final snow = Paint()..color = const Color(0x227BB9E8);
    for (var i = 0; i < 22; i++) {
      final x = size.width * ((i * 37 % 101) / 100);
      final y = size.height * ((i * 61 % 97) / 100);
      canvas.drawCircle(Offset(x, y), i % 4 == 0 ? 1.8 : 1.0, snow);
    }
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0x00000000), const Color(0x99030710)],
        stops: const [0.42, 1],
      ).createShader(bounds);
    canvas.drawRect(bounds, vignette);
  }

  @override
  bool shouldRepaint(covariant _IcecrownBackgroundPainter oldDelegate) => false;
}

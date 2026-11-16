import 'package:flutter/material.dart';

const _gold = Color(0xFFE4B65D);
const _goldDark = Color(0xFF765329);
const _ink = Color(0xE90A0D14);
const _muted = Color(0xFFB8B0A0);

class GameUiPreviewPage extends StatefulWidget {
  const GameUiPreviewPage({super.key});

  @override
  State<GameUiPreviewPage> createState() => _GameUiPreviewPageState();
}

class _GameUiPreviewPageState extends State<GameUiPreviewPage> {
  String _selectedWindow = '';
  int _selectedAction = -1;
  int _selectedTab = 0;

  void _openWindow(String name) {
    setState(() => _selectedWindow = name);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF171923),
        title: Text(name, style: const TextStyle(color: _gold, fontFamily: 'Georgia')),
        content: Text(
          '$name interface preview. This is a visual UI prototype; live character and game data will connect after runtime integration.',
          style: const TextStyle(color: _muted),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF100F12),
        foregroundColor: _gold,
        title: const Text('AZEROTH MOBILE  •  GAME UI', style: TextStyle(fontFamily: 'Georgia', fontSize: 15, letterSpacing: 1)),
        actions: [
          IconButton(tooltip: 'Interface help', onPressed: () => _openWindow('UI GUIDE'), icon: const Icon(Icons.help_outline)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: [
            _scene(),
            const SizedBox(height: 10),
            _sectionLabel('CHARACTER & WORLD'),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _playerFrame()),
              const SizedBox(width: 8),
              Expanded(child: _targetFrame()),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _buffs()),
              const SizedBox(width: 8),
              Expanded(child: _miniMap()),
            ]),
            const SizedBox(height: 12),
            _sectionLabel('WORLD ACTIONS'),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _actionBars()),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _questTracker()),
            ]),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _chatWindow()),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _menuDock()),
            ]),
            const SizedBox(height: 12),
            _sectionLabel('GAME WINDOWS'),
            _windowButtons(),
            const SizedBox(height: 12),
            _sectionLabel('INTERFACE STYLE'),
            _stylePanel(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _scene() => AspectRatio(
    aspectRatio: 16 / 7,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _goldDark, width: 1.4),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF15283D), Color(0xFF26394B), Color(0xFF3A3028), Color(0xFF17151A)]),
      ),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _FantasyBackdropPainter())),
        const Positioned(top: 9, left: 0, right: 0, child: Center(
          child: Text('WORLD OF WARCRAFT', style: TextStyle(color: _gold, fontFamily: 'Georgia', fontWeight: FontWeight.w900, letterSpacing: 2, shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
        )),
        const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shield_moon, size: 38, color: Color(0x99E4C17B)),
          Text('AZEROTH', style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontWeight: FontWeight.bold, letterSpacing: 3, shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
          Text('MOBILE INTERFACE PREVIEW', style: TextStyle(color: _gold, fontSize: 8, letterSpacing: 1.5)),
        ])),
        Positioned(bottom: 7, left: 8, child: _tinyPill('NORTHREND')),
        Positioned(bottom: 7, right: 8, child: _tinyPill('12:34')),
      ]),
    ),
  );

  Widget _playerFrame() => _frame(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      _portrait(Icons.person, const Color(0xFF9A6B42)),
      const SizedBox(width: 7),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('AZEROTH', style: TextStyle(color: _gold, fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 11)),
        Text('Level 80 • Human Paladin', style: TextStyle(color: _muted, fontSize: 8)),
      ])),
      const Text('80', style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
    ]),
    const SizedBox(height: 7),
    _bar('HP', '32,457 / 32,457', const Color(0xFF238B37)),
    const SizedBox(height: 4),
    _bar('MP', '5,886 / 5,886', const Color(0xFF245DA8)),
  ]));

  Widget _targetFrame() => _frame(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      _portrait(Icons.pets, const Color(0xFF6D8750)),
      const SizedBox(width: 7),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('DALARAN GUARDIAN', style: TextStyle(color: _gold, fontSize: 9, fontWeight: FontWeight.bold)),
        Text('Target • Level 75', style: TextStyle(color: _muted, fontSize: 8)),
      ])),
    ]),
    const SizedBox(height: 8),
    _bar('HP', 'Enemy target', const Color(0xFF9A2929)),
  ]));

  Widget _buffs() => _frame(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('BUFFS / DEBUFFS', style: TextStyle(color: _gold, fontSize: 9, fontWeight: FontWeight.bold)),
    const SizedBox(height: 7),
    Wrap(spacing: 5, children: const [
      _BuffIcon(icon: Icons.auto_awesome, time: '30m'),
      _BuffIcon(icon: Icons.flash_on, time: '10m'),
      _BuffIcon(icon: Icons.shield, time: '5m'),
    ]),
  ]));

  Widget _miniMap() => _frame(child: Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF34465A), border: Border.all(color: _gold, width: 2)),
      child: const Icon(Icons.explore, color: _gold, size: 30)),
    const SizedBox(width: 7),
    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('DALARAN', style: TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 10)),
      Text('Northrend', style: TextStyle(color: _muted, fontSize: 8)),
      Text('12:34  •  Map', style: TextStyle(color: Colors.white70, fontSize: 8)),
    ])),
  ]));

  Widget _actionBars() => _frame(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('ACTION BARS', style: TextStyle(color: _gold, fontSize: 9, fontWeight: FontWeight.bold)),
    const SizedBox(height: 7),
    Wrap(spacing: 4, runSpacing: 4, children: List.generate(12, (i) => _actionButton(i))),
    const SizedBox(height: 5),
    Wrap(spacing: 4, children: List.generate(8, (i) => _actionButton(i + 12, small: true))),
  ]));

  Widget _actionButton(int index, {bool small = false}) {
    const icons = [Icons.local_fire_department, Icons.flash_on, Icons.auto_awesome, Icons.shield, Icons.bolt, Icons.healing, Icons.ac_unit, Icons.swords, Icons.star, Icons.favorite, Icons.waves, Icons.whatshot];
    return InkWell(
      onTap: () => setState(() => _selectedAction = index),
      child: Container(
        width: small ? 23 : 29, height: small ? 23 : 29,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _selectedAction == index ? [const Color(0xFFB88B42), const Color(0xFF49351E)] : [const Color(0xFF4A4A4A), const Color(0xFF17191F)]),
          border: Border.all(color: _selectedAction == index ? const Color(0xFFFFE2A1) : _goldDark),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icons[index % icons.length], color: index % 3 == 0 ? const Color(0xFFFFD27C) : Colors.white70, size: small ? 13 : 17),
      ),
    );
  }

  Widget _questTracker() => _frame(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
    Text('OBJECTIVES', style: TextStyle(color: _gold, fontSize: 9, fontWeight: FontWeight.bold)),
    SizedBox(height: 6),
    Text('✦ The Lich King’s Fall', style: TextStyle(color: Color(0xFFE9C36C), fontSize: 9)),
    Text('  Defeat the Lich King (0/1)', style: TextStyle(color: _muted, fontSize: 8)),
    SizedBox(height: 5),
    Text('✦ A Royal Escort', style: TextStyle(color: Color(0xFFE9C36C), fontSize: 9)),
    Text('  Speak to Uther (0/1)', style: TextStyle(color: _muted, fontSize: 8)),
  ]));

  Widget _chatWindow() => _frame(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
    Text('CHAT  •  GENERAL  •  COMBAT  •  GUILD', style: TextStyle(color: _gold, fontSize: 8, fontWeight: FontWeight.bold)),
    SizedBox(height: 6),
    Text('[2. Trade] WTB: Saronite Bar x20', style: TextStyle(color: Colors.white70, fontSize: 8)),
    Text('[Guild] [Azeroth]: Invite for ICC 10?', style: TextStyle(color: Color(0xFF69D58A), fontSize: 8)),
    Text('[Party] [Moon]: Ready!', style: TextStyle(color: Color(0xFF8DBBFF), fontSize: 8)),
  ]));

  Widget _menuDock() => _frame(child: Wrap(spacing: 5, runSpacing: 5, children: [
    _menuIcon(Icons.person, 'Character'),
    _menuIcon(Icons.menu_book, 'Spellbook'),
    _menuIcon(Icons.military_tech, 'Talents'),
    _menuIcon(Icons.emoji_events, 'Achieve'),
    _menuIcon(Icons.backpack, 'Bag'),
    _menuIcon(Icons.map, 'Map'),
  ]));

  Widget _menuIcon(IconData icon, String name) => InkWell(
    onTap: () => _openWindow(name),
    child: SizedBox(width: 45, child: Column(children: [
      Icon(icon, color: _gold, size: 21),
      Text(name, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 7)),
    ])),
  );

  Widget _windowButtons() => Wrap(spacing: 7, runSpacing: 7, children: [
    for (final entry in const [
      ('Character (C)', Icons.person),
      ('Spellbook (P)', Icons.menu_book),
      ('Talents (N)', Icons.auto_awesome),
      ('Achievements (Y)', Icons.emoji_events),
      ('Quest Log (L)', Icons.assignment),
      ('Guild (J)', Icons.groups),
      ('Friends (O)', Icons.people),
      ('Who (Shift+O)', Icons.search),
      ('Collections', Icons.collections),
      ('Map (M)', Icons.map),
      ('Calendar', Icons.calendar_month),
      ('Inventory (B)', Icons.backpack),
      ('Game Menu (ESC)', Icons.settings),
    ])
      OutlinedButton.icon(
        onPressed: () => _openWindow(entry.$1),
        icon: Icon(entry.$2, size: 15),
        label: Text(entry.$1, style: const TextStyle(fontSize: 9)),
        style: OutlinedButton.styleFrom(foregroundColor: _gold, side: const BorderSide(color: _goldDark)),
      ),
  ]);

  Widget _stylePanel() => _frame(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
    Text('WOW CLASSIC • GOLD & DARK UI', style: TextStyle(color: _gold, fontFamily: 'Georgia', fontSize: 12, fontWeight: FontWeight.bold)),
    SizedBox(height: 7),
    Text('AaBbCcDdEe  1234567890', style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontSize: 19)),
    Text('Serif fantasy headings • compact readable labels • gold borders • dark metal panels', style: TextStyle(color: _muted, fontSize: 9)),
  ]));

  Widget _frame({required Widget child}) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: _ink,
      border: Border.all(color: _goldDark, width: 1),
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 7, offset: Offset(0, 3))],
    ),
    child: child,
  );

  Widget _portrait(IconData icon, Color color) => Container(
    width: 35, height: 35,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: _gold, width: 1.5)),
    child: Icon(icon, color: Colors.white, size: 21),
  );

  Widget _bar(String label, String value, Color color) => ClipRRect(
    borderRadius: BorderRadius.circular(5),
    child: Container(
      height: 15,
      color: const Color(0xFF17191E),
      child: Stack(children: [
        Positioned.fill(child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: 1, child: ColoredBox(color: color))),
        Center(child: Text('$label  •  $value', style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 3)]))),
      ]),
    ),
  );

  Widget _tinyPill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: Colors.black87, border: Border.all(color: _goldDark), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: const TextStyle(color: _gold, fontSize: 7, letterSpacing: 1)),
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(text, style: const TextStyle(color: _gold, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.6, fontFamily: 'Georgia')),
  );
}

class _BuffIcon extends StatelessWidget {
  const _BuffIcon({required this.icon, required this.time});
  final IconData icon;
  final String time;
  @override
  Widget build(BuildContext context) => Container(
    width: 31, height: 39,
    decoration: BoxDecoration(color: const Color(0xFF29252A), border: Border.all(color: _goldDark), borderRadius: BorderRadius.circular(5)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: _gold, size: 17),
      Text(time, style: const TextStyle(color: Colors.white, fontSize: 7)),
    ]),
  );
}

class _FantasyBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x332B6B9A);
    final center = Offset(size.width * .5, size.height * .54);
    final path = Path()
      ..moveTo(center.dx, size.height * .17)
      ..lineTo(center.dx - size.width * .12, size.height * .83)
      ..lineTo(center.dx + size.width * .12, size.height * .83)
      ..close();
    canvas.drawPath(path, paint);
    final glow = Paint()..color = const Color(0x335DA9E8);
    canvas.drawCircle(center, size.height * .15, glow);
    final line = Paint()..color = const Color(0x338A9DB1)..strokeWidth = 1;
    for (var i = 0; i < 7; i++) {
      final x = size.width * i / 7;
      canvas.drawLine(Offset(x, size.height * .4), Offset(x + size.width * .08, size.height), line);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

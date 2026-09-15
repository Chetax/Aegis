// lib/screens/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'checkin_screen.dart';
import 'dictionary_screen.dart';
import 'home_screen.dart';
import 'learn_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  // Home is the default landing tab now — most opens are calm-mode
  // check-ins on progress, not mid-crisis. Learn/Check-In are one tap away.
  int _index = 0;

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(active: _index == 0, onNavigate: _goTo),
          LearnScreen(active: _index == 1),
          CheckinScreen(active: _index == 2),
          const DictionaryScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', selected: _index == 0, onTap: () => _goTo(0)),
                _NavItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book, label: 'Learn', selected: _index == 1, onTap: () => _goTo(1)),
                _NavItem(icon: Icons.shield_outlined, activeIcon: Icons.shield, label: 'Check-In', selected: _index == 2, onTap: () => _goTo(2)),
                _NavItem(icon: Icons.gavel_outlined, activeIcon: Icons.gavel, label: 'Rules', selected: _index == 3, onTap: () => _goTo(3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}
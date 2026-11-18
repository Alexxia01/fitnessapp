import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../activity/activity_screen.dart';
import '../nutrition/nutrition_screen.dart';
import 'splits_home_screen.dart';

/// The app's real home once you're signed in and onboarded — a bottom tab
/// bar switching between the Workout tracker, Nutrition tracker, and
/// Activity (steps). Each tab is its own full Scaffold (they manage their
/// own headers/scrolling); this shell just decides which one is showing
/// and draws the bar.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  // Starts on Nutrition (index 1), not Workout — this is the screen people
  // actually want to see first on opening the app.
  int _index = 1;

  // IndexedStack, not a plain conditional — keeps all three tabs' scroll
  // position and in-progress state (a half-typed set, a pending search)
  // alive when you switch away and back, instead of rebuilding from
  // scratch every time.
  static const _tabs = [SplitsHomeScreen(), NutritionScreen(), ActivityScreen()];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.1,
              ),
              blurRadius: 14,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              _NavItem(
                icon: Icons.fitness_center,
                label: 'Workout',
                selected: _index == 0,
                colors: colors,
                onTap: () => setState(() => _index = 0),
              ),
              _NavItem(
                icon: Icons.restaurant,
                label: 'Nutrition',
                selected: _index == 1,
                colors: colors,
                onTap: () => setState(() => _index = 1),
              ),
              _NavItem(
                icon: Icons.directions_walk,
                label: 'Activity',
                selected: _index == 2,
                colors: colors,
                onTap: () => setState(() => _index = 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? colors.tealDeep : colors.mutedText;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

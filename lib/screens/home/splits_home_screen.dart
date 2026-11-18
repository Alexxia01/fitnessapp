import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/workout_split.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import 'split_detail_screen.dart';

/// The Workout tab's home — lists every split (Push, Pull, Legs, ...) as
/// its own card. Tap one to open SplitDetailScreen, which is everything
/// that used to live directly on this page (the exercise list, "+ Add
/// exercise", logging a set) before splits got pulled out into their own
/// screen, so picking a day is its own step instead of a pill-tab switch
/// on the same page.
class SplitsHomeScreen extends StatefulWidget {
  const SplitsHomeScreen({super.key});

  @override
  State<SplitsHomeScreen> createState() => _SplitsHomeScreenState();
}

class _SplitsHomeScreenState extends State<SplitsHomeScreen> {
  final _firestoreService = FirestoreService();

  Future<void> _createSplit(List<WorkoutSplit> existing) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewSplitSheet(),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await _firestoreService.addSplit(
        uid,
        // Appends to the end of the existing order so a new split always
        // shows up last, after whatever's already there.
        WorkoutSplit(id: '', name: name.trim(), order: existing.length),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('Could not add split: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: StreamBuilder<List<WorkoutSplit>>(
        stream: _firestoreService.streamSplits(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading splits:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final splits = snapshot.data ?? [];

          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.tealVivid, colors.tealDeep],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          Text(
                            'My Split',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          _ThemeToggleButton(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your own program — tracked, not prescribed.',
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.86)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: splits.isEmpty
                      ? const _EmptyState(
                          message: 'No splits yet — tap "+ New split" below to add your first day.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                          itemCount: splits.length,
                          itemBuilder: (context, i) {
                            final split = splits[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _SplitCard(
                                split: split,
                                colors: colors,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SplitDetailScreen(split: split),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _createSplit(splits),
                      icon: Icon(Icons.add, color: colors.tealDeep),
                      label: Text(
                        'New split',
                        style: TextStyle(color: colors.tealDeep, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.tealDeep),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SplitCard extends StatelessWidget {
  final WorkoutSplit split;
  final AppColors colors;
  final VoidCallback onTap;

  const _SplitCard({required this.split, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                bottomLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.14),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    split.name,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.ink),
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.mutedText),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: colors.tealVivid,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewSplitSheet extends StatefulWidget {
  const _NewSplitSheet();

  @override
  State<_NewSplitSheet> createState() => _NewSplitSheetState();
}

class _NewSplitSheetState extends State<_NewSplitSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New split', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.ink)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (v) => Navigator.of(context).pop(v),
              style: TextStyle(color: colors.ink),
              decoration: InputDecoration(
                labelText: 'Name (e.g. Push, Pull, Legs)',
                labelStyle: TextStyle(color: colors.mutedText),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.tealDeep)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.tealDeep,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: () => Navigator.of(context).pop(_controller.text),
                child: const Text(
                  'Add split',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sun/moon icon button that flips the app's light/dark setting. Always
/// drawn in white since it sits on the teal gradient header, which stays
/// the same brand color in both themes.
class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          onPressed: themeController.toggle,
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: Colors.white,
          ),
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: context.colors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

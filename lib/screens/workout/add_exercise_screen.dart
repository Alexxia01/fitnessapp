import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/exercise.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';

class AddExerciseScreen extends StatefulWidget {
  final String splitId;
  final String splitName;

  const AddExerciseScreen({
    super.key,
    required this.splitId,
    required this.splitName,
  });

  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  final _firestoreService = FirestoreService();
  final _customNameController = TextEditingController();
  final _minRepsController = TextEditingController(text: '8');
  final _maxRepsController = TextEditingController(text: '12');

  static const Map<String, List<String>> _exerciseLibrary = {
    'Push': [
      'Bench Press',
      'Overhead Press',
      'Incline Bench Press',
      'Dips',
      'Lateral Raise',
      'Triceps Pushdown',
    ],
    'Pull': [
      'Deadlift',
      'Barbell Row',
      'Lat Pulldown',
      'Pull-Up',
      'Face Pull',
      'Bicep Curl',
    ],
    'Quads': [
      'Squat',
      'Leg Press',
      'Lunge',
      'Leg Extension',
      'Bulgarian Split Squat',
    ],
    'Hamstrings': ['Romanian Deadlift', 'Leg Curl', 'Good Morning'],
    'Glutes': ['Hip Thrust', 'Glute Bridge', 'Cable Kickback'],
  };

  final Set<String> _selectedExercises = {};
  int _sets = 3;
  bool _isSaving = false;

  @override
  void dispose() {
    _customNameController.dispose();
    _minRepsController.dispose();
    _maxRepsController.dispose();
    super.dispose();
  }

  String _saveLabel() {
    final customName = _customNameController.text.trim();
    final count = _selectedExercises.length + (customName.isNotEmpty ? 1 : 0);
    if (count <= 1) return 'Save to ${widget.splitName}';
    return 'Save $count exercises to ${widget.splitName}';
  }

  Future<void> _save() async {
    final names = <String>{..._selectedExercises};
    final customName = _customNameController.text.trim();
    if (customName.isNotEmpty) names.add(customName);

    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one exercise, or type your own name.'),
        ),
      );
      return;
    }
    final minReps = int.tryParse(_minRepsController.text);
    final maxReps = int.tryParse(_maxRepsController.text);
    if (minReps == null || maxReps == null || minReps > maxReps) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid rep range.')));
      return;
    }

    setState(() => _isSaving = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Skip anything already in this split (case-insensitive), so re-running
    // this screen (or picking the same exercise twice across visits) can't
    // create duplicate docs. Also lets new exercises continue the existing
    // order count instead of every save restarting at 0.
    final existingExercises = await _firestoreService
        .streamExercises(uid, widget.splitId)
        .first;
    final existingLower = existingExercises
        .map((e) => e.name.toLowerCase())
        .toSet();
    final toSave = names
        .where((n) => !existingLower.contains(n.toLowerCase()))
        .toList();
    final duplicates = names
        .where((n) => existingLower.contains(n.toLowerCase()))
        .toList();

    if (toSave.isEmpty) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${duplicates.join(", ")} already in this split.'),
          ),
        );
      }
      return;
    }

    await Future.wait(
      toSave.asMap().entries.map((entry) {
        final index = entry.key;
        final name = entry.value;
        return _firestoreService.addExercise(
          uid,
          widget.splitId,
          Exercise(
            id: '', // ignored — addExercise only reads toMap(), Firestore assigns the real id
            name: name,
            targetSets: _sets,
            targetRepMin: minReps,
            targetRepMax: maxReps,
            order: existingExercises.length + index,
          ),
        );
      }),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gradient hero
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
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
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_back,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.splitName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Add exercise',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'to ${widget.splitName}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.86),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'CHOOSE FROM YOUR LIBRARY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: colors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._exerciseLibrary.entries.map((entry) {
                      final category = entry.key;
                      final exercises = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: colors.mutedText,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.white,
                                  Colors.white,
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.92, 1.0],
                              ).createShader(bounds),
                              blendMode: BlendMode.dstIn,
                              child: SizedBox(
                                height: 36,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: exercises.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, i) {
                                    final name = exercises[i];
                                    final selected = _selectedExercises
                                        .contains(name);
                                    return GestureDetector(
                                      onTap: () => setState(() {
                                        if (selected) {
                                          _selectedExercises.remove(name);
                                        } else {
                                          _selectedExercises.add(name);
                                        }
                                      }),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        curve: Curves.easeOut,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? colors.purpleDeep
                                              : colors.surface,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? colors.purpleDeep
                                                : colors.lilacBackground,
                                            width: 2,
                                          ),
                                        ),
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: selected
                                                ? Colors.white
                                                : colors.ink,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    TextField(
                      controller: _customNameController,
                      decoration: const InputDecoration(
                        labelText: 'Or type your own',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'SETS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: colors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _StepperButton(
                          icon: Icons.remove,
                          onTap: () =>
                              setState(() => _sets = (_sets - 1).clamp(1, 10)),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '$_sets',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 16),
                        _StepperButton(
                          icon: Icons.add,
                          onTap: () =>
                              setState(() => _sets = (_sets + 1).clamp(1, 10)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'YOUR TARGET REP RANGE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: colors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minRepsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Min'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'to',
                            style: TextStyle(
                              color: colors.mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _maxRepsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Max'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.lilacBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        "This is your own target — Compound tracks it, it doesn't prescribe it.",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.lilacText,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: colors.tealDeep.withOpacity(0.38),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: InkWell(
                    onTap: _isSaving ? null : _save,
                    child: Ink(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.tealVivid, colors.tealDeep],
                        ),
                      ),
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _saveLabel(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: CircleBorder(side: BorderSide(color: colors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 18, color: colors.tealDeep),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/nutrition_goals.dart';
import '../../models/nutrition_log.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/number_bubble.dart';
import 'favorites_screen.dart';
import 'food_search_screen.dart';
import 'nutrition_goals_screen.dart';

/// Today's food log — calorie/macro progress against your daily goals,
/// then what you've eaten broken out by meal. The Nutrition tab's home
/// screen, same role here that MainScreen plays for workouts.
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen>
    with WidgetsBindingObserver {
  final _firestoreService = FirestoreService();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The 'yyyy-MM-dd' key logs are stored under in Firestore.
  static String _dateKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  // The day currently on screen — starts as today, but the arrows/date
  // picker in the header move it to any past or future day. Everything
  // logged (search, quick add, recipes, saved meals) lands on this date.
  DateTime _selected = _dateOnly(DateTime.now());

  // What "today" was the last time we checked — lets us notice when the
  // app has been left open past midnight (see didChangeAppLifecycleState).
  DateTime _knownToday = _dateOnly(DateTime.now());

  String get _selectedKey => _dateKey(_selected);
  bool get _isToday => _selected == _dateOnly(DateTime.now());

  // Whether the macro bars show "eaten / goal" (false) or what's left to
  // hit each goal (true). Remembered between launches.
  bool _showRemaining = false;
  static const _showRemainingKey = 'nutrition_show_remaining';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadShowRemaining();
  }

  Future<void> _loadShowRemaining() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_showRemainingKey) ?? false;
      if (mounted && saved != _showRemaining) {
        setState(() => _showRemaining = saved);
      }
    } catch (_) {
      // Preference is a nicety — default view is fine if it can't load.
    }
  }

  Future<void> _toggleShowRemaining() async {
    final next = !_showRemaining;
    setState(() => _showRemaining = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_showRemainingKey, next);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // If the app was backgrounded across midnight while sitting on "today",
  // roll forward to the new today so the screen always matches the real
  // date. If the user had deliberately navigated to another day, leave it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final today = _dateOnly(DateTime.now());
    if (today == _knownToday) return;
    setState(() {
      if (_selected == _knownToday) _selected = today;
      _knownToday = today;
    });
  }

  void _shiftDay(int days) {
    setState(() {
      _selected = DateTime(_selected.year, _selected.month, _selected.day + days);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _selected = _dateOnly(picked));
  }

  void _openFoodSearch(Meal meal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(meal: meal, date: _selectedKey),
      ),
    );
  }

  // Entries swiped away but whose Firestore delete hasn't echoed back
  // through the stream yet. A swiped Dismissible must leave the widget tree
  // immediately, so we hide it locally right away instead of waiting.
  final Set<String> _hiddenLogIds = {};

  Future<void> _deleteLog(NutritionLog log) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    setState(() => _hiddenLogIds.add(log.id));
    try {
      await _firestoreService.deleteNutritionLog(uid, log.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hiddenLogIds.remove(log.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: SelectableText('Could not delete: $e')),
      );
    }
  }

  /// Tap an entry to change how much of it you ate.
  Future<void> _editLog(NutritionLog log) async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditAmountSheet(log: log),
    );
    if (amount == null || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await _firestoreService.updateNutritionLog(uid, log.withAmount(amount));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: SelectableText('Could not update: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _DateBar(
              colors: colors,
              selectedDate: _selected,
              isToday: _isToday,
              onPrevDay: () => _shiftDay(-1),
              onNextDay: () => _shiftDay(1),
              onPickDate: _pickDate,
              onJumpToToday: () =>
                  setState(() => _selected = _dateOnly(DateTime.now())),
            ),
            Expanded(
              child: StreamBuilder<NutritionGoals>(
          stream: _firestoreService.streamNutritionGoals(uid),
          builder: (context, goalsSnapshot) {
            final goals = goalsSnapshot.data ?? NutritionGoals.defaults;

            return StreamBuilder<List<NutritionLog>>(
              stream: _firestoreService.streamNutritionLogsForDate(
                uid,
                _selectedKey,
              ),
              builder: (context, logsSnapshot) {
                final logs = (logsSnapshot.data ?? [])
                    .where((l) => !_hiddenLogIds.contains(l.id))
                    .toList();
                final totalCalories = logs.fold<double>(
                  0,
                  (sum, l) => sum + l.calories,
                );
                final totalProtein = logs.fold<double>(
                  0,
                  (sum, l) => sum + l.protein,
                );
                final totalCarbs = logs.fold<double>(
                  0,
                  (sum, l) => sum + l.carbs,
                );
                final totalFat = logs.fold<double>(
                  0,
                  (sum, l) => sum + l.fat,
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        colors: colors,
                        goals: goals,
                        totalCalories: totalCalories,
                        totalProtein: totalProtein,
                        totalCarbs: totalCarbs,
                        totalFat: totalFat,
                        isToday: _isToday,
                        showRemaining: _showRemaining,
                        onToggleRemaining: _toggleShowRemaining,
                        onEditGoals: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  NutritionGoalsScreen(initialGoals: goals),
                            ),
                          );
                        },
                        onQuickAdd: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FavoritesScreen(date: _selectedKey),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final meal in Meal.values) ...[
                              _MealSection(
                                meal: meal,
                                colors: colors,
                                entries: logs
                                    .where((l) => l.meal == meal)
                                    .toList(),
                                onAdd: () => _openFoodSearch(meal),
                                onDelete: _deleteLog,
                                onEdit: _editLog,
                              ),
                              const SizedBox(height: 22),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cronometer-style day switcher: a fixed bar above the scrolling content
/// (calendar picker on the left, < Today > in the middle, a "Today" jump
/// button on the right when you've wandered off), separated from the rest
/// of the screen by a hairline divider so it reads as navigation, not as
/// part of the gradient header below it.
class _DateBar extends StatelessWidget {
  final AppColors colors;
  final DateTime selectedDate;
  final bool isToday;
  final VoidCallback onPrevDay;
  final VoidCallback onNextDay;
  final VoidCallback onPickDate;
  final VoidCallback onJumpToToday;

  const _DateBar({
    required this.colors,
    required this.selectedDate,
    required this.isToday,
    required this.onPrevDay,
    required this.onNextDay,
    required this.onPickDate,
    required this.onJumpToToday,
  });

  /// "Today" / "Yesterday" / "Tomorrow" for the adjacent days, otherwise
  /// e.g. "Mon, Nov 9" (with the year added when it isn't the current one).
  String _dateLabel() {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = selectedDate.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    final base =
        '${weekdays[selectedDate.weekday - 1]}, ${months[selectedDate.month - 1]} ${selectedDate.day}';
    return selectedDate.year == today.year ? base : '$base, ${selectedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onPickDate,
            icon: Icon(Icons.calendar_month_outlined, color: colors.tealDeep),
            tooltip: 'Pick a date',
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: onPrevDay,
                  icon: Icon(Icons.chevron_left, color: colors.ink, size: 28),
                  tooltip: 'Previous day',
                ),
                GestureDetector(
                  onTap: onPickDate,
                  behavior: HitTestBehavior.opaque,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 96),
                    child: Text(
                      _dateLabel(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.ink,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onNextDay,
                  icon: Icon(Icons.chevron_right, color: colors.ink, size: 28),
                  tooltip: 'Next day',
                ),
              ],
            ),
          ),
          // Same width as the calendar button on the left either way, so
          // the date stays truly centered whether or not this is showing.
          SizedBox(
            width: 48,
            child: isToday
                ? null
                : IconButton(
                    onPressed: onJumpToToday,
                    icon: Icon(Icons.today, color: colors.tealDeep),
                    tooltip: 'Jump to today',
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppColors colors;
  final NutritionGoals goals;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final bool isToday;
  final bool showRemaining;
  final VoidCallback onToggleRemaining;
  final VoidCallback onEditGoals;
  final VoidCallback onQuickAdd;

  const _Header({
    required this.colors,
    required this.goals,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.isToday,
    required this.showRemaining,
    required this.onToggleRemaining,
    required this.onEditGoals,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (goals.calories - totalCalories).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
            children: [
              const Text(
                'Nutrition',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: onQuickAdd,
                    icon: const Icon(Icons.bookmark_outline, color: Colors.white),
                    tooltip: 'Quick add',
                  ),
                  IconButton(
                    onPressed: onEditGoals,
                    icon: const Icon(Icons.tune, color: Colors.white),
                    tooltip: 'Daily goals',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          _OverableText(
            text: remaining >= 0
                ? '$remaining kcal left ${isToday ? 'today' : 'this day'}'
                : '${-remaining} kcal over ${isToday ? 'today' : 'this day'}',
            isOver: remaining < 0,
            fontSize: 14,
            normalWeight: FontWeight.w400,
            normalColor: Colors.white.withOpacity(0.86),
          ),
          const SizedBox(height: 12),
          // Cronometer-style switch between "eaten / goal" and "remaining".
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onToggleRemaining,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      showRemaining ? 'REMAINING' : 'EATEN / GOAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.swap_horiz, size: 18, color: Colors.white.withOpacity(0.9)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _ProgressBar(
            label: 'Calories',
            value: totalCalories,
            goal: goals.calories,
            unit: '',
            showRemaining: showRemaining,
            fillColor: colors.purpleDeep,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniProgress(
                  label: 'Protein',
                  value: totalProtein,
                  goal: goals.protein,
                  showRemaining: showRemaining,
                  fillColor: colors.purpleDeep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniProgress(
                  label: 'Carbs',
                  value: totalCarbs,
                  goal: goals.carbs,
                  showRemaining: showRemaining,
                  fillColor: colors.purpleDeep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniProgress(
                  label: 'Fat',
                  value: totalFat,
                  goal: goals.fat,
                  showRemaining: showRemaining,
                  fillColor: colors.purpleDeep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "123 left" while under the goal, "+45 over" once past it (the over case
/// is also colored red by the callers, same as the eaten/goal view).
String _remainingText(double value, double goal, String unit) {
  final remaining = (goal - value).round();
  return remaining >= 0 ? '$remaining$unit left' : '+${-remaining}$unit over';
}

/// A number that reads as normal text while you're under a goal and turns a
/// bright, heavy red once you're over. The red is much brighter/bolder than
/// a default "red" and carries a soft dark shadow, because plain red text
/// otherwise washes out against the teal header gradient.
class _OverableText extends StatelessWidget {
  final String text;
  final bool isOver;
  final double fontSize;
  final Color normalColor;
  final FontWeight normalWeight;

  const _OverableText({
    required this.text,
    required this.isOver,
    required this.fontSize,
    required this.normalColor,
    this.normalWeight = FontWeight.w700,
  });

  static const _overRed = Color(0xFFFF2D2D);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: isOver ? FontWeight.w900 : normalWeight,
        color: isOver ? _overRed : normalColor,
        shadows: isOver
            ? const [Shadow(color: Color(0x80000000), blurRadius: 4, offset: Offset(0, 1))]
            : null,
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final double goal;
  final String unit;
  final bool showRemaining;
  final Color fillColor;

  const _ProgressBar({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.showRemaining,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0);
    // Only the number flags going over — the bar itself stays capped at
    // 100% fill (see .clamp above) and keeps its normal color, since a
    // full-red bar reads as more alarming than "you're a bit over today".
    final isOver = goal > 0 && value > goal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            _OverableText(
              text: showRemaining
                  ? _remainingText(value, goal, unit)
                  : '${value.round()}$unit / ${goal.round()}$unit',
              isOver: isOver,
              fontSize: 13,
              normalColor: Colors.white.withOpacity(0.9),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: Colors.white.withOpacity(0.25),
            valueColor: AlwaysStoppedAnimation(fillColor),
          ),
        ),
      ],
    );
  }
}

class _MiniProgress extends StatelessWidget {
  final String label;
  final double value;
  final double goal;
  final bool showRemaining;
  final Color fillColor;

  const _MiniProgress({
    required this.label,
    required this.value,
    required this.goal,
    required this.showRemaining,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0);
    final isOver = goal > 0 && value > goal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OverableText(
          text: showRemaining
              ? _remainingText(value, goal, 'g')
              : '${value.round()}g / ${goal.round()}g',
          isOver: isOver,
          fontSize: 11,
          normalColor: Colors.white,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8)),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: Colors.white.withOpacity(0.25),
            valueColor: AlwaysStoppedAnimation(fillColor),
          ),
        ),
      ],
    );
  }
}

class _MealSection extends StatelessWidget {
  final Meal meal;
  final AppColors colors;
  final List<NutritionLog> entries;
  final VoidCallback onAdd;
  final ValueChanged<NutritionLog> onDelete;
  final ValueChanged<NutritionLog> onEdit;

  const _MealSection({
    required this.meal,
    required this.colors,
    required this.entries,
    required this.onAdd,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final mealCalories = entries.fold<double>(0, (sum, l) => sum + l.calories);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  meal.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.ink,
                  ),
                ),
                if (entries.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${mealCalories.round()} kcal',
                    style: TextStyle(fontSize: 13, color: colors.mutedText),
                  ),
                ],
              ],
            ),
            GestureDetector(
              onTap: onAdd,
              child: Row(
                children: [
                  Icon(Icons.add, size: 16, color: colors.tealDeep),
                  const SizedBox(width: 2),
                  Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.tealDeep,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Text(
            'Nothing logged yet.',
            style: TextStyle(fontSize: 13, color: colors.mutedText),
          )
        else
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _SwipeToDelete(
              key: ValueKey(entries[i].id),
              onDelete: () => onDelete(entries[i]),
              child: _FoodLogRow(
                log: entries[i],
                colors: colors,
                onTap: () => onEdit(entries[i]),
              ),
            ),
          ],
      ],
    );
  }
}

/// "2" instead of "2.0" for a whole-number servings count, but keeps one
/// decimal place for something like "1.5 servings".
String _formatServings(double n) =>
    n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);

class _FoodLogRow extends StatelessWidget {
  final NutritionLog log;
  final AppColors colors;
  final VoidCallback onTap;

  const _FoodLogRow({
    required this.log,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Same card language as the exercise cards on the split page and the
    // set-log cards on the workout log screen — a teal strip layered on a
    // shadowed surface — so food entries read as the same kind of thing
    // instead of a one-off style just for this screen.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.foodDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // A recipe-sourced entry doesn't have a meaningful
                      // gram amount (grams is 0 — it's a whole dish, not
                      // one ingredient) — show how many servings instead.
                      log.recipeServings != null
                          ? '${_formatServings(log.recipeServings!)} serving'
                              '${log.recipeServings == 1 ? '' : 's'} · ${log.calories.round()} kcal'
                          : '${log.grams.round()}g · ${log.calories.round()} kcal',
                      style: TextStyle(fontSize: 12, color: colors.mutedText),
                    ),
                  ],
                ),
              ),
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

/// Swipe an entry left to reveal a red delete strip with a trash icon —
/// releasing past the threshold deletes it (same gesture as Cronometer).
class _SwipeToDelete extends StatelessWidget {
  final Widget child;
  final VoidCallback onDelete;

  const _SwipeToDelete({super.key, required this.child, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.4},
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            bottomLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      child: child,
    );
  }
}

/// Bottom sheet for changing the amount of a logged entry — grams for a
/// normal food, servings for a recipe. Shows the macros rescaling live.
class _EditAmountSheet extends StatefulWidget {
  final NutritionLog log;
  const _EditAmountSheet({required this.log});

  @override
  State<_EditAmountSheet> createState() => _EditAmountSheetState();
}

class _EditAmountSheetState extends State<_EditAmountSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final a = widget.log.amount;
    _controller = TextEditingController(
      text: a == a.roundToDouble() ? a.round().toString() : a.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final log = widget.log;
    final amount = double.tryParse(_controller.text) ?? 0;
    // Preview of the entry at the typed amount (falls back to the current
    // numbers while the field is empty/invalid or the entry can't scale).
    final preview = amount > 0 ? log.withAmount(amount) : log;

    Widget macro(String label, double value, String unit, Color accent) {
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(height: 6),
            Text(
              '${value.round()}$unit',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.ink),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: colors.mutedText)),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              log.foodDescription,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Editing amount in ${log.meal.label}',
              style: TextStyle(fontSize: 13, color: colors.mutedText),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Amount',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.ink),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: NumberBubble(
                    width: log.isRecipe ? 130 : 100,
                    height: 52,
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    suffixText: log.isRecipe ? ' servings' : ' g',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: colors.lilacBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  macro('kcal', preview.calories, '', colors.tealDeep),
                  macro('protein', preview.protein, 'g', colors.purpleDeep),
                  macro('carbs', preview.carbs, 'g', colors.lilacText),
                  macro('fat', preview.fat, 'g', colors.mutedText),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                child: InkWell(
                  onTap: amount > 0 ? () => Navigator.of(context).pop(amount) : null,
                  child: Ink(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [colors.tealVivid, colors.tealDeep]),
                    ),
                    child: const Center(
                      child: Text(
                        'Save',
                        style: TextStyle(
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
          ],
        ),
      ),
    );
  }
}

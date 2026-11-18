import 'package:health/health.dart';

/// Wraps the `health` package (Apple HealthKit on iOS, Health Connect on
/// Android) down to just what the Steps card needs: today's total step
/// count. Everything else the package can do (sleep, heart rate, workouts,
/// writing data back) is deliberately not exposed here — we only read steps.
class StepTrackerService {
  final _health = Health();
  bool _configured = false;

  static const _types = [HealthDataType.STEPS];

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Whether we already have permission to read steps. Does not prompt —
  /// call [requestPermission] for that.
  Future<bool> hasPermission() async {
    await _ensureConfigured();
    final granted = await _health.hasPermissions(_types);
    return granted ?? false;
  }

  /// Shows the system/Health Connect permission prompt. Returns whether the
  /// user granted it.
  Future<bool> requestPermission() async {
    await _ensureConfigured();
    return _health.requestAuthorization(_types);
  }

  /// Total steps since midnight today, or null if the platform returned no
  /// data (distinct from 0 steps, which is a valid answer).
  Future<int?> getStepsToday() async {
    await _ensureConfigured();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    return _health.getTotalStepsInInterval(midnight, now);
  }

  /// DEBUG helper: writes a few fake blocks of steps into Health Connect /
  /// HealthKit for earlier hours today, so the Activity tab's chart can be
  /// tested on an emulator that has no real step data. Asks for write
  /// access first (separate from the read access used everywhere else).
  /// Returns false if write access was denied or nothing could be written.
  Future<bool> addSampleSteps() async {
    await _ensureConfigured();
    final granted = await _health.requestAuthorization(
      _types,
      permissions: [HealthDataAccess.READ_WRITE],
    );
    if (!granted) return false;

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    // hour of day -> steps; only hours that have already finished today.
    const pattern = {7: 650, 8: 1300, 9: 300, 12: 900, 13: 500, 17: 1500, 18: 800, 19: 400};
    var wrote = false;
    for (final entry in pattern.entries) {
      final start = midnight.add(Duration(hours: entry.key));
      final end = start.add(const Duration(minutes: 50));
      if (end.isAfter(now)) continue;
      final ok = await _health.writeHealthData(
        value: entry.value.toDouble(),
        unit: HealthDataUnit.COUNT,
        type: HealthDataType.STEPS,
        startTime: start,
        endTime: end,
        recordingMethod: RecordingMethod.manual,
      );
      wrote = wrote || ok;
    }
    // Very early in the day nothing above has "happened" yet — drop one
    // small block in the last few minutes so there's still something to see.
    if (!wrote) {
      final end = now.subtract(const Duration(minutes: 1));
      final start = end.subtract(const Duration(minutes: 10));
      if (start.isAfter(midnight)) {
        wrote = await _health.writeHealthData(
          value: 250,
          unit: HealthDataUnit.COUNT,
          type: HealthDataType.STEPS,
          startTime: start,
          endTime: end,
          recordingMethod: RecordingMethod.manual,
        );
      }
    }
    return wrote;
  }

  /// Steps bucketed by hour-of-day (index 0 = 12am–1am, ..., 23 = 11pm–
  /// midnight) for today so far. Used to draw the Activity tab's hourly
  /// bar chart — a visual breakdown, not an exact total, so it reads raw
  /// data points directly rather than going through [getStepsToday]'s
  /// platform-aggregated total.
  Future<List<int>> getHourlySteps() async {
    await _ensureConfigured();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: midnight,
      endTime: now,
    );
    final hourly = List<int>.filled(24, 0);
    for (final point in points) {
      final value = point.value;
      if (value is NumericHealthValue) {
        final hour = point.dateFrom.hour.clamp(0, 23);
        hourly[hour] += value.numericValue.round();
      }
    }
    return hourly;
  }
}

import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'progress_service.dart';

class ActivityTimeService with WidgetsBindingObserver {
  ActivityTimeService._();

  static final ActivityTimeService instance = ActivityTimeService._();
  static const _storage = FlutterSecureStorage();
  static const _dailyLimitSeconds = 24 * 60 * 60;
  static const _flushInterval = Duration(seconds: 60);

  Timer? _timer;
  Timer? _displayTimer;
  DateTime? _activeSince;
  DateTime? _sessionStartedAt;
  bool _started = false;
  bool _flushing = false;
  final ValueNotifier<int> liveSessionSeconds = ValueNotifier<int>(0);

  void start() {
    if (_started) return;
    _started = true;
    _sessionStartedAt = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flush());
      _timer?.cancel();
      _activeSince = null;
    }
  }

  void _resume() {
    _activeSince ??= DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(_flushInterval, (_) => unawaited(_flush()));
    _displayTimer?.cancel();
    _displayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final sessionStartedAt = _sessionStartedAt;
      if (sessionStartedAt == null) return;
      liveSessionSeconds.value =
          DateTime.now().difference(sessionStartedAt).inSeconds;
    });
  }

  Future<void> _flush() async {
    if (_flushing) return;
    final startedAt = _activeSince;
    if (startedAt == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(startedAt).inSeconds;
    if (elapsed <= 0) return;
    _activeSince = now;

    final todayKey = _todayKey(now);
    final storageKey = 'activity_seconds_$todayKey';
    final storedSeconds =
        int.tryParse(await _storage.read(key: storageKey) ?? '0') ?? 0;
    final remaining = _dailyLimitSeconds - storedSeconds;
    if (remaining <= 0) return;

    final secondsToRecord = elapsed.clamp(0, remaining);
    if (secondsToRecord <= 0) return;

    _flushing = true;
    try {
      await ProgressService().recordActivity(
        category: 'detector',
        secondsSpent: secondsToRecord,
        countEvent: false,
      );
      await _storage.write(
        key: storageKey,
        value: '${storedSeconds + secondsToRecord}',
      );
    } catch (e) {
      dev.log(
        'Activity time sync skipped',
        name: 'ActivityTimeService',
        error: e,
      );
      _activeSince = startedAt;
    } finally {
      _flushing = false;
    }
  }

  String _todayKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

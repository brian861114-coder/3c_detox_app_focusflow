import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/models/block_list.dart';
import 'package:focus_flow/models/focus_session.dart';
import 'package:focus_flow/models/schedule.dart';
import 'package:focus_flow/providers/schedule_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final t0 = DateTime(2026, 9, 24, 9, 0);

  FocusSession start({int minutes = 60, bool pomodoro = true}) => FocusSession.start(
        now: t0,
        focusSeconds: minutes * 60,
        pomodoro: pomodoro,
        strict: false,
        blockedApps: const ['com.example.distraction'],
      );

  group('FocusSession', () {
    test('counts down without pomodoro and completes at the end', () {
      final session = start(pomodoro: false);
      expect(session.remainingSeconds(t0), 3600);
      expect(session.advance(t0.add(const Duration(minutes: 59))), isEmpty);
      expect(session.remainingSeconds(t0.add(const Duration(minutes: 59))), 60);
      expect(session.advance(t0.add(const Duration(minutes: 60))), [SessionEvent.completed]);
    });

    test('pomodoro rests after 25 min and resumes with the saved focus time', () {
      final session = start();
      final events = session.advance(t0.add(const Duration(minutes: 25)));
      expect(events, [SessionEvent.enteredRest]);
      expect(session.isResting, isTrue);
      expect(session.remainingSeconds(t0.add(const Duration(minutes: 25))), 5 * 60);

      expect(session.advance(t0.add(const Duration(minutes: 30))), [SessionEvent.resumedFocus]);
      expect(session.isFocusing, isTrue);
      // 60 min planned - 25 already focused = 35 min left after the rest.
      expect(session.remainingSeconds(t0.add(const Duration(minutes: 30))), 35 * 60);
    });

    test('catches up several transitions at once (e.g. after an app restart)', () {
      final session = start();
      // 25 focus + 5 rest + 25 focus -> second rest has started 2 minutes ago.
      final events = session.advance(t0.add(const Duration(minutes: 57)));
      expect(events, [SessionEvent.enteredRest, SessionEvent.resumedFocus, SessionEvent.enteredRest]);
      expect(session.isResting, isTrue);
      expect(session.remainingSeconds(t0.add(const Duration(minutes: 57))), 3 * 60);

      // The remaining 10 min of focus then finish without another rest.
      expect(
        session.advance(t0.add(const Duration(minutes: 70))),
        [SessionEvent.resumedFocus, SessionEvent.completed],
      );
    });

    test('no rest when the session ends exactly at the pomodoro boundary', () {
      final session = start(minutes: 25);
      expect(session.advance(t0.add(const Duration(minutes: 25))), [SessionEvent.completed]);
    });

    test('survives a JSON round trip', () {
      final session = start()..advance(t0.add(const Duration(minutes: 26)));
      final restored = FocusSession.fromJson(session.toJson());
      final now = t0.add(const Duration(minutes: 27));
      expect(restored.isResting, isTrue);
      expect(restored.remainingSeconds(now), session.remainingSeconds(now));
      expect(restored.blockedApps, session.blockedApps);
      expect(restored.plannedFocusSeconds, 3600);
    });
  });

  test('BlockList without apps can still be edited', () {
    final list = BlockList(id: '1', name: 'x');
    list.apps.add('com.example.app');
    expect(list.apps, ['com.example.app']);
  });

  group('ScheduleProvider.activeWindow', () {
    Future<ScheduleProvider> providerWith(List<FocusSchedule> schedules) async {
      SharedPreferences.setMockInitialValues({
        'focus_schedules': jsonEncode(schedules.map((s) => s.toJson()).toList()),
      });
      final provider = ScheduleProvider();
      while (!provider.isLoaded) {
        await Future<void>.delayed(Duration.zero);
      }
      return provider;
    }

    test('returns the window end for a schedule running today', () async {
      final provider = await providerWith([
        // 2026-09-24 is a Thursday (weekday 4).
        FocusSchedule(id: 'a', weekdays: [4], startHour: 9, startMinute: 0, durationMinutes: 90),
      ]);
      final window = provider.activeWindow(DateTime(2026, 9, 24, 9, 30));
      expect(window?.schedule.id, 'a');
      expect(window?.end, DateTime(2026, 9, 24, 10, 30));
      expect(provider.activeWindow(DateTime(2026, 9, 24, 10, 30)), isNull);
    });

    test('handles a window that started yesterday and crosses midnight', () async {
      final provider = await providerWith([
        FocusSchedule(id: 'n', weekdays: [3], startHour: 23, startMinute: 0, durationMinutes: 120),
      ]);
      final window = provider.activeWindow(DateTime(2026, 9, 24, 0, 30));
      expect(window?.end, DateTime(2026, 9, 24, 1, 0));
    });

    test('ignores disabled schedules', () async {
      final provider = await providerWith([
        FocusSchedule(id: 'd', weekdays: [4], startHour: 9, startMinute: 0, durationMinutes: 60, isEnabled: false),
      ]);
      expect(provider.activeWindow(DateTime(2026, 9, 24, 9, 30)), isNull);
    });
  });
}

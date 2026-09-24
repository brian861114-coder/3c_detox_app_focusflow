import 'dart:convert';

enum FocusPhase { focusing, resting }

enum SessionEvent { enteredRest, resumedFocus, completed }

/// A running focus session, driven by wall-clock timestamps so it survives
/// timer drift, backgrounding and process restarts.
class FocusSession {
  static const pomodoroFocus = Duration(minutes: 25);
  static const pomodoroRest = Duration(minutes: 5);

  FocusPhase phase;

  /// When the current countdown (focus or rest) reaches zero.
  DateTime phaseEnd;

  /// Focusing in Pomodoro mode: when the next rest starts.
  DateTime? pomodoroBlockEnd;

  /// Resting: focus time left to resume after the rest.
  Duration savedFocus;

  final bool pomodoro;
  final bool strict;
  final bool scheduled;
  final List<String> blockedApps;

  /// Planned focus length, credited to stats on completion.
  final int plannedFocusSeconds;

  FocusSession({
    required this.phase,
    required this.phaseEnd,
    this.pomodoroBlockEnd,
    this.savedFocus = Duration.zero,
    required this.pomodoro,
    required this.strict,
    required this.scheduled,
    required this.blockedApps,
    required this.plannedFocusSeconds,
  });

  factory FocusSession.start({
    required DateTime now,
    required int focusSeconds,
    required bool pomodoro,
    required bool strict,
    bool scheduled = false,
    required List<String> blockedApps,
  }) {
    return FocusSession(
      phase: FocusPhase.focusing,
      phaseEnd: now.add(Duration(seconds: focusSeconds)),
      pomodoroBlockEnd: pomodoro ? now.add(pomodoroFocus) : null,
      pomodoro: pomodoro,
      strict: strict,
      scheduled: scheduled,
      blockedApps: List.of(blockedApps),
      plannedFocusSeconds: focusSeconds,
    );
  }

  bool get isFocusing => phase == FocusPhase.focusing;
  bool get isResting => phase == FocusPhase.resting;

  int remainingSeconds(DateTime now) {
    final ms = phaseEnd.difference(now).inMilliseconds;
    return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  }

  /// Applies every phase transition due at [now], in order, using the
  /// scheduled transition times (not [now]) so catch-up after a restart is exact.
  /// After [SessionEvent.completed] the session must be discarded.
  List<SessionEvent> advance(DateTime now) {
    final events = <SessionEvent>[];
    while (true) {
      if (isFocusing) {
        final blockEnd = pomodoroBlockEnd;
        if (blockEnd != null && !now.isBefore(blockEnd) && blockEnd.isBefore(phaseEnd)) {
          savedFocus = phaseEnd.difference(blockEnd);
          phase = FocusPhase.resting;
          phaseEnd = blockEnd.add(pomodoroRest);
          pomodoroBlockEnd = null;
          events.add(SessionEvent.enteredRest);
          continue;
        }
        if (!now.isBefore(phaseEnd)) {
          events.add(SessionEvent.completed);
        }
        return events;
      }
      if (now.isBefore(phaseEnd)) return events;
      final restEnd = phaseEnd;
      phase = FocusPhase.focusing;
      phaseEnd = restEnd.add(savedFocus);
      pomodoroBlockEnd = restEnd.add(pomodoroFocus);
      savedFocus = Duration.zero;
      events.add(SessionEvent.resumedFocus);
    }
  }

  String toJson() => json.encode({
        'phase': phase.name,
        'phaseEnd': phaseEnd.millisecondsSinceEpoch,
        'pomodoroBlockEnd': pomodoroBlockEnd?.millisecondsSinceEpoch,
        'savedFocusMs': savedFocus.inMilliseconds,
        'pomodoro': pomodoro,
        'strict': strict,
        'scheduled': scheduled,
        'blockedApps': blockedApps,
        'plannedFocusSeconds': plannedFocusSeconds,
      });

  factory FocusSession.fromJson(String source) {
    final map = json.decode(source) as Map<String, dynamic>;
    final blockEnd = map['pomodoroBlockEnd'] as int?;
    return FocusSession(
      phase: FocusPhase.values.byName(map['phase'] as String),
      phaseEnd: DateTime.fromMillisecondsSinceEpoch(map['phaseEnd'] as int),
      pomodoroBlockEnd: blockEnd == null ? null : DateTime.fromMillisecondsSinceEpoch(blockEnd),
      savedFocus: Duration(milliseconds: map['savedFocusMs'] as int? ?? 0),
      pomodoro: map['pomodoro'] as bool? ?? false,
      strict: map['strict'] as bool? ?? false,
      scheduled: map['scheduled'] as bool? ?? false,
      blockedApps: List<String>.from(map['blockedApps'] as List? ?? const []),
      plannedFocusSeconds: map['plannedFocusSeconds'] as int? ?? 0,
    );
  }
}

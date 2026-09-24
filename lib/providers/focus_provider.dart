import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/block_list.dart';
import '../models/focus_session.dart';
import '../utils/native_integration.dart';

const _audioExtensions = ['.mp3', '.wav', '.m4a', '.aac', '.flac'];

// Keys of the pre-FocusSession timer state, removed on load.
const _legacyTimerKeys = [
  'isFocusing',
  'isResting',
  'endTime',
  'pomodoroElapsedSeconds',
  'savedFocusSeconds',
  'remainingSecondsAtSave',
];

class FocusProvider with ChangeNotifier {
  // Config state
  int _userFocusDurationSeconds = 30 * 60;
  bool _isPomodoroMode = true;
  bool _isStrictMode = false;
  bool _isAlarmEnabled = false;
  bool _isMusicEnabled = false;
  bool _isShuffleMusic = false;
  List<String> _musicPaths = [];

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _alarmPlayer = AudioPlayer();
  int _currentMusicIndex = 0;
  StreamSubscription? _onCompleteSubscription;

  // Block Lists
  List<BlockList> _blockLists = [];
  String _activeBlockListId = '';

  // Active state
  FocusSession? _session;
  Timer? _timer;
  bool _isAlarmRinging = false;
  Timer? _alarmAutoStopTimer;
  bool _isLoaded = false;

  // Stats
  int _focusCyclesCompleted = 0;
  int _totalFocusedMinutes = 0;

  FocusProvider() {
    _onCompleteSubscription = _musicPlayer.onPlayerComplete.listen((_) {
      if (isSessionActive && _isMusicEnabled) _playNextTrack();
    });
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();

    final blockListsJson = prefs.getStringList('blockLists');
    if (blockListsJson != null && blockListsJson.isNotEmpty) {
      _blockLists = blockListsJson.map((e) => BlockList.fromJson(e)).toList();
    } else {
      // Setup default list (migrate old blacklisted apps if they exist)
      _blockLists = [
        BlockList(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: '新封鎖清單1',
          apps: prefs.getStringList('blacklistedApps') ?? [],
        ),
      ];
    }

    _activeBlockListId = prefs.getString('activeBlockListId') ?? _blockLists.first.id;
    if (!_blockLists.any((list) => list.id == _activeBlockListId)) {
      _activeBlockListId = _blockLists.first.id;
    }

    _focusCyclesCompleted = prefs.getInt('focusCyclesCompleted') ?? 0;
    _totalFocusedMinutes = prefs.getInt('totalFocusedMinutes') ?? 0;
    _isPomodoroMode = prefs.getBool('isPomodoroMode') ?? true;
    _isStrictMode = prefs.getBool('isStrictMode') ?? false;
    _isAlarmEnabled = prefs.getBool('isAlarmEnabled') ?? false;
    _isMusicEnabled = prefs.getBool('isMusicEnabled') ?? false;
    _isShuffleMusic = prefs.getBool('isShuffleMusic') ?? false;
    _musicPaths = prefs.getStringList('musicPaths') ?? [];
    _userFocusDurationSeconds = prefs.getInt('userFocusDurationSeconds') ?? 30 * 60;

    for (final key in _legacyTimerKeys) {
      await prefs.remove(key);
    }

    final sessionJson = prefs.getString('focusSession');
    if (sessionJson != null) {
      try {
        final session = FocusSession.fromJson(sessionJson);
        final events = session.advance(DateTime.now());
        if (events.contains(SessionEvent.completed)) {
          _creditCompletedSession(session);
          await prefs.remove('focusSession');
        } else {
          _session = session;
          _syncNativeService();
          _saveSession();
          _startInternalTimer();
        }
      } catch (e) {
        debugPrint('Discarding unreadable focus session: $e');
        await prefs.remove('focusSession');
      }
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveBlockLists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blockLists', _blockLists.map((e) => e.toJson()).toList());
    await prefs.setString('activeBlockListId', _activeBlockListId);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('focusCyclesCompleted', _focusCyclesCompleted);
    await prefs.setInt('totalFocusedMinutes', _totalFocusedMinutes);
    await prefs.setBool('isPomodoroMode', _isPomodoroMode);
    await prefs.setBool('isStrictMode', _isStrictMode);
    await prefs.setBool('isAlarmEnabled', _isAlarmEnabled);
    await prefs.setBool('isMusicEnabled', _isMusicEnabled);
    await prefs.setBool('isShuffleMusic', _isShuffleMusic);
    await prefs.setStringList('musicPaths', _musicPaths);
    await prefs.setInt('userFocusDurationSeconds', _userFocusDurationSeconds);
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final session = _session;
    if (session == null) {
      await prefs.remove('focusSession');
    } else {
      await prefs.setString('focusSession', session.toJson());
    }
  }

  bool get isLoaded => _isLoaded;
  bool get isFocusing => _session?.isFocusing ?? false;
  bool get isResting => _session?.isResting ?? false;
  bool get isSessionActive => _session != null;
  bool get isPomodoroMode => _isPomodoroMode;

  /// The user's strict-mode preference for manually started sessions.
  bool get isStrictMode => _isStrictMode;

  /// Whether the running session forbids giving up while focusing
  /// (strict preference at start, or a scheduled session).
  bool get isSessionStrict => _session?.strict ?? false;
  bool get isAlarmEnabled => _isAlarmEnabled;
  bool get isMusicEnabled => _isMusicEnabled;
  bool get isShuffleMusic => _isShuffleMusic;
  List<String> get musicPaths => List.unmodifiable(_musicPaths);
  bool get isAlarmRinging => _isAlarmRinging;
  int get currentMusicIndex => _currentMusicIndex;

  int get remainingSeconds => _session?.remainingSeconds(DateTime.now()) ?? _userFocusDurationSeconds;
  int get userFocusDurationSeconds => _userFocusDurationSeconds;
  int get focusCyclesCompleted => _focusCyclesCompleted;
  int get totalFocusedMinutes => _totalFocusedMinutes;

  List<BlockList> get blockLists => _blockLists;
  String get activeBlockListId => _activeBlockListId;

  String get formattedTime {
    final seconds = remainingSeconds;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  BlockList? _findBlockList(String id) {
    for (final list in _blockLists) {
      if (list.id == id) return list;
    }
    return null;
  }

  List<String> getActiveBlockListApps() => _findBlockList(_activeBlockListId)?.apps ?? [];

  /// Apps of [blockListId], falling back to the active list when it no longer exists.
  List<String> getBlockListApps(String blockListId) =>
      _findBlockList(blockListId)?.apps ?? getActiveBlockListApps();

  BlockList getBlockList(String id) => _findBlockList(id) ?? _blockLists.first;

  void setActiveBlockList(String id) {
    if (isSessionActive) return;
    _activeBlockListId = id;
    _saveBlockLists();
    notifyListeners();
  }

  String createBlockList() {
    int counter = 1;
    String newName = "新封鎖清單$counter";
    while (_blockLists.any((list) => list.name == newName)) {
      counter++;
      newName = "新封鎖清單$counter";
    }

    final newList = BlockList(id: DateTime.now().millisecondsSinceEpoch.toString(), name: newName);
    _blockLists.add(newList);
    _saveBlockLists();
    notifyListeners();
    return newList.id;
  }

  void updateBlockListName(String id, String newName) {
    final list = _findBlockList(id);
    // Only update if new name is unique or same as current
    if (list != null && newName.isNotEmpty && !_blockLists.any((l) => l.name == newName && l.id != id)) {
      list.name = newName;
      _saveBlockLists();
      notifyListeners();
    }
  }

  /// Returns false when the list cannot be deleted (last list, or a session is running).
  bool deleteBlockList(String id) {
    if (_blockLists.length <= 1 || isSessionActive) return false;
    _blockLists.removeWhere((list) => list.id == id);
    if (_activeBlockListId == id) {
      _activeBlockListId = _blockLists.first.id;
    }
    _saveBlockLists();
    notifyListeners();
    return true;
  }

  void toggleAppInList(String listId, String packageName) {
    final list = _findBlockList(listId);
    if (list == null) return;
    if (!list.apps.remove(packageName)) {
      list.apps.add(packageName);
    }
    _saveBlockLists();
    notifyListeners();
  }

  void setUserFocusDuration(int minutes, int seconds) {
    if (isSessionActive) return;
    _userFocusDurationSeconds = minutes * 60 + seconds;
    _saveSettings();
    notifyListeners();
  }

  void togglePomodoroMode() {
    if (isSessionActive) return;
    _isPomodoroMode = !_isPomodoroMode;
    _saveSettings();
    notifyListeners();
  }

  void toggleStrictMode() {
    if (isSessionActive) return;
    _isStrictMode = !_isStrictMode;
    _saveSettings();
    notifyListeners();
  }

  void toggleAlarm() {
    _isAlarmEnabled = !_isAlarmEnabled;
    _saveSettings();
    notifyListeners();
  }

  void toggleMusic() {
    _isMusicEnabled = !_isMusicEnabled;
    if (!_isMusicEnabled) {
      _musicPlayer.stop();
    } else if (isSessionActive) {
      _playMusic();
    }
    _saveSettings();
    notifyListeners();
  }

  void removeMusicPath(String path) {
    final index = _musicPaths.indexOf(path);
    if (index == -1) return;
    _musicPaths.removeAt(index);
    if (index < _currentMusicIndex) {
      _currentMusicIndex--;
    } else if (index == _currentMusicIndex && isSessionActive && _isMusicEnabled) {
      // The playing track was removed: move on to what now sits at this index.
      _musicPlayer.stop();
      if (_musicPaths.isNotEmpty) {
        _currentMusicIndex %= _musicPaths.length;
        _playCurrentTrack();
      }
    }
    if (_currentMusicIndex >= _musicPaths.length) _currentMusicIndex = 0;
    _saveSettings();
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffleMusic = !_isShuffleMusic;
    _saveSettings();
    notifyListeners();
  }

  void setMusicPaths(List<String> paths) {
    _musicPaths = List.of(paths);
    _currentMusicIndex = 0;
    if (_musicPaths.isEmpty) _musicPlayer.stop();
    _saveSettings();
    notifyListeners();
  }

  void addMusicPaths(List<String> paths) {
    for (final p in paths) {
      if (!_musicPaths.contains(p)) _musicPaths.add(p);
    }
    _saveSettings();
    notifyListeners();
  }

  Future<void> addMusicFromDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;
      final newPaths = <String>[];
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final lower = entity.path.toLowerCase();
        if (_audioExtensions.any(lower.endsWith)) newPaths.add(entity.path);
      }
      addMusicPaths(newPaths);
    } catch (e) {
      debugPrint("Error reading directory: $e");
    }
  }

  void stopAlarm() {
    _isAlarmRinging = false;
    _alarmPlayer.stop();
    _alarmAutoStopTimer?.cancel();
    notifyListeners();
  }

  void startFocus() {
    _beginSession(FocusSession.start(
      now: DateTime.now(),
      focusSeconds: _userFocusDurationSeconds,
      pomodoro: _isPomodoroMode,
      strict: _isStrictMode,
      blockedApps: getActiveBlockListApps(),
    ));
  }

  /// Scheduled sessions are always strict, without touching the user's preference.
  void startScheduledFocus({required int durationSeconds, String? blockListId}) {
    _beginSession(FocusSession.start(
      now: DateTime.now(),
      focusSeconds: durationSeconds,
      pomodoro: _isPomodoroMode,
      strict: true,
      scheduled: true,
      blockedApps: blockListId != null ? getBlockListApps(blockListId) : getActiveBlockListApps(),
    ));
  }

  void _beginSession(FocusSession session) {
    if (_isAlarmRinging) stopAlarm();
    _session = session;
    _syncNativeService();
    _saveSession();
    _startInternalTimer();
    if (_isMusicEnabled) _playMusic();
    notifyListeners();
  }

  /// Tells the native blocker what the current phase needs:
  /// block the session's apps while focusing, block nothing while resting.
  void _syncNativeService() {
    final session = _session;
    if (session == null) {
      NativeIntegration.stopPersistentService();
      return;
    }
    NativeIntegration.startPersistentService(
      session.isFocusing ? session.blockedApps : const [],
      session.remainingSeconds(DateTime.now()),
      resting: session.isResting,
    );
  }

  void _startInternalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final session = _session;
    if (session == null) return;
    final events = session.advance(DateTime.now());
    if (events.contains(SessionEvent.completed)) {
      _onFocusComplete(session);
      return;
    }
    if (events.isNotEmpty) {
      _syncNativeService();
      _saveSession();
    }
    notifyListeners();
  }

  void _creditCompletedSession(FocusSession session) {
    _focusCyclesCompleted++;
    _totalFocusedMinutes += session.plannedFocusSeconds ~/ 60;
    _saveSettings();
  }

  void _onFocusComplete(FocusSession session) {
    _creditCompletedSession(session);
    // Stop focus FIRST, then trigger alarm so alarm UI state is not overwritten
    stopFocus();
    if (_isAlarmEnabled) _triggerAlarm();
  }

  Future<void> _triggerAlarm() async {
    _isAlarmRinging = true;
    notifyListeners();

    try {
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer.play(AssetSource('retro_alarm.wav'));
    } catch (e) {
      debugPrint("Alarm error: $e");
    }

    _alarmAutoStopTimer?.cancel();
    _alarmAutoStopTimer = Timer(const Duration(minutes: 5), stopAlarm);
  }

  void stopFocus() {
    _timer?.cancel();
    _session = null;
    _syncNativeService();
    _saveSession();
    _musicPlayer.stop();
    notifyListeners();
  }

  void _playMusic() {
    if (_musicPaths.isEmpty) return;
    _currentMusicIndex = _isShuffleMusic ? math.Random().nextInt(_musicPaths.length) : 0;
    _playCurrentTrack();
  }

  Future<void> _playCurrentTrack() async {
    // Each failure removes one path, so this loop terminates.
    while (_musicPaths.isNotEmpty) {
      if (_currentMusicIndex >= _musicPaths.length) _currentMusicIndex = 0;
      final path = _musicPaths[_currentMusicIndex];
      try {
        if (!await File(path).exists()) throw Exception("File not found");
        await _musicPlayer.play(DeviceFileSource(path));
        return;
      } catch (e) {
        debugPrint("Error playing music: $e");
        _musicPaths.remove(path);
        _saveSettings();
      }
    }
    _isMusicEnabled = false;
    _saveSettings();
    notifyListeners();
  }

  void _playNextTrack() {
    if (_musicPaths.isEmpty) return;
    _currentMusicIndex = _isShuffleMusic
        ? math.Random().nextInt(_musicPaths.length)
        : (_currentMusicIndex + 1) % _musicPaths.length;
    _playCurrentTrack();
  }

  Future<void> playSpecificTrack(int index) async {
    if (index < 0 || index >= _musicPaths.length) return;
    _currentMusicIndex = index;
    _isShuffleMusic = false;
    _isMusicEnabled = true;
    _saveSettings();
    await _musicPlayer.stop();
    _playCurrentTrack();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _alarmAutoStopTimer?.cancel();
    _onCompleteSubscription?.cancel();
    _musicPlayer.dispose();
    _alarmPlayer.dispose();
    super.dispose();
  }
}

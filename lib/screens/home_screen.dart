import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/focus_provider.dart';
import '../providers/language_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/native_integration.dart';

import 'block_list_db_screen.dart';
import 'stats_screen.dart';
import 'schedule_screen.dart';
import 'music_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
    });
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_permissions') ?? false;
    
    if (!hasSeen && mounted) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    final lang = context.read<LanguageProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF8FAFC),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(lang.translate('perm_title'), style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.translate('perm_desc'), style: const TextStyle(color: Color(0xFF475569), fontSize: 14)),
                const SizedBox(height: 20),
                _buildPermButton(lang.translate('perm_overlay'), Icons.layers, () {
                  NativeIntegration.requestOverlayPermission();
                }),
                const SizedBox(height: 10),
                _buildPermButton(lang.translate('perm_usage'), Icons.data_usage, () {
                  NativeIntegration.requestUsageStatsPermission();
                }),
                const SizedBox(height: 10),
                _buildPermButton(lang.translate('perm_battery'), Icons.battery_charging_full, () {
                  NativeIntegration.requestBatteryOptimizationPermission();
                }),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('has_seen_permissions', true);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: Text(lang.translate('perm_done'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  Widget _buildPermButton(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFA1C6EA), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF3B82F6)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final focusProvider = context.watch<FocusProvider>();
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          DropdownButton<String>(
            value: lang.currentLanguage,
            dropdownColor: const Color(0xFFF8FAFC),
            underline: const SizedBox(),
            icon: const Icon(Icons.language, color: Color(0xFF475569), size: 20),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('EN', style: TextStyle(color: Color(0xFF334155)))),
              DropdownMenuItem(value: 'zh', child: Text('中文', style: TextStyle(color: Color(0xFF334155)))),
              DropdownMenuItem(value: 'ja', child: Text('日本語', style: TextStyle(color: Color(0xFF334155)))),
            ],
            onChanged: (String? newValue) {
              if (newValue != null) {
                context.read<LanguageProvider>().changeLanguage(newValue);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduleScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockListDbScreen()));
            },
          )
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8E6F8), // pastel lavender
                  Color(0xFFE0F4E8), // mint green
                  Color(0xFFD6E8EE), // baby blue
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                    child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!focusProvider.isFocusing && !focusProvider.isResting)
                              SizedBox(
                                width: 250,
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(lang.translate('pomodoro_mode'), style: const TextStyle(color: Color(0xFF475569))),
                                        Switch(
                                          value: focusProvider.isPomodoroMode,
                                          activeColor: const Color(0xFF10B981),
                                          onChanged: (_) => focusProvider.togglePomodoroMode(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(lang.translate('strict_mode'), style: const TextStyle(color: Color(0xFF475569))),
                                        Switch(
                                          value: focusProvider.isStrictMode,
                                          activeColor: const Color(0xFF10B981),
                                          onChanged: (_) => focusProvider.toggleStrictMode(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                        Text(
                          focusProvider.isResting ? lang.translate('resting') : (focusProvider.isFocusing ? lang.translate('focus_active') : lang.translate('ready_to_focus')),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        // Alarm Switch (Design similar to Strict Mode)
                        if (focusProvider.isFocusing || focusProvider.isResting)
                          SizedBox(
                            width: 200,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(lang.translate('enable_alarm'), style: const TextStyle(color: Color(0xFF475569), fontSize: 16)),
                                const SizedBox(width: 10),
                                Switch(
                                  value: focusProvider.isAlarmEnabled,
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: (_) => focusProvider.toggleAlarm(),
                                ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 30),
                        
                        GestureDetector(
                          onTap: () {
                            if (!focusProvider.isFocusing && !focusProvider.isResting) {
                              _showTimeInputDialog(context, focusProvider, lang);
                            }
                          },
                          child: Text(
                            focusProvider.formattedTime,
                            style: const TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w200,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        GestureDetector(
                          onTap: () {
                            if (focusProvider.isFocusing && focusProvider.isSessionStrict && !focusProvider.isResting) {
                              // Cannot give up during strict mode!
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${lang.translate('strict_mode')}!!!'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                              return;
                            }
                            if (focusProvider.isFocusing || focusProvider.isResting) {
                              focusProvider.stopFocus();
                            } else {
                              focusProvider.startFocus();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 40),
                            decoration: BoxDecoration(
                              gradient: (focusProvider.isFocusing || focusProvider.isResting)
                                  ? ((focusProvider.isFocusing && focusProvider.isSessionStrict) 
                                      ? const LinearGradient(colors: [Color(0xFF6B7280), Color(0xFF374151)]) // Greyed out if strict
                                      : const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFF991B1B)]))
                                  : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF047857)]),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: ((focusProvider.isFocusing || focusProvider.isResting) 
                                      ? ((focusProvider.isFocusing && focusProvider.isSessionStrict) ? const Color(0xFF6B7280) : const Color(0xFFEF4444)) 
                                      : const Color(0xFF10B981)).withOpacity(0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Text(
                              (focusProvider.isFocusing || focusProvider.isResting) ? lang.translate('give_up') : lang.translate('start_focus'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        if (!focusProvider.isFocusing && !focusProvider.isResting)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.6)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: focusProvider.activeBlockListId,
                                dropdownColor: const Color(0xFFF8FAFC),
                                isDense: true,
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF334155)),
                                style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w500, fontSize: 16),
                                items: focusProvider.blockLists.map((list) {
                                  return DropdownMenuItem(
                                    value: list.id,
                                    child: Text(list.name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    focusProvider.setActiveBlockList(value);
                                  }
                                },
                              ),
                            ),
                          ),
                        
                        const SizedBox(height: 30),
                        Divider(color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 10),
                        
                        // Music Player Section
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.music_note, color: Color(0xFF475569), size: 20),
                                    const SizedBox(width: 8),
                                    Text(lang.translate('music_player'), style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Switch(
                                  value: focusProvider.isMusicEnabled,
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: (_) => focusProvider.toggleMusic(),
                                ),
                              ],
                            ),
                            if (focusProvider.isMusicEnabled) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicListScreen()));
                                      },
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              focusProvider.musicPaths.isEmpty 
                                                  ? lang.translate('none_selected')
                                                  : lang.translate('music_count', arguments: {'count': focusProvider.musicPaths.length.toString()}),
                                              style: TextStyle(
                                                color: focusProvider.musicPaths.isEmpty ? const Color(0xFF64748B) : const Color(0xFF3B82F6), 
                                                fontSize: 13,
                                                decoration: focusProvider.musicPaths.isEmpty ? TextDecoration.none : TextDecoration.underline,
                                                decorationColor: const Color(0xFF3B82F6),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (focusProvider.musicPaths.isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.open_in_new, size: 14, color: Color(0xFF3B82F6)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: Icon(
                                      (focusProvider.isFocusing || focusProvider.isResting) ? Icons.play_circle_outline : Icons.add_circle_outline, 
                                      size: 18
                                    ),
                                    label: Text(
                                      (focusProvider.isFocusing || focusProvider.isResting) 
                                          ? lang.translate('select_to_play') 
                                          : lang.translate('select_music')
                                    ),
                                    onPressed: () {
                                      if (focusProvider.isFocusing || focusProvider.isResting) {
                                         if (focusProvider.musicPaths.isNotEmpty) {
                                           _showPlayMusicDialog(context, focusProvider, lang);
                                         }
                                      } else {
                                        _showMusicPickerDialog(context, focusProvider, lang);
                                      }
                                    },
                                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF3B82F6)),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(lang.translate('shuffle_mode'), style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                  Checkbox(
                                    value: focusProvider.isShuffleMusic,
                                    onChanged: (_) => focusProvider.toggleShuffle(),
                                    activeColor: const Color(0xFF10B981),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        
                        // Alarm Overlay (If ringing)
                        if (focusProvider.isAlarmRinging)
                          Container(
                            margin: const EdgeInsets.only(top: 20),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                Text(lang.translate('alarm_ringing'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () => focusProvider.stopAlarm(),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red),
                                  child: Text(lang.translate('stop_alarm')),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMusicPickerDialog(BuildContext context, FocusProvider focusProvider, LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.insert_drive_file, color: Color(0xFF3B82F6)),
                  title: Text(lang.translate('select_files'), style: const TextStyle(color: Color(0xFF334155))),
                  onTap: () async {
                    Navigator.pop(ctx);
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.audio,
                      allowMultiple: true,
                    );
                    if (result != null) {
                      List<String> paths = result.paths.whereType<String>().toList();
                      focusProvider.addMusicPaths(paths);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder, color: Color(0xFF10B981)),
                  title: Text(lang.translate('import_folder'), style: const TextStyle(color: Color(0xFF334155))),
                  onTap: () async {
                    Navigator.pop(ctx);
                    String? dirPath = await FilePicker.platform.getDirectoryPath();
                    if (dirPath != null) {
                      focusProvider.addMusicFromDirectory(dirPath);
                    }
                  },
                ),
                if (focusProvider.musicPaths.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: Text(lang.translate('clear_music'), style: const TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(ctx);
                      focusProvider.setMusicPaths([]);
                    },
                  )
              ],
            ),
          ),
        );
      }
    );
  }

  void _showPlayMusicDialog(BuildContext context, FocusProvider focusProvider, LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: focusProvider.musicPaths.length,
              itemBuilder: (context, index) {
                final path = focusProvider.musicPaths[index];
                final fileName = path.split('/').last;
                return ListTile(
                  leading: Icon(
                    focusProvider.currentMusicIndex == index ? Icons.play_arrow : Icons.music_note, 
                    color: focusProvider.currentMusicIndex == index ? const Color(0xFF10B981) : const Color(0xFF3B82F6)
                  ),
                  title: Text(fileName, style: TextStyle(color: focusProvider.currentMusicIndex == index ? const Color(0xFF10B981) : const Color(0xFF334155)), overflow: TextOverflow.ellipsis),
                  onTap: () {
                    focusProvider.playSpecificTrack(index);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        );
      }
    );
  }

  void _showTimeInputDialog(BuildContext context, FocusProvider provider, LanguageProvider lang) {
    int totalSec = provider.userFocusDurationSeconds;
    int currentMin = totalSec ~/ 60;
    int currentSec = totalSec % 60;

    TextEditingController minController = TextEditingController(text: currentMin.toString());
    TextEditingController secController = TextEditingController(text: currentSec.toString().padLeft(2, '0'));
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF8FAFC),
          title: Text(lang.translate('set_focus_time'), style: const TextStyle(color: Color(0xFF334155))),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: TextField(
                  controller: minController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF334155), fontSize: 24),
                  decoration: InputDecoration(
                    hintText: 'Min',
                    hintStyle: TextStyle(color: const Color(0xFF334155).withOpacity(0.5)),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(":", style: TextStyle(color: Color(0xFF334155), fontSize: 24)),
              ),
              Expanded(
                child: TextField(
                  controller: secController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF334155), fontSize: 24),
                  decoration: InputDecoration(
                    hintText: 'Sec',
                    hintStyle: TextStyle(color: const Color(0xFF334155).withOpacity(0.5)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.translate('cancel'), style: const TextStyle(color: Color(0xFF475569))),
            ),
            TextButton(
              onPressed: () {
                final minVal = int.tryParse(minController.text) ?? 0;
                final secVal = int.tryParse(secController.text) ?? 0;
                if ((minVal > 0 || secVal > 0) && minVal <= 99 && secVal <= 59) {
                  provider.setUserFocusDuration(minVal, secVal);
                }
                Navigator.pop(context);
              },
              child: Text(lang.translate('confirm'), style: const TextStyle(color: Color(0xFF10B981))),
            ),
          ],
        );
      }
    );
  }
}

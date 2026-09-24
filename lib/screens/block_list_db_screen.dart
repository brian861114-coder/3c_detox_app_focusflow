import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/focus_provider.dart';
import '../providers/language_provider.dart';
import '../providers/schedule_provider.dart';
import 'app_selector_screen.dart';

class BlockListDbScreen extends StatelessWidget {
  const BlockListDbScreen({super.key});

  /// Show warning dialog if the block list is used by any schedules.
  /// Returns true if user confirms (or no schedules use it), false if user cancels.
  Future<bool> _confirmBlockListAction(
    BuildContext context,
    String blockListId,
    LanguageProvider lang,
    ScheduleProvider scheduleProvider,
  ) async {
    final affectedSchedules = scheduleProvider.getSchedulesUsingBlockList(blockListId);
    if (affectedSchedules.isEmpty) {
      return true; // No schedules affected, safe to proceed
    }

    final schedulesText = affectedSchedules.map((s) => '• $s').join('\n');
    final description = lang
        .translate('blocklist_in_use_desc')
        .replaceAll('{schedules}', schedulesText);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF8FAFC),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.translate('blocklist_in_use_warning'),
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            description,
            style: const TextStyle(color: Color(0xFF475569), fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                lang.translate('cancel'),
                style: const TextStyle(color: Color(0xFF475569)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                lang.translate('confirm'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      // User confirmed — disable affected schedules and mark them
      scheduleProvider.onBlockListChanged(blockListId);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final focusProvider = context.watch<FocusProvider>();
    final lang = context.watch<LanguageProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('block_lists'), style: const TextStyle(fontWeight: FontWeight.w300, letterSpacing: 1.0)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8E6F8),
                  Color(0xFFE0F4E8),
                  Color(0xFFD6E8EE),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: focusProvider.blockLists.length,
                    itemBuilder: (context, index) {
                      final list = focusProvider.blockLists[index];
                      // Check if any schedules use this block list
                      final isUsedBySchedules = scheduleProvider
                          .getSchedulesUsingBlockList(list.id)
                          .isNotEmpty;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.6),
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        list.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                    if (isUsedBySchedules)
                                      const Tooltip(
                                        message: 'Used by schedules',
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 4),
                                          child: Icon(
                                            Icons.schedule,
                                            size: 16,
                                            color: Color(0xFF3B82F6),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${list.apps.length} apps',
                                  style: TextStyle(color: const Color(0xFF334155).withOpacity(0.7)),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Color(0xFF3B82F6)),
                                      onPressed: () async {
                                        // Check if schedules use this list — warn before editing
                                        final confirmed = await _confirmBlockListAction(
                                          context,
                                          list.id,
                                          lang,
                                          scheduleProvider,
                                        );
                                        if (confirmed && context.mounted) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AppSelectorScreen(blockListId: list.id),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    // Deleting is refused mid-session; hide it so the
                                    // schedule warning never disables schedules for nothing.
                                    if (focusProvider.blockLists.length > 1 && !focusProvider.isSessionActive)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                                        onPressed: () async {
                                          // Check if schedules use this list — warn before deleting
                                          final confirmed = await _confirmBlockListAction(
                                            context,
                                            list.id,
                                            lang,
                                            scheduleProvider,
                                          );
                                          if (confirmed) {
                                            focusProvider.deleteBlockList(list.id);
                                          }
                                        },
                                      ),
                                  ],
                                ),
                                onTap: () async {
                                  // Also warn when tapping to enter edit
                                  final confirmed = await _confirmBlockListAction(
                                    context,
                                    list.id,
                                    lang,
                                    scheduleProvider,
                                  );
                                  if (confirmed && context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AppSelectorScreen(blockListId: list.id),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0, top: 10.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 5,
                    ),
                    onPressed: () {
                      final newId = focusProvider.createBlockList();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AppSelectorScreen(blockListId: newId)));
                    },
                    icon: const Icon(Icons.add),
                    label: Text(lang.translate('create_new_list'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

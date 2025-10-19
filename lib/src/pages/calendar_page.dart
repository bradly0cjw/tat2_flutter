import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../l10n/app_localizations.dart';
import '../providers/calendar_provider.dart';
import '../widgets/add_event_bottom_sheet.dart';
import '../services/local_event_service.dart';

/// 日曆頁面
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    // 初始化日曆數據
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final calendarProvider = context.watch<CalendarProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calendar),
        actions: [
          // 回到今天
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              calendarProvider.resetToToday();
            },
            tooltip: '回到今天',
          ),
          // 刷新
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              calendarProvider.refresh();
            },
            tooltip: '重新載入',
          ),
        ],
      ),
      body: _buildBody(calendarProvider),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventBottomSheet(context),
        tooltip: '新增事件',
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.7),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 構建主體內容（處理載入狀態）
  Widget _buildBody(CalendarProvider provider) {
    // 首次載入時，等待資料載入完成
    if (!provider.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // 錯誤狀態
    if (provider.error != null) {
      return _buildErrorView(provider.error!);
    }

    // 正常內容，使用 AnimatedOpacity 實現淡入效果
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: provider.isInitialized ? 1.0 : 0.0,
      child: Column(
        children: [
          _buildCalendar(provider),
          const Divider(height: 1),
          Expanded(
            child: _buildEventList(provider),
          ),
        ],
      ),
    );
  }

  /// 構建日曆視圖
  Widget _buildCalendar(CalendarProvider provider) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: TableCalendar(
          firstDay: DateTime(2020, 1, 1),
          lastDay: DateTime(2030, 12, 31),
          focusedDay: provider.focusedDay,
          selectedDayPredicate: (day) {
            return isSameDay(provider.selectedDay, day);
          },
          calendarFormat: _calendarFormat,
          startingDayOfWeek: StartingDayOfWeek.monday,
          locale: 'zh_TW',
          // 樣式設定
          calendarStyle: CalendarStyle(
            // 調整日期單元格的邊距
            cellMargin: const EdgeInsets.fromLTRB(2, 0, 2, 4),
            // 調整日期單元格的內邊距，大幅縮小圓圈
            cellPadding: const EdgeInsets.all(1),
            // 讓點點非常靠近日期
            markersAlignment: Alignment.bottomCenter,
            markersOffset: const PositionedOffset(bottom: 8),
          todayDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black26
                  : Colors.white24,
              width: 2,
            ),
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          todayTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          defaultTextStyle: const TextStyle(fontSize: 15),
          weekendTextStyle: TextStyle(
            color: Colors.red.shade600,
            fontSize: 15,
          ),
          outsideTextStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 15,
          ),
          markerDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            shape: BoxShape.circle,
          ),
          markerSize: 6.5,
          markerMargin: const EdgeInsets.symmetric(horizontal: 1),
          markersMaxCount: 3,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonShowsNext: false,
          formatButtonDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(12.0),
          ),
          formatButtonTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
          titleTextStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          // 最小化 header 的高度
          headerPadding: const EdgeInsets.symmetric(vertical: 2),
          headerMargin: const EdgeInsets.only(bottom: 2),
          decoration: const BoxDecoration(),
          // 減少標題和格式按鈕之間的間距
          leftChevronMargin: const EdgeInsets.symmetric(horizontal: 2),
          rightChevronMargin: const EdgeInsets.symmetric(horizontal: 2),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          // 星期標題的樣式
          weekdayStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          weekendStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.red.shade600,
          ),
        ),
        // 設定行高，大幅縮小垂直空間
        daysOfWeekHeight: 24,
        rowHeight: 48,
        // 事件標記（只在開始日期顯示標記，避免跨日事件重複）
        eventLoader: (day) {
          return provider.getEventsForDay(day);
        },
        // 自訂標記外觀和選中樣式
        calendarBuilders: CalendarBuilders(
          // 自定義選中日期的樣式（縮小圈圈，無邊框）
          selectedBuilder: (context, date, focusedDay) {
            return Container(
              margin: const EdgeInsets.all(4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${date.day}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            );
          },
          // 自定義今天的樣式（縮小圈圈）
          todayBuilder: (context, date, focusedDay) {
            return Container(
              margin: const EdgeInsets.all(4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            );
          },
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return const SizedBox.shrink();
            
            // 最多顯示 3 個標記
            final displayEvents = events.take(3).toList();
            
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: displayEvents.map((event) {
                // 轉換為 UnifiedEvent 並使用事件自訂顏色
                if (event is! UnifiedEvent) return const SizedBox.shrink();
                final color = _parseColor(event.color);
                return Container(
                  width: 6.5,
                  height: 6.5,
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                );
              }).toList(),
            );
          },
        ),
        // 回調
        onDaySelected: (selectedDay, focusedDay) {
          provider.selectDay(selectedDay, focusedDay);
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        onPageChanged: (focusedDay) {
          provider.setFocusedDay(focusedDay);
        },
        ),
      ),
    );
  }

  /// 構建事件列表
  Widget _buildEventList(CalendarProvider provider) {
    final selectedEvents = provider.selectedDayEvents;

    if (selectedEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '這天沒有事件',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: selectedEvents.length,
      itemBuilder: (context, index) {
        final event = selectedEvents[index];
        return _buildEventCard(event);
      },
    );
  }

  /// 構建事件卡片
  Widget _buildEventCard(event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _parseColor(event.color),
          child: Icon(
            event.isLocalEvent ? Icons.person : Icons.school,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          event.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Builder(
                  builder: (context) {
                    // 檢查是否有時間資訊（不是 00:00）
                    final hasStartTime = event.startTime.hour != 0 || event.startTime.minute != 0;
                    final hasEndTime = event.endTime.hour != 0 || event.endTime.minute != 0;
                    final hasTime = hasStartTime || hasEndTime;
                    
                    return Icon(
                      hasTime ? Icons.access_time : Icons.calendar_today,
                      size: 14,
                      color: Colors.grey.shade600,
                    );
                  },
                ),
                const SizedBox(width: 4),
                Text(
                  event.dateRangeText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (event.location != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        onTap: () => _showEventDetail(event),
        trailing: event.isLocalEvent
            ? PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('編輯'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('刪除', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'edit') {
                    await _editLocalEvent(context, event.localEvent!);
                  } else if (value == 'delete') {
                    await _deleteLocalEvent(context, event.localEvent!);
                  }
                },
              )
            : null,
      ),
    );
  }

  /// 構建錯誤視圖
  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              '載入失敗',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                context.read<CalendarProvider>().refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }

  /// 顯示事件詳情
  void _showEventDetail(event) {
    // 檢查是否有時間資訊（不是 00:00）
    final hasStartTime = event.startTime.hour != 0 || event.startTime.minute != 0;
    final hasEndTime = event.endTime.hour != 0 || event.endTime.minute != 0;
    final hasTime = hasStartTime || hasEndTime;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasTime)
                _buildDetailRow(Icons.access_time, '時間', event.dateRangeText)
              else
                _buildDetailRow(Icons.calendar_today, '日期', event.dateRangeText),
              if (event.location != null)
                _buildDetailRow(Icons.location_on, '地點', event.location!),
              if (event.description != null) ...[
                const SizedBox(height: 12),
                const Text(
                  '說明',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(event.description!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 編輯本地事件
  Future<void> _editLocalEvent(BuildContext context, localEvent) async {
    final calendarProvider = context.read<CalendarProvider>();
    
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEventBottomSheet(
        event: localEvent,
        initialDate: calendarProvider.selectedDay,
      ),
    );

    if (result != null && mounted) {
      try {
        final eventService = LocalEventService();
        await eventService.updateEvent(result);
        await calendarProvider.loadLocalEvents();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('事件已更新'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新失敗：$e')),
          );
        }
      }
    }
  }

  /// 刪除本地事件
  Future<void> _deleteLocalEvent(BuildContext context, localEvent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除「${localEvent.title}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed == true && localEvent.id != null && mounted) {
      try {
        final eventService = LocalEventService();
        await eventService.deleteEvent(localEvent.id!);
        await context.read<CalendarProvider>().loadLocalEvents();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('事件已刪除'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('刪除失敗：$e')),
          );
        }
      }
    }
  }

  /// 顯示新增事件 Bottom Sheet
  Future<void> _showAddEventBottomSheet(BuildContext context) async {
    final calendarProvider = context.read<CalendarProvider>();
    
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEventBottomSheet(
        initialDate: calendarProvider.selectedDay,
      ),
    );

    if (result != null && mounted) {
      try {
        // 儲存到資料庫
        final eventService = LocalEventService();
        await eventService.insertEvent(result);
        
        // 重新載入事件
        await calendarProvider.loadLocalEvents();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('事件已新增'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('新增失敗：$e')),
          );
        }
      }
    }
  }

  /// 解析顏色字串
  Color _parseColor(String colorString) {
    try {
      final hex = colorString.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (e) {
      // 解析失敗，返回預設藍色
    }
    return Colors.blue;
  }
}

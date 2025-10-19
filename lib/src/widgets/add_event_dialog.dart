import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/local_calendar_event.dart';

/// 新增/編輯事件對話框
class AddEventDialog extends StatefulWidget {
  final LocalCalendarEvent? event; // 如果為 null 則是新增，否則是編輯
  final DateTime? initialDate; // 初始日期

  const AddEventDialog({
    super.key,
    this.event,
    this.initialDate,
  });

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  late DateTime _startDate;
  TimeOfDay? _startTime; // 改為 nullable
  late DateTime _endDate;
  TimeOfDay? _endTime; // 改為 nullable
  bool _isAllDay = false;
  RecurrenceType _recurrenceType = RecurrenceType.none;
  DateTime? _recurrenceEndDate;
  String _selectedColor = '#2196F3';
  bool _isAdvancedMode = false; // 進階模式開關

  final List<Map<String, dynamic>> _colorOptions = [
    {'name': '藍色', 'value': '#2196F3'},
    {'name': '紅色', 'value': '#F44336'},
    {'name': '綠色', 'value': '#4CAF50'},
    {'name': '橙色', 'value': '#FF9800'},
    {'name': '紫色', 'value': '#9C27B0'},
    {'name': '粉色', 'value': '#E91E63'},
    {'name': '青色', 'value': '#00BCD4'},
    {'name': '黃色', 'value': '#FFEB3B'},
  ];

  @override
  void initState() {
    super.initState();

    if (widget.event != null) {
      // 編輯模式
      final event = widget.event!;
      _titleController.text = event.title;
      _descriptionController.text = event.description ?? '';
      _locationController.text = event.location ?? '';
      _startDate = event.startTime;
      _endDate = event.endTime;
      _isAllDay = event.isAllDay;
      _recurrenceType = event.recurrenceType;
      _recurrenceEndDate = event.recurrenceEndDate;
      _selectedColor = event.color;
      
      // 如果不是全天事件且有指定時間（不是 00:00），則設定時間
      if (!event.isAllDay && (event.startTime.hour != 0 || event.startTime.minute != 0)) {
        _startTime = TimeOfDay.fromDateTime(event.startTime);
      }
      if (!event.isAllDay && (event.endTime.hour != 0 || event.endTime.minute != 0)) {
        _endTime = TimeOfDay.fromDateTime(event.endTime);
      }
    } else {
      // 新增模式 - 使用選中的日期作為預設值，不預設時間
      final selectedDate = widget.initialDate ?? DateTime.now();
      _startDate = selectedDate;
      _endDate = selectedDate;
      _startTime = null; // 不預設時間
      _endTime = null; // 不預設時間
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: _isAdvancedMode ? 650 : 350,
        ),
        child: Column(
          children: [
            // 標題列
            AppBar(
              title: Text(widget.event == null ? '新增事件' : '編輯事件'),
              automaticallyImplyLeading: false,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            // 表單內容
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 標題
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: '標題 *',
                          prefixIcon: Icon(Icons.title),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '請輸入標題';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 開始日期（簡單模式只顯示日期，不顯示時間）
                      _buildDateField(
                        label: '日期',
                        date: _startDate,
                        onDateTap: () => _selectDate(context, true),
                      ),
                      const SizedBox(height: 12),

                      // 模式切換開關（緊湊版，放在日期下方）
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isAdvancedMode = !_isAdvancedMode;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                _isAdvancedMode ? Icons.expand_less : Icons.expand_more,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '更多選項',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 以下為進階模式才顯示的欄位
                      if (_isAdvancedMode) ...[
                        // 描述
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: '描述',
                            prefixIcon: Icon(Icons.description),
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // 地點
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: '地點',
                            prefixIcon: Icon(Icons.location_on),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 全天事件開關
                        SwitchListTile(
                          title: const Text('全天事件'),
                          value: _isAllDay,
                          onChanged: (value) {
                            setState(() {
                              _isAllDay = value;
                            });
                          },
                          secondary: const Icon(Icons.event_available),
                        ),
                        const SizedBox(height: 8),

                        // 時間區段（開始和結束時間放在一起）
                        if (!_isAllDay) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildTimeButton(
                                  label: '開始時間',
                                  time: _startTime,
                                  onTap: () => _selectTime(context, true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTimeButton(
                                  label: '結束時間',
                                  time: _endTime,
                                  onTap: () => _selectTime(context, false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 重複規則
                        _buildRecurrenceField(),
                        const SizedBox(height: 16),

                        // 顏色選擇
                        _buildColorPicker(),
                        const SizedBox(height: 16),
                      ],

                      // 儲存按鈕
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveEvent,
                          icon: const Icon(Icons.check),
                          label: Text(widget.event == null ? '新增' : '儲存'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 構建純日期欄位（不含時間）
  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onDateTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onDateTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8),
                Text(DateFormat('yyyy/MM/dd').format(date)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 構建時間按鈕（用於進階模式的開始/結束時間）
  Widget _buildTimeButton({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 8),
                Text(
                  time != null ? time.format(context) : '未設定',
                  style: TextStyle(
                    color: time != null ? Colors.black : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 構建重複規則欄位
  Widget _buildRecurrenceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '重複',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<RecurrenceType>(
          value: _recurrenceType,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.repeat),
            border: OutlineInputBorder(),
          ),
          items: RecurrenceType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(_getRecurrenceText(type)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _recurrenceType = value!;
            });
          },
        ),
        if (_recurrenceType != RecurrenceType.none) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _selectRecurrenceEndDate(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_busy),
                  const SizedBox(width: 8),
                  Text(
                    _recurrenceEndDate == null
                        ? '選擇結束日期（選填）'
                        : '結束於：${DateFormat('yyyy/MM/dd').format(_recurrenceEndDate!)}',
                  ),
                  const Spacer(),
                  if (_recurrenceEndDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _recurrenceEndDate = null;
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 構建顏色選擇器
  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '顏色',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _colorOptions.map((colorOption) {
            final colorValue = colorOption['value'] as String;
            final colorName = colorOption['name'] as String;
            final color = _parseColor(colorValue);
            final isSelected = _selectedColor == colorValue;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedColor = colorValue;
                });
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 選擇日期
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'TW'),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // 如果開始日期晚於結束日期，自動調整結束日期
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          // 如果結束日期早於開始日期，自動調整開始日期
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  /// 選擇時間
  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final currentTime = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  /// 選擇重複結束日期
  Future<void> _selectRecurrenceEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'TW'),
    );

    if (picked != null) {
      setState(() {
        _recurrenceEndDate = picked;
      });
    }
  }

  /// 儲存事件
  void _saveEvent() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 組合日期和時間
    // 如果沒有指定時間，使用 00:00 表示只有日期
    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _isAllDay ? 0 : (_startTime?.hour ?? 0),
      _isAllDay ? 0 : (_startTime?.minute ?? 0),
    );

    // 結束時間：
    // - 全天事件：23:59
    // - 有指定結束時間：使用指定時間
    // - 沒有指定時間：使用 00:00（表示只有日期）
    final endDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _isAllDay ? 23 : (_endTime?.hour ?? 0),
      _isAllDay ? 59 : (_endTime?.minute ?? 0),
    );

    // 驗證時間邏輯（只有在設定了時間時才驗證）
    if (_startTime != null && _endTime != null && endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('結束時間不能早於開始時間'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 創建事件對象
    final event = LocalCalendarEvent(
      id: widget.event?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      startTime: startDateTime,
      endTime: endDateTime,
      isAllDay: _isAllDay,
      recurrenceType: _recurrenceType,
      recurrenceEndDate: _recurrenceEndDate,
      color: _selectedColor,
      createdAt: widget.event?.createdAt,
      updatedAt: DateTime.now(),
    );

    // 返回事件
    Navigator.pop(context, event);
  }

  /// 取得重複類型文字
  String _getRecurrenceText(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.none:
        return '不重複';
      case RecurrenceType.daily:
        return '每天';
      case RecurrenceType.weekly:
        return '每週';
      case RecurrenceType.monthly:
        return '每月';
      case RecurrenceType.yearly:
        return '每年';
    }
  }

  /// 解析顏色字串
  Color _parseColor(String colorString) {
    final hex = colorString.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return Colors.blue;
  }
}

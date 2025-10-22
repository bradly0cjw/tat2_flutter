import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/empty_classroom.dart';
import '../services/ntut_api_service.dart';

/// 空教室查詢頁面 - Material Design 3 風格
class EmptyClassroomPage extends StatefulWidget {
  const EmptyClassroomPage({super.key});

  @override
  State<EmptyClassroomPage> createState() => _EmptyClassroomPageState();
}

class _EmptyClassroomPageState extends State<EmptyClassroomPage> 
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {

  // 時間相關常數（只顯示週一到週五）
  static const Map<String, String> _dayNames = {
    'mon': '週一',
    'tue': '週二',
    'wed': '週三',
    'thu': '週四',
    'fri': '週五',
  };

  static const Map<String, String> _periodTimes = {
    '1': '08:10-09:00',
    '2': '09:10-10:00',
    '3': '10:10-11:00',
    '4': '11:10-12:00',
    'N': '12:10-13:00',
    '5': '13:10-14:00',
    '6': '14:10-15:00',
    '7': '15:10-16:00',
    '8': '16:10-17:00',
    '9': '17:10-18:00',
    'A': '18:30-19:20',
    'B': '19:20-20:10',
    'C': '20:20-21:10',
    'D': '21:10-22:00',
  };

  static const List<String> _allPeriods = [
    '1', '2', '3', '4', 'N', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D'
  ];

  // 狀態
  String _selectedDay = 'mon';
  String? _selectedBuilding; // 選擇的教學大樓
  int? _selectedFloor; // 選擇的樓層
  bool _isLoading = false;
  List<EmptyClassroom> _classrooms = [];
  String? _errorMessage;
  
  // 緩存機制：每個星期的資料只查詢一次
  final Map<String, List<EmptyClassroom>> _cache = {};
  bool _hasInitialized = false; // 是否已經初始化

  @override
  bool get wantKeepAlive => true; // 保持狀態不被銷毀

  @override
  void initState() {
    super.initState();
    _selectedDay = _getCurrentDay();
    // 不在 initState 載入資料，等待第一次被顯示時才載入
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 取得目前星期
  String _getCurrentDay() {
    final now = DateTime.now();
    const days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
    final day = days[now.weekday % 7];
    // 如果是週末，預設為週一
    return _dayNames.containsKey(day) ? day : 'mon';
  }

  /// 解析教室的樓層
  int? _parseFloor(String classroomName) {

    
    // 處理 "5F" 格式
    final fMatch = RegExp(r'(\d+)F').firstMatch(classroomName);
    if (fMatch != null) {
      return int.tryParse(fMatch.group(1)!);
    }
    
    // 處理數字格式（取前面的數字作為樓層）
    final digitMatch = RegExp(r'[^\d]*(\d+)').firstMatch(classroomName);
    if (digitMatch != null) {
      final numStr = digitMatch.group(1)!;
      if (numStr.length >= 2) {
        // 億光0728 -> 07 -> 7
        // 億光1128 -> 11 -> 11
        // 二教205 -> 20 -> 2 (但這裡應該是2)
        if (numStr.length == 4) {
          // 4位數：前2位是樓層
          return int.tryParse(numStr.substring(0, 2));
        } else if (numStr.length == 3) {
          // 3位數：第1位是樓層
          return int.tryParse(numStr.substring(0, 1));
        } else {
          // 其他情況
          return int.tryParse(numStr.substring(0, 1));
        }
      }
    }
    
    return null;
  }

  /// 取得所有教學大樓列表（使用 category 欄位）
  List<String> _getBuildings() {
    final buildings = _classrooms
        .map((c) => c.category)
        .toSet()
        .toList();
    buildings.sort();
    return buildings;
  }

  /// 取得所有樓層列表
  List<int> _getFloors() {
    final floors = _classrooms
        .map((c) => _parseFloor(c.name))
        .where((f) => f != null)
        .cast<int>()
        .toSet()
        .toList();
    floors.sort();
    return floors;
  }

  /// 過濾教室列表
  List<EmptyClassroom> _getFilteredClassrooms() {
    var filtered = _classrooms;
    
    // 教學大樓篩選（使用 category 欄位）
    if (_selectedBuilding != null) {
      filtered = filtered.where((c) => 
        c.category == _selectedBuilding
      ).toList();
    }
    
    // 樓層篩選
    if (_selectedFloor != null) {
      filtered = filtered.where((c) => 
        _parseFloor(c.name) == _selectedFloor
      ).toList();
    }
    
    return filtered;
  }

  /// 顯示教學大樓篩選對話框 - MD3 風格
  void _showBuildingFilterDialog() {
    final buildings = _getBuildings();
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.business, color: colorScheme.primary),
        title: const Text('選擇教學大樓'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: _selectedBuilding == null 
                    ? Icon(Icons.check_circle, color: colorScheme.primary)
                    : Icon(Icons.circle_outlined, color: colorScheme.outlineVariant),
                title: const Text('全部大樓'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  setState(() {
                    _selectedBuilding = null;
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              ...buildings.map((building) => ListTile(
                    leading: _selectedBuilding == building
                        ? Icon(Icons.check_circle, color: colorScheme.primary)
                        : Icon(Icons.circle_outlined, color: colorScheme.outlineVariant),
                    title: Text(building),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedBuilding = building;
                      });
                      Navigator.pop(context);
                    },
                  )),
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

  /// 顯示樓層篩選對話框 - MD3 風格
  void _showFloorFilterDialog() {
    final floors = _getFloors();
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.layers, color: colorScheme.primary),
        title: const Text('選擇樓層'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: _selectedFloor == null 
                    ? Icon(Icons.check_circle, color: colorScheme.primary)
                    : Icon(Icons.circle_outlined, color: colorScheme.outlineVariant),
                title: const Text('全部樓層'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  setState(() {
                    _selectedFloor = null;
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              ...floors.map((floor) => ListTile(
                    leading: _selectedFloor == floor
                        ? Icon(Icons.check_circle, color: colorScheme.primary)
                        : Icon(Icons.circle_outlined, color: colorScheme.outlineVariant),
                    title: Text('$floor樓'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedFloor = floor;
                      });
                      Navigator.pop(context);
                    },
                  )),
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

  /// 載入空教室資料（支援緩存）
  Future<void> _loadEmptyClassrooms({bool forceRefresh = false}) async {
    // 如果已有緩存且不強制刷新，直接使用緩存
    if (!forceRefresh && _cache.containsKey(_selectedDay)) {
      setState(() {
        _classrooms = _cache[_selectedDay]!;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ntutApi = context.read<NtutApiService>();
      final response = await ntutApi.courseSearch.getEmptyClassrooms(
        dayOfWeek: _selectedDay,
        year: '114',
        semester: '1',
      );

      if (response != null && response.success) {
        setState(() {
          _classrooms = response.data;
          _cache[_selectedDay] = response.data; // 緩存資料
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '查詢失敗，請稍後再試';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '發生錯誤: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必須調用以使 AutomaticKeepAliveClientMixin 生效
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 頁面首次顯示時自動載入資料（因為有懶加載，只有真正切換到此頁面時才會執行）
    if (!_hasInitialized) {
      _hasInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadEmptyClassrooms();
        }
      });
    }

    final hasActiveFilters = _selectedBuilding != null || _selectedFloor != null;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // AppBar
            SliverAppBar(
              floating: true,
              pinned: false,
              snap: true,
              title: Text(l10n.emptyClassroom),
              actions: [
                if (hasActiveFilters)
                  IconButton(
                    icon: const Icon(Icons.filter_list_off),
                    tooltip: '清除篩選',
                    onPressed: () {
                      setState(() {
                        _selectedBuilding = null;
                        _selectedFloor = null;
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '重新整理',
                  onPressed: () => _loadEmptyClassrooms(forceRefresh: true),
                ),
              ],
            ),
            
            // 篩選區域 - 固定在 AppBar 下方，有陰影和層次感
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    // 星期選擇器 - SegmentedButton (M3 風格) - 置中
                    Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<String>(
                          segments: _dayNames.entries.map((entry) {
                            return ButtonSegment<String>(
                              value: entry.key,
                              label: Text(entry.value),
                            );
                          }).toList(),
                          selected: {_selectedDay},
                          onSelectionChanged: (Set<String> selected) {
                            if (selected.isNotEmpty) {
                              setState(() => _selectedDay = selected.first);
                              _loadEmptyClassrooms();
                            }
                          },
                          showSelectedIcon: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 大樓和樓層篩選
                    Row(
                      children: [
                        Expanded(
                          child: FilterChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.business, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _selectedBuilding ?? '全部大樓',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            selected: _selectedBuilding != null,
                            showCheckmark: false,
                            onSelected: (_) => _showBuildingFilterDialog(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilterChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.layers, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _selectedFloor != null ? '$_selectedFloor樓' : '全部樓層',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            selected: _selectedFloor != null,
                            showCheckmark: false,
                            onSelected: (_) => _showFloorFilterDialog(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: CustomScrollView(
          slivers: _buildClassroomListSlivers(theme),
        ),
      ),
    );
  }

  Widget _buildLegendItem(ThemeData theme, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildClassroomListSlivers(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    
    if (_isLoading) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  '載入中...',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_errorMessage != null) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _loadEmptyClassrooms(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重試'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_classrooms.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.meeting_room_outlined,
                  size: 64,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  '目前沒有空教室資料',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '可以切換其他星期查看',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    // 取得過濾後的教室
    final filteredClassrooms = _getFilteredClassrooms();
    
    if (filteredClassrooms.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  '沒有符合條件的空教室',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '試試調整篩選條件',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    // 顯示教室列表
    return [
        // 統計資訊和圖例
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.meeting_room,
                      size: 18,
                      color: colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '找到 ${filteredClassrooms.length} 間教室',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildLegendItem(
                      theme,
                      theme.brightness == Brightness.light 
                        ? Colors.green.shade300.withOpacity(0.8)
                        : Colors.green.shade700.withOpacity(0.7),
                      '空',
                    ),
                    const SizedBox(width: 12),
                    _buildLegendItem(
                      theme,
                      theme.brightness == Brightness.light 
                        ? Colors.red.shade300.withOpacity(0.8)
                        : Colors.red.shade700.withOpacity(0.7),
                      '忙',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      // 教室列表
      SliverPadding(
        padding: const EdgeInsets.all(8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final classroom = filteredClassrooms[index];
              return _buildClassroomCard(classroom, theme);
            },
            childCount: filteredClassrooms.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildClassroomCard(EmptyClassroom classroom, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final building = classroom.category;
    final floor = _parseFloor(classroom.name);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => _showClassroomDetail(classroom),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 標題行
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        classroom.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 資訊行
                Row(
                  children: [
                    Icon(
                      Icons.business,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      floor != null ? '$building $floor樓' : building,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 時段狀態網格
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _allPeriods.map((period) {
                    final isAvailable = classroom.timetable.contains(period);
                    final bgColor = isAvailable
                        ? (theme.brightness == Brightness.light
                            ? Colors.green.shade300.withOpacity(0.85)
                            : Colors.green.shade700.withOpacity(0.75))
                        : (theme.brightness == Brightness.light
                            ? Colors.red.shade300.withOpacity(0.85)
                            : Colors.red.shade700.withOpacity(0.75));
                    
                    return Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          period,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.brightness == Brightness.light
                                ? Colors.grey.shade800
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClassroomDetail(EmptyClassroom classroom) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final building = classroom.category;
    final floor = _parseFloor(classroom.name);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                // 拖拽指示器
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.meeting_room_rounded,
                              color: colorScheme.onPrimaryContainer,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  classroom.name,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.business,
                                      size: 16,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      floor != null ? '$building $floor樓' : building,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_dayNames[_selectedDay]} 時段一覽',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _allPeriods.length,
                    itemBuilder: (context, index) {
                      final period = _allPeriods[index];
                      final isAvailable = classroom.timetable.contains(period);
                      final textColor = isAvailable
                          ? (theme.brightness == Brightness.light
                              ? Colors.green.shade700.withOpacity(0.85)
                              : Colors.green.shade300)
                          : (theme.brightness == Brightness.light
                              ? Colors.red.shade700.withOpacity(0.85)
                              : Colors.red.shade300);
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            // 節次方塊
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isAvailable
                                    ? (theme.brightness == Brightness.light
                                        ? Colors.green.shade300.withOpacity(0.85)
                                        : Colors.green.shade700.withOpacity(0.75))
                                    : (theme.brightness == Brightness.light
                                        ? Colors.red.shade300.withOpacity(0.85)
                                        : Colors.red.shade700.withOpacity(0.75)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  period,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: theme.brightness == Brightness.light
                                        ? Colors.grey.shade800
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 時間
                            Expanded(
                              child: Text(
                                _periodTimes[period]!,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            // 狀態標籤
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: textColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                isAvailable ? '空堂' : '有課',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

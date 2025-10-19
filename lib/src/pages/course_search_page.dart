import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/ntut_api_service.dart';
import '../widgets/class_selector_dialog.dart';
import '../widgets/course_detail_dialog.dart';
import '../l10n/app_localizations.dart';

class CourseSearchPage extends StatefulWidget {
  const CourseSearchPage({super.key});

  @override
  State<CourseSearchPage> createState() => _CourseSearchPageState();
}

class _CourseSearchPageState extends State<CourseSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allCourses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  bool _isLoading = false;
  bool _hasSearched = false; // 追蹤是否已執行過搜尋
  
  // 分頁
  int _currentPage = 1;
  final int _itemsPerPage = 20;
  
  int get _totalPages => _filteredCourses.isEmpty ? 1 : (_filteredCourses.length / _itemsPerPage).ceil();
  
  List<Map<String, dynamic>> get _currentPageCourses {
    if (_filteredCourses.isEmpty) return [];
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _filteredCourses.length);
    return _filteredCourses.sublist(startIndex, endIndex);
  }
  
  // 博雅類別
  final Set<String> _selectedCategories = {};
  final Map<String, String> _categoryList = {
    '創新與創業': '創新與創業',
    '人文與藝術': '人文與藝術',
    '社會與法治': '社會與法治',
    '自然與科學': '自然',
  };
  
  // 學院篩選
  String? _selectedCollege;
  final List<String> _collegeList = [
    '校院級',
    '機電學院',
    '工程學院',
    '管理學院',
    '設計學院',
    '人文與社會科學學院',
    '電資學院',
    '創新前瞻科技研究學院',
  ];
  
  // 時間篩選
  final Map<String, Set<String>> _selectedTimes = {
    '一': {}, '二': {}, '三': {}, '四': {}, '五': {},
  };
  final List<String> _timeSlots = ['1', '2', '3', '4', 'N', '5', '6', '7', '8', '9', 'A', 'B', 'C'];
  
  List<Map<String, dynamic>>? _userCourses;

    @override
  void initState() {
    super.initState();
    _initCache(); // 只載入緩存供「不選衝堂」功能使用
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initCache() async {
    try {
      final userCourseBox = await Hive.openBox('course_table_cache');
      final now = DateTime.now();
      final year = now.year - 1911;
      final semester = (now.month >= 2 && now.month <= 7) ? 2 : 1;
      final cacheKey = 'courses_${year}_$semester';
      final cachedUserCourses = userCourseBox.get(cacheKey);
      
      if (cachedUserCourses != null) {
        _userCourses = (cachedUserCourses as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        debugPrint('[CourseSearch] 從緩存載入 ${_userCourses!.length} 門用戶課程');
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('[CourseSearch] 初始化緩存失敗: $e');
      setState(() => _isLoading = false);
    }
  }

  // 已移除下拉選單相關方法，改用彈出視窗

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    
    try {
      debugPrint('[CourseSearch] 使用搜尋 API');
      final api = context.read<NtutApiService>();
      final now = DateTime.now();
      final year = (now.year - 1911).toString();
      final sem = (now.month >= 2 && now.month <= 7) ? '2' : '1';
      
      // 構建時間篩選參數
      List<Map<String, dynamic>>? timeSlots;
      if (_selectedTimes.values.any((times) => times.isNotEmpty)) {
        timeSlots = [];
        _selectedTimes.forEach((day, periods) {
          if (periods.isNotEmpty) {
            timeSlots!.add({
              'day': _dayToEnglish(day),
              'periods': periods.toList(),
            });
          }
        });
      }
      
      // 調用新的搜尋 API
      final courses = await api.searchCourses(
        keyword: _searchController.text.trim(),
        year: year,
        semester: sem,
        category: _selectedCategories.isNotEmpty ? _selectedCategories.first : null,
        college: _selectedCollege,
        timeSlots: timeSlots,
      );
      
      if (mounted) {
        setState(() {
          _allCourses = courses;
          _filteredCourses = courses;
          _currentPage = 1; // 重置到第一頁
          _isLoading = false;
          _hasSearched = true; // 標記已執行搜尋
        });
      }
      
      debugPrint('[CourseSearch] 找到 ${courses.length} 筆課程');
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入失敗：$e')),
        );
      }
    }
  }
  // 生成目前篩選條件的指紋，用於比較是否有變更
  String _filtersFingerprint() {
    // 類別
    final categories = _selectedCategories.toList()..sort();
    // 學院
    final college = _selectedCollege ?? '';
    // 時間（依固定日序，內部時段排序）
    const dayOrder = ['一', '二', '三', '四', '五'];
    final timeParts = <String>[];
    for (final d in dayOrder) {
      final set = _selectedTimes[d] ?? {};
      final times = set.toList()..sort();
      timeParts.add('$d:${times.join("")}');
    }
    return [categories.join(','), college, timeParts.join('|')].join('#');
  }

  // 顯示博雅類別篩選
  Future<void> _showCategoryFilter() async {
    final before = _filtersFingerprint();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          _categoryFilterModalState = setModalState;
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 標題列
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.category,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '博雅類別',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _categoryFilterModalState = null;
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              // 內容
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildCategoryFilterContent(),
              ),
            ],
            ),
          );
        },
      ),
    );
    // 底部彈窗關閉後再決定是否搜尋
    _categoryFilterModalState = null;
    final after = _filtersFingerprint();
    if (before != after) {
      _loadCourses();
    }
  }

  // 顯示時間篩選
  Future<void> _showTimeFilter() async {
    final before = _filtersFingerprint();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          _timeFilterModalState = setModalState;
          return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 標題列
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '時間篩選',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _timeFilterModalState = null;
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              // 內容
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildTimeFilterContent(),
              ),
            ],
          ),
        );
        },
      ),
    );
    _timeFilterModalState = null;
    final after = _filtersFingerprint();
    if (before != after) {
      _loadCourses();
    }
  }

  // 顯示學院篩選
  Future<void> _showCollegeFilter() async {
    final before = _filtersFingerprint();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          _collegeFilterModalState = setModalState;
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 標題列
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.business,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '學院篩選',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _collegeFilterModalState = null;
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              // 內容
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildCollegeFilterContent(),
              ),
            ],
            ),
          );
        },
      ),
    );
    _collegeFilterModalState = null;
    final after = _filtersFingerprint();
    if (before != after) {
      _loadCourses();
    }
  }

  /// 將中文星期轉換為英文
  String _dayToEnglish(String chineseDay) {
    const dayMap = {
      '一': 'mon',
      '二': 'tue',
      '三': 'wed',
      '四': 'thu',
      '五': 'fri',
    };
    return dayMap[chineseDay] ?? 'mon';
  }

  // 已移除 _applyFilters，改用 API 直接搜尋

  /// 顯示班級/學程選擇對話框
  void _showClassSelector() {
    final now = DateTime.now();
    final year = (now.year - 1911).toString();
    final sem = (now.month >= 2 && now.month <= 7) ? '2' : '1';
    
    showDialog(
      context: context,
      builder: (context) => ClassSelectorDialog(
        year: year,
        semester: sem,
        onCoursesSelected: (courses, title) {
          setState(() {
            _allCourses = courses;
            _filteredCourses = courses;
            _isLoading = false;
            _hasSearched = true; // 標記已執行搜尋
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已載入 $title 的課程 (${courses.length} 筆)')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasActiveFilters = _selectedTimes.values.any((times) => times.isNotEmpty) ||
        _selectedCategories.isNotEmpty ||
        _selectedCollege != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.courseSearch),
        actions: [
          if (hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_list_off),
              tooltip: '清除篩選',
              onPressed: _resetFilters,
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSearchBar()),
          ..._buildResultsSlivers(),
        ],
      ),
      floatingActionButton: _buildExpandableFAB(),
    );
  }
  
  bool _isFABExpanded = false;
  
  Widget _buildExpandableFAB() {
    // 計算各篩選器的狀態
    final timeCount = _selectedTimes.values.fold<int>(0, (sum, times) => sum + times.length);
    final categoryCount = _selectedCategories.length;
    final hasCollege = _selectedCollege != null;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isFABExpanded) ...[
          _buildMiniFAB(
            icon: Icons.class_,
            label: '班級查詢',
            onPressed: () {
              setState(() => _isFABExpanded = false);
              _showClassSelector();
            },
            hasSelection: false,
          ),
          const SizedBox(height: 12),
          _buildMiniFAB(
            icon: Icons.category,
            label: categoryCount > 0 ? '博雅類別 ($categoryCount)' : '博雅類別',
            onPressed: () {
              setState(() => _isFABExpanded = false);
              _showCategoryFilter();
            },
            hasSelection: categoryCount > 0,
          ),
          const SizedBox(height: 12),
          _buildMiniFAB(
            icon: Icons.access_time,
            label: timeCount > 0 ? '時間篩選 ($timeCount)' : '時間篩選',
            onPressed: () {
              setState(() => _isFABExpanded = false);
              _showTimeFilter();
            },
            hasSelection: timeCount > 0,
          ),
          const SizedBox(height: 12),
          _buildMiniFAB(
            icon: Icons.business,
            label: hasCollege ? '學院篩選 (1)' : '學院篩選',
            onPressed: () {
              setState(() => _isFABExpanded = false);
              _showCollegeFilter();
            },
            hasSelection: hasCollege,
          ),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          onPressed: () {
            setState(() => _isFABExpanded = !_isFABExpanded);
          },
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          foregroundColor: Colors.white,
          child: AnimatedRotation(
            turns: _isFABExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(_isFABExpanded ? Icons.close : Icons.tune),
          ),
        ),
      ],
    );
  }
  
  Widget _buildMiniFAB({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool hasSelection,
  }) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      heroTag: label,
      icon: Icon(icon, size: 20),
      label: Text(label),
      backgroundColor: hasSelection 
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      foregroundColor: hasSelection 
          ? Theme.of(context).colorScheme.onPrimaryContainer
          : null,
    );
  }
  
  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategories.clear();
      _selectedCollege = null;
      _clearAllTimes();
      _allCourses.clear();
      _filteredCourses.clear();
      _currentPage = 1;
      _hasSearched = false; // 重置搜尋狀態
    });
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SearchBar(
        controller: _searchController,
        hintText: '課程名稱、教師、課號',
        leading: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(Icons.search),
        ),
        trailing: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() => _searchController.clear());
              },
            ),
        ],
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _loadCourses(),
        elevation: const WidgetStatePropertyAll(1),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  void _clearAllTimes() {
    for (var times in _selectedTimes.values) {
      times.clear();
    }
    setState(() {});
    _timeFilterModalState?.call(() {});
  }

  Widget _buildTimeFilterContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 快速操作按鈕
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.select_all, size: 18),
              label: const Text('全選'),
              onPressed: _selectAllTimes,
            ),
            ActionChip(
              avatar: const Icon(Icons.clear, size: 18),
              label: const Text('清除'),
              onPressed: _clearAllTimes,
            ),
            ActionChip(
              avatar: const Icon(Icons.event_busy, size: 18),
              label: const Text('不選衝堂'),
              onPressed: _deselectConflictTimes,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 時間表
        _buildTimeTable(),
      ],
    );
  }

  Widget _buildTimeTable() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          border: TableBorder.symmetric(
            inside: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
          columnWidths: const {
            0: FixedColumnWidth(40),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
            3: FlexColumnWidth(),
            4: FlexColumnWidth(),
            5: FlexColumnWidth(),
          },
          children: [
            // 標題行
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              children: [
                _buildTimeTableHeaderCell('', null, isTimeSlot: true),
                ..._selectedTimes.keys.map((day) {
                  return _buildTimeTableHeaderCell(day, () => _selectDayTimes(day));
                }),
              ],
            ),
            // 時間行
            ..._timeSlots.map((slot) {
              return TableRow(
                children: [
                  _buildTimeTableHeaderCell(slot, null, isTimeSlot: true),
                  ..._selectedTimes.keys.map((day) {
                    final isSelected = _selectedTimes[day]!.contains(slot);
                    return _buildTimeTableCell(isSelected, () => _toggleTime(day, slot));
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeTableHeaderCell(String text, VoidCallback? onTap, {bool isTimeSlot = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isTimeSlot
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }

  Widget _buildTimeTableCell(bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
        ),
        child: isSelected
            ? Icon(
                Icons.check_circle,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
      ),
    );
  }

  StateSetter? _timeFilterModalState;
  StateSetter? _categoryFilterModalState;
  StateSetter? _collegeFilterModalState;

  void _toggleTime(String day, String time) {
    if (_selectedTimes[day]!.contains(time)) {
      _selectedTimes[day]!.remove(time);
    } else {
      _selectedTimes[day]!.add(time);
    }
    setState(() {});
    _timeFilterModalState?.call(() {});
  }

  void _selectAllTimes() {
    for (final day in _selectedTimes.keys) {
      _selectedTimes[day]!.addAll(_timeSlots);
    }
    setState(() {});
    _timeFilterModalState?.call(() {});
  }

  void _selectDayTimes(String day) {
    _selectedTimes[day]!.addAll(_timeSlots);
    setState(() {});
    _timeFilterModalState?.call(() {});
  }

  void _deselectConflictTimes() {
    if (_userCourses == null || _userCourses!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('沒有找到用戶課表'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    debugPrint('[CourseSearch] 開始解析用戶課表以取消衝堂時間');
    int removedCount = 0;

    for (final course in _userCourses!) {
      final schedule = course['schedule'];

      if (schedule is String && schedule.isNotEmpty) {
        try {
          final scheduleMap = Map<String, dynamic>.from(
            schedule.replaceAll('{', '').replaceAll('}', '').split(',').fold<Map<String, String>>({}, (map, pair) {
              final parts = pair.split(':');
              if (parts.length == 2) {
                final key = parts[0].trim().replaceAll('"', '');
                final value = parts[1].trim().replaceAll('"', '');
                map[key] = value;
              }
              return map;
            })
          );

          scheduleMap.forEach((day, timeStr) {
            if (timeStr is String && timeStr.isNotEmpty) {
              final times = timeStr.split(' ');

              for (final time in times) {
                if (time.isNotEmpty && _selectedTimes.containsKey(day)) {
                  final removed = _selectedTimes[day]?.remove(time);
                  if (removed == true) {
                    removedCount++;
                  }
                }
              }
            }
          });
        } catch (e) {
          debugPrint('[CourseSearch] 解析 schedule 失敗: $e');
        }
      }
    }

    debugPrint('[CourseSearch] 不選衝堂完成,共取消 $removedCount 個時段');

    setState(() {});
    _timeFilterModalState?.call(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已取消選取 $removedCount 個衝堂時段')),
    );
  }

  Widget _buildCategoryFilterContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '選擇一個或多個博雅類別',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categoryList.entries.map((entry) {
            final isSelected = _selectedCategories.contains(entry.value);
            return FilterChip(
              label: Text(
                entry.key,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _selectedCategories.add(entry.value);
                } else {
                  _selectedCategories.remove(entry.value);
                }
                setState(() {});
                _categoryFilterModalState?.call(() {});
              },
              showCheckmark: false,
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCollegeFilterContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '選擇一個學院',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _collegeList.map((college) {
            final isSelected = _selectedCollege == college;
            return ChoiceChip(
              label: Text(
                college,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                _selectedCollege = selected ? college : null;
                setState(() {});
                _collegeFilterModalState?.call(() {});
              },
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Widget> _buildResultsSlivers() {
    if (_isLoading) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  '搜尋中...',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    // 如果還沒搜尋過,顯示初始提示
    if (!_hasSearched) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.manage_search,
                    size: 80,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '開始搜尋課程',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '輸入關鍵字或點擊右下角按鈕\n設定篩選條件或選擇班級',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    // 已搜尋但無結果
    if (_filteredCourses.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 80,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '沒有找到符合的課程',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '試試調整搜尋條件或篩選器',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    // 有結果時顯示列表
    return [
      // 搜尋結果統計
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.list_alt,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '找到 ${_filteredCourses.length} 筆課程',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              if (_totalPages > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_currentPage/$_totalPages',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
      
      // 分頁器（上方）
      if (_totalPages > 1) SliverToBoxAdapter(child: _buildPaginationBar()),
      
      // 課程列表
      SliverPadding(
        padding: const EdgeInsets.all(8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final course = _currentPageCourses[index];
              
              // 從新 API 格式解析資料
              final name = course['name'] is Map 
                  ? (course['name']['zh'] ?? course['name']['en'] ?? '')
                  : course['name']?.toString() ?? '';
              final courseId = course['id']?.toString() ?? ''; // 課號應該使用 id 欄位（六位數）
              final credit = course['credit']?.toString() ?? '';
              final hours = course['hours']?.toString() ?? '';
              
              // 解析教師列表
              final teachers = course['teacher'] is List 
                  ? (course['teacher'] as List).map((t) => t['name']?.toString() ?? '').join('、')
                  : '';
              
              // 解析班級列表
              final classes = course['class'] is List 
                  ? (course['class'] as List).map((c) => c['name']?.toString() ?? '').join('、')
                  : '';
              
              // 解析上課時間
              String timeText = '';
              if (course['time'] is Map) {
                final timeMap = course['time'] as Map;
                final List<String> timeParts = [];
                const dayNames = {'mon': '一', 'tue': '二', 'wed': '三', 'thu': '四', 'fri': '五'};
                dayNames.forEach((eng, chi) {
                  final periods = timeMap[eng];
                  if (periods is List && periods.isNotEmpty) {
                    timeParts.add('$chi ${periods.join('')}');
                  }
                });
                timeText = timeParts.join('、');
              }
              
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                child: InkWell(
                  onTap: () {
                    CourseDetailDialog.show(context, course);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildInfoChip(Icons.numbers, courseId),
                            if (credit.isNotEmpty)
                              _buildInfoChip(Icons.school, '$credit 學分'),
                            if (hours.isNotEmpty)
                              _buildInfoChip(Icons.schedule, '$hours 小時'),
                          ],
                        ),
                        if (teachers.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow(Icons.person, teachers),
                        ],
                        if (classes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _buildInfoRow(Icons.class_, classes),
                        ],
                        if (timeText.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _buildInfoRow(
                            Icons.access_time,
                            timeText,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
            },
            childCount: _currentPageCourses.length,
          ),
        ),
      ),
      
      // 分頁器（下方）
      if (_totalPages > 1) SliverToBoxAdapter(child: _buildPaginationBar()),
    ];
  }
  
  void _goToPage(int page) {
    setState(() {
      _currentPage = page.clamp(1, _totalPages);
    });
  }

  Widget _buildPaginationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filledTonal(
            icon: const Icon(Icons.first_page),
            onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
            tooltip: '第一頁',
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
            tooltip: '上一頁',
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_currentPage / $_totalPages',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton.filledTonal(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
            tooltip: '下一頁',
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            icon: const Icon(Icons.last_page),
            onPressed: _currentPage < _totalPages ? () => _goToPage(_totalPages) : null,
            tooltip: '最後一頁',
          ),
        ],
      ),
    );
  }

  
  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

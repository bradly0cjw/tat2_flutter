import 'package:flutter/material.dart';
import '../services/ntut_api_service.dart';

/// 課程詳細資訊 Bottom Sheet
class CourseDetailDialog extends StatefulWidget {
  final Map<String, dynamic> course;

  const CourseDetailDialog({
    super.key,
    required this.course,
  });

  /// 顯示課程詳細資訊 Bottom Sheet
  static void show(BuildContext context, Map<String, dynamic> course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CourseDetailDialog(course: course),
    );
  }

  @override
  State<CourseDetailDialog> createState() => _CourseDetailDialogState();
}

class _CourseDetailDialogState extends State<CourseDetailDialog> {
  List<Map<String, dynamic>>? _courseDetails;
  bool _isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    _loadCourseDetail();
  }

  Future<void> _loadCourseDetail() async {
    try {
      final courseId = widget.course['id']?.toString() ?? '';
      if (courseId.isEmpty) {
        setState(() => _isLoadingDetails = false);
        return;
      }

      final apiService = NtutApiService();
      final response = await apiService.getCourseDetail(courseId);
      
      if (response != null && response['success'] == true) {
        setState(() {
          _courseDetails = (response['data'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isLoadingDetails = false;
        });
        debugPrint('[CourseDetail] 載入課程 $courseId: ${_courseDetails!.length} 位教師');
      } else {
        setState(() => _isLoadingDetails = false);
        debugPrint('[CourseDetail] 課程 $courseId 沒有詳細資料');
      }
    } catch (e) {
      debugPrint('[CourseDetail] 載入詳細資料失敗: $e');
      setState(() => _isLoadingDetails = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    // 解析課程資料
    final name = course['name'] is Map 
        ? (course['name']['zh'] ?? course['name']['en'] ?? '')
        : course['name']?.toString() ?? '';
    final nameEn = course['name'] is Map 
        ? (course['name']['en'] ?? '')
        : '';
    final courseId = course['id']?.toString() ?? '';
    final credit = course['credit']?.toString() ?? '';
    final hours = course['hours']?.toString() ?? '';
    final courseType = course['courseType']?.toString() ?? '';
    final notes = course['notes']?.toString() ?? '';
    final people = course['people']?.toString() ?? '';
    final peopleWithdraw = course['peopleWithdraw']?.toString() ?? '0';
    
    // 解析教師列表
    final teachers = course['teacher'] is List 
        ? (course['teacher'] as List).map((t) => t['name']?.toString() ?? '').toList()
        : <String>[];
    
    // 解析班級列表
    final classes = course['class'] is List 
        ? (course['class'] as List).map((c) => c['name']?.toString() ?? '').toList()
        : <String>[];
    
    // 解析上課時間
    final Map<String, List<String>> timeData = {};
    if (course['time'] is Map) {
      final timeMap = course['time'] as Map;
      const dayNames = {
        'mon': '星期一',
        'tue': '星期二',
        'wed': '星期三',
        'thu': '星期四',
        'fri': '星期五',
      };
      dayNames.forEach((eng, chi) {
        final periods = timeMap[eng];
        if (periods is List && periods.isNotEmpty) {
          timeData[chi] = periods.map((p) => p.toString()).toList();
        }
      });
    }
    
    // 解析課程描述
    final description = course['description'] is Map
        ? (course['description']['zh'] ?? course['description']['en'] ?? '')
        : course['description']?.toString() ?? '';
    
    // 解析教室列表
    final classrooms = course['classroom'] is List 
        ? (course['classroom'] as List).map((c) {
            if (c is Map) {
              return c['name']?.toString() ?? '';
            }
            return c.toString();
          }).where((name) => name.isNotEmpty).toList()
        : <String>[];
    
    // 解析語言
    final language = course['language']?.toString() ?? '';
    
    // 解析評量標準（從 notes 或其他欄位）
    final evaluation = course['evaluation']?.toString() ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 拖動指示器
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 標題列
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (nameEn.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                nameEn,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '關閉',
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // 內容區
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                  // 基本資訊卡片
                  _buildInfoCard(
                    context,
                    icon: Icons.info_outline,
                    title: '基本資訊',
                    children: [
                      _buildInfoRow('課號', courseId),
                      _buildInfoRow('學分', credit),
                      _buildInfoRow('時數', hours),
                      if (courseType.isNotEmpty)
                        _buildInfoRow('課程標準', courseType),
                      if (people.isNotEmpty)
                        _buildInfoRow('人數', people),
                      if (int.tryParse(peopleWithdraw) != null && int.parse(peopleWithdraw) > 0)
                        _buildInfoRow('退選', peopleWithdraw),
                      if (language.isNotEmpty)
                        _buildInfoRow('授課語言', language),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 教師資訊
                  if (teachers.isNotEmpty)
                    _buildInfoCard(
                      context,
                      icon: Icons.person,
                      title: '授課教師',
                      children: [
                        _buildChipList(teachers),
                      ],
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // 班級資訊
                  if (classes.isNotEmpty)
                    _buildInfoCard(
                      context,
                      icon: Icons.groups,
                      title: '開課班級',
                      children: [
                        _buildChipList(classes),
                      ],
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // 上課時間和地點
                  if (timeData.isNotEmpty || classrooms.isNotEmpty)
                    _buildInfoCard(
                      context,
                      icon: Icons.schedule,
                      title: '上課時間與地點',
                      children: [
                        if (timeData.isNotEmpty)
                          ...timeData.entries.map((entry) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      entry.key,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      entry.value.join(' '),
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        if (classrooms.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(top: timeData.isNotEmpty ? 4 : 0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.room,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    classrooms.join('、'),
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // 課程描述
                  if (description.isNotEmpty)
                    _buildInfoCard(
                      context,
                      icon: Icons.description,
                      title: '課程概述',
                      children: [
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // 評分規則（從課程詳細資料載入）
                  _buildInfoCard(
                    context,
                    icon: Icons.assignment,
                    title: '評分規則',
                    children: [
                      if (_isLoadingDetails)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '載入中...',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_courseDetails != null && _courseDetails!.isNotEmpty)
                        ..._courseDetails!.asMap().entries.map((entry) {
                          final index = entry.key;
                          final detail = entry.value;
                          final teacherName = detail['name'] ?? '未知教師';
                          final scorePolicy = detail['scorePolicy'] ?? '';
                          
                          return Container(
                            margin: EdgeInsets.only(top: index > 0 ? 12 : 0),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: scorePolicy.isEmpty 
                                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                                  : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: scorePolicy.isEmpty
                                    ? Theme.of(context).colorScheme.outlineVariant
                                    : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_courseDetails!.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          teacherName,
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Text(
                                  scorePolicy.isNotEmpty 
                                      ? scorePolicy 
                                      : '此教師未提供評分規則',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.6,
                                    color: scorePolicy.isEmpty 
                                        ? Theme.of(context).colorScheme.onSurfaceVariant
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontStyle: scorePolicy.isEmpty ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '此課程目前無課程大綱資訊',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 備註
                  if (notes.isNotEmpty)
                    _buildInfoCard(
                      context,
                      icon: Icons.note,
                      title: '備註',
                      children: [
                        Text(
                          notes,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  
                  // 底部留白
                  const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon, 
                  size: 20, 
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon, 
          size: 18, 
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipList(List<String> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }
}

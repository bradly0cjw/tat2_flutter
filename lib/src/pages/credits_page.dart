import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/course_credit_models.dart';
import '../services/credits_service.dart';
import '../core/auth/auth_manager.dart';
import '../widgets/graduation_settings_dialog.dart';

/// 學分計算頁面（M3 設計，功能按照 TAT）
class CreditsPage extends StatefulWidget {
  const CreditsPage({super.key});

  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage> {
  CreditStatistics? _stats;
  bool _isLoading = true;
  String? _errorMessage;
  double _loadingProgress = 0.0;
  String _loadingMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCreditStatistics();
  }

  Future<void> _loadCreditStatistics({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadingProgress = 0.0;
      _loadingMessage = '準備載入...';
    });

    try {
      final authManager = context.read<AuthManager>();
      final creditsService = context.read<CreditsService>();
      
      final studentId = authManager.currentCredential?.username;
      if (studentId == null) {
        setState(() {
          _errorMessage = '請先登入';
          _isLoading = false;
        });
        return;
      }

      final stats = await creditsService.getCreditStatistics(
        studentId: studentId,
        forceRefresh: forceRefresh,
        onProgress: (current, total, courseName) {
          // 更新進度（從 0 到 1）
          final progress = current / total;
          setState(() {
            _loadingProgress = progress;
            _loadingMessage = '正在查詢課程資訊... ($current/$total)\n$courseName';
          });
        },
      );

      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '載入失敗: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showSettingsDialog() async {
    final result = await showGraduationSettingsDialog(
      context,
      initialInfo: _stats?.graduationInfo,
    );

    if (result != null) {
      final creditsService = context.read<CreditsService>();
      await creditsService.saveGraduationInformation(result);
      await _loadCreditStatistics(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.credits),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadCreditStatistics(forceRefresh: true),
            tooltip: '重新整理',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: '設定畢業標準',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 圓形進度指示器
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              
              // 線性進度條
              LinearProgressIndicator(
                value: _loadingProgress,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              
              // 進度文字
              Text(
                _loadingMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // 進度百分比
              Text(
                '${(_loadingProgress * 100).toInt()}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadCreditStatistics,
              icon: const Icon(Icons.refresh),
              label: const Text('重試'),
            ),
          ],
        ),
      );
    }

    if (_stats == null) {
      return const Center(
        child: Text('暫無資料'),
      );
    }

    // 如果未設定畢業標準，顯示提示
    if (!_stats!.graduationInfo.isSelected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_outlined, size: 64),
            const SizedBox(height: 16),
            const Text('請先設定畢業標準'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _showSettingsDialog,
              icon: const Icon(Icons.settings),
              label: const Text('設定畢業標準'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadCreditStatistics(forceRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 學分總覽卡片（對應 TAT 的 _summaryTile）
            _buildSummaryCard(),
            const SizedBox(height: 16),

            // 各類課程學分卡片
            _buildCourseTypesCard(),
            const SizedBox(height: 16),

            // 博雅學分卡片（對應 TAT 的 _generalLessonItemTile）
            _buildGeneralLessonCard(),
            const SizedBox(height: 16),

            // 外系學分卡片（對應 TAT 的 _otherDepartmentItemTile）
            _buildOtherDepartmentCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// 學分總覽卡片（對應 TAT 的 _summaryTile）
  Widget _buildSummaryCard() {
    final stats = _stats!;
    final needed = stats.creditsNeededForGraduation;
    final progress = stats.totalCredits / stats.graduationInfo.lowCredit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.school_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '學分總覽',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    label: '已修學分',
                    value: '${stats.totalCredits}',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    label: '畢業門檻',
                    value: '${stats.graduationInfo.lowCredit}',
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                if (needed > 0)
                  Expanded(
                    child: _buildStatItem(
                      label: '還需',
                      value: '$needed',
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // 進度條
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '進度',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${(progress * 100).clamp(0, 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// 各類課程學分卡片（對應 TAT 的 constCourseType 顯示）
  Widget _buildCourseTypesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '各類課程學分',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ..._buildCourseTypeItems(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCourseTypeItems() {
    const names = {
      "○": "部訂共同必修",
      "△": "校訂共同必修",
      "☆": "共同選修",
      "●": "部訂專業必修",
      "▲": "校訂專業必修",
      "★": "專業選修",
    };

    return courseTypes.map((type) {
      final nowCredit = _stats!.getCreditByType(type);
      final minCredit = _stats!.graduationInfo.courseTypeMinCredit[type] ?? 0;
      
      // 如果上限為0且學分也為0，跳過不顯示
      if (minCredit == 0 && nowCredit == 0) {
        return const SizedBox.shrink();
      }
      
      final progress = minCredit > 0 ? (nowCredit / minCredit).clamp(0.0, 1.0) : 1.0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showCourseTypeDetail(type, names[type]!),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('$type ${names[type]}'),
                  ),
                  Text(
                    '$nowCredit / $minCredit',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showCourseTypeDetail(String type, String typeName) {
    final courses = _stats!.getCoursesByType(type);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$type $typeName'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return ListTile(
                title: Text(course.nameZh),
                subtitle: Text(course.openClass),
                trailing: Text('${course.credit.toInt()}學分'),
              );
            },
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

  /// 博雅學分卡片（根據學院需求顯示）
  Widget _buildGeneralLessonCard() {
    final generalCredits = _stats!.coreGeneralLessonCredits + _stats!.selectGeneralLessonCredits;
    final minCredits = 15; // 博雅學分最低要求 15 學分
    final progress = generalCredits / minCredits;
    
    // 取得各向度學分
    final dimensionCredits = _stats!.generalLessonCreditsByDimension;
    
    // 取得學院要求
    final requirement = _stats!.collegeBoyaRequirement;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showGeneralLessonDetail(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題與狀態
              Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '博雅學分',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        // 顯示學院
                        if (requirement != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            requirement.college.displayName,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 總學分進度
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已修 $generalCredits / 需求 $minCredits',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${(progress * 100).clamp(0, 100).toInt()}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),

              // 顯示各向度
              if (dimensionCredits.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                
                // 如果有學院要求，分成必修和選修
                if (requirement != null) ...[
                  // 必修向度
                  ...requirement.requiredDimensions.entries.map((entry) {
                    final dimension = entry.key;
                    final required = entry.value;
                    final actual = dimensionCredits[dimension] ?? 0;
                    final progress = required > 0 ? (actual / required).clamp(0.0, 1.0) : 1.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  dimension.replaceAll('向度', ''),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                '$actual / $required',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  
                  // 自由選修（與其他向度同層級）
                  Builder(builder: (context) {
                    final mandatoryCredits = requirement.requiredDimensions.entries
                        .fold<int>(0, (sum, entry) => sum + (dimensionCredits[entry.key] ?? 0));
                    final totalCredits = generalCredits;
                    final freeChoiceCredits = (totalCredits - mandatoryCredits).clamp(0, requirement.freeChoice);
                    final freeChoiceRequired = requirement.freeChoice;
                    final progress = freeChoiceRequired > 0 ? (freeChoiceCredits / freeChoiceRequired).clamp(0.0, 1.0) : 1.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '自由選修',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                '$freeChoiceCredits / $freeChoiceRequired',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ),
                    );
                  }),
                ]
                // 沒有學院要求時，顯示所有向度
                else ...[
                  ...dimensionCredits.entries.map((entry) {
                    final required = 4; // 一般向度需求為4學分
                    final actual = entry.value;
                    final progress = (actual / required).clamp(0.0, 1.0);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key.replaceAll('向度', ''),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                '$actual / $required',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showGeneralLessonDetail() {
    final courses = _stats!.generalLessonCourses;
    final dimensionCredits = _stats!.generalLessonCreditsByDimension;
    final requirement = _stats!.collegeBoyaRequirement;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('博雅學分詳情'),
            if (requirement != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  requirement.college.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 按向度分組顯示所有課程
                ...dimensionCredits.entries.map((entry) {
                  final dimension = entry.key;
                  final credit = entry.value;
                  final dimensionCourses = courses.where((c) => 
                    c.generalLessonDimension == dimension
                  ).toList();
                  
                  // 判斷是否為必修向度
                  final isRequired = requirement?.requiredDimensions.containsKey(dimension) ?? false;
                  final required = isRequired ? (requirement!.requiredDimensions[dimension] ?? 4) : 4;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          '${dimension.replaceAll('向度', '')} ($credit / $required 學分)',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      ...dimensionCourses.map((course) => Padding(
                            padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    course.nameZh,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  '${course.credit.toInt()}學分',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          )).toList(),
                      const Divider(),
                    ],
                  );
                }).toList(),
                
                // 總計
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '總計',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '${courses.fold(0, (sum, c) => sum + c.credit.toInt())} 學分',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

  /// 外系學分卡片（對應 TAT 的 _otherDepartmentItemTile）
  Widget _buildOtherDepartmentCard() {
    final otherCredits = _stats!.otherDepartmentCredits;
    final maxCredits = _stats!.graduationInfo.outerDepartmentMaxCredit;
    final progress = maxCredits > 0 ? (otherCredits / maxCredits).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOtherDepartmentDetail(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.swap_horiz,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '外系學分',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已修 $otherCredits / 上限 $maxCredits',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOtherDepartmentDetail() {
    final courses = _stats!.getOtherDepartmentCourses();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('外系學分'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return ListTile(
                title: Text(course.nameZh),
                subtitle: Text(course.openClass),
                trailing: Text('${course.credit.toInt()}學分'),
              );
            },
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
}

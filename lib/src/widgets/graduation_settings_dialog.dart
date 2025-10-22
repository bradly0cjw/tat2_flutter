import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_credit_models.dart';
import '../services/credits_service.dart';
import '../core/auth/auth_manager.dart';

/// 畢業學分標準設定對話框（M3 設計，功能完全按照 TAT 的 GraduationPicker）
class GraduationSettingsDialog extends StatefulWidget {
  final GraduationInformation? initialInfo;

  const GraduationSettingsDialog({
    super.key,
    this.initialInfo,
  });

  @override
  State<GraduationSettingsDialog> createState() =>
      _GraduationSettingsDialogState();
}

class _GraduationSettingsDialogState extends State<GraduationSettingsDialog> {
  bool _isLoading = true;
  bool _isLoadingDivisions = false;
  bool _isLoadingDepartments = false;
  String? _error;

  // 完全按照 TAT 的三級選單
  List<String> _yearList = [];
  List<Map<String, dynamic>> _divisionList = [];
  List<Map<String, dynamic>> _departmentList = [];

  String? _selectedYear;
  String? _selectedDivisionName; // 改用 String 來追蹤
  String? _selectedDepartmentName; // 改用 String 來追蹤

  GraduationInformation? _graduationInfo;

  @override
  void initState() {
    super.initState();
    _graduationInfo = widget.initialInfo;
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final creditsService = context.read<CreditsService>();
      final authManager = context.read<AuthManager>();

      // 1. 獲取學年度列表（對應 TAT 的 _getYearList）
      _yearList = await creditsService.getYearList();

      // 2. 預設學年度（從學號推斷，對應 TAT 的邏輯）
      if (_graduationInfo == null || _graduationInfo!.selectYear.isEmpty) {
        final studentId = authManager.currentCredential?.username ?? '';
        if (studentId.length >= 3) {
          final yearFromId = studentId.substring(0, 3);
          for (final year in _yearList) {
            if (year.contains(yearFromId)) {
              _selectedYear = year;
              break;
            }
          }
        }
      } else {
        _selectedYear = _yearList.firstWhere(
          (y) => y.contains(_graduationInfo!.selectYear),
          orElse: () => _yearList.first,
        );
      }

      if (_selectedYear == null && _yearList.isNotEmpty) {
        _selectedYear = _yearList.first;
      }

      // 3. 獲取學制列表（對應 TAT 的 _getDivisionList）
      if (_selectedYear != null) {
        await _loadDivisionList();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '載入失敗: $e';
      });
    }
  }

  Future<void> _loadDivisionList() async {
    setState(() {
      _isLoadingDivisions = true;
    });
    
    try {
      final creditsService = context.read<CreditsService>();
      // 從 " 113 學年度入學" 這樣的格式中提取 "113"
      // 使用正則表達式提取數字部分
      final yearMatch = RegExp(r'\d+').firstMatch(_selectedYear!);
      final year = yearMatch?.group(0) ?? '';
      
      _divisionList = await creditsService.getDivisionList(year);

      // 預設選擇
      if (_graduationInfo != null && _graduationInfo!.selectDivision.isNotEmpty) {
        final division = _divisionList.firstWhere(
          (d) => d['name'].toString().contains(_graduationInfo!.selectDivision),
          orElse: () => _divisionList.first,
        );
        _selectedDivisionName = division['name'] as String;
      } else if (_divisionList.isNotEmpty) {
        _selectedDivisionName = _divisionList.first['name'] as String;
      }

      // 載入系所列表
      if (_selectedDivisionName != null) {
        await _loadDepartmentList();
      }

      setState(() {
        _isLoadingDivisions = false;
      }); // 更新 UI
    } catch (e) {
      print('[GraduationSettings] 載入學制列表失敗: $e');
      setState(() {
        _isLoadingDivisions = false;
      });
    }
  }

  Future<void> _loadDepartmentList() async {
    setState(() {
      _isLoadingDepartments = true;
    });
    
    try {
      final creditsService = context.read<CreditsService>();
      
      final selectedDivision = _divisionList.firstWhere(
        (d) => d['name'] == _selectedDivisionName,
      );
      final code = Map<String, String>.from(selectedDivision['code'] as Map);

      _departmentList = await creditsService.getDepartmentList(code);

      // 預設選擇
      if (_graduationInfo != null && _graduationInfo!.selectDepartment.isNotEmpty) {
        final department = _departmentList.firstWhere(
          (d) => d['name'].toString().contains(_graduationInfo!.selectDepartment),
          orElse: () => _departmentList.first,
        );
        _selectedDepartmentName = department['name'] as String;
      } else if (_departmentList.isNotEmpty) {
        _selectedDepartmentName = _departmentList.first['name'] as String;
      }

      // 獲取課程標準
      if (_selectedDepartmentName != null) {
        await _loadCreditInfo();
      }

      setState(() {
        _isLoadingDepartments = false;
      }); // 更新 UI
    } catch (e) {
      print('[GraduationSettings] 載入系所列表失敗: $e');
      setState(() {
        _isLoadingDepartments = false;
      });
    }
  }

  Future<void> _loadCreditInfo() async {
    try {
      final creditsService = context.read<CreditsService>();
      final selectedDivision = _divisionList.firstWhere(
        (d) => d['name'] == _selectedDivisionName,
      );
      final code = Map<String, String>.from(selectedDivision['code'] as Map);

      final info = await creditsService.getCreditInfo(code, _selectedDepartmentName!);

      if (info != null) {
        setState(() {
          _graduationInfo = GraduationInformation(
            selectYear: _selectedYear ?? '',
            selectDivision: _selectedDivisionName!,
            selectDepartment: _selectedDepartmentName!,
            lowCredit: info.lowCredit,
            outerDepartmentMaxCredit: info.outerDepartmentMaxCredit,
            courseTypeMinCredit: info.courseTypeMinCredit,
          );
        });
      }
    } catch (e) {
      print('[GraduationSettings] 載入課程標準失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('畢業學分標準設定'),
      content: _buildContent(),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _graduationInfo != null && _graduationInfo!.isSelected
              ? () => Navigator.of(context).pop(_graduationInfo)
              : null,
          child: const Text('儲存'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        width: 300,
        height: 200,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return SizedBox(
        width: 300,
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 學年度下拉選單
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: '學年度',
              border: OutlineInputBorder(),
            ),
            value: _selectedYear,
            items: _yearList.map((year) {
              return DropdownMenuItem(
                value: year,
                child: Text(year),
              );
            }).toList(),
            onChanged: (value) async {
              setState(() {
                _selectedYear = value;
                _divisionList = [];
                _departmentList = [];
                _selectedDivisionName = null;
                _selectedDepartmentName = null;
              });
              if (value != null) {
                await _loadDivisionList();
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 16),

          // 學制下拉選單
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: '學制',
              border: const OutlineInputBorder(),
              suffixIcon: _isLoadingDivisions
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            isExpanded: true, // 讓下拉選單占滿寬度
            value: _selectedDivisionName,
            items: _divisionList.map((division) {
              final name = division['name'] as String;
              return DropdownMenuItem(
                value: name,
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis, // 文字過長時顯示省略號
                ),
              );
            }).toList(),
            onChanged: _isLoadingDivisions ? null : (value) async {
              if (value != null) {
                setState(() {
                  _selectedDivisionName = value;
                  _departmentList = [];
                  _selectedDepartmentName = null;
                });
                await _loadDepartmentList();
              }
            },
          ),
          const SizedBox(height: 16),

          // 系所下拉選單
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: '系所',
              border: const OutlineInputBorder(),
              suffixIcon: _isLoadingDepartments
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            isExpanded: true, // 讓下拉選單占滿寬度
            value: _selectedDepartmentName,
            items: _departmentList.map((department) {
              final name = department['name'] as String;
              return DropdownMenuItem(
                value: name,
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis, // 文字過長時顯示省略號
                ),
              );
            }).toList(),
            onChanged: _isLoadingDepartments ? null : (value) async {
              if (value != null) {
                setState(() {
                  _selectedDepartmentName = value;
                });
                await _loadCreditInfo();
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// 顯示畢業學分標準設定對話框
Future<GraduationInformation?> showGraduationSettingsDialog(
  BuildContext context, {
  GraduationInformation? initialInfo,
}) {
  return showDialog<GraduationInformation>(
    context: context,
    barrierDismissible: false,
    builder: (context) => GraduationSettingsDialog(
      initialInfo: initialInfo,
    ),
  );
}

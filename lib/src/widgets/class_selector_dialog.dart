import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ntut_api_service.dart';

/// 班級/學程選擇器對話框
/// 整合三種查詢方式：
/// 1. 班級選擇（學院 → 系所 → 班級）
/// 2. 微學程查詢
/// 3. 學程查詢（未來擴展）
class ClassSelectorDialog extends StatefulWidget {
  final String year;
  final String semester;
  final Function(List<Map<String, dynamic>> courses, String title) onCoursesSelected;

  const ClassSelectorDialog({
    super.key,
    required this.year,
    required this.semester,
    required this.onCoursesSelected,
  });

  @override
  State<ClassSelectorDialog> createState() => _ClassSelectorDialogState();
}

class _ClassSelectorDialogState extends State<ClassSelectorDialog> {
  int _selectedTabIndex = 0; // 0: 班級, 1: 學程/微學程
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 標題
            Row(
              children: [
                const Text(
                  '選擇班級或學程',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Tab 選擇
            ToggleButtons(
              isSelected: [_selectedTabIndex == 0, _selectedTabIndex == 1],
              onPressed: (index) {
                setState(() => _selectedTabIndex = index);
              },
              borderRadius: BorderRadius.circular(8),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text('班級'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text('微學程'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 內容區域
            Expanded(
              child: _selectedTabIndex == 0
                  ? _ClassSelector(
                      year: widget.year,
                      semester: widget.semester,
                      onCoursesSelected: widget.onCoursesSelected,
                    )
                  : _ProgramSelector(
                      year: widget.year,
                      semester: widget.semester,
                      onCoursesSelected: widget.onCoursesSelected,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 班級選擇器（學院 → 系所 → 班級）
class _ClassSelector extends StatefulWidget {
  final String year;
  final String semester;
  final Function(List<Map<String, dynamic>> courses, String title) onCoursesSelected;

  const _ClassSelector({
    required this.year,
    required this.semester,
    required this.onCoursesSelected,
  });

  @override
  State<_ClassSelector> createState() => _ClassSelectorState();
}

class _ClassSelectorState extends State<_ClassSelector> {
  bool _isLoading = true;
  List<dynamic> _colleges = []; // 學院列表
  String? _selectedCollege; // 選中的學院
  List<dynamic> _departments = []; // 當前學院的系所列表
  String? _selectedDepartment; // 選中的系所
  List<dynamic> _grades = []; // 當前系所的班級列表

  @override
  void initState() {
    super.initState();
    _loadColleges();
  }

  Future<void> _loadColleges() async {
    setState(() => _isLoading = true);
    
    try {
      final api = context.read<NtutApiService>();
      final structure = await api.getColleges(
        year: widget.year,
        semester: widget.semester,
      );
      
      debugPrint('[ClassSelector] 載入學院結構');
      
      if (structure != null && structure['colleges'] != null) {
        setState(() {
          _colleges = structure['colleges'] as List;
          _isLoading = false;
        });
        debugPrint('[ClassSelector] 載入 ${_colleges.length} 個學院');
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('載入學院結構失敗'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ClassSelector] 載入學院結構失敗: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('錯誤:$e')),
        );
      }
    }
  }

  void _onCollegeSelected(String collegeName) {
    final college = _colleges.firstWhere(
      (c) => c['name'] == collegeName,
      orElse: () => null,
    );
    
    if (college != null && college['departments'] != null) {
      setState(() {
        _selectedCollege = collegeName;
        _departments = college['departments'] as List;
        _selectedDepartment = null;
        _grades = [];
      });
    }
  }

  void _onDepartmentSelected(String departmentName) {
    final dept = _departments.firstWhere(
      (d) => d['name'] == departmentName,
      orElse: () => null,
    );
    
    if (dept != null && dept['grades'] != null) {
      setState(() {
        _selectedDepartment = departmentName;
        _grades = dept['grades'] as List;
      });
    }
  }

  Future<void> _loadCoursesByGrade(String gradeCode, String gradeName) async {
    setState(() => _isLoading = true);
    
    try {
      final api = context.read<NtutApiService>();
      final courses = await api.getCoursesByGrade(
        gradeCode: gradeCode,
        year: widget.year,
        semester: widget.semester,
      );
      
      setState(() => _isLoading = false);
      
      if (courses.isNotEmpty) {
        widget.onCoursesSelected(courses, gradeName);
        Navigator.of(context).pop();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$gradeName 沒有開課資料')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入課程失敗：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 學院下拉選單
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: '學院',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          value: _selectedCollege,
          hint: const Text('請選擇學院'),
          items: _colleges.map((college) {
            final collegeName = college['name']?.toString() ?? '';
            return DropdownMenuItem<String>(
              value: collegeName,
              child: Text(collegeName),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              _onCollegeSelected(value);
            }
          },
        ),
        const SizedBox(height: 16),
        
        // 系所下拉選單
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: '系所',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          value: _selectedDepartment,
          hint: const Text('請先選擇學院'),
          items: _departments.map((dept) {
            final deptName = dept['name']?.toString() ?? '';
            return DropdownMenuItem<String>(
              value: deptName,
              child: Text(deptName),
            );
          }).toList(),
          onChanged: _selectedCollege == null
              ? null
              : (value) {
                  if (value != null) {
                    _onDepartmentSelected(value);
                  }
                },
        ),
        const SizedBox(height: 16),
        
        // 班級列表（保持列表形式，因為可能有很多班級）
        Expanded(
          child: _selectedDepartment == null
              ? Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      '請先選擇系所',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _grades.length,
                    itemBuilder: (context, index) {
                      final grade = _grades[index];
                      final gradeName = grade['name']?.toString() ?? '';
                      final gradeId = grade['id']?.toString() ?? '';
                      
                      return ListTile(
                        title: Text(gradeName),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _loadCoursesByGrade(gradeId, gradeName),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// 學程/微學程選擇器
class _ProgramSelector extends StatefulWidget {
  final String year;
  final String semester;
  final Function(List<Map<String, dynamic>> courses, String title) onCoursesSelected;

  const _ProgramSelector({
    required this.year,
    required this.semester,
    required this.onCoursesSelected,
  });

  @override
  State<_ProgramSelector> createState() => _ProgramSelectorState();
}

class _ProgramSelectorState extends State<_ProgramSelector> {
  bool _isLoading = true;
  List<dynamic> _programs = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    setState(() => _isLoading = true);
    
    try {
      final api = context.read<NtutApiService>();
      final structure = await api.getPrograms(
        year: widget.year,
        semester: widget.semester,
      );
      
      debugPrint('[ClassSelector] 載入學程結構');
      
      if (structure != null && structure['programs'] != null) {
        setState(() {
          _programs = structure['programs'] as List;
          _isLoading = false;
        });
        debugPrint('[ClassSelector] 載入 ${_programs.length} 個微學程');
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('載入微學程列表失敗'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ClassSelector] 載入微學程失敗: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('錯誤:$e')),
        );
      }
    }
  }

  Future<void> _loadCoursesByProgram(String programCode, String programName) async {
    setState(() => _isLoading = true);
    
    try {
      final api = context.read<NtutApiService>();
      final courses = await api.getCoursesByProgram(
        programCode: programCode,
        type: 'micro-program', // 目前都是微學程
        year: widget.year,
        semester: widget.semester,
      );
      
      setState(() => _isLoading = false);
      
      if (courses.isNotEmpty) {
        widget.onCoursesSelected(courses, programName);
        Navigator.of(context).pop();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$programName 沒有開課資料')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入課程失敗：$e')),
        );
      }
    }
  }

  List<dynamic> get _filteredPrograms {
    if (_searchQuery.isEmpty) return _programs;
    return _programs.where((p) {
      final name = p['name']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 搜尋框
        TextField(
          decoration: InputDecoration(
            hintText: '搜尋學程名稱',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
        const SizedBox(height: 16),
        
        // 學程列表
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: _filteredPrograms.length,
              itemBuilder: (context, index) {
                final program = _filteredPrograms[index];
                final programName = program['name']?.toString() ?? '';
                final programId = program['id']?.toString() ?? '';
                final courseCount = (program['course'] as List?)?.length ?? 0;
                
                return ListTile(
                  title: Text(programName),
                  subtitle: Text('$courseCount 門課程'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _loadCoursesByProgram(programId, programName),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

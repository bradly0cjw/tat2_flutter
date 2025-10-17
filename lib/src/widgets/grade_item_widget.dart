import 'package:flutter/material.dart';
import '../models/grade.dart';

/// 單筆成績項目 Widget
class GradeItemWidget extends StatelessWidget {
  final Grade grade;
  final VoidCallback? onTap;

  const GradeItemWidget({
    super.key,
    required this.grade,
    this.onTap,
  });

  Color _getGradeColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    switch (grade.gradeColor) {
      case GradeColor.excellent:
        return isDark ? Colors.green.shade300 : Colors.green.shade700;
      case GradeColor.good:
        return isDark ? Colors.blue.shade300 : Colors.blue.shade700;
      case GradeColor.average:
        return isDark ? Colors.orange.shade300 : Colors.orange.shade700;
      case GradeColor.poor:
        return isDark ? Colors.red.shade300 : Colors.red.shade700;
      case GradeColor.unknown:
        return colorScheme.onSurfaceVariant;
    }
  }

  String _getGradeText() {
    if (grade.grade != null && grade.grade!.isNotEmpty) {
      return grade.grade!;
    }
    if (grade.gradePoint != null) {
      return grade.gradePoint!.toStringAsFixed(1);
    }
    return '--';
  }

  String _getCreditsText() {
    if (grade.credits != null) {
      return grade.credits!.toStringAsFixed(1);
    }
    return '--';
  }

  @override
  Widget build(BuildContext context) {
    final gradeColor = _getGradeColor(context);
    
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // 課程名稱
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grade.courseName,
                    style: Theme.of(context).textTheme.bodyLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (grade.courseId.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        grade.courseId,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            // 學分
            Expanded(
              flex: 1,
              child: Text(
                _getCreditsText(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            
            // 成績
            Container(
              width: 60,
              alignment: Alignment.center,
              child: Text(
                _getGradeText(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: gradeColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 成績列表標題
class GradeListHeader extends StatelessWidget {
  const GradeListHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '課程名稱',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Text(
              '學分',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              '成績',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

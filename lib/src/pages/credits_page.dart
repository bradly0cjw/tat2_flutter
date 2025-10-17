import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 學分計算頁面
/// 用於計算學分、規劃課程
class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.credits),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calculate, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('學分計算功能開發中'),
            SizedBox(height: 8),
            Text(
              '規劃課程、計算學分、微學程規劃等功能',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

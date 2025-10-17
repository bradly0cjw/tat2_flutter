import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 美食地圖頁面
class FoodMapPage extends StatelessWidget {
  const FoodMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.foodMap),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 80, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 24),
            const Text(
              '美食地圖',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '探索校園周邊美食\n我需要資料，徵求同學順手拍菜單給我',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

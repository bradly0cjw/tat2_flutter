import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 校園地圖頁面
class CampusMapPage extends StatelessWidget {
  const CampusMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.campusMap),
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.asset(
            'assets/images/NtutMap.jpg',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

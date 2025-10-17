import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 社團公告頁面
class ClubAnnouncementsPage extends StatelessWidget {
  const ClubAnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.clubAnnouncements),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('社團公告功能開發中\n主要也沒東西讓我公告'),
          ],
        ),
      ),
    );
  }
}

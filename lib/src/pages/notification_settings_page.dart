import 'package:flutter/material.dart';
import '../services/badge_service.dart';

/// 通知設定頁面
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _hideAllBadges = false;
  bool _autoCheckISchool = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final hideAll = await BadgeService().isHideAllBadges();
    final autoCheck = await BadgeService().isAutoCheckISchoolEnabled();
    
    setState(() {
      _hideAllBadges = hideAll;
      _autoCheckISchool = autoCheck;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知設定'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // 紅點設定區域
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '紅點通知',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_off),
                  title: const Text('隱藏所有紅點'),
                  subtitle: const Text('隱藏 App 中的所有紅點通知'),
                  value: _hideAllBadges,
                  onChanged: (value) async {
                    await BadgeService().setHideAllBadges(value);
                    setState(() {
                      _hideAllBadges = value;
                    });
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value ? '已隱藏所有紅點' : '已顯示所有紅點'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
                const Divider(),

                // i學院設定區域
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '北科i學園',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                
                SwitchListTile(
                  secondary: const Icon(Icons.sync),
                  title: const Text('自動檢查公告'),
                  subtitle: const Text('登入時自動檢查新公告'),
                  value: _autoCheckISchool,
                  onChanged: (value) async {
                    await BadgeService().setAutoCheckISchool(value);
                    setState(() {
                      _autoCheckISchool = value;
                    });
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value ? '已啟用自動檢查' : '已關閉自動檢查'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
                const Divider(),

              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/navigation_config_service.dart';
import '../services/badge_service.dart';
import 'about_page.dart';
import 'navigation_config_page.dart';
import 'personalization_page.dart';
import 'notification_settings_page.dart';

/// 其他功能頁面 - 動態顯示不在導航列的功能
class OtherFeaturesPage extends StatefulWidget {
  const OtherFeaturesPage({super.key});

  @override
  State<OtherFeaturesPage> createState() => _OtherFeaturesPageState();
}

class _OtherFeaturesPageState extends State<OtherFeaturesPage> {
  @override
  void initState() {
    super.initState();
    // 監聽 BadgeService 變化
    BadgeService().addListener(_onBadgeChanged);
  }

  @override
  void dispose() {
    BadgeService().removeListener(_onBadgeChanged);
    super.dispose();
  }

  void _onBadgeChanged() {
    if (mounted) {
      setState(() {}); // 紅點狀態改變時重新整理
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navConfig = context.watch<NavigationConfigService>();
    final otherFeatures = navConfig.getOtherFeatures();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.other),
      ),
      body: ListView(
        children: [
          // 不在導航列的功能（動態顯示）
          if (otherFeatures.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                l10n.otherFeatures,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ...otherFeatures.map((item) {
              // 如果是 ntut_learn，檢查是否有未讀公告
              if (item.id == 'ntut_learn') {
                return Column(
                  children: [
                    FutureBuilder<bool>(
                      future: BadgeService().hasAnyUnreadInISchool(),
                      builder: (context, snapshot) {
                        final hasUnread = snapshot.data ?? false;
                        return ListTile(
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(item.icon),
                              if (hasUnread)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(item.label),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: item.pageBuilder),
                            );
                          },
                        );
                      },
                    ),
                    const Divider(),
                  ],
                );
              }
              
              // 其他項目保持原樣
              return Column(
                children: [
                  ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: item.pageBuilder),
                      );
                    },
                  ),
                  const Divider(),
                ],
              );
            }),
          ],

          // 設定功能區域
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.settings,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          
          // 通知設定
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('通知設定'),
            subtitle: const Text('管理紅點通知與自動檢查'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsPage(),
                ),
              );
            },
          ),
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.palette),
            title: Text(l10n.personalization),
            subtitle: Text(l10n.themeSettings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PersonalizationPage(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.customNavBar),
            subtitle: Text(l10n.customNavBarHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NavigationConfigPage(),
                ),
              );
            },
          ),
          const Divider(),

          // 系統功能區域
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.system,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.feedback),
            title: Text(l10n.feedback),
            subtitle: Text(l10n.feedbackHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _handleFeedback(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(l10n.about),
            subtitle: Text(l10n.aboutHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AboutPage(),
                ),
              );
            },
          ),
          const Divider(),

          // 帳號管理區域
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '帳號',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.red),
            title: Text(l10n.relogin, style: const TextStyle(color: Colors.red)),
            onTap: () => _handleRelogin(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
            onTap: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFeedback(BuildContext context) async {
    try {
      // 使用 url_launcher 直接開啟外部瀏覽器
      final uri = Uri.parse('https://forms.gle/2gGYEXuRufgYZMeQ7');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('無法開啟反饋頁面')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法開啟反饋頁面: $e')),
        );
      }
    }
  }

  Future<void> _handleRelogin(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.relogin),
        content: const Text('使用儲存的帳號密碼重新登入'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // 顯示載入對話框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('重新登入中...'),
            ],
          ),
        ),
      );

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        
        // 嘗試使用保存的帳密重新登入
        final result = await authService.tryAutoLogin();
        
        if (context.mounted) {
          Navigator.of(context).pop(); // 關閉載入對話框
          
          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('重新登入成功'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (result == false) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('重新登入失敗，請檢查網路連線或帳號密碼'),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('沒有保存的帳號密碼，請重新登入'),
                backgroundColor: Colors.orange,
              ),
            );
            if (context.mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          }
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop(); // 關閉載入對話框
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('重新登入失敗: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmLogout),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
}

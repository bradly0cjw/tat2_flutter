import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../l10n/app_localizations.dart';
import 'privacy_policy_page.dart';
import 'terms_of_service_page.dart';

/// 關於我們頁面
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  String _buildNumber = '';
  
  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }
  
  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.about),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // App 圖示和名稱
            const SizedBox(height: 40),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/logo_square.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'QAQ 北科生活',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _version.isEmpty ? 'Loading...' : 'Version $_version+$_buildNumber',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),



            const SizedBox(height: 24),

            // 作者資訊
            _buildSectionTitle('貢獻者', theme),
            _buildClickableCard(
              icon: Icons.person,
              title: 'changrun1',
              subtitle: 'GitHub',
              onTap: () => _launchUrl('https://github.com/changrun1'),
            ),

            const SizedBox(height: 24),

            // 特別感謝
            _buildSectionTitle('特別感謝', theme),
            _buildClickableCard(
              icon: Icons.favorite,
              title: 'NEO-TAT/tat_flutter',
              subtitle: '北科課表 APP 核心技術參考',
              onTap: () => _launchUrl('https://github.com/NEO-TAT/tat_flutter'),
            ),
            _buildClickableCard(
              icon: Icons.favorite,
              title: 'gnehs/ntut-course-web',
              subtitle: '北科課程爬蟲與網頁版參考',
              onTap: () => _launchUrl('https://github.com/gnehs/ntut-course-web'),
            ),

            const SizedBox(height: 24),

            // 法律資訊
            _buildSectionTitle('法律資訊', theme),
            _buildClickableCard(
              icon: Icons.privacy_tip,
              title: '隱私權條款',
              subtitle: '了解我們如何保護您的隱私',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyPage(),
                  ),
                );
              },
            ),
            _buildClickableCard(
              icon: Icons.description,
              title: '使用者條款',
              subtitle: '使用服務前請詳閱本條款',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsOfServicePage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // 開源資訊
            _buildSectionTitle('開源專案', theme),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.code, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '本專案尚未開源',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '開發中，預計未來會在 GitHub 上公開',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 版權資訊
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '© 2025 QAQ\n'
                '僅供學習交流使用',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildClickableCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey[700]),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.open_in_new, size: 20),
        onTap: onTap,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/ap_tree_json.dart';
import '../services/ntut_api_service.dart';
import 'webview_page.dart';

/// 校務系統頁面 - 完全參考 TAT 的實作
class AdminSystemPage extends StatefulWidget {
  final String? apDn; // 用於遞迴顯示子系統
  final NtutApiService? apiService; // 傳遞 API service 避免 Provider 問題

  const AdminSystemPage({super.key, this.apDn, this.apiService});

  @override
  State<AdminSystemPage> createState() => _AdminSystemPageState();
}

class _AdminSystemPageState extends State<AdminSystemPage> {
  bool _isLoading = true;
  APTreeJson? _apTree;
  String? _errorMessage;
  late NtutApiService _apiService;

  @override
  void initState() {
    super.initState();
    // apiService 應該總是會被傳入
    _apiService = widget.apiService!;
    _loadTree();
  }

  /// 載入系統樹狀結構 - 完全參考 TAT 的 NTUTConnector.getTree
  Future<void> _loadTree() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[AdminSystemPage] 載入系統樹: apDn=${widget.apDn}');
      
      final result = await _apiService.getAdminSystemTree(apDn: widget.apDn);
      
      if (result != null) {
        _apTree = APTreeJson.fromJson(result);
        debugPrint('[AdminSystemPage] 成功載入 ${_apTree!.apList.length} 個項目');
      } else {
        _errorMessage = '無法載入校務系統';
      }
    } catch (e, stackTrace) {
      debugPrint('[AdminSystemPage] 載入失敗: $e');
      debugPrint('[AdminSystemPage] StackTrace: $stackTrace');
      _errorMessage = '載入錯誤: $e';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 點擊系統項目 - 完全參考 TAT 的方式
  Future<void> _onItemTap(APListJson item) async {
    debugPrint('[AdminSystemPage] 點擊項目: ${item.description} (type: ${item.type})');
    debugPrint('[AdminSystemPage] 原始 urlLink: ${item.urlLink}');
    
    if (item.type == 'link') {
      // 這是一個連結，直接用 WebView 開啟
      final apLinkUrl = Uri.tryParse(item.urlLink);
      
      String finalUrl;
      
      // 檢查是否為完整 URL（有 scheme）
      if (apLinkUrl != null && apLinkUrl.hasScheme) {
        finalUrl = item.urlLink;
        debugPrint('[AdminSystemPage] 使用完整 URL: $finalUrl');
      } else {
        // 需要加上 host - 完全參考 TAT 的做法
        const host = 'https://app.ntut.edu.tw';
        // 確保 urlLink 開頭有 /
        final path = item.urlLink.startsWith('/') ? item.urlLink : '/${item.urlLink}';
        finalUrl = '$host$path';
        debugPrint('[AdminSystemPage] 組合 URL: $finalUrl');
      }
      
      // 驗證最終 URL 是否有效
      final finalUri = Uri.tryParse(finalUrl);
      if (finalUri == null || !finalUri.hasScheme) {
        debugPrint('[AdminSystemPage] URL 格式錯誤: $finalUrl');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('URL 格式錯誤: $finalUrl')),
          );
        }
        return;
      }
      
      if (mounted) {
        debugPrint('[AdminSystemPage] 導航到 WebView: $finalUrl');
        
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewPage(
              url: finalUrl,
              title: item.description,
              apiService: _apiService, // 傳遞 apiService
            ),
          ),
        );
      }
    } else {
      // 這是一個資料夾,遞迴載入子系統
      debugPrint('[AdminSystemPage] 導航到子系統: ${item.apDn}');
      
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminSystemPage(
              apDn: item.apDn,
              apiService: _apiService, // 傳遞 apiService
            ),
          ),
        );
      }
    }
  }

  /// 建立系統項目 - 參考 TAT 的 buildTree
  Widget _buildItem(APListJson item) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isLink = item.type == 'link';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          isLink ? Icons.link_outlined : Icons.folder_outlined,
          color: isDarkMode 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).primaryColor,
        ),
        title: Text(
          item.description,
          style: TextStyle(
            color: isDarkMode 
                ? Theme.of(context).colorScheme.onSurface 
                : null,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios, 
          size: 16,
          color: isDarkMode 
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5) 
              : null,
        ),
        onTap: () => _onItemTap(item),
      ),
    );
  }

  /// 建立系統列表
  Widget _buildTree() {
    if (_apTree == null || _apTree!.apList.isEmpty) {
      return const Center(
        child: Text('沒有可用的系統'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: _apTree!.apList.length,
      itemBuilder: (context, index) {
        return _buildItem(_apTree!.apList[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.apDn == null ? l10n.adminSystem : '校務系統'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadTree,
                icon: const Icon(Icons.refresh),
                label: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    return _buildTree();
  }
}

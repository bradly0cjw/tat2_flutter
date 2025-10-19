import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../services/navigation_config_service.dart';

/// 導航列設定頁面
/// 允許使用者自訂底部導航列的項目（最多 5 個）
class NavigationConfigPage extends StatefulWidget {
  const NavigationConfigPage({super.key});

  @override
  State<NavigationConfigPage> createState() => _NavigationConfigPageState();
}

class _NavigationConfigPageState extends State<NavigationConfigPage> {
  late List<String> _selectedItems;
  late List<String> _originalItems;
  late NavigationConfigService _configService;

  @override
  void initState() {
    super.initState();
    _configService = context.read<NavigationConfigService>();
    _selectedItems = List.from(_configService.currentNavOrder);
    _originalItems = List.from(_configService.currentNavOrder);
  }
  
  /// 檢查是否有未儲存的變更
  bool get _hasUnsavedChanges {
    if (_selectedItems.length != _originalItems.length) return true;
    for (int i = 0; i < _selectedItems.length; i++) {
      if (_selectedItems[i] != _originalItems[i]) return true;
    }
    return false;
  }
  
  /// 確認離開對話框
  Future<bool> _confirmExit() async {
    if (!_hasUnsavedChanges) return true;
    
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unsavedChanges),
        content: Text(l10n.unsavedChangesDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.leave, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 顯示可選項目對話框
  void _showItemPicker(int index) {
    final l10n = AppLocalizations.of(context);
    // 取得未被選擇的項目
    final availableItems = _configService.availableNavItems
        .where((item) => 
            item.id == 'other' || // 'other' 不可選，但不會出現在 available 中
            !_selectedItems.contains(item.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectFunction),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableItems.length,
            itemBuilder: (context, i) {
              final item = availableItems[i];
              return ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                onTap: () {
                  setState(() {
                    _selectedItems[index] = item.id;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  /// 儲存設定
  Future<void> _saveConfig() async {
    final l10n = AppLocalizations.of(context);
    await _configService.saveNavOrder(_selectedItems);
    _originalItems = List.from(_selectedItems);
    if (mounted) {
      // 顯示儲存成功並提示即將關閉
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('設定已儲存，App 即將關閉以套用新配置'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
      
      // 延遲 1 秒後關閉 App
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        // 關閉 App
        SystemNavigator.pop();
      }
    }
  }

  /// 重設為預設值
  void _resetToDefault() {
    setState(() {
      _selectedItems = List.from(NavigationConfigService.defaultNavOrder);
    });
  }
  
  /// 新增導航項目
  void _addNavItem() {
    final l10n = AppLocalizations.of(context);
    if (_selectedItems.length >= NavigationConfigService.maxNavItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.maxNavItems)),
      );
      return;
    }
    
    // 取得未被選擇的項目
    final availableItems = _configService.availableNavItems
        .where((item) => !_selectedItems.contains(item.id))
        .toList();
    
    if (availableItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noMoreFunctions)),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addFunction),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableItems.length,
            itemBuilder: (context, i) {
              final item = availableItems[i];
              return ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                onTap: () {
                  setState(() {
                    _selectedItems.add(item.id);
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
  
  /// 移除導航項目
  void _removeNavItem(int index) {
    final l10n = AppLocalizations.of(context);
    if (_selectedItems.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.minOneNavItem)),
      );
      return;
    }
    
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _confirmExit();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navConfigTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: l10n.resetToDefault,
              onPressed: _resetToDefault,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: l10n.save,
              onPressed: _saveConfig,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '自訂底部導航列',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '點擊項目更換功能，長按可拖曳排序',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (_selectedItems.length < NavigationConfigService.maxNavItems)
                  FilledButton.icon(
                    onPressed: _addNavItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.add),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '已選擇 ${_selectedItems.length}/${NavigationConfigService.maxNavItems} 個導航項目',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // 使用 ReorderableListView
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedItems.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _selectedItems.removeAt(oldIndex);
                  _selectedItems.insert(newIndex, item);
                });
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Material(
                      elevation: 8,
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final itemId = _selectedItems[index];
                final item = _configService.availableNavItems
                    .firstWhere((i) => i.id == itemId);
                
                return Card(
                  key: ValueKey(itemId),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          child: Text('${index + 1}'),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.drag_handle),
                      ],
                    ),
                    title: Text(item.label),
                    subtitle: Text('位置 ${index + 1}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => _removeNavItem(index),
                          tooltip: '移除',
                        ),
                      ],
                    ),
                    onTap: () => _showItemPicker(index),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.more_horiz),
              title: Text(l10n.other),
              subtitle: Text('位置 ${_selectedItems.length + 1}（固定）'),
              enabled: false,
            ),
          const SizedBox(height: 24),
            Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                children: [
                  Icon(
                  Icons.info_outline, 
                  color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                  '提示',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  ),
                ],
                ),
                const SizedBox(height: 8),
                Text(
                '• 可自訂 1-5 個導航項目，最多 6 個（含「其他」）\n'
                '• 預設導航列為：課表、日曆、課程查詢、成績\n'
                '• 長按項目可拖曳調整順序\n'
                '• 未加入導航列的功能會顯示在「其他」頁面\n'
                '• 儲存後 App 會自動關閉，請重新開啟以套用配置',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                ),
              ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/ischool_plus/announcement.dart';
import '../../models/ischool_plus/announcement_detail.dart';
import '../../services/ischool_plus_service.dart';
import '../../services/ischool_plus_cache_service.dart';
import '../../services/badge_service.dart';
import '../../services/file_download_service.dart';
import '../../services/file_store.dart';

/// 課程公告列表頁面
class AnnouncementListPage extends StatefulWidget {
  final String courseId;
  final String courseName;

  const AnnouncementListPage({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<AnnouncementListPage> createState() => _AnnouncementListPageState();
}

class _AnnouncementListPageState extends State<AnnouncementListPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ISchoolPlusAnnouncement> _announcements = [];

  @override
  void initState() {
    super.initState();
    // 監聽 BadgeService 變化
    BadgeService().addListener(_onBadgeChanged);
    _loadAnnouncements();
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

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ISchoolPlusService.instance;
      
      // 確保已登入
      if (!service.isLoggedIn) {
        final loginSuccess = await service.login();
        if (!loginSuccess) {
          setState(() {
            _errorMessage = '登入 i學院失敗，請稍後再試';
            _isLoading = false;
          });
          return;
        }
      }

      // 取得公告列表（手動操作，使用高優先級）
      final announcements = await service.connector
          .getCourseAnnouncements(widget.courseId, highPriority: true);

      // 同步公告列表（不自動清除紅點，只有用戶點擊查看時才標記為已讀）
      final announcementIds = announcements
          .where((a) => a.nid != null && a.nid!.isNotEmpty)
          .map((a) => a.nid!)
          .toList();
      
      await BadgeService().syncCourseAnnouncements(
        widget.courseId,
        announcementIds,
      );

      setState(() {
        _announcements = announcements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        // 更友好的錯誤提示
        if (e.toString().contains('API error')) {
          _errorMessage = '此課程目前沒有公告';
        } else {
          _errorMessage = '載入公告失敗，請稍後再試';
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnnouncements,
            tooltip: '重新載入',
          ),
        ],
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnnouncements,
              child: const Text('重試'),
            ),
          ],
        ),
      );
    }

    if (_announcements.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '目前沒有公告',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _announcements.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final announcement = _announcements[index];
          return _buildAnnouncementItem(announcement);
        },
      ),
    );
  }

  Widget _buildAnnouncementItem(ISchoolPlusAnnouncement announcement) {
    return FutureBuilder<bool>(
      future: BadgeService().hasISchoolAnnouncementBadge(
        widget.courseId,
        announcement.nid ?? '',
      ),
      builder: (context, snapshot) {
        final hasUnread = snapshot.data ?? false;
        
        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: hasUnread ? Colors.red : Colors.grey,
                child: Icon(
                  hasUnread ? Icons.mail : Icons.mail_outline,
                  color: Colors.white,
                ),
              ),
              if (hasUnread)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            announcement.subject,
            style: TextStyle(
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(Icons.person, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              announcement.sender,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(width: 16),
            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              announcement.postTime,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
          onTap: () {
            _showAnnouncementDialog(announcement);
          },
        );
      },
    );
  }

  /// 顯示公告詳情彈窗
  void _showAnnouncementDialog(ISchoolPlusAnnouncement announcement) async {
    // 標記為已讀
    await BadgeService().markISchoolAnnouncementAsRead(
      widget.courseId,
      announcement.nid ?? '',
    );
    
    // 立即重新整理以更新紅點狀態
    if (mounted) {
      setState(() {});
    }
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AnnouncementBottomSheet(
        announcement: announcement,
        courseId: widget.courseId,
      ),
    );
  }
}

/// 公告詳情底部彈窗
class _AnnouncementBottomSheet extends StatefulWidget {
  final ISchoolPlusAnnouncement announcement;
  final String courseId;

  const _AnnouncementBottomSheet({
    required this.announcement,
    required this.courseId,
  });

  @override
  State<_AnnouncementBottomSheet> createState() => _AnnouncementBottomSheetState();
}

class _AnnouncementBottomSheetState extends State<_AnnouncementBottomSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  ISchoolPlusAnnouncementDetail? _detail;
  
  // 下載狀態管理
  final Map<String, bool> _downloadingFiles = {}; // fileName -> isDownloading
  final Map<String, double> _downloadProgress = {}; // fileName -> progress
  final Map<String, String> _downloadedFiles = {}; // fileName -> localPath

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadDownloadedFiles();
  }

  /// 載入已下載的附件列表
  Future<void> _loadDownloadedFiles() async {
    try {
      final courseName = widget.announcement.subject; // 使用公告標題作為目錄名
      final files = await FileStore.getDownloadedFiles(courseName);
      if (mounted) {
        setState(() {
          _downloadedFiles.clear();
          _downloadedFiles.addAll(files);
        });
      }
      debugPrint('[AnnouncementAttachment] Loaded ${files.length} downloaded files');
    } catch (e) {
      debugPrint('[AnnouncementAttachment] Load downloaded files error: $e');
      if (mounted) {
        setState(() {
          _downloadedFiles.clear();
        });
      }
    }
  }

  Future<void> _loadDetail() async {
    try {
      final cacheService = ISchoolPlusCacheService();
      final courseId = widget.announcement.cid ?? '';
      final announcementId = widget.announcement.nid ?? '';
      
      // 先從緩存讀取
      final cachedDetail = await cacheService.getCachedAnnouncementDetail(courseId, announcementId);
      if (cachedDetail != null) {
        setState(() {
          _detail = cachedDetail;
          _isLoading = false;
        });
        // 背景更新緩存
        _updateCache();
        return;
      }
      
      // 緩存不存在，從網路載入
      await _fetchFromNetwork();
    } catch (e) {
      setState(() {
        _errorMessage = '載入公告詳情時發生錯誤：$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchFromNetwork() async {
    try {
      final service = ISchoolPlusService.instance;
      final detail = await service.connector
          .getAnnouncementDetail(widget.announcement);

      if (detail == null) {
        setState(() {
          _errorMessage = '無法載入公告詳情';
          _isLoading = false;
        });
        return;
      }

      // 儲存到緩存
      final cacheService = ISchoolPlusCacheService();
      final courseId = widget.announcement.cid ?? '';
      final announcementId = widget.announcement.nid ?? '';
      await cacheService.cacheAnnouncementDetail(courseId, announcementId, detail);

      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _updateCache() async {
    try {
      final service = ISchoolPlusService.instance;
      final detail = await service.connector
          .getAnnouncementDetail(widget.announcement);

      if (detail != null) {
        final cacheService = ISchoolPlusCacheService();
        final courseId = widget.announcement.cid ?? '';
        final announcementId = widget.announcement.nid ?? '';
        await cacheService.cacheAnnouncementDetail(courseId, announcementId, detail);
      }
    } catch (e) {
      print('[AnnouncementDialog] Failed to update cache: $e');
    }
  }

  /// 下載附件（參考教材下載邏輯）
  Future<void> _downloadAttachment(String fileName, String fileUrl) async {
    if (_downloadingFiles[fileName] == true) {
      return; // 已經在下載中
    }

    setState(() {
      _downloadingFiles[fileName] = true;
      _downloadProgress[fileName] = 0.0;
    });

    try {
      final service = ISchoolPlusService.instance;
      
      debugPrint('[AnnouncementAttachment] Starting download: $fileName');
      debugPrint('[AnnouncementAttachment] URL: $fileUrl');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('開始下載：$fileName')),
        );
      }

      // 使用與教材相同的下載服務
      final courseName = widget.announcement.subject; // 使用公告標題作為目錄名
      final filePath = await FileDownloadService.download(
        connector: service.connector,
        url: fileUrl,
        dirName: courseName,
        name: fileName,
        referer: fileUrl,
        onProgress: (current, total) {
          if (total > 0) {
            setState(() {
              _downloadProgress[fileName] = current / total;
            });
          }
        },
      );

      // 更新已下載檔案列表
      final downloadedFileName = filePath.split(Platform.pathSeparator).last;
      setState(() {
        _downloadedFiles[downloadedFileName] = filePath;
        _downloadProgress.remove(fileName);
      });

      // 重新載入已下載檔案列表
      await _loadDownloadedFiles();

      debugPrint('[AnnouncementAttachment] Download completed: $downloadedFileName');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下載完成：$downloadedFileName'),
            action: SnackBarAction(
              label: '開啟',
              onPressed: () => _openFile(filePath),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('[AnnouncementAttachment] Download error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下載失敗：$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _downloadingFiles[fileName] = false;
        _downloadProgress.remove(fileName);
      });
    }
  }

  /// 開啟檔案
  Future<void> _openFile(String path) async {
    try {
      debugPrint('[AnnouncementAttachment] Opening file: $path');

      final file = File(path);
      if (!await file.exists()) {
        throw Exception('檔案不存在');
      }

      final result = await OpenFilex.open(path);
      debugPrint('[AnnouncementAttachment] Open result: ${result.type} - ${result.message}');

      if (result.type != ResultType.done) {
        String errorMsg = '開啟檔案失敗';

        switch (result.type) {
          case ResultType.noAppToOpen:
            errorMsg = '沒有可開啟此檔案的應用程式';
            break;
          case ResultType.fileNotFound:
            errorMsg = '找不到檔案';
            break;
          case ResultType.permissionDenied:
            errorMsg = '權限被拒絕';
            break;
          case ResultType.error:
            errorMsg = '開啟檔案時發生錯誤：${result.message}';
            break;
          default:
            errorMsg = result.message;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              action: SnackBarAction(
                label: '分享',
                onPressed: () => _shareFile(path),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[AnnouncementAttachment] Open file error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('開啟檔案失敗：$e')),
        );
      }
    }
  }

  /// 分享檔案
  Future<void> _shareFile(String path) async {
    try {
      final fileName = path.split(Platform.pathSeparator).last;
      await Share.shareXFiles(
        [XFile(path)],
        subject: fileName,
      );
    } catch (e) {
      debugPrint('[AnnouncementAttachment] Share file error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失敗：$e')),
        );
      }
    }
  }

  /// 刪除附件
  Future<void> _deleteFile(String path, String fileName) async {
    try {
      final success = await FileStore.deleteFile(path);
      
      if (success) {
        setState(() {
          _downloadedFiles.remove(fileName);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已刪除：$fileName')),
          );
        }
      } else {
        throw Exception('刪除失敗');
      }
    } catch (e) {
      debugPrint('[AnnouncementAttachment] Delete file error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除失敗：$e')),
        );
      }
    }
  }

  /// 顯示檔案操作選單（已下載的附件）
  void _showFileActions(String fileName, String filePath) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('開啟'),
              onTap: () {
                Navigator.pop(context);
                _openFile(filePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () {
                Navigator.pop(context);
                _shareFile(filePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('刪除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(fileName, filePath);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 確認刪除對話框
  void _confirmDelete(String fileName, String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除「$fileName」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFile(filePath, fileName);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // 拖動指示器與標題列
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // 拖動指示器
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // 標題列
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.announcement.subject,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: onSurface),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 內容
              SliverFillRemaining(
                hasScrollBody: true,
                child: _buildContent(null),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController? scrollController) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadDetail();
                },
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    if (_detail == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('無公告內容'),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 發送者和時間
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                _detail!.sender,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _detail!.postTime,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          // HTML 內容
          Html(
            data: _detail!.body,
            style: {
              "body": Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontSize: FontSize(14),
                lineHeight: const LineHeight(1.5),
              ),
              "p": Style(
                margin: Margins.only(bottom: 8),
              ),
              "div": Style(
                margin: Margins.only(bottom: 8),
              ),
              "br": Style(
                margin: Margins.only(bottom: 4),
              ),
            },
          ),
          // 附件
          if (_detail!.hasAttachments) ...[
            const SizedBox(height: 16),
            const Divider(),
            const Text(
              '附件',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._detail!.files.entries.map((entry) {
              final fileName = entry.key;
              final fileUrl = entry.value;
              final isDownloading = _downloadingFiles[fileName] ?? false;
              final progress = _downloadProgress[fileName] ?? 0.0;
              
              // 檢查檔案是否已下載（需要檢查可能的不同檔名）
              String? downloadedPath;
              bool isDownloaded = false;
              
              // 嘗試找到匹配的已下載檔案
              for (final entry in _downloadedFiles.entries) {
                final savedFileName = entry.key;
                // 移除擴展名後比對（因為下載後可能會自動加上擴展名）
                final baseFileName = fileName.split('.').first;
                final baseSavedFileName = savedFileName.split('.').first;
                if (baseSavedFileName.contains(baseFileName) || baseFileName.contains(baseSavedFileName)) {
                  downloadedPath = entry.value;
                  isDownloaded = true;
                  break;
                }
              }
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    dense: true,
                    leading: Icon(
                      isDownloaded ? Icons.check_circle : Icons.attach_file,
                      size: 20,
                      color: isDownloaded ? Colors.green : Colors.blue,
                    ),
                    title: Text(
                      fileName,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      isDownloaded ? '已下載 · 點擊開啟' : '點擊下載',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDownloaded ? Colors.green : Colors.grey,
                      ),
                    ),
                    trailing: isDownloading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              value: progress > 0 ? progress : null,
                              strokeWidth: 2,
                            ),
                          )
                        : isDownloaded
                            ? GestureDetector(
                                onTap: () => _showFileActions(fileName, downloadedPath!),
                                child: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                              )
                            : const Icon(Icons.download, size: 20),
                    onTap: isDownloading
                        ? null
                        : isDownloaded
                            ? () => _openFile(downloadedPath!)
                            : () => _downloadAttachment(fileName, fileUrl),
                  ),
                  if (isDownloading && progress > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: LinearProgressIndicator(value: progress),
                    ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}


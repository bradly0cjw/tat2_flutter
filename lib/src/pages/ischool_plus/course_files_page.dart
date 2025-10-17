import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ischool_plus/course_file.dart';
import '../../services/ischool_plus_service.dart';
import '../../services/file_store.dart';
import '../../services/file_download_service.dart';

/// 課程檔案列表頁面
/// 完全重構版本 - 使用新的下載服務架構
class CourseFilesPage extends StatefulWidget {
  final String courseId;
  final String courseName;

  const CourseFilesPage({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<CourseFilesPage> createState() => _CourseFilesPageState();
}

class _CourseFilesPageState extends State<CourseFilesPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ISchoolPlusCourseFile> _files = [];
  
  // 下載狀態管理
  final Set<int> _downloadingIndices = {};
  final Map<int, double?> _downloadProgress = {}; // null 表示檔案大小未知
  final Map<String, String> _downloadedFiles = {}; // fileName -> localPath

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _loadDownloadedFiles();
  }

  /// 載入已下載的檔案列表
  Future<void> _loadDownloadedFiles() async {
    try {
      final files = await FileStore.getDownloadedFiles(widget.courseName);
      if (mounted) {
        setState(() {
          _downloadedFiles.clear();
          _downloadedFiles.addAll(files);
        });
      }
      debugPrint('[CourseFiles] Loaded ${files.length} downloaded files');
    } catch (e) {
      debugPrint('[CourseFiles] Load downloaded files error: $e');
      // 如果讀取失敗（可能是目錄被刪除），清空列表
      if (mounted) {
        setState(() {
          _downloadedFiles.clear();
        });
      }
    }
  }

  /// 載入課程檔案列表
  Future<void> _loadFiles() async {
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

      // 取得檔案列表
      final files = await service.connector.getCourseFiles(widget.courseId);

      setState(() {
        _files = files;
        _isLoading = false;
      });

      debugPrint('[CourseFiles] Loaded ${files.length} files');
    } catch (e) {
      setState(() {
        _errorMessage = '載入檔案列表時發生錯誤：$e';
        _isLoading = false;
      });
      debugPrint('[CourseFiles] Load files error: $e');
    }
  }

  /// 下載檔案
  Future<void> _downloadFile(int index, ISchoolPlusCourseFile file) async {
    if (_downloadingIndices.contains(index)) {
      return; // 已經在下載中
    }

    setState(() {
      _downloadingIndices.add(index);
      _downloadProgress[index] = 0.0;
    });

    try {
      // 取得下載資訊
      final postData = file.primaryFileType.postData;
      if (postData == null) {
        throw Exception('無法取得檔案下載資訊');
      }

      final service = ISchoolPlusService.instance;
      final urlInfo = await service.connector.getRealFileUrl(postData);

      if (urlInfo == null || urlInfo.isEmpty) {
        throw Exception('無法取得檔案下載網址');
      }

      final downloadUrl = urlInfo[0];
      final refererUrl = urlInfo.length > 1 ? urlInfo[1] : downloadUrl;

      debugPrint('[CourseFiles] Starting download: ${file.name}');
      debugPrint('[CourseFiles] URL: $downloadUrl');

      // 解析 URL 以檢查網域（完全照 TAT 的邏輯）
      final urlParse = Uri.parse(downloadUrl);
      
      // 檢查 1：如果不是 NTUT 的網域，顯示警告（這可能是外部連結）
      if (!urlParse.host.toLowerCase().contains("ntut.edu.tw")) {
        setState(() {
          _downloadingIndices.remove(index);
          _downloadProgress.remove(index);
        });
        
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確定要打開嗎？'),
            content: const Text('這是一個外部連結'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _launchURL(downloadUrl);
                },
                child: const Text('確定'),
              ),
            ],
          ),
        );
        return;
      }

      // 檢查 2：如果是上課錄影（istream.ntut.edu.tw），顯示特殊警告並導向播放器
      if (urlParse.host.contains("istream.ntut.edu.tw")) {
        setState(() {
          _downloadingIndices.remove(index);
          _downloadProgress.remove(index);
        });
        
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確定要打開嗎？'),
            content: const Text('上課錄影\n\n注意：影片可能會載入失敗，若失敗請重試或使用瀏覽器開啟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _launchURL(downloadUrl);
                },
                child: const Text('確定'),
              ),
            ],
          ),
        );
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('開始下載：${file.name}')),
        );
      }

      // 使用新的下載服務
      final filePath = await FileDownloadService.download(
        connector: service.connector,
        url: downloadUrl,
        dirName: widget.courseName,
        name: file.name,
        referer: refererUrl,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              if (total > 0) {
                // 已知檔案大小，顯示確定的進度
                _downloadProgress[index] = current / total;
              } else {
                // 檔案大小未知（total = -1），設定為 null 以顯示不確定的進度
                _downloadProgress[index] = null;
              }
            });
          }
        },
      );

      // 更新已下載檔案列表
      final fileName = filePath.split(Platform.pathSeparator).last;
      setState(() {
        _downloadedFiles[fileName] = filePath;
        _downloadProgress.remove(index);
      });

      debugPrint('[CourseFiles] Download completed: $fileName');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下載完成：$fileName'),
            action: SnackBarAction(
              label: '開啟',
              onPressed: () => _openFile(filePath),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('[CourseFiles] Download error: $e');
      
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
        _downloadingIndices.remove(index);
        _downloadProgress.remove(index);
      });
    }
  }

  /// 開啟檔案
  Future<void> _openFile(String path) async {
    try {
      debugPrint('[CourseFiles] Opening file: $path');

      final file = File(path);
      if (!await file.exists()) {
        throw Exception('檔案不存在');
      }

      final result = await OpenFilex.open(path);
      debugPrint('[CourseFiles] Open result: ${result.type} - ${result.message}');

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
      debugPrint('[CourseFiles] Open file error: $e');
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
      debugPrint('[CourseFiles] Share file error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失敗：$e')),
        );
      }
    }
  }

  /// 刪除檔案
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
      debugPrint('[CourseFiles] Delete file error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除失敗：$e')),
        );
      }
    }
  }

  /// 取得檔案圖示
  IconData _getFileIcon(ISchoolPlusCourseFile file) {
    switch (file.primaryFileType.type) {
      case CourseFileType.pdf:
        return Icons.picture_as_pdf;
      case CourseFileType.video:
        return Icons.play_circle_outline;
      case CourseFileType.file:
        return Icons.insert_drive_file;
      case CourseFileType.unknown:
      default:
        return Icons.description;
    }
  }

  /// 取得檔案圖示顏色
  Color _getFileIconColor(ISchoolPlusCourseFile file) {
    switch (file.primaryFileType.type) {
      case CourseFileType.pdf:
        return Colors.red;
      case CourseFileType.video:
        return Colors.purple;
      case CourseFileType.file:
        return Colors.blue;
      case CourseFileType.unknown:
      default:
        return Colors.grey;
    }
  }

  @override
  void didUpdateWidget(CourseFilesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 當 widget 更新時，重新載入已下載的檔案列表
    // 這樣清除快取後父頁面 setState() 就會觸發更新
    _loadDownloadedFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadFiles();
              _loadDownloadedFiles();
            },
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFiles,
              child: const Text('重試'),
            ),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '目前沒有教材檔案',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadFiles();
        await _loadDownloadedFiles();
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _files.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final file = _files[index];
          return _buildFileItem(index, file);
        },
      ),
    );
  }

  Widget _buildFileItem(int index, ISchoolPlusCourseFile file) {
    final isDownloading = _downloadingIndices.contains(index);
    final downloadProgress = _downloadProgress[index];
    
    // 檢查是否已下載
    final isDownloaded = _downloadedFiles.keys.any((key) => 
      key == file.name || key.startsWith(file.name.split('.').first)
    );
    
    String? localPath;
    if (isDownloaded) {
      localPath = _downloadedFiles[file.name] ?? 
                  _downloadedFiles.entries
                      .firstWhere(
                        (entry) => entry.key.startsWith(file.name.split('.').first),
                        orElse: () => const MapEntry('', ''),
                      )
                      .value;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: Stack(
              children: [
                Icon(
                  _getFileIcon(file),
                  color: _getFileIconColor(file),
                  size: 32,
                ),
                if (isDownloaded)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              file.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: isDownloaded
                ? const Text('已下載', style: TextStyle(color: Colors.green))
                : null,
            trailing: isDownloading
                ? SizedBox(
                    width: 48,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            // value 為 null 表示不確定的進度（檔案大小未知）
                            value: downloadProgress,
                          ),
                        ),
                        // 只有在已知進度時才顯示百分比
                        if (downloadProgress != null && downloadProgress > 0)
                          Text(
                            '${(downloadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 10),
                          )
                        else
                          const Text(
                            '下載中',
                            style: TextStyle(fontSize: 9),
                          ),
                      ],
                    ),
                  )
                : isDownloaded
                    ? IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {
                          // 從實際檔案路徑取得檔名
                          final actualFileName = localPath!.split(Platform.pathSeparator).last;
                          _showFileOptions(localPath, actualFileName);
                        },
                        tooltip: '更多選項',
                      )
                    : IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => _downloadFile(index, file),
                        tooltip: '下載',
                      ),
            onTap: isDownloading
                ? null
                : isDownloaded && localPath != null && localPath.isNotEmpty
                    ? () => _openFile(localPath!)
                    : () => _downloadFile(index, file),
          ),
          // 下載中時顯示進度條
          if (isDownloading)
            LinearProgressIndicator(
              // value 為 null 時顯示不確定的進度動畫
              value: downloadProgress,
            ),
        ],
      ),
    );
  }

  /// 顯示檔案操作選項
  Future<void> _showFileOptions(String path, String fileName) async {
    // 取得檔案資訊
    final file = File(path);
    String fileSize = '計算中...';
    String modifiedTime = '';
    
    try {
      final stat = await file.stat();
      final bytes = stat.size;
      fileSize = FileStore.formatBytes(bytes);
      
      final modified = stat.modified;
      modifiedTime = '${modified.year}/${modified.month}/${modified.day} '
          '${modified.hour.toString().padLeft(2, '0')}:'
          '${modified.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('[CourseFiles] Get file info error: $e');
      fileSize = '未知';
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 檔案資訊
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '大小: $fileSize',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (modifiedTime.isNotEmpty)
                    Text(
                      '修改時間: $modifiedTime',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 操作選項
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('開啟'),
              onTap: () {
                Navigator.pop(context);
                _openFile(path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () {
                Navigator.pop(context);
                _shareFile(path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('刪除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(path, fileName);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 啟動外部瀏覽器開啟 URL
  Future<void> _launchURL(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        throw Exception('無效的網址');
      }
      
      debugPrint('[CourseFiles] Launch URL: $url');
      
      // 嘗試使用系統瀏覽器開啟
      final canLaunch = await canLaunchUrl(uri);
      
      if (canLaunch) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // 使用外部瀏覽器
        );
        
        if (launched) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已在瀏覽器中開啟'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }
      
      // 如果無法開啟，提供複製選項
      throw Exception('無法開啟瀏覽器');
      
    } catch (e) {
      debugPrint('[CourseFiles] Launch URL error: $e');
      
      // 開啟失敗時，提供複製網址的選項
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('無法自動開啟瀏覽器，已複製網址'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '複製',
              onPressed: () => _copyToClipboard(url),
            ),
          ),
        );
        
        // 自動複製到剪貼簿
        await _copyToClipboard(url);
      }
    }
  }
  
  /// 複製文字到剪貼簿
  Future<void> _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      debugPrint('[CourseFiles] Copied to clipboard: $text');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已複製到剪貼簿'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[CourseFiles] Copy to clipboard error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('複製失敗：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 確認刪除對話框
  void _confirmDelete(String path, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除檔案'),
        content: Text('確定要刪除「$fileName」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFile(path, fileName);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}

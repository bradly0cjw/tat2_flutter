import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/ischool_plus/announcement_detail.dart';

/// i學院緩存服務
class ISchoolPlusCacheService {
  static final ISchoolPlusCacheService _instance = ISchoolPlusCacheService._internal();
  factory ISchoolPlusCacheService() => _instance;
  ISchoolPlusCacheService._internal();

  /// 取得緩存目錄
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/QAQ/ISchoolPlus/Cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 取得下載目錄（與 FileStore 保持一致）
  Future<Directory> _getDownloadDirectory() async {
    Directory? directory;
    
    if (Platform.isAndroid) {
      // Android 使用外部儲存，與 FileStore 一致
      directory = await getExternalStorageDirectory();
    } else {
      // iOS 和其他平台使用應用文件目錄
      directory = await getApplicationDocumentsDirectory();
    }
    
    final downloadDir = Directory('${directory?.path ?? ''}/QAQ/Downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  /// 儲存公告詳情到緩存
  Future<void> cacheAnnouncementDetail(String courseId, String announcementId, ISchoolPlusAnnouncementDetail detail) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final file = File('${cacheDir.path}/announcement_${courseId}_$announcementId.json');
      
      final data = {
        'title': detail.title,
        'sender': detail.sender,
        'postTime': detail.postTime,
        'body': detail.body,
        'files': detail.files,
        'cachedAt': DateTime.now().toIso8601String(),
      };
      
      await file.writeAsString(jsonEncode(data));
      print('[Cache] Saved announcement: $announcementId');
    } catch (e) {
      print('[Cache] Failed to save announcement: $e');
    }
  }

  /// 從緩存讀取公告詳情
  Future<ISchoolPlusAnnouncementDetail?> getCachedAnnouncementDetail(String courseId, String announcementId) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final file = File('${cacheDir.path}/announcement_${courseId}_$announcementId.json');
      
      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      return ISchoolPlusAnnouncementDetail(
        title: data['title'] as String? ?? '',
        sender: data['sender'] as String? ?? '',
        postTime: data['post_time'] as String? ?? data['postTime'] as String? ?? '',
        body: data['body'] as String? ?? '',
        files: Map<String, String>.from(data['files'] as Map? ?? {}),
      );
    } catch (e) {
      print('[Cache] Failed to read cached announcement: $e');
      return null;
    }
  }

  /// 清除所有 i學院 緩存
  Future<void> clearAllCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('[Cache] All cache cleared');
      }
    } catch (e) {
      print('[Cache] Failed to clear cache: $e');
      rethrow;
    }
  }

  /// 清除所有下載的檔案
  Future<void> clearAllDownloads() async {
    try {
      final downloadDir = await _getDownloadDirectory();
      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
        print('[Cache] All downloads cleared');
      }
    } catch (e) {
      print('[Cache] Failed to clear downloads: $e');
      rethrow;
    }
  }

  /// 取得緩存大小
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) {
        return 0;
      }
      
      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      print('[Cache] Failed to get cache size: $e');
      return 0;
    }
  }

  /// 取得下載檔案大小
  Future<int> getDownloadSize() async {
    try {
      final downloadDir = await _getDownloadDirectory();
      if (!await downloadDir.exists()) {
        return 0;
      }
      
      int totalSize = 0;
      await for (final entity in downloadDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      print('[Cache] Failed to get download size: $e');
      return 0;
    }
  }

  /// 格式化檔案大小
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

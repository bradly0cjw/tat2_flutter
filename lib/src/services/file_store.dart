import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 檔案儲存目錄管理服務
/// 參考 TAT 的 FileStore 實作
class FileStore {
  /// 取得應用程式的基礎儲存路徑
  /// 
  /// Android: External Storage Directory
  /// iOS/其他平台: Application Documents Directory
  static Future<String> findLocalPath() async {
    Directory? directory;
    
    if (Platform.isAndroid) {
      // Android 使用外部儲存
      directory = await getExternalStorageDirectory();
    } else {
      // iOS 和其他平台使用應用文件目錄
      directory = await getApplicationDocumentsDirectory();
    }

    // 建立 QAQ 資料夾
    final targetDir = Directory('${directory?.path ?? ''}/QAQ');
    final hasExisted = await targetDir.exists();
    
    if (!hasExisted) {
      await targetDir.create(recursive: true);
    }

    return targetDir.path;
  }

  /// 取得下載目錄
  /// 
  /// [dirName] 子目錄名稱（通常是課程名稱）
  /// 返回完整的目錄路徑，如果目錄不存在會自動建立
  static Future<String> getDownloadDir(String dirName) async {
    final localPath = '${await findLocalPath()}/Downloads/$dirName';
    final savedDir = Directory(localPath);
    final hasExisted = await savedDir.exists();

    if (!hasExisted) {
      await savedDir.create(recursive: true);
    }

    return savedDir.path;
  }

  /// 檢查檔案是否已下載
  /// 
  /// [dirName] 子目錄名稱
  /// [fileName] 檔案名稱
  /// 返回檔案路徑，如果不存在返回 null
  static Future<String?> checkFileExists(String dirName, String fileName) async {
    try {
      final dir = await getDownloadDir(dirName);
      final filePath = '$dir/$fileName';
      final file = File(filePath);
      
      if (await file.exists()) {
        return filePath;
      }
    } catch (e) {
      print('[FileStore] Check file exists error: $e');
    }
    
    return null;
  }

  /// 取得目錄中所有已下載的檔案
  /// 
  /// [dirName] 子目錄名稱
  /// 返回檔案名稱與路徑的 Map
  static Future<Map<String, String>> getDownloadedFiles(String dirName) async {
    final result = <String, String>{};
    
    try {
      final dir = await getDownloadDir(dirName);
      final directory = Directory(dir);
      
      if (await directory.exists()) {
        final files = await directory.list().toList();
        for (final file in files) {
          if (file is File) {
            final fileName = file.path.split(Platform.pathSeparator).last;
            result[fileName] = file.path;
          }
        }
      }
    } catch (e) {
      print('[FileStore] Get downloaded files error: $e');
    }
    
    return result;
  }

  /// 刪除檔案
  /// 
  /// [filePath] 檔案完整路徑
  /// 返回是否刪除成功
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('[FileStore] Successfully deleted: $filePath');
        return true;
      } else {
        print('[FileStore] File not found: $filePath');
        return false;
      }
    } catch (e) {
      print('[FileStore] Delete file error: $e');
      // 重新拋出錯誤，讓上層能看到具體錯誤訊息
      rethrow;
    }
  }

  /// 取得檔案大小（格式化為人類可讀的字串）
  /// 
  /// [filePath] 檔案完整路徑
  /// 返回格式化後的檔案大小，例如 "1.5 MB"
  static Future<String> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.length();
        return formatBytes(bytes);
      }
    } catch (e) {
      print('[FileStore] Get file size error: $e');
    }
    
    return '未知';
  }

  /// 格式化位元組大小
  /// 
  /// [bytes] 位元組數
  /// [decimals] 小數位數（預設 2）
  static String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (bytes.bitLength - 1) ~/ 10;
    final size = bytes / (1 << (i * 10));
    
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}

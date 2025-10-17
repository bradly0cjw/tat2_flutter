import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../connectors/ischool_plus_connector.dart';
import 'file_store.dart';

/// 下載進度回調
/// [current] 當前已下載的位元組數
/// [total] 檔案總位元組數
typedef ProgressCallback = void Function(int current, int total);

/// 檔案下載服務
/// 完全模仿 TAT 的 FileDownload 實作
class FileDownloadService {

  /// 下載檔案（完全模仿 TAT 的實作）
  /// 
  /// [connector] ISchoolPlusConnector 實例（用於共享 cookies）
  /// [url] 下載網址
  /// [dirName] 儲存目錄名稱（通常是課程名稱）
  /// [name] 原始檔案名稱
  /// [referer] Referer header（用於某些網站的防盜鏈）
  /// [onProgress] 下載進度回調
  /// 
  /// 返回下載後的檔案路徑
  static Future<String> download({
    required ISchoolPlusConnector connector,
    required String url,
    required String dirName,
    required String name,
    String? referer,
    ProgressCallback? onProgress,
  }) async {
    final path = await FileStore.getDownloadDir(dirName);
    String realFileName = "";
    String? fileExtension;
    referer ??= url;

    debugPrint('[FileDownload] Starting download');
    debugPrint('[FileDownload] URL: $url');
    debugPrint('[FileDownload] Referer: $referer');
    debugPrint('[FileDownload] Original filename: $name');

    // 進度回調：節流以提升性能
    int lastReportedSize = 0;
    const int reportThreshold = 1024 * 128; // 每 128KB 報告一次
    
    void throttledProgress(int count, int total) {
      // 檔案大小未知或首次回調時，總是報告
      bool shouldReport = total <= 0 || 
                         lastReportedSize == 0 || 
                         count >= total ||
                         (count - lastReportedSize >= reportThreshold);
      
      if (shouldReport) {
        lastReportedSize = count;
        if (total > 0) {
          debugPrint('[FileDownload] Progress: ${(count / total * 100).toStringAsFixed(1)}% ($count / $total bytes)');
        } else {
          debugPrint('[FileDownload] Downloaded: $count bytes (total size unknown)');
        }
      }
      
      // 總是觸發回調，讓 UI 層處理進度更新
      if (onProgress != null) {
        onProgress(count, total);
      }
    }

    // 最終儲存路徑（會在回調中設定）
    String? finalSavePath;

    // 使用 connector.download（完全模仿 TAT 的 DioConnector.download）
    await connector.download(
      url,
      (responseHeaders) {
        // 從 response headers 提取檔案名稱（完全照 TAT 的邏輯）
        final Map<String, List<String>> headers = responseHeaders.map;
        
        if (headers.containsKey("content-disposition")) {
          final headerName = headers["content-disposition"];
          final exp = RegExp("['|\"](?<name>.+)['|\"]");
          final matches = headerName != null ? exp.firstMatch(headerName[0]) : null;
          realFileName = matches?.group(1) ?? "";
        } else if (headers.containsKey("content-type")) {
          final headerName = headers["content-type"];
          if (headerName?[0].toLowerCase().contains("pdf") == true) {
            realFileName = '.pdf';
          }
        }
        
        // 清理檔案名稱：移除 URL 參數和非法字符
        // 從 URL 中提取乾淨的檔案名（去除 query parameters）
        String cleanName = name;
        if (name.contains('?')) {
          cleanName = name.split('?')[0];
        }
        // 移除路徑分隔符
        cleanName = cleanName.split('/').last;
        // 移除非法字符
        cleanName = cleanName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        
        if (!cleanName.contains(".")) {
          if (realFileName.isNotEmpty) {
            fileExtension = realFileName.split(".").reversed.toList()[0];
            realFileName = "$cleanName.$fileExtension";
          } else {
            final maybeName = url.split("/").toList().last.split("?")[0];
            if (maybeName.contains(".")) {
              fileExtension = maybeName.split(".").toList().last;
              realFileName = "$cleanName.$fileExtension";
            }
          }
        } else {
          final List<String> s = cleanName.split(".");
          s.removeLast();
          if (realFileName.isNotEmpty && realFileName.contains(".")) {
            realFileName = '${s.join()}.${realFileName.split(".").last}';
          }
        }
        
        if (realFileName.isEmpty) {
          realFileName = cleanName;
        }
        
        // 最終清理：確保沒有非法字符
        realFileName = realFileName.replaceAll(RegExp(r'[<>:"/\\|?*%]'), '_');
        
        debugPrint('[FileDownload] Final filename: $realFileName');
        finalSavePath = "$path/$realFileName";
        return finalSavePath!;
      },
      progressCallback: throttledProgress,
      cancelToken: CancelToken(),
      header: {"referer": referer},
    );

    debugPrint('[FileDownload] Download completed successfully');
    return finalSavePath ?? "$path/$name";
  }
}

/// i學院課程檔案類型
enum CourseFileType {
  /// 未知類型
  unknown,
  /// PDF 檔案
  pdf,
  /// 影片
  video,
  /// 一般檔案
  file,
}

/// 檔案類型資訊
class FileTypeInfo {
  /// 檔案類型
  final CourseFileType type;
  
  /// POST 資料 (用於取得真實下載網址)
  final Map<String, String>? postData;

  FileTypeInfo({
    required this.type,
    this.postData,
  });
}

/// i學院課程檔案
class ISchoolPlusCourseFile {
  /// 檔案名稱
  final String name;
  
  /// 檔案類型資訊列表
  final List<FileTypeInfo> fileTypes;

  ISchoolPlusCourseFile({
    required this.name,
    required this.fileTypes,
  });

  /// 取得主要檔案類型
  FileTypeInfo get primaryFileType => 
      fileTypes.isNotEmpty ? fileTypes.first : FileTypeInfo(type: CourseFileType.unknown);
}

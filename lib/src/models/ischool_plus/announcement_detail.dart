/// i學院課程公告詳細內容
class ISchoolPlusAnnouncementDetail {
  /// 公告標題
  final String title;
  
  /// 發送者
  final String sender;
  
  /// 發布時間
  final String postTime;
  
  /// 公告內容 (HTML 格式)
  final String body;
  
  /// 附件列表 Map<檔案名稱, 下載網址>
  final Map<String, String> files;

  ISchoolPlusAnnouncementDetail({
    required this.title,
    required this.sender,
    required this.postTime,
    required this.body,
    required this.files,
  });

  factory ISchoolPlusAnnouncementDetail.fromJson(Map<String, dynamic> json) {
    return ISchoolPlusAnnouncementDetail(
      title: json['title'] as String? ?? '',
      sender: json['sender'] as String? ?? '',
      postTime: json['postTime'] as String? ?? '',
      body: json['body'] as String? ?? '',
      files: Map<String, String>.from(json['file'] as Map? ?? {}),
    );
  }

  /// 是否有附件
  bool get hasAttachments => files.isNotEmpty;
}

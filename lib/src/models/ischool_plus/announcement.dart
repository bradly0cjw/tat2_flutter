/// i學院課程公告資料模型
class ISchoolPlusAnnouncement {
  /// 課程 ID
  final String? cid;
  
  /// 公告 ID
  final String? bid;
  
  /// 節點 ID
  final String? nid;
  
  /// 公告主旨
  final String subject;
  
  /// 發布者
  final String sender;
  
  /// 發布時間
  final String postTime;
  
  /// 是否已讀 (1: 已讀, 0: 未讀)
  final int readFlag;
  
  /// Token (用於取得詳細內容)
  final String? token;

  ISchoolPlusAnnouncement({
    this.cid,
    this.bid,
    this.nid,
    required this.subject,
    required this.sender,
    required this.postTime,
    this.readFlag = 0,
    this.token,
  });

  factory ISchoolPlusAnnouncement.fromJson(Map<String, dynamic> json) {
    // 嘗試多種可能的欄位名稱
    String getPostTime() {
      return json['post_time'] as String? ?? 
             json['postTime'] as String? ?? 
             json['posttime'] as String? ?? 
             json['time'] as String? ?? 
             '';
    }
    
    String getSender() {
      return json['sender'] as String? ?? 
             json['author'] as String? ?? 
             json['poster'] as String? ?? 
             '';
    }
    
    return ISchoolPlusAnnouncement(
      cid: json['cid'] as String?,
      bid: json['bid'] as String?,
      nid: json['nid'] as String?,
      subject: json['subject'] as String? ?? json['title'] as String? ?? '',
      sender: getSender(),
      postTime: getPostTime(),
      readFlag: json['readflag'] as int? ?? json['readFlag'] as int? ?? 0,
      token: json['token'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cid': cid,
      'bid': bid,
      'nid': nid,
      'subject': subject,
      'sender': sender,
      'post_time': postTime,
      'readflag': readFlag,
      'token': token,
    };
  }

  /// 是否已讀
  bool get isRead => readFlag == 1;
}

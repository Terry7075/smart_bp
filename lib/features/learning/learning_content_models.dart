/// 學習內容分類（對應 `learning_content.category`）。
abstract final class LearningCategory {
  static const String antiFraud = 'anti_fraud';
  static const String health = 'health';
  static const String hakkaVocab = 'hakka_vocab';
  static const String hakkaSong = 'hakka_song';
  static const String hakkaStory = 'hakka_story';

  static const List<String> communityLearning = [antiFraud, health];

  static const List<String> hakkaCulture = [hakkaVocab, hakkaSong, hakkaStory];

  static const List<String> all = [
    antiFraud,
    health,
    hakkaVocab,
    hakkaSong,
    hakkaStory,
  ];

  static String label(String category) => switch (category) {
        antiFraud => '防詐騙宣導',
        health => '健康小教室',
        hakkaVocab => '客語生活認字',
        hakkaSong => '客家歌謠',
        hakkaStory => '客庄故事館',
        _ => category,
      };
}

/// 內容型態（對應 `learning_content.content_type`）。
abstract final class LearningContentType {
  static const String video = 'video';
  static const String article = 'article';

  static String label(String type) => switch (type) {
        video => '影片',
        article => '文章',
        _ => type,
      };
}

class LearningContent {
  const LearningContent({
    required this.id,
    required this.createdAt,
    required this.title,
    this.description,
    required this.category,
    required this.contentType,
    required this.url,
    this.volunteerId,
  });

  final String id;
  final DateTime createdAt;
  final String title;
  final String? description;
  final String category;
  final String contentType;
  final String url;
  final String? volunteerId;

  bool get isVideo => contentType == LearningContentType.video;
  bool get isArticle => contentType == LearningContentType.article;

  factory LearningContent.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['created_at'];
    final createdAt = createdRaw is DateTime
        ? createdRaw.toLocal()
        : DateTime.tryParse(createdRaw?.toString() ?? '')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0);

    return LearningContent(
      id: map['id'].toString(),
      createdAt: createdAt,
      title: (map['title'] as String?)?.trim() ?? '',
      description: (map['description'] as String?)?.trim(),
      // category / content_type 來自 DB，理論上 NOT NULL，但用安全解析避免
      // 任一筆髒資料（null / 型別不符）就讓整個學習清單載入失敗。
      category: map['category']?.toString() ?? '',
      contentType: map['content_type']?.toString() ?? '',
      url: (map['url'] as String?)?.trim() ?? '',
      volunteerId: map['volunteer_id'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap({required String volunteerId}) {
    return {
      'title': title,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'category': category,
      'content_type': contentType,
      'url': url,
      'volunteer_id': volunteerId,
    };
  }
}

/// 一般 YouTube 播放器支援的 host 白名單。
///
/// 刻意**排除** `music.youtube.com`：它的歌曲連結放進一般影片播放器常播不出來，
/// 與其黑屏不如交由呼叫端 fallback 用外部 App 開啟。
const Set<String> _kYoutubeHosts = {
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'youtu.be',
  'www.youtu.be',
};

/// 從 YouTube 網址解析影片 ID。host 不在白名單（如 music.youtube.com）時回傳 null。
String? youtubeVideoIdFromUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;

  final host = uri.host.toLowerCase();
  if (!_kYoutubeHosts.contains(host)) return null;

  bool valid(String? id) => id != null && id.isNotEmpty;

  if (host == 'youtu.be' || host == 'www.youtu.be') {
    final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    return valid(id) ? id : null;
  }

  // youtube.com / www / m
  final v = uri.queryParameters['v'];
  if (valid(v)) return v;
  final segments = uri.pathSegments;
  if (segments.length >= 2 &&
      (segments[0] == 'embed' || segments[0] == 'shorts' || segments[0] == 'v')) {
    return valid(segments[1]) ? segments[1] : null;
  }
  return null;
}

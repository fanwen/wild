/// 章节正文里的插图标记：Rust 侧 `c_content` 把章节页里的 `<img>` 抽成
/// `<!--image-->图片地址<!--image-->` 一行，两个阅读器都按这个标记分页/渲染。
final RegExp readerImageMarkerPattern = RegExp(
  r'<!--image-->([^<]+)<!--image-->',
);

/// 一行正文按插图标记切出来的片段：要么是文字，要么是一张插图。
class ReaderContentPart {
  final String? text;
  final String? imageUrl;

  const ReaderContentPart.text(this.text) : imageUrl = null;

  const ReaderContentPart.image(this.imageUrl) : text = null;

  bool get isImage => imageUrl != null;
}

/// 把一行正文按插图标记切成有序片段。
///
/// 支持标记在行首 / 行中 / 行尾以及一行里多张插图（标记在行首时旧代码不推进下标，
/// 会死循环 —— 所以这里统一用「匹配不到就退出」的写法）。
List<ReaderContentPart> splitImageMarkers(String paragraph) {
  final parts = <ReaderContentPart>[];
  var rest = paragraph;
  while (true) {
    final match = readerImageMarkerPattern.firstMatch(rest);
    if (match == null) break;
    final text = rest.substring(0, match.start).trim();
    if (text.isNotEmpty) {
      parts.add(ReaderContentPart.text(text));
    }
    final url = match.group(1)!.trim();
    if (url.isNotEmpty) {
      parts.add(ReaderContentPart.image(url));
    }
    rest = rest.substring(match.end);
  }
  final tail = rest.trim();
  if (tail.isNotEmpty) {
    parts.add(ReaderContentPart.text(tail));
  }
  return parts;
}

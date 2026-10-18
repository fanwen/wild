class ReaderPage {
  final String content;
  final bool isImage;

  /// 这一页的最后一个段落是否被分页截断（本页放不下、后面还有内容）。
  /// 是的话：它的末行其实不是段落末行 —— 末行也要两端对齐，
  /// 且这一页最后不该跟段间距（那不是段落结束）。
  final bool continues;

  const ReaderPage({
    required this.content,
    required this.isImage,
    this.continues = false,
  });
}

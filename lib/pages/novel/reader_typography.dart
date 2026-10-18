/// 中文正文排版：段首缩进 + 半角标点转全角 + 「标点可置行首」（行尾排满）。
///
/// 纯函数，分页与渲染必须用同一份结果 —— 否则会出现「按排版后的文字分页、
/// 按原文渲染」这类高度不一致（溢出/断页错位）。
///
/// 这里**故意去掉**中文断行里「标点不能出现在行首」的禁则：
/// 引擎（Skia/ICU）遇到这种情况会把标点连同前一个字一起挤到下一行，
/// 结果是上一行行尾空出一格（用户反馈的「行尾空白」）。
/// 做法是「行尾排满」：把下一行的字按宽度一个个提到这一行行尾，塞得下就提 ——
/// 标点因此可以落在行首，行尾也不再留白。
///
/// 剩下的行尾空隙（引擎断行不可能每次都刚好排满）用轻微字距拉伸补齐：
/// 除段落最后一行外，每行拉伸到与版心同宽（两端对齐）。
///
/// 行分隔用 U+2028(LINE SEPARATOR)：不是 '\n'，因为 `_TextPage` 是按 '\n'
/// 切段落并插段间距的；U+2028 实测在 TextPainter 里换行且不占宽度。
/// 打开这项排版时**每一行的行首都会被标记**，这样渲染侧只凭字符串就能知道
/// 行的切分（分页存的是纯文本，带不了别的元数据）。
library;

import 'package:flutter/painting.dart';

/// 全角空格，用作段首缩进字符
const String kFullWidthSpace = '\u3000';

/// 强制换行（行内换行）：LINE SEPARATOR，不是段落分隔符
const String kForcedLineBreak = '\u2028';

/// 行尾对齐时单行最多拉伸的字距（相对字号）—— 超过就不拉了，
/// 免得一行只有几个字时被拉得散开。
const double kMaxLineStretchRatio = 0.25;

/// 半角标点 → 全角标点（只在中文语境里转，别把 3.14、1,000、网址里的符号转了）
const Map<String, String> kHalfWidthToFullWidth = {
  ',': '，',
  '.': '。',
  '!': '！',
  '?': '？',
  ':': '：',
  ';': '；',
  '(': '（',
  ')': '）',
  '[': '［',
  ']': '］',
};

/// 收尾类标点：只剩这些标点单独占一行时，允许把它们收进上一行
/// （上一行轻微压缩字距）。否则页面顶部会出现「只有标点的一行」，
/// 看起来就像空了一行。
const Set<String> kTrailingPunctuation = {
  '。', '，', '、', '！', '？', '：', '；', '）', '」', '』', '】', '》', '〉',
  '”', '’', '…', '—', '·', '．', ',', '.',
};

/// 行尾压缩上限（相对字号）：只用在「把收尾标点收上来」这一种情况 ——
/// 普通行引擎本来就不会超出版心，能超出只有这一种来源。
const double kMaxLineCompressRatio = 0.12;

/// 左括号类：断行时不把它吊在行尾（UAX#14 本来也不允许，这条保留）
const Set<String> kOpenBrackets = {
  '「', '『', '（', '【', '《', '〈', '“', '‘', '［', '｛',
};

/// 渲染余量：行尾排满/对齐都留这么点空隙，几像素误差就会让 TextPainter
/// 多折一行，行数一旦和分页时算的不一样，页面就会溢出。
const double _renderSlack = 0.5;

/// 行首空白（含全角空格）
final RegExp _leadingWhitespace = RegExp(r'^\s+');

/// 是不是中文语境（汉字 / 中文标点 / 全角符号 / 假名都算）
bool _isCjkContext(String ch) => ch.isNotEmpty && ch.runes.first > 0x2E80;

bool _isAllTrailingPunctuation(String text) {
  if (text.isEmpty) return false;
  return text.runes.every(
    (r) => kTrailingPunctuation.contains(String.fromCharCode(r)),
  );
}

bool _isAsciiWordChar(String ch) {
  if (ch.isEmpty) return false;
  final code = ch.codeUnitAt(0);
  return (code >= 0x30 && code <= 0x39) || // 0-9
      (code >= 0x41 && code <= 0x5A) || // A-Z
      (code >= 0x61 && code <= 0x7A); // a-z
}

/// 半角标点转全角（强制用全角标点）。
///
/// 只在**前一个字符是中文语境**时转换，所以 '3.14'、'1,000'、'hello!' 这类
/// 不会被改；中文句子里夹的 ',' '.' '!' 会变成 '，' '。' '！'。
String toFullWidthPunctuation(String text) {
  if (text.isEmpty) return text;
  final runes = text.runes.toList();
  final out = StringBuffer();
  for (var i = 0; i < runes.length; i++) {
    final ch = String.fromCharCode(runes[i]);
    final full = kHalfWidthToFullWidth[ch];
    final prevIsCjk =
        i > 0 && _isCjkContext(String.fromCharCode(runes[i - 1]));
    out.write(full != null && prevIsCjk ? full : ch);
  }
  return out.toString();
}

/// 段首缩进：先剥掉正文原有的行首空白（网页里常带全角空格），
/// 再按设定补 [indentChars] 个全角空格。空段落原样返回。
String applyParagraphIndent(String paragraph, int indentChars) {
  if (paragraph.isEmpty) return paragraph;
  final body = paragraph.replaceFirst(_leadingWhitespace, '');
  // 整段都是空白：保持原样，别把空行也变成缩进行
  if (body.isEmpty) return paragraph;
  if (indentChars <= 0) return body;
  return '${kFullWidthSpace * indentChars}$body';
}

/// 用引擎（TextPainter）算出每一行的起始下标。
///
/// 用 [TextPainter.computeLineMetrics] 每行的 baseline 反查字符位置 ——
/// 不要用「caret.dy ÷ 行高」这种估算，长段落里行高的小数误差会把行数算错，
/// 行结构一旦错，分页高度和渲染就会对不上。
List<int> engineLineStarts(
  String text, {
  required double maxWidth,
  required TextStyle style,
}) {
  if (text.isEmpty || maxWidth <= 0) return const [];
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(text: text, style: style),
  );
  painter.layout(maxWidth: maxWidth);
  final metrics = painter.computeLineMetrics();
  if (metrics.isEmpty) return const [];
  final starts = <int>[];
  for (final metric in metrics) {
    final offset = painter
        .getPositionForOffset(Offset(0, metric.baseline))
        .offset;
    final start = offset.clamp(0, text.length);
    if (starts.isEmpty || start > starts.last) {
      starts.add(start);
    }
  }
  if (starts.isEmpty || starts.first != 0) starts.insert(0, 0);
  return starts;
}

/// 按引擎断行把 [text] 切成一行一行（含行尾的 [kForcedLineBreak]，见 [lineAtoms]）。
List<String> splitEngineLines(
  String text, {
  required double maxWidth,
  required TextStyle style,
}) {
  if (text.isEmpty) return const [];
  final starts = engineLineStarts(text, maxWidth: maxWidth, style: style);
  if (starts.length <= 1) return [text];
  final lines = <String>[];
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1] : text.length;
    lines.add(text.substring(starts[i], end));
  }
  return lines;
}

/// 拆行并把行尾的强制换行符剥掉（U+2028 是行分隔符，不该算进行内容里，
/// 否则再次处理会出现「一个位置两个标记」）。空行丢弃。
List<String> lineAtoms(
  String text, {
  required double maxWidth,
  required TextStyle style,
}) {
  if (text.isEmpty) return const [];
  return splitEngineLines(text, maxWidth: maxWidth, style: style)
      .map(
        (line) => line.endsWith(kForcedLineBreak)
            ? line.substring(0, line.length - kForcedLineBreak.length)
            : line,
      )
      .where((line) => line.isNotEmpty)
      .toList();
}

/// 不带换行的单行宽度
double _measure(String text, TextStyle style) {
  if (text.isEmpty) return 0;
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 1,
    text: TextSpan(text: text, style: style),
  );
  painter.layout();
  return painter.width;
}

/// 能从下一行提到这一行行尾的字数（0 = 提不动）。
///
/// 纯「塞得下就提」：宽度不超过版心就继续提，不做字距压缩 ——
/// 要的是去掉禁则，不是把字挤紧。英文/数字不拆词，左括号不吊行尾。
int _pullUpCount(
  String prev,
  String line, {
  required double maxWidth,
  required TextStyle style,
}) {
  if (line.isEmpty) return 0;
  var width = _measure(prev, style);
  var count = 0;
  while (count < line.length) {
    final ch = line[count];
    if (count == 0 && kOpenBrackets.contains(ch)) break;
    if (_isAsciiWordChar(ch) &&
        count + 1 < line.length &&
        _isAsciiWordChar(line[count + 1])) {
      break;
    }
    final charWidth = _measure(ch, style);
    if (width + charWidth > maxWidth - _renderSlack) {
      // 剩下整行都是收尾标点：把它们全收到这一行（上一行轻微压缩字距）。
      // 不做的话标点会自己占一行 —— 翻页后出现在页面顶部就像空了一行。
      final rest = line.substring(count);
      final overflow =
          width + _measure(rest, style) - (maxWidth - _renderSlack);
      final budget =
          kMaxLineCompressRatio *
          (style.fontSize ?? 14.0) *
          (prev.runes.length + rest.runes.length);
      if (_isAllTrailingPunctuation(rest) && overflow <= budget) {
        return line.length;
      }
      break;
    }
    width += charWidth;
    count++;
  }
  return count;
}

/// 行尾排满：把下一行的字提到这一行行尾（塞得下就提），因此**标点可以落在行首**
/// —— 这就是去掉「标点不能出现在行首」禁则的效果。
///
/// 返回每一行行首都用 [kForcedLineBreak] 标记的文本。
String fillReaderLines(
  String text, {
  required double maxWidth,
  required TextStyle style,
  int maxIterations = 3,
}) {
  if (text.isEmpty || maxWidth <= 0) return text;
  final lines = lineAtoms(text, maxWidth: maxWidth, style: style);
  for (var iteration = 0; iteration < maxIterations; iteration++) {
    var changed = false;
    for (var k = 0; k + 1 < lines.length; k++) {
      final pull = _pullUpCount(
        lines[k],
        lines[k + 1],
        maxWidth: maxWidth,
        style: style,
      );
      if (pull <= 0) continue;
      lines[k] = lines[k] + lines[k + 1].substring(0, pull);
      lines[k + 1] = lines[k + 1].substring(pull);
      if (lines[k + 1].isEmpty) lines.removeAt(k + 1);
      changed = true;
    }
    if (!changed) break;
  }
  return lines.where((line) => line.isNotEmpty).join(kForcedLineBreak);
}

/// 正文显示前的统一排版处理（全角标点 + 段首缩进 + 行尾排满）。
///
/// [style] / [maxWidth] 给定时才会做「行尾排满」—— 不给就只做标点全角化与缩进，
/// 换行完全交回引擎（相当于关掉这项排版，零开销）。
String applyReaderTypography(
  String paragraph, {
  required int indentChars,
  required bool allowPunctuationAtLineStart,
  TextStyle? style,
  double? maxWidth,
}) {
  final text = applyParagraphIndent(
    toFullWidthPunctuation(paragraph),
    indentChars,
  );
  if (text.isEmpty) return text;
  if (!allowPunctuationAtLineStart ||
      style == null ||
      maxWidth == null ||
      maxWidth <= 0) {
    return text;
  }
  return fillReaderLines(text, maxWidth: maxWidth, style: style);
}

/// 段落文本是否带行标记（做过「行尾排满」排版）
bool hasReaderLineBreaks(String paragraph) =>
    paragraph.contains(kForcedLineBreak);

/// 段落文本按行切开
List<String> readerLines(String paragraph) => paragraph.split(kForcedLineBreak);

/// 段落占几行（没标记就是引擎自己折，返回 1 不作数，调用方按引擎测量走）
int readerLineCount(String paragraph) => readerLines(paragraph).length;

/// 一行还要拉伸多少字距才能和版心同宽（每字，正值）。
/// 已经够宽、或者需要的拉伸超过 [kMaxLineStretchRatio] 就返回 0（不拉）。
/// 段首缩进的全角空格不参与拉伸。
double lineStretchAmount(
  String line, {
  required double maxWidth,
  required TextStyle style,
}) {
  if (line.isEmpty || maxWidth <= 0) return 0;
  var head = 0;
  while (head < line.length && line[head] == kFullWidthSpace) {
    head++;
  }
  final body = line.substring(head);
  if (body.isEmpty) return 0;
  final headWidth = head > 0 ? _measure(kFullWidthSpace * head, style) : 0.0;
  final slack = maxWidth - headWidth - _measure(body, style) - _renderSlack;
  final count = body.runes.length;
  if (count == 0) return 0;
  final fontSize = style.fontSize ?? 14.0;
  if (slack < 0) {
    // 比版心宽：只可能是上面「把收尾标点收上来」的行，允许有限压缩把它挤回来
    return -slack <= kMaxLineCompressRatio * fontSize * count
        ? slack / count
        : 0;
  }
  final stretch = slack / count;
  return stretch > kMaxLineStretchRatio * fontSize ? 0 : stretch;
}

/// 一行的渲染/测量用 span（[stretch] = 行尾对齐要多拉的字距）。
/// 测量与渲染必须共用它，否则折行位置对不上。
TextSpan readerLineSpan(
  String line, {
  required TextStyle style,
  double stretch = 0,
}) {
  if (line.isEmpty) return const TextSpan();
  if (stretch == 0) return TextSpan(text: line, style: style);
  final base = style.letterSpacing ?? 0;
  var head = 0;
  while (head < line.length && line[head] == kFullWidthSpace) {
    head++;
  }
  final children = <TextSpan>[];
  if (head > 0) children.add(TextSpan(text: line.substring(0, head)));
  children.add(
    TextSpan(
      text: line.substring(head),
      style: style.copyWith(letterSpacing: base + stretch),
    ),
  );
  return TextSpan(style: style, children: children);
}

/// 渲染用：一段正文 → TextSpan。
///
/// 带行标记的段落按行渲染，除最后一行外每行拉伸到与版心同宽（两端对齐）；
/// 没标记的段落整段交给引擎折行。
TextSpan readerParagraphSpan(
  String paragraph, {
  required TextStyle style,
  required double maxWidth,
  bool continuesAfter = false,
}) {
  final lines = hasReaderLineBreaks(paragraph)
      ? readerLines(paragraph)
      : [paragraph];
  if (lines.length == 1 && !continuesAfter) {
    return TextSpan(text: lines.first, style: style);
  }
  final children = <TextSpan>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final isLast = i == lines.length - 1;
    children.add(
      readerLineSpan(
        line,
        style: style,
        stretch: (isLast && !continuesAfter)
            ? 0
            : lineStretchAmount(line, maxWidth: maxWidth, style: style),
      ),
    );
    if (!isLast) {
      children.add(TextSpan(text: kForcedLineBreak, style: style));
    }
  }
  return TextSpan(style: style, children: children);
}

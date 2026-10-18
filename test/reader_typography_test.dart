import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wild/pages/novel/reader_typography.dart';

/// 测试字体每字宽 = fontSize（16），且测试里不加 letterSpacing，
/// 所以行宽可以直接用「几个字」来算（1 字 = 1 em）。
const double _charWidth = 16.0;
const TextStyle _style = TextStyle(fontSize: _charWidth, height: 1.3);

/// 不限宽测量：不带换行的文本 = 单行宽；带 [kForcedLineBreak] 的 = 最宽那一行
double _width(String text, {TextStyle style = _style}) {
  if (text.isEmpty) return 0;
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(text: text, style: style),
  );
  painter.layout();
  return painter.width;
}

List<String> _engineLines(String text, {required double charsPerLine}) {
  final starts = engineLineStarts(
    text,
    maxWidth: charsPerLine * _charWidth,
    style: _style,
  );
  final lines = <String>[];
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1] : text.length;
    lines.add(text.substring(starts[i], end).replaceAll(kForcedLineBreak, ''));
  }
  return lines;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('段首缩进', () {
    test('按设定补全角空格，并剥掉原有的行首空白', () {
      expect(applyParagraphIndent('他说。', 2), '　　他说。');
      expect(applyParagraphIndent('　　他说。', 2), '　　他说。');
      expect(applyParagraphIndent('  他说。', 2), '　　他说。');
      expect(applyParagraphIndent('他说。', 0), '他说。');
      expect(applyParagraphIndent('　　他说。', 0), '他说。');
      expect(applyParagraphIndent('', 2), '');
      // 整段空白保持原样，别把空行变成缩进行
      expect(applyParagraphIndent('　　', 2), '　　');
    });
  });

  group('强制换行符 U+2028', () {
    test('在文本布局里确实断行，且不占宽度', () {
      const width = 10 * _charWidth;
      TextPainter layout(String text) => TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(text: text, style: _style),
      )..layout(maxWidth: width);

      final oneLine = layout('你好世界');
      final marked = layout('你好${kForcedLineBreak}世界');
      expect(oneLine.computeLineMetrics().length, 1);
      expect(marked.computeLineMetrics().length, 2);
      // 标记不占宽：断成两行，最宽的一行还是 2 字
      expect(marked.width, closeTo(2 * _charWidth, 0.01));
      expect(marked.width, closeTo(oneLine.width / 2, 0.01));
    });

    test('带行标记的段落：每行行高一致（分页按「总高 ÷ 行数」取行高）', () {
      const lineHeight = 1.3;
      const width = 4 * _charWidth;
      final marked = '一二三${kForcedLineBreak}四五六${kForcedLineBreak}七八';
      double heightOf(String text) {
        final painter = TextPainter(
          textDirection: TextDirection.ltr,
          strutStyle: const StrutStyle(height: lineHeight),
          text: readerParagraphSpan(text, style: _style, maxWidth: width),
        );
        painter.layout(maxWidth: width);
        return painter.height;
      }

      final oneLine = TextPainter(
        textDirection: TextDirection.ltr,
        strutStyle: const StrutStyle(height: lineHeight),
        text: readerParagraphSpan('一二三', style: _style, maxWidth: width),
      )..layout(maxWidth: width);
      expect(
        heightOf(marked),
        closeTo(oneLine.height * readerLineCount(marked), 0.01),
      );
    });
  });

  group('强制全角标点', () {
    test('中文旁边的半角标点转全角', () {
      expect(toFullWidthPunctuation('他说,你好.'), '他说，你好。');
      expect(toFullWidthPunctuation('什么?真的!'), '什么？真的！');
      expect(toFullWidthPunctuation('如下:第一;第二'), '如下：第一；第二');
    });

    test('西文语境里的半角标点不动', () {
      expect(toFullWidthPunctuation('3.14'), '3.14');
      expect(toFullWidthPunctuation('1,000'), '1,000');
      expect(toFullWidthPunctuation('hello!'), 'hello!');
      expect(toFullWidthPunctuation('a:b'), 'a:b');
      expect(toFullWidthPunctuation('https://a.b/c'), 'https://a.b/c');
    });
  });

  group('去掉「标点不能出现在行首」禁则（行尾排满）', () {
    // 行宽 4 字：引擎（ICU）不许在「，」前断行，于是把「四，」一起推到下一行，
    // 上一行「一二三」就空出一格 —— 这正是用户反馈的行尾空白。
    const text = '一二三四，五六七八';
    const charsPerLine = 4.0;
    // 多给 1px：测试字体每字正好 16px，正好等于版心时会卡在渲染余量的边界上
    const maxWidth = charsPerLine * _charWidth + 1;

    test('引擎原始断行确实会让上一行空一格（说明这个问题真实存在）', () {
      final raw = _engineLines(text, charsPerLine: charsPerLine);
      expect(raw, ['一二三', '四，五六', '七八']);
      expect(_width(raw.first) + _width('四'), lessThanOrEqualTo(maxWidth));
      expect(_width(raw.first), lessThan(maxWidth - _charWidth / 2));
    });

    test('排满之后上一行不再空、标点落到下一行行首（允许）', () {
      final fixed = fillReaderLines(text, maxWidth: maxWidth, style: _style);
      expect(readerLines(fixed), ['一二三四', '，五六七', '八']);
      expect(readerLines(fixed).join(), text);
      // 标点在行首是允许的（禁则已去掉）
      expect(readerLines(fixed)[1].startsWith('，'), isTrue);
    });

    test('除最后一行外每行都排满（再加一个字就放不下）', () {
      final fixed = fillReaderLines(
        '窗外下着很大的雨，打在玻璃上——他想起很久以前的事。',
        maxWidth: maxWidth,
        style: _style,
      );
      final lines = readerLines(fixed);
      for (var i = 0; i + 1 < lines.length; i++) {
        expect(
          _width(lines[i]) + _width(lines[i + 1][0]),
          greaterThanOrEqualTo(maxWidth - 0.01),
          reason: '第 $i 行没排满：$lines',
        );
      }
    });

    test('英文/数字不拆词', () {
      // 'hello' 是整体：行尾塞不下整个词就不提进来，但后面的汉字照提
      const mixed = '一二hello三';
      const width = 6 * _charWidth + 1;
      final fixed = fillReaderLines(mixed, maxWidth: width, style: _style);
      expect(readerLines(fixed), ['一二', 'hello三']);
      expect(readerLines(fixed).join(), mixed);
    });

    test('幂等：反复处理结果一样', () {
      final once = fillReaderLines(text, maxWidth: maxWidth, style: _style);
      final twice = fillReaderLines(once, maxWidth: maxWidth, style: _style);
      expect(twice, once);
    });
  });

  group('行尾对齐（两端对齐）', () {
    const text = '一二三四，五六七八九十';
    const maxWidth = 4 * _charWidth + 1;

    test('中间的行拉伸到和版心同宽，最后一行不拉', () {
      final fixed = fillReaderLines(text, maxWidth: maxWidth, style: _style);
      final lines = readerLines(fixed);
      for (var i = 0; i < lines.length; i++) {
        final stretch = lineStretchAmount(
          lines[i],
          maxWidth: maxWidth,
          style: _style,
        );
        final painter = TextPainter(
          textDirection: TextDirection.ltr,
          text: readerLineSpan(lines[i], style: _style, stretch: stretch),
        )..layout();
        if (i == lines.length - 1) {
          expect(stretch, 0, reason: '最后一行不该拉伸：${lines[i]}');
          continue;
        }
        // 拉伸到版心（留 0.5px 渲染余量）
        expect(painter.width, closeTo(maxWidth - 0.5, 0.6));
      }
    });

    test('整段渲染出来的跨度不超过版心（分页高度才对得上）', () {
      final fixed = fillReaderLines(text, maxWidth: maxWidth, style: _style);
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: readerParagraphSpan(fixed, style: _style, maxWidth: maxWidth),
      )..layout();
      expect(painter.width, lessThanOrEqualTo(maxWidth + 0.01));
      expect(painter.computeLineMetrics().length, readerLines(fixed).length);
    });
  });

  group('整段排版（缩进 + 全角 + 排满）', () {
    const text = '一二三四五六，七八九十';
    const maxWidth = 4 * _charWidth + 1;

    test('三项一起生效', () {
      final out = applyReaderTypography(
        text,
        indentChars: 2,
        allowPunctuationAtLineStart: true,
        style: _style,
        maxWidth: maxWidth,
      );
      expect(out.startsWith('　　'), isTrue, reason: '没有段首缩进: $out');
      expect(readerLines(out).join(), '　　$text');
    });

    test('半角标点在这一步就变成全角', () {
      expect(
        applyReaderTypography(
          '他说,你好.',
          indentChars: 0,
          allowPunctuationAtLineStart: false,
        ),
        '他说，你好。',
      );
    });

    test('收尾标点不单独占一行（收进上一行 + 上一行轻微压缩）', () {
      // 上一行排满 10 字，下一行只有一个句号 —— 引擎禁则下这种「标点单独成行」
      // 会出现在页面顶部，看着像空了一行。要把句号收上去。
      const text = '一二三四五六七八九十${kForcedLineBreak}。';
      const maxWidth = 10 * _charWidth;
      final fixed = fillReaderLines(text, maxWidth: maxWidth, style: _style);

      expect(readerLines(fixed), ['一二三四五六七八九十。']);

      // 收上去之后这一行超出版心，靠负拉伸（压缩）挤回来
      final line = readerLines(fixed).single;
      final stretch = lineStretchAmount(
        line,
        maxWidth: maxWidth,
        style: _style,
      );
      expect(stretch, lessThan(0));
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: readerLineSpan(line, style: _style, stretch: stretch),
      )..layout(maxWidth: maxWidth);
      expect(painter.width, lessThanOrEqualTo(maxWidth));
      expect(painter.computeLineMetrics().length, 1);
    });

    test('压缩有上限：超出太多就不收（免得把行挤变形）', () {
      // 上一行已经排满 4 字，后面 3 个句号 —— 收上去要压 3em，远超上限
      const text = '一二三四${kForcedLineBreak}。。。';
      const maxWidth = 4 * _charWidth;
      final fixed = fillReaderLines(text, maxWidth: maxWidth, style: _style);
      expect(readerLines(fixed).length, 2);
    });

    test('被分页截断的段落：末行也两端对齐（continuesAfter）', () {
      const text =
          '一二三四五六七八九十${kForcedLineBreak}一二三四五六七八九';
      const maxWidth = 10 * _charWidth;

      final spanEnd = readerParagraphSpan(text, style: _style, maxWidth: maxWidth);
      final spanCut = readerParagraphSpan(
        text,
        style: _style,
        maxWidth: maxWidth,
        continuesAfter: true,
      );

      // 真段落末行：普通 span（没有子 span = 没加字距）
      final endLast = spanEnd.children!.last as TextSpan;
      expect(endLast.children, isNull);

      // 被截断的段末行：拆成子 span 并带正字距
      final cutLast = spanCut.children!.last as TextSpan;
      expect(cutLast.children, isNotNull);
      final cutRun = cutLast.children!.last as TextSpan;
      expect(cutRun.style!.letterSpacing! > 0, isTrue);

      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: spanCut,
      )..layout(maxWidth: maxWidth);
      expect(painter.width, lessThanOrEqualTo(maxWidth + 0.01));
    });

    test('单行残留片段（continuesAfter）也要两端对齐', () {
      const text = '一二三四五六七八九';
      const maxWidth = 10 * _charWidth;
      final plain = readerParagraphSpan(text, style: _style, maxWidth: maxWidth);
      expect(plain.children, isNull);

      final cut = readerParagraphSpan(
        text,
        style: _style,
        maxWidth: maxWidth,
        continuesAfter: true,
      );
      final run = (cut.children!.last as TextSpan).children!.last as TextSpan;
      expect(run.style!.letterSpacing! > 0, isTrue);
    });

    test('不给宽度时只做标点全角化与缩进，不做排满', () {
      expect(
        applyReaderTypography(
          text,
          indentChars: 2,
          allowPunctuationAtLineStart: true,
        ),
        '　　$text',
      );
    });

    test('开关关掉时只做全角化，行结构交给引擎', () {
      final out = applyReaderTypography(
        text,
        indentChars: 0,
        allowPunctuationAtLineStart: false,
        style: _style,
        maxWidth: maxWidth,
      );
      expect(out, text);
      expect(hasReaderLineBreaks(out), isFalse);
    });
  });
}

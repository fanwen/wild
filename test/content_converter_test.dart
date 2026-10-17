import 'package:flutter_test/flutter_test.dart';
import 'package:wild/l10n/content_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentConverter c;

  String toTw(String s) => c.convert(s, toTraditional: true);
  String toCn(String s) => c.convert(s, toTraditional: false);

  setUpAll(() async {
    await ContentConverter.load();
    c = ContentConverter.instance!;
  });

  test('表已加载', () {
    expect(ContentConverter.isLoaded, isTrue);
    expect(toTw('测试'), isNot('测试'));
  });

  group('台湾用词（OpenCC s2twp）', () {
    test('词汇级', () {
      expect(toTw('网络'), '網路');
      expect(toTw('软件'), '軟體');
      expect(toTw('信息'), '資訊');
      expect(toTw('文件夹'), '資料夾');
      expect(toTw('硬盘'), '硬碟');
    });

    test('字形级（含易错字）', () {
      expect(toTw('头发'), '頭髮');
      expect(toTw('里面'), '裡面');
      expect(toTw('干什么'), '幹什麼');
      expect(toTw('干净'), '乾淨');
      expect(toTw('台湾'), '臺灣');
      expect(toTw('着一件'), '著一件');
    });

    test('整句', () {
      expect(toTw('这个软件的网络信息'), '這個軟體的網路資訊');
      expect(
        toTw('他戴着兜帽，只身走进书店。'),
        '他戴著兜帽，隻身走進書店。',
      );
    });
  });

  test('非中文原样（网址、数字、标点、空串）', () {
    expect(toTw('https://pic.777743.xyz/1/1269/40162/48046.jpg'),
        'https://pic.777743.xyz/1/1269/40162/48046.jpg');
    expect(toTw('Chapter 12 - 2026/10/17'), 'Chapter 12 - 2026/10/17');
    expect(toTw(''), '');
    expect(toTw('。。。！？ '), '。。。！？ ');
  });

  test('已经是繁体就不再动（含台湾用词校正）', () {
    expect(toTw('繁體中文測試'), '繁體中文測試');
    expect(toTw('網路資訊'), '網路資訊');
  });

  group('繁 → 简（tw2sp）', () {
    test('字形与台湾用词', () {
      expect(toCn('小說詳情'), '小说详情');
      expect(toCn('第一卷 中央諸國篇'), '第一卷 中央诸国篇');
      expect(toCn('無頭騎士'), '无头骑士');
      expect(toCn('這個軟體的網路資訊'), '这个软件的网络信息');
      expect(toCn('硬碟'), '硬盘');
    });

    test('简体输入基本不变（幂等）', () {
      expect(toCn('这是一段简体中文。'), '这是一段简体中文。');
      expect(toCn('网络信息'), '网络信息');
    });

    test('非中文原样', () {
      expect(toCn('https://a.b/1.jpg'), 'https://a.b/1.jpg');
    });
  });

  test('同一个字符串重复调用结果一致（有缓存）', () {
    const text = '这是一段用来测试缓存的中文内容。';
    final first = toTw(text);
    for (var i = 0; i < 5; i++) {
      expect(toTw(text), first);
    }
    expect(toTw(text), isNot(text));
  });

  test('长文本（含换行、HTML 片段）也能转', () {
    const html =
        '<div class="divimage"><a href="/1/1269/40162/48046.jpg"><img src="x.jpg"/></a></div>\n'
        '他的记忆中，那段对话始终清晰。\n';
    final out = toTw(html);
    expect(out, contains('class="divimage"'));
    expect(out, contains('他的記憶中，那段對話始終清晰。'));
  });
}

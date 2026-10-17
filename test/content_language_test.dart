import 'package:flutter_test/flutter_test.dart';
import 'package:wild/l10n/content_converter.dart';
import 'package:wild/l10n/content_language.dart';
import 'package:wild/l10n/ui_language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    setContentTraditional(false);
    setUiTraditional(false);
  });

  test('表还没加载：原样返回，不抛异常', () {
    setContentTraditional(true);
    expect(ContentConverter.isLoaded, isFalse);
    expect(cv('网络'), '网络');
  });

  test('存储值往返（属性键 content_language）', () {
    for (final language in ContentLanguage.values) {
      expect(
        contentLanguageFromStorage(contentLanguageToStorage(language)),
        language,
      );
    }
    // 没存过 / 存了怪值 → 跟随界面语言
    expect(contentLanguageFromStorage(''), ContentLanguage.followUi);
    expect(contentLanguageFromStorage('zh_HK'), ContentLanguage.followUi);
  });

  test('跟随界面语言：界面繁 → 内容繁', () {
    setUiTraditional(true);
    expect(contentIsTraditional(ContentLanguage.followUi), isTrue);
    setUiTraditional(false);
    expect(contentIsTraditional(ContentLanguage.followUi), isFalse);
  });

  test('强制繁 / 强制简与界面语言无关', () {
    setUiTraditional(false);
    expect(contentIsTraditional(ContentLanguage.zhTW), isTrue);
    setUiTraditional(true);
    expect(contentIsTraditional(ContentLanguage.zhCN), isFalse);
  });

  test('简体模式：简体原文不动，繁体内容转简体', () async {
    await ContentConverter.load();
    setContentTraditional(false);
    expect(cv('他戴着一顶帽子'), '他戴着一顶帽子');
    expect(cv('網路資訊'), '网络信息');
    expect(cvAll(['小说详情']), ['小说详情']);
  });

  test('繁体模式 + 表已加载：转换', () async {
    setContentTraditional(true);
    await ContentConverter.load();
    expect(cv('网络'), '網路');
    expect(cv('这个软件的网络信息'), '這個軟體的網路資訊');
    expect(cvAll(['网络', '软件']), ['網路', '軟體']);
    expect(cv('https://a.b/c.jpg'), 'https://a.b/c.jpg');
  });

  test('目标字形可读（给页面判断用）', () {
    setContentScript(ContentScript.simplified);
    expect(contentScriptNow, ContentScript.simplified);
    setContentTraditional(true);
    expect(contentIsTraditionalNow, isTrue);
    setContentTraditional(false);
    expect(contentIsTraditionalNow, isFalse);
  });
}

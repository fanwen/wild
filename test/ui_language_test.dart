import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wild/l10n/ui_language.dart';
import 'package:wild/l10n/zh_tw_strings.dart';

void main() {
  group('语言设置 → 是否繁体', () {
    const tw = Locale('zh', 'TW');
    const hk = Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
      countryCode: 'HK',
    );
    const cn = Locale('zh', 'CN');
    const en = Locale('en', 'US');

    test('明确选了就按选的', () {
      expect(useTraditionalOf(UiLanguage.zhTW, cn), isTrue);
      expect(useTraditionalOf(UiLanguage.zhCN, tw), isFalse);
    });

    test('跟随系统：看设备语言', () {
      expect(useTraditionalOf(UiLanguage.system, tw), isTrue);
      expect(useTraditionalOf(UiLanguage.system, hk), isTrue);
      expect(useTraditionalOf(UiLanguage.system, cn), isFalse);
      // 设备是英文/其他语言时回落到 app 原生的简中
      expect(useTraditionalOf(UiLanguage.system, en), isFalse);
    });
  });

  test('MaterialApp.locale', () {
    expect(materialLocaleOf(UiLanguage.system), isNull);
    expect(materialLocaleOf(UiLanguage.zhTW), const Locale('zh', 'TW'));
    expect(materialLocaleOf(UiLanguage.zhCN), const Locale('zh', 'CN'));
    expect(kSupportedLocales, contains(const Locale('zh', 'TW')));
  });

  group('l10n()', () {
    tearDown(() => setUiTraditional(false));

    test('简体模式：原样返回', () {
      setUiTraditional(false);
      expect(l10n('设置'), '设置');
      expect(l10n('书架'), '书架');
    });

    test('繁体模式：查表转换，表外的原样返回', () {
      setUiTraditional(true);
      expect(l10n('设置'), '設定');
      expect(l10n('书架'), '書架');
      expect(l10n('这是一句表里没有的话'), '这是一句表里没有的话');
    });
  });

  test('繁体表本身没问题（非空、没有空键空值、抽样的条目确实是繁体）', () {
    expect(kZhTwStrings, isNotEmpty);
    expect(kZhTwStrings.length, greaterThan(150));
    for (final entry in kZhTwStrings.entries) {
      expect(entry.key, isNotEmpty);
      expect(entry.value, isNotEmpty);
    }
    // 表里既有「简繁同形」的键（原样保留，好让覆盖率测试能断言键都在表内），
    // 也有真的转换过的键；抽查几条确认转换方向是简 → 繁。
    expect(kZhTwStrings['设置'], '設定');
    expect(kZhTwStrings['书架'], '書架');
    expect(kZhTwStrings['下载失败'], '下載失敗');
  });

  testWidgets('Material 组件文案（按钮/选择菜单/日期选择器）跟着界面语言走', (
    WidgetTester tester,
  ) async {
    Future<MaterialLocalizations> loc(UiLanguage lang) async {
      late MaterialLocalizations material;
      await tester.pumpWidget(
        MaterialApp(
          locale: materialLocaleOf(lang),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              material = MaterialLocalizations.of(context);
              expect(CupertinoLocalizations.of(context), isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return material;
    }

    // 界面语言 = 繁體中文：Material 自带的按钮、文本选择菜单、日期选择器都该是繁体
    final tw = await loc(UiLanguage.zhTW);
    expect(tw.okButtonLabel, '確定');
    expect(tw.copyButtonLabel, '複製');
    expect(tw.cutButtonLabel, '剪下');
    expect(tw.pasteButtonLabel, '貼上');
    expect(tw.selectAllButtonLabel, '全選');
    expect(tw.datePickerHelpText, '選取日期');

    // 界面语言 = 简体中文
    final cn = await loc(UiLanguage.zhCN);
    expect(cn.okButtonLabel, '确定');
    expect(cn.copyButtonLabel, '复制');
    expect(cn.cutButtonLabel, '剪切');
    expect(cn.pasteButtonLabel, '粘贴');
    expect(cn.selectAllButtonLabel, '全选');
    expect(cn.datePickerHelpText, '选择日期');

    // 跟随系统：locale 交给 Flutter 按设备语言在 kSupportedLocales 里挑。
    // 测试环境是 en_US，匹配不到就回落 supportedLocales.first = zh_CN（和 app 自带文案一致）。
    final sys = await loc(UiLanguage.system);
    expect(sys.okButtonLabel, '确定');
    expect(sys.datePickerHelpText, '选择日期');
  });

  for (final (lang, help, ok) in [
    (UiLanguage.zhTW, '選取日期', '確定'),
    (UiLanguage.zhCN, '选择日期', '确定'),
  ]) {
    testWidgets('日期选择器按界面语言渲染（$lang）', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: materialLocaleOf(lang),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showDatePicker(
                        context: context,
                        initialDate: DateTime(2026, 10, 17),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      ),
                  child: const Text('open'),
                ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(help), findsOneWidget);
      expect(find.text(ok), findsOneWidget);
    });
  }
}

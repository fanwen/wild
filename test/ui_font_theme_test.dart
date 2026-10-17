import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wild/pages/novel/font_family_cubit.dart';

void main() {
  test('系统默认：主题原样返回（不动字体族）', () {
    final base = ThemeData(useMaterial3: true);
    final applied = applyUiFontToTheme(base, const ReaderFont());

    // 原样返回：连字体族都不碰（测试环境的默认族名是 Roboto，这里不假设它是 null）
    expect(identical(applied, base), isTrue);
  });

  test('自定义界面字体：textTheme / primaryTextTheme 都带上族名', () {
    final base = ThemeData(useMaterial3: true);
    final applied = applyUiFontToTheme(
      base,
      const ReaderFont(family: 'ui_font_cafe', label: '界面体.ttf'),
    );

    expect(applied.textTheme.bodyMedium?.fontFamily, 'ui_font_cafe');
    expect(applied.textTheme.titleLarge?.fontFamily, 'ui_font_cafe');
    expect(applied.primaryTextTheme.titleMedium?.fontFamily, 'ui_font_cafe');
    // 别的没被改坏
    expect(applied.colorScheme.primary, base.colorScheme.primary);
    expect(applied.useMaterial3, isTrue);
  });

  testWidgets('主题里的界面字体真的落到 Text 上', (WidgetTester tester) async {
    final theme = applyUiFontToTheme(
      ThemeData(useMaterial3: true),
      const ReaderFont(family: 'ui_font_cafe', label: '界面体.ttf'),
    );

    late TextStyle style;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            style = Theme.of(context).textTheme.bodyMedium!;
            return const Scaffold(body: Text('设置'));
          },
        ),
      ),
    );

    expect(style.fontFamily, 'ui_font_cafe');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wild/cubits/content_language_cubit.dart';
import 'package:wild/l10n/content_language.dart';
import 'package:wild/widgets/content_language_row.dart';

/// 阅读器设置菜单里的「内容语言」这一行（用户要求：阅读器里也能改内容语言）。
void main() {
  late ContentLanguageCubit cubit;

  setUp(() {
    cubit = ContentLanguageCubit();
  });

  Future<void> pumpRow(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ContentLanguageCubit>.value(
          value: cubit,
          child: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: ContentLanguageRow(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('显示「内容语言」和当前值', (WidgetTester tester) async {
    await pumpRow(tester);
    expect(find.text('内容语言'), findsOneWidget);
    expect(find.text('跟随界面语言'), findsOneWidget);
  });

  testWidgets('点开弹窗列出三个选项，选简体中文（原文）后状态与显示都变', (WidgetTester tester) async {
    await pumpRow(tester);

    await tester.tap(find.text('内容语言'));
    await tester.pumpAndSettle();

    expect(find.text('跟随界面语言'), findsNWidgets(2)); // 行上的当前值 + 弹窗选项
    expect(find.text('繁體中文'), findsOneWidget);
    expect(find.text('简体中文（原文）'), findsOneWidget);

    await tester.tap(find.text('简体中文（原文）'));
    await tester.pumpAndSettle();

    expect(cubit.state, ContentLanguage.zhCN);
    expect(contentIsTraditionalNow, isFalse);
    expect(find.text('简体中文（原文）'), findsOneWidget); // 弹窗已关，行上显示新值
    expect(find.text('跟随界面语言'), findsNothing);
  });
}

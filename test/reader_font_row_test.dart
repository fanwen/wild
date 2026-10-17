import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wild/pages/novel/font_family_cubit.dart';
import 'package:wild/widgets/reader_font_row.dart';

void main() {
  testWidgets('字体行显示当前字体，点「选择」弹出字体选择框', (WidgetTester tester) async {
    final cubit = FontFamilyCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: Column(
              children: [
                ReaderFontRow(cubit: cubit, onFontChanged: () async {}),
              ],
            ),
          ),
        ),
      ),
    );

    // 默认状态
    expect(find.text('字体'), findsOneWidget);
    expect(find.text('系统默认'), findsOneWidget);

    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();

    // 选择框：预览 + 系统默认 + 从文件选择
    expect(find.text('中文预览效果：轻小说文库 Aa 123'), findsOneWidget);
    expect(find.textContaining('从文件选择'), findsOneWidget);
    expect(find.text('系统默认'), findsNWidgets(2)); // 设置行 + 选择框
  });

  testWidgets('切到自定义字体后设置行显示文件名', (WidgetTester tester) async {
    final cubit = FontFamilyCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: Column(
              children: [
                ReaderFontRow(cubit: cubit, onFontChanged: () async {}),
              ],
            ),
          ),
        ),
      ),
    );

    cubit.emit(const ReaderFont(family: 'reader_font_deadbeef', label: '楷体.ttf'));
    await tester.pumpAndSettle();

    expect(find.text('楷体.ttf'), findsOneWidget);
    expect(find.text('系统默认'), findsNothing);
  });

  testWidgets('界面字体行：标题可换、用的是 UiFontFamilyCubit（和正文互不相干）', (
    WidgetTester tester,
  ) async {
    final readerCubit = FontFamilyCubit();
    final uiCubit = UiFontFamilyCubit();
    addTearDown(readerCubit.close);
    addTearDown(uiCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<FontFamilyCubit>.value(value: readerCubit),
            BlocProvider<UiFontFamilyCubit>.value(value: uiCubit),
          ],
          child: Scaffold(
            body: Column(
              children: [
                ReaderFontRow(cubit: readerCubit, label: '正文字体'),
                ReaderFontRow(cubit: uiCubit, label: '界面字体'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('正文字体'), findsOneWidget);
    expect(find.text('界面字体'), findsOneWidget);

    // 只改正文那一个：界面行不受影响
    readerCubit.emit(
      const ReaderFont(family: 'reader_font_beef', label: '正文.ttf'),
    );
    await tester.pumpAndSettle();
    expect(find.text('正文.ttf'), findsOneWidget);
    expect(find.text('界面.ttf'), findsNothing);

    // 再只改界面那一个：正文行不受影响
    uiCubit.emit(const ReaderFont(family: 'ui_font_cafe', label: '界面.ttf'));
    await tester.pumpAndSettle();
    expect(find.text('正文.ttf'), findsOneWidget);
    expect(find.text('界面.ttf'), findsOneWidget);

    // 选择框标题跟随行的 label
    await tester.tap(find.text('选择').last);
    await tester.pumpAndSettle();
    expect(find.text('界面字体'), findsNWidgets(2)); // 行 + 选择框标题
  });
}

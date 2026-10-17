import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wild/cubits/reader_battery.dart';
import 'package:wild/cubits/reader_clock.dart';
import 'package:wild/widgets/reader_corners.dart';

/// 逻辑屏幕 360x800（1080x2400 @3x），正文边距：状态栏 24 + 上边距 56 / 导航栏 48 + 下边距 56。
const double _screenHeight = 800;
const EdgeInsets _readerPadding = EdgeInsets.only(
  top: 24 + 56,
  bottom: 48 + 56,
  left: 16,
  right: 16,
);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Stack(children: [child])),
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host(child));
}

void main() {
  testWidgets('四角：左上电量 / 右上章节名 / 左下时间 / 右下页码+百分比', (WidgetTester tester) async {
    readerClock.value = '09:05';
    readerBattery.value = const ReaderBattery(level: 85, charging: false);

    await _pump(
      tester,
      const ReaderCorners(
        chapterTitle: '第一章 序章',
        color: Colors.black,
        padding: _readerPadding,
        pageNumber: 3,
        pageCount: 12,
      ),
    );

    expect(find.text('第一章 序章'), findsOneWidget);
    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('3/12 25%'), findsOneWidget);
    expect(find.byType(BatteryBadge), findsOneWidget);
  });

  testWidgets('角标落在正文边距里：上排底边在上边距内 5px、下排顶边在下边距内 5px', (WidgetTester tester) async {
    readerClock.value = '09:05';
    readerBattery.value = const ReaderBattery(level: 85, charging: false);

    await _pump(
      tester,
      const ReaderCorners(
        chapterTitle: '第一章 序章',
        color: Colors.black,
        padding: _readerPadding,
        pageNumber: 3,
        pageCount: 12,
      ),
    );

    // 上排：电池（最高元素）底边 = padding.top - 5 = 75，且不越过正文块外沿
    final battery = tester.getRect(find.byType(BatteryBadge));
    expect(battery.bottom, closeTo(_readerPadding.top - 5, 0.01));
    expect(battery.left, closeTo(_readerPadding.left, 0.01));
    expect(battery.bottom, lessThan(_readerPadding.top));

    // 右上章节名与电池同一行底部对齐
    final title = tester.getRect(find.text('第一章 序章'));
    expect(title.bottom, closeTo(battery.bottom, 0.01));
    expect(title.right, closeTo(360 - _readerPadding.right, 0.01));

    // 下排：页码顶边 = 高度 - padding.bottom + 5，时间与它同一基线
    final page = tester.getRect(find.text('3/12 25%'));
    expect(page.top, closeTo(_screenHeight - _readerPadding.bottom + 5, 0.01));
    expect(page.top, greaterThan(_screenHeight - _readerPadding.bottom));
    expect(page.right, closeTo(360 - _readerPadding.right, 0.01));

    final clock = tester.getRect(find.text('09:05'));
    expect(clock.left, closeTo(_readerPadding.left, 0.01));
    expect(clock.top, closeTo(page.top, 0.01));
  });

  testWidgets('滚动式阅读器：右下角显示进度文案而不是页码', (WidgetTester tester) async {
    readerClock.value = '23:59';
    readerBattery.value = const ReaderBattery(level: 40, charging: true);

    await _pump(
      tester,
      const ReaderCorners(
        chapterTitle: '第二章',
        color: Colors.black,
        padding: _readerPadding,
        progressText: '42% 已读',
      ),
    );

    expect(find.text('42% 已读'), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('没有电量数据时不画电池（避免占位跳动）', (WidgetTester tester) async {
    readerClock.value = '09:05';
    readerBattery.value = null;

    await _pump(
      tester,
      const ReaderCorners(
        chapterTitle: '第一章',
        color: Colors.black,
        padding: _readerPadding,
        pageNumber: 1,
        pageCount: 1,
      ),
    );

    expect(find.byType(BatteryBadge), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('1/1 100%'), findsOneWidget);
  });

  testWidgets('布局快照（golden，视觉确认百分比在电池框里）', (WidgetTester tester) async {
    readerClock.value = '14:52';
    readerBattery.value = const ReaderBattery(level: 85, charging: false);

    await _pump(
      tester,
      const ReaderCorners(
        chapterTitle: '序章',
        color: Colors.black,
        padding: _readerPadding,
        pageNumber: 8,
        pageCount: 27,
      ),
    );

    await expectLater(
      find.byType(ReaderCorners),
      matchesGoldenFile('goldens/reader_corners.png'),
    );
  });
}

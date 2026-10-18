import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wild/cubits/reader_battery.dart';
import 'package:wild/cubits/reader_clock.dart';
import 'package:wild/widgets/reader_corners.dart';

/// 逻辑屏幕 360x800（1080x2400 @3x）。
/// 布局：状态栏安全区 24 → 上角标栏 24 →（上边距）→ 正文 →（下边距）→
/// 下角标栏 24 → 导航栏安全区 48。（上/下边距是用户设的，不含角标栏。）
const double _screenHeight = 800;
const double _safeTop = 24;
const double _safeBottom = 48;
const double _inset = 16;

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Stack(children: [child])));

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
        safeTop: _safeTop,
        safeBottom: _safeBottom,
        leftInset: _inset,
        rightInset: _inset,
        pageNumber: 3,
        pageCount: 12,
      ),
    );

    expect(find.text('第一章 序章'), findsOneWidget);
    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('3/12 25%'), findsOneWidget);
    expect(find.byType(BatteryBadge), findsOneWidget);
  });

  testWidgets('上排在「安全区+上角标栏」里、下排在下角标栏里（都不进正文区）', (
    WidgetTester tester,
  ) async {
    readerClock.value = '09:05';
    readerBattery.value = const ReaderBattery(level: 85, charging: false);

    await _pump(
      tester,
      const ReaderCorners(
        chapterTitle: '第一章 序章',
        color: Colors.black,
        safeTop: _safeTop,
        safeBottom: _safeBottom,
        leftInset: _inset,
        rightInset: _inset,
        pageNumber: 3,
        pageCount: 12,
      ),
    );

    // 上角标栏 = [24, 48]，条带内垂直居中 → 中心 36
    const barCenter = _safeTop + kReaderCornerBarHeight / 2;
    final battery = tester.getRect(find.byType(BatteryBadge));
    expect(battery.center.dy, closeTo(barCenter, 0.01));
    expect(battery.left, closeTo(_inset, 0.01));
    expect(battery.top, greaterThanOrEqualTo(_safeTop));
    expect(battery.bottom, lessThanOrEqualTo(_safeTop + kReaderCornerBarHeight));

    final title = tester.getRect(find.text('第一章 序章'));
    expect(title.center.dy, closeTo(barCenter, 0.01));
    expect(title.right, closeTo(360 - _inset, 0.01));

    // 下角标栏 = [800-48-24, 800-48] = [728, 752]，中心 740
    const bottomBarCenter =
        _screenHeight - _safeBottom - kReaderCornerBarHeight / 2;
    final page = tester.getRect(find.text('3/12 25%'));
    expect(page.center.dy, closeTo(bottomBarCenter, 0.01));
    expect(
      page.top,
      greaterThanOrEqualTo(_screenHeight - _safeBottom - kReaderCornerBarHeight),
    );
    expect(page.bottom, lessThanOrEqualTo(_screenHeight - _safeBottom));
    expect(page.right, closeTo(360 - _inset, 0.01));

    final clock = tester.getRect(find.text('09:05'));
    expect(clock.left, closeTo(_inset, 0.01));
    expect(clock.center.dy, closeTo(page.center.dy, 0.01));
  });

  testWidgets('滚动式阅读器：右下角显示进度文案而不是页码', (WidgetTester tester) async {
    readerClock.value = '23:59';
    readerBattery.value = const ReaderBattery(level: 40, charging: true);

    await _pump(
      tester,
      const ReaderCorners(
        chapterTitle: '第二章',
        color: Colors.black,
        safeTop: _safeTop,
        safeBottom: _safeBottom,
        leftInset: _inset,
        rightInset: _inset,
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
        safeTop: _safeTop,
        safeBottom: _safeBottom,
        leftInset: _inset,
        rightInset: _inset,
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
        safeTop: _safeTop,
        safeBottom: _safeBottom,
        leftInset: _inset,
        rightInset: _inset,
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

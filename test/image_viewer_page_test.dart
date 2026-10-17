import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wild/widgets/image_viewer_page.dart';

Widget _host(String url) => MaterialApp(
  home: ImageViewerPage(imageUrl: url),
);

void main() {
  testWidgets('全屏看图：黑底 + 可缩放的 InteractiveViewer + 关闭按钮', (WidgetTester tester) async {
    await tester.pumpWidget(_host('https://pic.example/1.jpg'));
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.black);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    // 图片加载失败时也要有个交代（测试环境里没有 Rust 下载器）
    tester.takeException();
  });

  testWidgets('双击放大到 2.5 倍，再双击回到原大小', (WidgetTester tester) async {
    await tester.pumpWidget(_host('https://pic.example/2.jpg'));
    await tester.pump();
    tester.takeException();

    InteractiveViewer viewer() =>
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    double scale() => viewer().transformationController!.value.getMaxScaleOnAxis();

    expect(scale(), closeTo(1, 0.01));

    // 双击：两次点击之间要隔开至少 kDoubleTapMinTime，否则会被判成两次单击
    Future<void> doubleTap() async {
      await tester.tap(find.byType(InteractiveViewer));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byType(InteractiveViewer));
      await tester.pumpAndSettle();
    }

    await doubleTap();
    expect(scale(), closeTo(2.5, 0.01));

    await doubleTap();
    expect(scale(), closeTo(1, 0.01));
  });

  testWidgets('点关闭按钮退出全屏看图', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    ImageViewerPage.open(context, 'https://pic.example/3.jpg'),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerPage), findsNothing);
    tester.takeException();
  });
}

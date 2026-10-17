import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wild/widgets/image_viewer_page.dart';
import 'package:wild/widgets/tappable_reader_image.dart';

/// 200x100（宽高比 2:1）的测试图
final MemoryImage _image = MemoryImage(base64Decode('''iVBORw0KGgoAAAANSUhEUgAAAMgAAABkCAIAAABM5OhcAAABJUlEQVR4nO3SQQ2AMADAwIGQyUIkSpA1C3yaBXKnoI8ecz6Dd+5x7U74jHN3AP9kLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGImEsEsYiYSwSxiJhLBLGIrEAwxICzCoMxYwAAAAASUVORK5CYII='''));

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 300, height: 300, child: child)),
  ),
);

Future<void> _precache(WidgetTester tester) async {
  await tester.runAsync(() async {
    await precacheImage(
      _image,
      tester.element(find.byType(TappableReaderImage)),
    );
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('插图按图片自身比例摆放（2:1，不是一刀切的 4:3）', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(TappableReaderImage(imageUrl: 'mem://a', provider: _image)),
    );
    await _precache(tester);

    final ratio = tester
        .widget<AspectRatio>(find.byType(AspectRatio))
        .aspectRatio;
    expect(ratio, closeTo(2.0, 0.001));
  });

  testWidgets('点图片开全屏看图', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(TappableReaderImage(imageUrl: 'mem://b', provider: _image)),
    );
    await _precache(tester);

    expect(find.byType(ImageViewerPage), findsNothing);
    await tester.tapAt(tester.getCenter(find.byType(TappableReaderImage)));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerPage), findsOneWidget);
  });

  testWidgets('点留白呼菜单、点图片开看图，两边不互相触发', (WidgetTester tester) async {
    var outsideTapped = 0;
    await tester.pumpWidget(
      _host(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => outsideTapped++,
          child: TappableReaderImage(
            imageUrl: 'mem://c',
            provider: _image,
            onOutsideTap: () => outsideTapped++,
          ),
        ),
      ),
    );
    await _precache(tester);

    // 300x300 的框里图片是 300x150、竖直居中，上下一共 150 的留白
    final rect = tester.getRect(find.byType(TappableReaderImage));
    await tester.tapAt(Offset(rect.center.dx, rect.top + 10));
    await tester.pumpAndSettle();
    expect(outsideTapped, 1, reason: '留白点击只该走 onOutsideTap（呼菜单）');
    expect(find.byType(ImageViewerPage), findsNothing);

    // 点图片：开看图，不要再触发菜单
    await tester.tapAt(rect.center);
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerPage), findsOneWidget);
    expect(outsideTapped, 1, reason: '点图片不该同时呼出菜单');
  });

  testWidgets('图片加载失败：显示占位且不接管点击', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        const TappableReaderImage(
          imageUrl: 'mem://broken',
          provider: _BrokenImage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('图片加载失败'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(TappableReaderImage)));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerPage), findsNothing);
  });
}

/// 永远加载失败的 provider（模拟下载失败）
class _BrokenImage extends ImageProvider<_BrokenImage> {
  const _BrokenImage();

  @override
  ImageStreamCompleter loadImage(
    _BrokenImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(Exception('download failed')),
    );
  }

  @override
  Future<_BrokenImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_BrokenImage>(this);
}

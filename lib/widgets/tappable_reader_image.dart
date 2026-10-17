import 'package:flutter/material.dart';

import 'package:wild/widgets/cached_image.dart';
import 'package:wild/widgets/image_viewer_page.dart';
import 'package:wild/l10n/ui_language.dart';

/// 阅读器正文里的一张插图。
///
/// - 按图片**自身比例**居中摆放（不是一刀切的 4:3，也不会把整块正文区域都吃掉）。
/// - **点图片本身**打开全屏看图；
/// - 图片以外的留白不接管手势，点击照样走阅读器原本的翻页 / 呼出菜单。
class TappableReaderImage extends StatefulWidget {
  final String imageUrl;

  /// 测试用：换掉默认的 [CachedImageProvider]（它要走 Rust 下载）。
  final ImageProvider? provider;

  /// 点**图片以外**的留白时回调（阅读器用来呼出上面的菜单栏）；
  /// 不传则留白不接管手势，交给阅读器原本的处理。
  final VoidCallback? onOutsideTap;

  const TappableReaderImage({
    super.key,
    required this.imageUrl,
    this.provider,
    this.onOutsideTap,
  });

  @override
  State<TappableReaderImage> createState() => _TappableReaderImageState();
}

class _TappableReaderImageState extends State<TappableReaderImage> {
  late ImageProvider _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(TappableReaderImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.provider != widget.provider) {
      _resolve();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    final listener = _listener;
    if (listener != null) {
      _stream?.removeListener(listener);
    }
    _listener = null;
    _stream = null;
  }

  /// 先解码一次拿到真实宽高比，图标/占位尺寸才和图片一致（点击区域也跟着准）。
  void _resolve() {
    _detach();
    _aspectRatio = null;
    _provider = widget.provider ?? CachedImageProvider(widget.imageUrl);
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        final ratio = info.image.width / info.image.height;
        setState(() => _aspectRatio = ratio);
      },
      onError: (error, stackTrace) {
        // 下载/解码失败：下面 Image 的 errorBuilder 会显示占位
      },
    );
    _stream = _provider.resolve(ImageConfiguration.empty)
      ..addListener(listener);
    _listener = listener;
  }

  Widget _placeholder(Widget child) =>
      Container(color: Colors.grey[200], child: Center(child: child));

  @override
  Widget build(BuildContext context) {
    final image = Image(
      image: _provider,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholder(const CircularProgressIndicator());
      },
      errorBuilder:
          (context, error, stackTrace) => _placeholder(Text(l10n('图片加载失败'))),
    );

    final ratio = _aspectRatio;
    final Widget content;
    // 还没解码出宽高比：按老样子（4:3 占位框）铺满，此时图片本身不接管点击
    if (ratio == null || !ratio.isFinite || ratio <= 0) {
      content = Center(child: AspectRatio(aspectRatio: 4 / 3, child: image));
    } else {
      content = Center(
        child: AspectRatio(
          aspectRatio: ratio,
          child: GestureDetector(
            onTap: () => ImageViewerPage.open(context, widget.imageUrl),
            child: Hero(tag: readerImageHeroTag(widget.imageUrl), child: image),
          ),
        ),
      );
    }

    final onOutsideTap = widget.onOutsideTap;
    if (onOutsideTap == null) {
      return content;
    }
    // 留白（图片以外）用 opaque 接住：点它和点正文中央一样，呼出上面的菜单栏。
    // 点图片本体还是走里面那层，阅读器里最内层的手势赢。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOutsideTap,
      child: content,
    );
  }
}

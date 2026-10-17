import 'package:flutter/material.dart';

import 'package:wild/widgets/cached_image.dart';
import 'package:wild/l10n/ui_language.dart';

/// 全屏看图（阅读器里点插图打开）：黑底、捏合/双击缩放、单指拖动；
/// 点任意位置、右上角 ×、返回键都能关闭。
class ImageViewerPage extends StatefulWidget {
  final String imageUrl;

  /// 和正文里的缩略图配对的 Hero 标签（传 null 就没有转场动画）。
  final Object? heroTag;

  const ImageViewerPage({super.key, required this.imageUrl, this.heroTag});

  /// 从阅读器打开全屏看图。
  static Future<void> open(BuildContext context, String imageUrl) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (_) => ImageViewerPage(
              imageUrl: imageUrl,
              heroTag: readerImageHeroTag(imageUrl),
            ),
      ),
    );
  }

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

/// 正文缩略图与全屏看图共用同一个 Hero 标签。
Object readerImageHeroTag(String imageUrl) => 'reader-image:$imageUrl';

class _ImageViewerPageState extends State<ImageViewerPage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformation = TransformationController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Animation<Matrix4>? _zoomAnimation;
  Offset _doubleTapPosition = Offset.zero;

  static const double _doubleTapScale = 2.5;

  @override
  void initState() {
    super.initState();
    _animation.addListener(() {
      final value = _zoomAnimation?.value;
      if (value != null) {
        _transformation.value = value;
      }
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    _transformation.dispose();
    super.dispose();
  }

  bool get _isZoomed => _transformation.value.getMaxScaleOnAxis() > 1.02;

  void _animateTo(Matrix4 target) {
    _zoomAnimation = Matrix4Tween(
      begin: _transformation.value,
      end: target,
    ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOut));
    _animation.forward(from: 0);
  }

  void _handleDoubleTap() {
    if (_isZoomed) {
      _animateTo(Matrix4.identity());
      return;
    }
    final position = _doubleTapPosition;
    _animateTo(
      Matrix4.identity()
        ..translateByDouble(
          -position.dx * (_doubleTapScale - 1),
          -position.dy * (_doubleTapScale - 1),
          0,
          1,
        )
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1),
    );
  }

  Widget _buildImage() {
    final image = Image(
      image: CachedImageProvider(widget.imageUrl),
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Text(l10n('图片加载失败'), style: TextStyle(color: Colors.white70)),
        );
      },
    );
    final tag = widget.heroTag;
    return tag == null ? image : Hero(tag: tag, child: image);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              onDoubleTapDown:
                  (details) => _doubleTapPosition = details.localPosition,
              onDoubleTap: _handleDoubleTap,
              child: InteractiveViewer(
                transformationController: _transformation,
                minScale: 1,
                maxScale: 6,
                child: SizedBox.expand(child: Center(child: _buildImage())),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).viewPadding.top + 8,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              tooltip: l10n('关闭'),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}

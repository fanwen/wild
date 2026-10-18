import 'package:flutter/material.dart';

import 'package:wild/cubits/reader_battery.dart';
import 'package:wild/cubits/reader_clock.dart';

/// 角标栏的高度（逻辑像素）：阅读器顶部/底部那两个「角标栏」——
/// 上栏放电量 + 章节名，下栏放时间 + 阅读进度。
///
/// 阅读器布局自上而下是：状态栏安全区 → 上角标栏 → 上边距 → 正文 → 下边距 →
/// 下角标栏 → 导航栏安全区。用户设的「上边距/下边距」是角标栏与正文之间的空白，
/// **不含**这两个角标栏，所以分页高度要减掉两倍这个值（见 `reader_cubit`）。
const double kReaderCornerBarHeight = 24.0;

/// 阅读器四角信息：左上电量 / 右上章节名 / 左下时间 / 右下页码（当前/总页 + 百分比）。
///
/// [pageNumber] / [pageCount] 为 null 时右下角改显示 [progressText]（滚动式阅读器没有页的概念，
/// 传滚动进度百分比）；两个都为 null 则右下角为空。
///
/// 位置规则：上排落在「安全区 + 上角标栏」这条带子里、垂直居中；
/// 下排落在「下角标栏」里（贴导航栏安全区上方）——
/// 两条带子都在正文上下边距**之外**，所以角标永远不会压到正文首/末行。
class ReaderCorners extends StatelessWidget {
  final String chapterTitle;
  final Color color;

  /// 状态栏安全区高度（`MediaQuery.viewPadding.top`）
  final double safeTop;

  /// 导航栏安全区高度（`MediaQuery.viewPadding.bottom`）
  final double safeBottom;

  /// 角标栏高度，默认 [kReaderCornerBarHeight]
  final double barHeight;

  /// 左右内缩（和正文左右边距一致，角标和正文左右对齐）
  final double leftInset;
  final double rightInset;

  final int? pageNumber;
  final int? pageCount;
  final String? progressText;

  /// 小字的不透明度，和阅读器原有的页码风格一致。
  final double opacity;

  const ReaderCorners({
    super.key,
    required this.chapterTitle,
    required this.color,
    required this.safeTop,
    required this.safeBottom,
    required this.leftInset,
    required this.rightInset,
    this.barHeight = kReaderCornerBarHeight,
    this.pageNumber,
    this.pageCount,
    this.progressText,
    this.opacity = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    final bar = barHeight.clamp(0.0, double.infinity);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final topBarTop = safeTop.clamp(0.0, height);
          final bottomBarTop = (height - safeBottom - bar).clamp(0.0, height);
          return Stack(
            children: [
              // 上角标栏：电量（左） + 章节名（右）
              Positioned(
                top: topBarTop,
                height: bar,
                left: leftInset,
                right: rightInset,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: opacity,
                      child: BatteryBadge(color: color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chapterTitle,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _cornerStyle(),
                      ),
                    ),
                  ],
                ),
              ),
              // 下角标栏：时间（左） + 页码/进度（右）
              Positioned(
                top: bottomBarTop,
                height: bar,
                left: leftInset,
                right: rightInset,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: readerClock,
                      builder:
                          (context, clock, _) =>
                              Text(clock, style: _cornerStyle()),
                    ),
                    const Spacer(),
                    Text(_pageText(), style: _cornerStyle()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  TextStyle _cornerStyle() =>
      TextStyle(fontSize: 10, color: color, height: 1.2);

  String _pageText() {
    if (pageNumber != null && pageCount != null && pageCount! > 0) {
      final percent = (pageNumber! / pageCount! * 100).round();
      return '$pageNumber/$pageCount $percent%';
    }
    return progressText ?? '';
  }
}

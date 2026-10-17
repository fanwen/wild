import 'package:flutter/material.dart';

import 'package:wild/cubits/reader_battery.dart';
import 'package:wild/cubits/reader_clock.dart';

/// 阅读器四角信息：左上电量 / 右上章节名 / 左下时间 / 右下页码（当前/总页 + 百分比）。
///
/// [pageNumber] / [pageCount] 为 null 时右下角改显示 [progressText]（滚动式阅读器没有页的概念，
/// 传滚动进度百分比）；两个都为 null 则右下角为空。
///
/// 位置规则：两行角标都落在正文上下边距里、紧贴正文块的外沿 ——
/// 上排底边在上边距内 [marginInset] 像素处，下排顶边在下边距内 [marginInset] 像素处，
/// 所以角标永远不压正文首/末行。
class ReaderCorners extends StatelessWidget {
  final String chapterTitle;
  final Color color;

  /// 正文块的内边距（系统栏 + 用户设的顶部/底部边距、左右边距）。
  final EdgeInsets padding;

  final int? pageNumber;
  final int? pageCount;
  final String? progressText;

  /// 小字的不透明度，和阅读器原有的页码风格一致。
  final double opacity;

  /// 角标与正文块外沿之间的空隙（像素）。
  final double marginInset;

  const ReaderCorners({
    super.key,
    required this.chapterTitle,
    required this.color,
    required this.padding,
    this.pageNumber,
    this.pageCount,
    this.progressText,
    this.opacity = 0.45,
    this.marginInset = 5,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          // 上排：底边对齐「正文上边距」外沿再让出 marginInset
          final topEdge = (padding.top - marginInset).clamp(0.0, height);
          // 下排：顶边对齐「正文下边距」外沿再让出 marginInset
          final bottomEdge = (height - padding.bottom + marginInset).clamp(
            0.0,
            height,
          );
          return Stack(
            children: [
              Positioned(
                left: padding.left,
                right: padding.right,
                bottom: height - topEdge,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
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
              Positioned(
                left: padding.left,
                right: padding.right,
                top: bottomEdge,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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

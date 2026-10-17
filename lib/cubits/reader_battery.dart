import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

/// 阅读器左上角的电量信息（全局，避免页面 widget 不重建时读不到新值）。
class ReaderBattery {
  final int level;
  final bool charging;

  const ReaderBattery({required this.level, required this.charging});
}

final ValueNotifier<ReaderBattery?> readerBattery = ValueNotifier(null);

Timer? _batteryTimer;

Future<void> _refreshBattery() async {
  try {
    final battery = Battery();
    final level = await battery.batteryLevel;
    final state = await battery.batteryState;
    readerBattery.value = ReaderBattery(
      level: level,
      charging:
          state == BatteryState.charging ||
          state == BatteryState.full ||
          state == BatteryState.connectedNotCharging,
    );
  } catch (e) {
    print('[电量] 读取失败: $e');
  }
}

/// 进阅读器时调（60 秒一次，不轮询）。
void startBatteryWatch() {
  _refreshBattery();
  _batteryTimer ??= Timer.periodic(
    const Duration(seconds: 60),
    (_) => _refreshBattery(),
  );
}

/// 退出阅读器时调。
void stopBatteryWatch() {
  _batteryTimer?.cancel();
  _batteryTimer = null;
}

/// 画成电池形状（外框 + 右侧正极凸起 + 按电量填充 + 居中百分比），
/// 用 [ValueListenableBuilder] 订阅全局 notifier 才能跟着电量刷新。
class BatteryBadge extends StatelessWidget {
  final Color color;
  final double width;

  const BatteryBadge({super.key, required this.color, this.width = 36});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReaderBattery?>(
      valueListenable: readerBattery,
      builder: (context, battery, _) {
        if (battery == null) return const SizedBox.shrink();
        return CustomPaint(
          size: Size(width, width * 0.42),
          painter: _BatteryPainter(battery: battery, color: color),
        );
      },
    );
  }
}

class _BatteryPainter extends CustomPainter {
  final ReaderBattery battery;
  final Color color;

  _BatteryPainter({required this.battery, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final terminalWidth = size.height * 0.18;
    final bodyWidth = size.width - terminalWidth - 1;
    final radius = Radius.circular(size.height * 0.28);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, bodyWidth, size.height),
      radius,
    );

    final stroke =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = color;
    canvas.drawRRect(body, stroke);

    // 正极
    final terminal = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bodyWidth + 1,
          size.height * 0.3,
          terminalWidth,
          size.height * 0.4,
        ),
        Radius.circular(size.height * 0.1),
      ),
      terminal,
    );

    // 电量填充（半透明，让上面的百分比数字仍然看得清）
    final ratio = (battery.level.clamp(0, 100)) / 100;
    if (ratio > 0) {
      final inset = size.height * 0.18;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset,
            (bodyWidth - inset * 2) * ratio,
            size.height - inset * 2,
          ),
          Radius.circular(size.height * 0.16),
        ),
        Paint()..color = color.withValues(alpha: 0.32),
      );
    }

    // 居中百分比
    final painter = TextPainter(
      text: TextSpan(
        text: '${battery.level}%',
        style: TextStyle(
          fontSize: size.height * 0.6 + 0.6,
          height: 1.0,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: bodyWidth);
    painter.paint(
      canvas,
      Offset(
        (bodyWidth - painter.width) / 2,
        (size.height - painter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) =>
      oldDelegate.battery.level != battery.level ||
      oldDelegate.battery.charging != battery.charging ||
      oldDelegate.color != color;
}

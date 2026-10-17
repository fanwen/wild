import 'dart:async';

import 'package:flutter/material.dart';

/// 阅读器左下角的时间（24 小时制，不跟随系统 12/24 小时设置）。
final ValueNotifier<String> readerClock = ValueNotifier('--:--');

Timer? _clockTimer;

String _format(DateTime now) =>
    '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

/// 定时器对齐到下一个整分，不做每秒轮询。
void _scheduleTick() {
  _clockTimer?.cancel();
  final now = DateTime.now();
  final nextMinute = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  ).add(const Duration(minutes: 1));
  _clockTimer = Timer(nextMinute.difference(now), () {
    readerClock.value = _format(DateTime.now());
    _scheduleTick();
  });
}

/// 进阅读器时调。
void startReaderClock() {
  readerClock.value = _format(DateTime.now());
  _scheduleTick();
}

/// 退出阅读器时调。
void stopReaderClock() {
  _clockTimer?.cancel();
  _clockTimer = null;
}

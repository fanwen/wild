import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/database.dart';

/// 标点可置行首开关（默认开）。
///
/// 打开时去掉中文断行的「标点不能出现在行首」禁则：行尾按宽度排满，
/// 引擎不再把标点连同前一个字挤到下一行（那样上一行会空出一格）。
class PunctuationRuleCubit extends Cubit<bool> {
  static const bool defaultEnabled = true;
  static const String _key = 'allow_punctuation_line_start';

  PunctuationRuleCubit() : super(defaultEnabled);

  Future<void> loadPunctuationRule() async {
    try {
      final savedValue = await loadProperty(key: _key);
      if (savedValue.isNotEmpty) {
        emit(savedValue == 'true');
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      emit(defaultEnabled);
    }
  }

  Future<void> updatePunctuationRule(bool enabled) async {
    try {
      await saveProperty(key: _key, value: enabled.toString());
      emit(enabled);
    } catch (e) {
      // 如果保存失败，仍然更新状态
      emit(enabled);
    }
  }
}

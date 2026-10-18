import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/src/rust/api/database.dart';

/// 段首缩进几个字（0 = 不缩进）
class ParagraphIndentCubit extends Cubit<int> {
  static const int defaultIndent = 2;
  static const int maxIndent = 4;
  static const String _key = 'paragraph_indent';

  ParagraphIndentCubit() : super(defaultIndent);

  Future<void> loadParagraphIndent() async {
    try {
      final savedValue = await loadProperty(key: _key);
      if (savedValue.isNotEmpty) {
        emit(int.parse(savedValue).clamp(0, maxIndent));
      }
    } catch (e) {
      // 如果加载失败，使用默认值
      emit(defaultIndent);
    }
  }

  Future<void> updateParagraphIndent(int indent) async {
    final value = indent.clamp(0, maxIndent);
    try {
      await saveProperty(key: _key, value: value.toString());
      emit(value);
    } catch (e) {
      // 如果保存失败，仍然更新状态
      emit(value);
    }
  }
}

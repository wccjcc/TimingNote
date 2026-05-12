/// TodoType에 대응하는 표시용 색상.
///
/// 라벨 매핑은 [TodoType.labelOf]에 있고 색상은 view 영역 관심사라 별도 유틸로 분리.
/// 목록·상세 등 여러 화면에서 동일한 색을 쓰도록 단일 출처로 둔다.
library;

import 'package:flutter/material.dart';

import '../../../shared/theme/colors.dart';
import '../model/todo.dart';

Color todoTypeColor(String? type) {
  return switch (type) {
    TodoType.specific => SpaceColors.neonPurple,
    TodoType.generic => Colors.cyanAccent,
    TodoType.alias => SpaceColors.success,
    _ => SpaceColors.white50,
  };
}

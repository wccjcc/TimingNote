/// TodoType에 대응하는 표시용 색상.
///
/// 라벨 매핑은 [TodoType.labelOf]에 있고 색상은 view 영역 관심사라 별도 유틸로 분리.
/// 목록·상세 등 여러 화면에서 동일한 색을 쓰도록 단일 출처로 둔다.
library;

import 'package:flutter/material.dart';

import '../../../shared/theme/colors.dart';
import '../model/todo.dart';

/// 장소 타입별 표시 색.
/// - SPECIFIC: 보라 (메인 브랜드)
/// - ALIAS: 노랑 (사용자 등록 "내 장소", 친근 톤. 기존 초록은 success/완료와 의미 충돌이라 변경)
/// - GENERIC: cyan (시간성/카테고리 추상)
Color todoTypeColor(String? type) {
  return switch (type) {
    TodoType.specific => SpaceColors.neonPurple,
    TodoType.generic => SpaceColors.neonCyan,
    TodoType.alias => SpaceColors.neonYellow,
    _ => SpaceColors.white50,
  };
}

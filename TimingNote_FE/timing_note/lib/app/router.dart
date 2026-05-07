import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/view/home_screen.dart';
import '../features/map/view/map_screen.dart';
import '../features/mypage/view/mypage_screen.dart';
import '../features/notification/view/notification_screen.dart';
import '../features/todo/model/selected_kakao_place.dart';
import '../features/todo/view/place_search_screen.dart';
import '../features/todo/view/todo_detail_screen.dart';
import '../features/todo/view/todo_edit_screen.dart';
import '../features/todo/view/todo_input_screen.dart';
import '../features/todo/view/todo_list_screen.dart';
import 'main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      // ── 하단바 셸 (홈/지도/할일/마이) ────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          // ── 0: 홈 ───────────────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // ── 1: 지도 ─────────────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapScreen(),
              ),
            ],
          ),

          // ── 2: 할일 ─────────────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/todos',
                builder: (context, state) => const TodoListScreen(),
              ),
            ],
          ),

          // ── 3: 마이 ─────────────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my',
                builder: (context, state) => const MyPageScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── 하단바 위에 전체화면으로 올라오는 화면들 ───────────────────────
      // (하단바가 보이지 않아야 하는 경우 Shell 밖에 위치)
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/todos/new',
        builder: (context, state) => const TodoInputScreen(),
      ),
      GoRoute(
        path: '/todos/:id',
        builder: (context, state) {
          final todoId = int.parse(state.pathParameters['id']!);
          return TodoDetailScreen(todoId: todoId);
        },
      ),
      GoRoute(
        path: '/todos/:id/edit',
        builder: (context, state) {
          final todoId = int.parse(state.pathParameters['id']!);
          return TodoEditScreen(todoId: todoId);
        },
      ),
      // 장소 검색/지도 선택 — push<SelectedKakaoPlace>('/place-search?keyword=xxx')
      GoRoute(
        path: '/place-search',
        builder: (context, state) {
          final keyword = state.uri.queryParameters['keyword'];
          return PlaceSearchScreen(initialKeyword: keyword);
        },
      ),
    ],
  );
});

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../model/selected_kakao_place.dart';
import '../model/time_condition.dart';
import '../model/todo.dart';
import '../model/todo_detail.dart';
import '../viewmodel/todo_detail_viewmodel.dart';

// -- 디자인 상수 (우주 테마) ------------------------------------------
const _kBgDark = Color(0xFF050510);
const _kBgDeep = Color(0xFF110B1F);
const _kPurpleAccent = Color(0xFFA78BFA);
const _kPinkAccent = Color(0xFFF472B6);
const _kSurfaceDark = Color(0xE50F0F1A);
const _kBorderWhite = Color(0x1AFFFFFF);

class TodoDetailScreen extends ConsumerWidget {
  const TodoDetailScreen({super.key, required this.todoId});

  final int todoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todoDetailProvider(todoId));

    return Scaffold(
      backgroundColor: _kBgDark,
      body: Stack(
        children: [
          // LAYER 1: 우주 배경
          const _DetailRadialBackground(),
          const _DetailStarField(),

          // LAYER 2: 콘텐츠
          SafeArea(
            child: state.detail == null && state.isLoading
                ? const Center(child: CircularProgressIndicator(color: _kPurpleAccent))
                : state.error != null
                    ? _buildErrorView(ref, state.error!)
                    : _buildMainContent(context, ref, state.detail!),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('오류 발생: $error', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kPurpleAccent),
            onPressed: () => ref.read(todoDetailProvider(todoId).notifier).load(),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, WidgetRef ref, TodoDetail detail) {
    final categoryKey = detail.category ?? TodoCategory.etc;
    final themeColor = _getCategoryColor(categoryKey);

    return Column(
      children: [
        // 1. 헤더 (뒤로가기, 타이틀, 수정, 삭제)
        _buildHeader(context, ref, detail),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(todoDetailProvider(todoId).notifier).load(),
            color: _kPurpleAccent,
            backgroundColor: _kSurfaceDark,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              children: [
                // 2. 상태 배너 (분석 중일 때만)
                if (detail.isPending) _SpacePendingBanner(),

                // 3. 상단 요약 정보 (카테고리, 상태)
                Row(
                  children: [
                    _CategoryBadge(category: categoryKey, color: themeColor),
                    const SizedBox(width: 12),
                    Text(
                      detail.isDone ? '완료됨' : '진행 중',
                      style: TextStyle(
                        color: detail.isDone ? Colors.green : _kPurpleAccent,
                        fontSize: 12,
                        fontFamily: 'Galmuri11',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 4. 할 일 본문 (가장 크게 표시)
                Text(
                  detail.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '등록일: ${_formatDate(detail.createdAt)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),

                const SizedBox(height: 32),

                // 5. 조건 정보 섹션 (장소, 시간)
                _buildInfoSection(context, ref, detail, themeColor),

                const SizedBox(height: 24),

                // 6. 장소 상세 정보 (primaryPlace가 있을 때)
                if (detail.primaryPlace != null) ...[
                  _buildPlaceDetailCard(detail.primaryPlace!),
                  const SizedBox(height: 24),
                ],

                // 7. 시각 자료 (첨부 이미지)
                if (detail.imageUrls.isNotEmpty) ...[
                  const _SectionTitle(title: '첨부 이미지'),
                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: detail.imageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _ImageThumbnail(url: detail.imageUrls[i]),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),

        // 8. 하단 액션 버튼
        _buildBottomActions(ref, detail),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, TodoDetail? detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
          const Text(
            '할 일 상세',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Galmuri11',
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () => context.push('/todos/$todoId/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white54),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _kBorderWhite),
        ),
        title: const Text('할 일 삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          '이 할 일을 삭제할까요?\n삭제된 항목은 복구할 수 없습니다.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: _kPinkAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final ok = await ref.read(todoDetailProvider(todoId).notifier).deleteTodo();
    if (ok && context.mounted) context.pop();
  }

  Widget _buildInfoSection(BuildContext context, WidgetRef ref, TodoDetail detail, Color color) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 장소 정보
          Row(
            children: [
              Icon(Icons.location_on, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('실행 장소', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      detail.resolvedPlaceLabel ?? '장소 미정',
                      style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // 장소 빠른 수정 버튼
              GestureDetector(
                onTap: () => _onEditPlaceTap(context, ref, detail),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBorderWhite),
                  ),
                  child: const Icon(Icons.edit_location_alt_outlined, color: _kPurpleAccent, size: 16),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: _kBorderWhite, height: 1),
          ),
          // 시간 정보
          Row(
            children: [
              const Icon(Icons.access_time_filled, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('실행 시간', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 2),
                    detail.timeConditions.isEmpty
                        ? const Text('시간 조건 없음', style: TextStyle(color: Colors.white70, fontSize: 15))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: detail.timeConditions
                                .map((tc) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        _describeTime(tc),
                                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 15, fontWeight: FontWeight.w500),
                                      ),
                                    ))
                                .toList(),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceDetailCard(TodoPlace place) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('상세 장소 정보', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(place.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          if (place.roadAddress != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.map_outlined, size: 14, color: Colors.white54),
                const SizedBox(width: 8),
                Expanded(child: Text(place.roadAddress!, style: const TextStyle(color: Colors.white70, fontSize: 13))),
              ],
            ),
          ],
          if (place.phone != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: Colors.white54),
                const SizedBox(width: 8),
                Text(place.phone!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions(WidgetRef ref, TodoDetail detail) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: _kSurfaceDark,
        border: Border(top: BorderSide(color: _kBorderWhite)),
      ),
      child: Row(
        children: [
          _CircleActionButton(
            icon: detail.alertEnabled ? Icons.notifications : Icons.notifications_off,
            onTap: () => ref.read(todoDetailProvider(todoId).notifier).toggleAlert(),
            active: detail.alertEnabled,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _MainActionButton(
              label: detail.isDone ? '다시 시작' : '작업 완료',
              icon: detail.isDone ? Icons.replay : Icons.check_circle_outline,
              onTap: () => ref.read(todoDetailProvider(todoId).notifier).toggleStatus(),
              isDone: detail.isDone,
            ),
          ),
        ],
      ),
    );
  }

  String _describeTime(TimeCondition tc) {
    switch (tc.conditionType) {
      case ConditionType.datetime:
        return '${tc.startDate} ${tc.startTime ?? ''}';
      case ConditionType.date:
        return tc.startDate ?? '';
      case ConditionType.dateRange:
        return '${tc.startDate} ~ ${tc.endDate}';
      case ConditionType.week:
        final days = tc.dayNames.join(', ');
        final time = tc.startTime != null ? ' ${tc.startTime}${tc.endTime != null ? '~${tc.endTime}' : ''}' : '';
        return '$days$time';
      case ConditionType.timeRange:
        return '${tc.startTime} ~ ${tc.endTime}';
      default:
        return tc.rawExpression ?? tc.conditionType;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case TodoCategory.dine:
      case TodoCategory.acquire:
        return _kPurpleAccent;
      case TodoCategory.health:
      case TodoCategory.service:
        return const Color(0xFF8B5CF6);
      case TodoCategory.maintenance:
        return const Color(0xFFFDBA74);
      case TodoCategory.social:
        return _kPinkAccent;
      default:
        return _kPurpleAccent;
    }
  }

  String _formatDate(DateTime dt) => '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

  Future<void> _onEditPlaceTap(BuildContext context, WidgetRef ref, TodoDetail detail) async {
    final keyword = detail.primaryPlace?.name ?? detail.resolvedPlaceLabel ?? '';
    final uri = keyword.isNotEmpty
        ? '/place-search?keyword=${Uri.encodeComponent(keyword)}'
        : '/place-search';

    final result = await context.push<SelectedKakaoPlace>(uri);
    if (result == null || !context.mounted) return;

    await ref.read(todoDetailProvider(todoId).notifier).setPlace(
          kakaoPlaceId: result.kakaoPlaceId,
          placeName: result.name,
          addressName: result.address,
          roadAddressName: result.roadAddress,
          categoryGroupCode: result.categoryGroupCode,
          categoryGroupName: result.categoryGroupName,
          phone: result.phone,
          placeUrl: result.placeUrl,
          longitude: result.longitude,
          latitude: result.latitude,
        );
  }
}

// -- 하위 컴포넌트 --------------------------------------------------

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category, required this.color});
  final String category;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = TodoCategory.labels[category] ?? category;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Galmuri11'),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 12),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderWhite),
        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({required this.icon, required this.onTap, required this.active});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: active ? _kPurpleAccent.withOpacity(0.2) : const Color(0xFF2A2A4A),
          shape: BoxShape.circle,
          border: Border.all(color: active ? _kPurpleAccent : const Color(0x4CA78BFA)),
          boxShadow: active ? [BoxShadow(color: _kPurpleAccent.withOpacity(0.3), blurRadius: 10)] : null,
        ),
        child: Icon(icon, color: active ? Colors.white : Colors.white70, size: 24),
      ),
    );
  }
}

class _MainActionButton extends StatelessWidget {
  const _MainActionButton({required this.label, required this.icon, required this.onTap, required this.isDone});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isDone ? Colors.transparent : _kPurpleAccent,
          borderRadius: BorderRadius.circular(16),
          border: isDone ? Border.all(color: Colors.white24) : null,
          boxShadow: isDone ? null : [BoxShadow(color: _kPurpleAccent.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _SpacePendingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPurpleAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPurpleAccent.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: _kPurpleAccent)),
          SizedBox(width: 14),
          Text('AI가 내용을 분석 중입니다...', style: TextStyle(color: _kPurpleAccent, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: color, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13))),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• $label: ', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }
}

class _DetailRadialBackground extends StatelessWidget {
  const _DetailRadialBackground();
  @override
  Widget build(BuildContext context) => Container(decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment.topRight, radius: 1.5, colors: [_kBgDeep, _kBgDark])));
}

class _DetailStarField extends StatelessWidget {
  const _DetailStarField();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DetailStarPainter(), size: ui.Size.infinite);
}

class _DetailStarPainter extends CustomPainter {
  static final _rng = math.Random(101);
  static final List<_Star> _stars = List.generate(40, (_) => _Star(x: _rng.nextDouble(), y: _rng.nextDouble(), radius: _rng.nextDouble() * 1.5 + 0.5, opacity: _rng.nextDouble() * 0.3 + 0.1));
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = Paint();
    for (final star in _stars) {
      paint.color = (star.x > 0.5 ? _kPurpleAccent : Colors.white).withOpacity(star.opacity);
      canvas.drawCircle(Offset(star.x * size.width, star.y * size.height), star.radius, paint);
    }
  }
  @override
  bool shouldRepaint(CustomPainter old) => false;
}

class _Star {
  const _Star({required this.x, required this.y, required this.radius, required this.opacity});
  final double x, y, radius, opacity;
}

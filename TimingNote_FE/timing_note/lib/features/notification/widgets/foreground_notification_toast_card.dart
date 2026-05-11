import 'package:flutter/material.dart';

import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/neon_button.dart';
import '../../../shared/widgets/space_card.dart';

/// 포그라운드 푸시 수신 시 앱 내부에 노출하는 위치 알림 카드 UI.
///
/// App 루트 로직과 분리해두면:
/// - 화면 스타일 수정 시 영향 범위를 줄일 수 있고
/// - 토스트 표시 트리거 로직과 UI 책임을 분리할 수 있습니다.
class ForegroundNotificationToastCard extends StatelessWidget {
  const ForegroundNotificationToastCard({
    super.key,
    required this.placeName,
    required this.todoText,
    required this.onTapCard,
    required this.onTapSnooze,
    required this.onTapComplete,
    required this.onClose,
  });

  final String placeName;
  final String todoText;
  final VoidCallback onTapCard;
  final VoidCallback? onTapSnooze;
  final VoidCallback? onTapComplete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onTapCard,
        child: SpaceCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          borderColor: SpaceColors.neonViolet.withOpacity(0.45),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: SpaceColors.neonPurple.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: SpaceColors.neonPurple.withOpacity(0.45),
                      ),
                    ),
                    child: const Icon(
                      Icons.rocket_launch_outlined,
                      color: SpaceColors.neonLavender,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '할 일 알림',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Galmuri11',
                      ),
                    ),
                  ),
                  IconButton(
                    splashRadius: 18,
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: SpaceColors.white50,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: '지금 '),
                    TextSpan(
                      text: placeName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const TextSpan(text: ' 근처에 도착했어요.'),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '"$todoText"',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '를 처리할까요?',
                style: TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {},
                child: Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: NeonButton(
                        label: '1시간동안 알림 받지 않기',
                        isPrimary: false,
                        height: 46,
                        fontSize: 14,
                        fontFamily: 'Galmuri11',
                        onTap: onTapSnooze,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: NeonButton(
                        label: '완료',
                        icon: Icons.check_rounded,
                        height: 46,
                        fontSize: 14,
                        fontFamily: 'Galmuri11',
                        onTap: onTapComplete,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

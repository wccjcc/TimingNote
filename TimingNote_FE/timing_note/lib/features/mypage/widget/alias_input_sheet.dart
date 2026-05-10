import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/theme/colors.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/neon_button.dart';

/// 내 장소(ALIAS) 별칭 입력/수정 BottomSheet.
///
/// - 신규 등록: [initialAliasName] = null, [placeName]/[placeAddress] 표시
/// - 별칭 변경: [initialAliasName] = 기존 별칭, place 표시는 옵션
///
/// [existingAliases]는 중복 차단 대상. 변경 모드에서 자기 자신은 호출자가 제외해 전달.
/// 반환값: 확정된 별칭(trim 처리됨), 취소 시 null.
Future<String?> showAliasInputSheet({
  required BuildContext context,
  String? initialAliasName,
  required Iterable<String> existingAliases,
  String? placeName,
  String? placeAddress,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _AliasInputSheet(
      initialAliasName: initialAliasName,
      existingAliases: existingAliases
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toSet(),
      placeName: placeName,
      placeAddress: placeAddress,
    ),
  );
}

class _AliasInputSheet extends StatefulWidget {
  const _AliasInputSheet({
    required this.initialAliasName,
    required this.existingAliases,
    required this.placeName,
    required this.placeAddress,
  });

  final String? initialAliasName;
  final Set<String> existingAliases;
  final String? placeName;
  final String? placeAddress;

  @override
  State<_AliasInputSheet> createState() => _AliasInputSheetState();
}

class _AliasInputSheetState extends State<_AliasInputSheet> {
  static const int _maxLength = 12;

  late final TextEditingController _controller;

  bool get _isEditing => widget.initialAliasName != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAliasName ?? '');
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  // 입력값이 바뀔 때마다 리빌드해 _errorText / _canSubmit / 글자수 카운터를
  // 함께 갱신한다. (조건부 setState로 두면 NeonButton.onTap이 갱신되지 않아
  // 키보드 done은 동작하지만 버튼 탭이 동작하지 않는 문제 발생)
  void _onTextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String? get _errorText {
    final raw = _controller.text;
    if (raw.length > _maxLength) {
      return '$_maxLength자까지 입력할 수 있어요';
    }
    final normalized = raw.trim().toLowerCase();
    if (normalized.isNotEmpty &&
        widget.existingAliases.contains(normalized)) {
      return '이미 사용 중인 이름이에요';
    }
    return null;
  }

  bool get _canSubmit {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > _maxLength) return false;
    if (widget.existingAliases.contains(trimmed.toLowerCase())) return false;
    if (_isEditing && trimmed == widget.initialAliasName) return false;
    return true;
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final hasPlacePreview =
        !_isEditing &&
        ((widget.placeName != null && widget.placeName!.isNotEmpty) ||
            (widget.placeAddress != null && widget.placeAddress!.isNotEmpty));
    final remaining = _maxLength - _controller.text.runes.length;
    final remainingColor = remaining < 0
        ? SpaceColors.error
        : remaining <= 2
            ? SpaceColors.neonYellow
            : SpaceColors.neonPurple.withValues(alpha: 0.5);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        decoration: const BoxDecoration(
          color: SpaceColors.space900,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: SpaceColors.white10),
            left: BorderSide(color: SpaceColors.white10),
            right: BorderSide(color: SpaceColors.white10),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: SpaceColors.white20,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isEditing ? '별칭 변경' : '새 장소 등록',
                  style: const TextStyle(
                    fontFamily: SpaceTypography.pixelFontFamily,
                    fontSize: 18,
                    color: SpaceColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasPlacePreview) ...[
                  const SizedBox(height: 14),
                  _PlacePreview(
                    name: widget.placeName ?? '',
                    address: widget.placeAddress ?? '',
                    // P6: 탭하면 시트 닫고 검색 화면으로 복귀 — 잘못 고른 장소 빠르게 재선택
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  '별칭',
                  style: TextStyle(
                    fontFamily: SpaceTypography.pixelFontFamily,
                    fontSize: 11,
                    color: SpaceColors.neonPurple.withValues(alpha: 0.7),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                _AliasField(
                  controller: _controller,
                  maxLength: _maxLength,
                  hasError: _errorText != null,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _errorText ?? '집, 회사처럼 짧고 알아보기 쉬운 이름이 좋아요',
                        style: TextStyle(
                          fontSize: 11,
                          color: _errorText != null
                              ? SpaceColors.error
                              : SpaceColors.neonLavender.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    Text(
                      '$remaining',
                      style: TextStyle(
                        fontFamily: SpaceTypography.pixelFontFamily,
                        fontSize: 11,
                        color: remainingColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                NeonButton(
                  label: _isEditing ? '저장' : '등록하기',
                  onTap: _canSubmit ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AliasField extends StatelessWidget {
  const _AliasField({
    required this.controller,
    required this.maxLength,
    required this.hasError,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final int maxLength;
  final bool hasError;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? SpaceColors.error
        : SpaceColors.neonPurple.withValues(alpha: 0.4);
    return Container(
      decoration: BoxDecoration(
        color: SpaceColors.space800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        autofocus: true,
        maxLength: maxLength + 4, // 시각적 입력은 약간 여유, 검증은 _maxLength로
        textInputAction: TextInputAction.done,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          fontSize: 16,
          color: SpaceColors.white,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: SpaceColors.neonPurple,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'[\n\r\t]')),
        ],
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          hintText: '예: 집, 회사, 단골카페',
          hintStyle: TextStyle(
            color: SpaceColors.white.withValues(alpha: 0.25),
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _PlacePreview extends StatelessWidget {
  const _PlacePreview({
    required this.name,
    required this.address,
    this.onTap,
  });

  final String name;
  final String address;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on,
            color: SpaceColors.neonPurple,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (name.isNotEmpty)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SpaceColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: SpaceColors.neonLavender.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '다시 고르기',
                  style: TextStyle(
                    color: SpaceColors.neonPurple.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: SpaceColors.neonPurple.withValues(alpha: 0.75),
                  size: 16,
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final shape = BoxDecoration(
      color: SpaceColors.space800,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: SpaceColors.neonPurple.withValues(alpha: 0.18),
      ),
    );

    if (onTap == null) {
      return Container(decoration: shape, child: content);
    }
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: shape,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}

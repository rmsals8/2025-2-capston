// lib/widgets/transport_mode_selector.dart - isEnabled 속성 추가 버전

import 'package:flutter/material.dart';
import '../models/transport_mode.dart';

class TransportModeSelector extends StatelessWidget {
  final TransportMode selectedMode;
  final ValueChanged<TransportMode> onModeChanged;
  final bool isEnabled; // 🆕 추가된 속성

  const TransportModeSelector({
    Key? key,
    required this.selectedMode,
    required this.onModeChanged,
    this.isEnabled = true, // 🆕 기본값은 true
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: TransportMode.values.map((mode) {
          final isSelected = selectedMode == mode;
          final isButtonEnabled = isEnabled; // 🆕 활성화 상태 확인

          return Expanded(
            child: GestureDetector(
              onTap: isButtonEnabled ? () {
                print('🎯 ${mode.label} 버튼 탭됨 (활성화: $isButtonEnabled)');
                if (selectedMode != mode) {
                  onModeChanged(mode);
                }
              } : null, // 🆕 비활성화 시 null
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isButtonEnabled ? mode.color : mode.color.withOpacity(0.5)) // 🆕 비활성화 시 투명도
                      : (isButtonEnabled ? Colors.transparent : Colors.grey[100]), // 🆕 비활성화 스타일
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? (isButtonEnabled ? mode.color : mode.color.withOpacity(0.5))
                        : (isButtonEnabled ? Colors.grey[300]! : Colors.grey[200]!), // 🆕 비활성화 테두리
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 아이콘
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 20,
                        color: isButtonEnabled
                            ? (isSelected ? Colors.white : Colors.grey[600])
                            : Colors.grey[400], // 🆕 비활성화 시 회색
                      ),
                      child: Text(mode.icon),
                    ),
                    const SizedBox(height: 4),

                    // 라벨
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isButtonEnabled
                            ? (isSelected ? Colors.white : Colors.grey[700])
                            : Colors.grey[400], // 🆕 비활성화 시 회색
                      ),
                      child: Text(mode.label),
                    ),

                    // 🆕 로딩 인디케이터 (검색 중일 때)
                    if (!isButtonEnabled && isSelected) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(mode.color),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// 🆕 로딩 상태가 포함된 향상된 버전
class EnhancedTransportModeSelector extends StatelessWidget {
  final TransportMode selectedMode;
  final ValueChanged<TransportMode> onModeChanged;
  final bool isEnabled;
  final bool isLoading; // 🆕 로딩 상태
  final String? loadingMessage; // 🆕 로딩 메시지

  const EnhancedTransportModeSelector({
    Key? key,
    required this.selectedMode,
    required this.onModeChanged,
    this.isEnabled = true,
    this.isLoading = false,
    this.loadingMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 기본 선택기
        TransportModeSelector(
          selectedMode: selectedMode,
          onModeChanged: onModeChanged,
          isEnabled: isEnabled,
        ),

        // 🆕 로딩 메시지
        if (isLoading && loadingMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selectedMode.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(selectedMode.color),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  loadingMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: selectedMode.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// lib/screens/schedule/multiple_options_screen.dart

import 'package:flutter/material.dart';
import '../../models/multiple_schedule_response.dart';
import 'optimized_schedule_screen.dart';
import '../main_navigation.dart';

class MultipleOptionsScreen extends StatefulWidget {
  final MultipleOptimizeResponse multipleResponse;

  const MultipleOptionsScreen({
    Key? key,
    required this.multipleResponse,
  }) : super(key: key);

  @override
  State<MultipleOptionsScreen> createState() => _MultipleOptionsScreenState();
}

class _MultipleOptionsScreenState extends State<MultipleOptionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        leading: IconButton(
          icon: const Icon(Icons.home, color: Colors.black),
          onPressed: () {
            // 모든 일정 관련 화면을 제거하고 MainNavigation으로 이동
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainNavigation()),
                  (route) => route.isFirst, // 첫 번째 route(로그인 상태)는 유지
            );
          },
        ),
        title: const Text(
          '옵션 비교',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 추천 요약
            if (widget.multipleResponse.comparison?.summary != null)
              _buildRecommendationSummary(),

            const SizedBox(height: 24),

            // 최고 옵션들 표시
            if (widget.multipleResponse.comparison != null)
              _buildBestOptionsSection(),

            const SizedBox(height: 24),

            // 모든 옵션 목록
            _buildAllOptionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationSummary() {
    final summary = widget.multipleResponse.comparison!.summary!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.blue[700], size: 24),
              const SizedBox(width: 8),
              const Text(
                '추천 결과',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary.overallRecommendation,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryMetric(
                '분석된 옵션',
                '${summary.totalOptionsAnalyzed}개',
                Icons.compare_arrows,
              ),
              const SizedBox(width: 20),
              _buildSummaryMetric(
                '시간 편차',
                '${summary.timeVariancePercentage.toStringAsFixed(1)}%',
                Icons.schedule,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBestOptionsSection() {
    final comparison = widget.multipleResponse.comparison!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '카테고리별 최고 옵션',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),

        // 추천 옵션
        if (comparison.recommendedOption != null)
          _buildBestOptionCard(
            '🏆 가장 추천하는 옵션',
            comparison.recommendedOption!,
            Colors.amber[100]!,
            Colors.amber[700]!,
          ),

        const SizedBox(height: 12),

        // 시간 최적 옵션
        if (comparison.bestTimeOption != null)
          _buildBestOptionCard(
            '⏰ 시간이 가장 짧은 옵션',
            comparison.bestTimeOption!,
            Colors.green[100]!,
            Colors.green[700]!,
          ),

        const SizedBox(height: 12),

        // 거리 최적 옵션
        if (comparison.bestDistanceOption != null)
          _buildBestOptionCard(
            '🚗 거리가 가장 짧은 옵션',
            comparison.bestDistanceOption!,
            Colors.blue[100]!,
            Colors.blue[700]!,
          ),
      ],
    );
  }

  Widget _buildBestOptionCard(String title, OptimizedOption option, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '옵션 ${option.optionId}번 (${option.score.grade}등급)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '점수: ${option.score.totalScore.toStringAsFixed(1)}점',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: textColor,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _viewOptionDetail(option),
            child: const Text('보기'),
          ),
        ],
      ),
    );
  }

  Widget _buildAllOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '모든 옵션',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.multipleResponse.optimizedOptions.length,
          itemBuilder: (context, index) {
            final option = widget.multipleResponse.optimizedOptions[index];
            return _buildOptionCard(option);
          },
        ),
      ],
    );
  }

  Widget _buildOptionCard(OptimizedOption option) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '옵션 ${option.optionId}번',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getGradeColor(option.score.grade),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${option.score.grade}등급',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 점수 정보
            Row(
              children: [
                Expanded(
                  child: _buildScoreItem('총점', '${option.score.totalScore.toStringAsFixed(1)}점'),
                ),
                Expanded(
                  child: _buildScoreItem('시간 효율', '${(option.score.timeEfficiency * 100).toStringAsFixed(0)}%'),
                ),
                Expanded(
                  child: _buildScoreItem('거리 효율', '${(option.score.distanceEfficiency * 100).toStringAsFixed(0)}%'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 추천 사항
            Text(
              option.recommendation,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),

            const SizedBox(height: 16),

            // 상세보기 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _viewOptionDetail(option),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text('상세보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.deepOrange;
      case 'F':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _viewOptionDetail(OptimizedOption option) {
    // ✅ Navigator.push 대신 pushReplacement 사용
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OptimizedScheduleScreen(
          optimizedData: option.result,
        ),
      ),
    );
  }
}
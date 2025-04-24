import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/schedule_save_service.dart';
import 'saved_schedule_detail_screen.dart'; // 새로운 화면 import

class SavedScheduleListScreen extends StatefulWidget {
  const SavedScheduleListScreen({Key? key}) : super(key: key);

  @override
  State<SavedScheduleListScreen> createState() => _SavedScheduleListScreenState();
}

class _SavedScheduleListScreenState extends State<SavedScheduleListScreen> {
  final ScheduleSaveService _scheduleSaveService = ScheduleSaveService();
  List<Map<String, dynamic>> _savedSchedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedSchedules();
  }

  Future<void> _loadSavedSchedules() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final savedSchedules = await _scheduleSaveService.getSavedSchedules();
      setState(() {
        _savedSchedules = savedSchedules;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장된 일정을 불러오는 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSchedule(int scheduleId) async {
    try {
      final success = await _scheduleSaveService.deleteSavedSchedule(scheduleId);
      if (success) {
        setState(() {
          _savedSchedules.removeWhere((schedule) => schedule['id'] == scheduleId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정이 삭제되었습니다')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정 삭제에 실패했습니다')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 삭제 중 오류가 발생했습니다: $e')),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '일정 삭제',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('${schedule['scheduleName']} 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '취소',
              style: TextStyle(color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteSchedule(schedule['id']);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _navigateToDetailScreen(int scheduleId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavedScheduleDetailScreen(scheduleId: scheduleId),
      ),
    ).then((_) => _loadSavedSchedules()); // 상세 화면에서 돌아왔을 때 목록 갱신
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '저장된 일정',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
        onRefresh: _loadSavedSchedules,
        color: Colors.black,
        child: _savedSchedules.isEmpty
            ? _buildEmptyState()
            : _buildScheduleList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '저장된 일정이 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '최적화된 일정을 저장해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('일정 생성하기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _savedSchedules.length,
      itemBuilder: (context, index) {
        final schedule = _savedSchedules[index];
        return _buildScheduleCard(schedule);
      },
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    // 날짜 포맷 변환
    String createdAt = '날짜 정보 없음';
    String expiresAt = '만료일 정보 없음';

    try {
      if (schedule['createdAt'] != null) {
        final created = DateTime.parse(schedule['createdAt']);
        createdAt = DateFormat('yyyy년 MM월 dd일').format(created);
      }

      if (schedule['expirationDate'] != null) {
        final expires = DateTime.parse(schedule['expirationDate']);
        expiresAt = DateFormat('yyyy년 MM월 dd일').format(expires);
      }
    } catch (e) {
      print('날짜 파싱 오류: $e');
    }

    return GestureDetector(
      onTap: () {
        // 일정 세부 정보 화면으로 이동
        _navigateToDetailScreen(schedule['id']);
      },
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          schedule['scheduleName'] ?? '제목 없음',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _showDeleteDialog(context, schedule),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '생성일: $createdAt',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '만료일: $expiresAt',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricItem(
                    icon: Icons.route,
                    value: '${(schedule['totalDistance'] ?? 0.0).toStringAsFixed(1)} km',
                    label: '총 거리',
                  ),
                  _buildMetricItem(
                    icon: Icons.access_time,
                    value: '${schedule['totalTime'] ?? 0} 분',
                    label: '소요 시간',
                  ),
                  _buildMetricItem(
                    icon: Icons.place,
                    value: '${schedule['itemCount'] ?? 0} 곳',
                    label: '장소 수',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.black87, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
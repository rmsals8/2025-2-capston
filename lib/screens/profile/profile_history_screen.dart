// lib/screens/profile/profile_history_screen.dart
import 'dart:convert';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/visit_history.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/visit_history_service.dart';
import '../auth/auth_screen.dart';
import '../recommendations/history_based_recommendations_screen.dart';
import 'visit_history_screen.dart';
import '../settings/settings_screen.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart' ;

class ProfileHistoryScreen extends StatefulWidget {
  const ProfileHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ProfileHistoryScreen> createState() => _ProfileHistoryScreenState();
}

class _ProfileHistoryScreenState extends State<ProfileHistoryScreen> {
  final VisitHistoryService _historyService = VisitHistoryService();
  final baseUrl = dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8080/api/v1';
  // 상태 변수
  bool _isLoading = true;
  List<VisitHistory> _recentHistories = [];
  Map<String, int> _categoryCounts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 사용자 정보 조회 (백엔드에서) - 명시적으로 먼저 호출
      Map<String, String> userInfo = await _fetchUserInfoFromBackend();

      // 받아온 사용자 정보 출력하여 확인
      print('백엔드에서 가져온 사용자 정보: $userInfo');

      // SharedPreferences에 백엔드 정보 저장 (추가)
      final prefs = await SharedPreferences.getInstance();
      if (userInfo['name'] != null && userInfo['name']!.isNotEmpty) {
        await prefs.setString('user_name', userInfo['name']!);
      }
      if (userInfo['email'] != null && userInfo['email']!.isNotEmpty) {
        await prefs.setString('user_email', userInfo['email']!);
      }

      // 최근 방문 기록 5개만 로드
      _recentHistories = await _historyService.getRecentlyVisitedPlaces(limit: 5);

      // 모든 방문 기록을 로드하여 카테고리 통계 계산
      final allHistories = await _historyService.getVisitHistories();

      _categoryCounts = {};
      for (var history in allHistories) {
        _categoryCounts[history.category] = (_categoryCounts[history.category] ?? 0) + 1;
      }
    } catch (e) {
      print('프로필 데이터 로드 오류: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 프로필'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileCard(),
              _buildStatisticsCard(),
              _buildRecentVisitsSection(),
              _buildCategoryStats(),
              _buildActionButtons(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
              child: Icon(
                Icons.person,
                size: 40,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 사용자 이름 표시 - FutureBuilder 대신 직접 백엔드 조회 사용
                  FutureBuilder<Map<String, String>>(
                      future: _fetchUserInfoFromBackend(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            width: 120,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }

                        final userData = snapshot.data;
                        final userName = userData?['name'] ?? '사용자';
                        print('백엔드에서 직접 가져온 사용자 이름: $userName');

                        return Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }
                  ),
                  const SizedBox(height: 4),

                  // 사용자 이메일 표시 - FutureBuilder 대신 직접 백엔드 조회 사용
                  FutureBuilder<Map<String, String>>(
                      future: _fetchUserInfoFromBackend(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            width: 180,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }

                        final userData = snapshot.data;
                        final userEmail = userData?['email'] ?? 'user@example.com';
                        print('백엔드에서 직접 가져온 사용자 이메일: $userEmail');

                        return Text(
                          userEmail,
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        );
                      }
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _showLogoutDialog,
                    child: const Text('로그아웃'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<Map<String, String>> _fetchUserInfoFromBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      // 토큰 상세 정보 출력
      print('토큰 전체: $token');
      print('토큰 길이: ${token?.length}');
      print('토큰 시작: ${token?.substring(0, Math.min(20, token?.length ?? 0))}');

      if (token == null || token.isEmpty) {
        print('토큰이 없습니다.');
        return {'name': '사용자', 'email': 'user@example.com'};
      }

      // Bearer 토큰 형식 확인 및 수정
      final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

      print('API 요청에 사용되는 Authorization 헤더: ${authHeader.substring(0, Math.min(25, authHeader.length))}...');

      try {
        final response = await http.get(
          Uri.parse('$baseUrl/users/me'),
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/json',
          },
        );

        print('사용자 정보 API 응답 상태 코드: ${response.statusCode}');
        print('사용자 정보 API 응답 본문: ${response.body}');

        if (response.statusCode == 200) {
          final userData = json.decode(utf8.decode(response.bodyBytes));
          return {
            'name': userData['name'] ?? '사용자',
            'email': userData['email'] ?? 'user@example.com'
          };
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          print('인증 오류: 토큰이 만료되었거나 유효하지 않습니다.');

          // 토큰 만료 시 로컬에 저장된 사용자 정보 반환
          final name = prefs.getString('user_name');
          final email = prefs.getString('user_email');

          print('로컬 저장소에서 가져온 사용자 정보: $name, $email');

          // RefreshToken 처리 로직 추가할 수 있음

          return {
            'name': name ?? '사용자',
            'email': email ?? 'user@example.com'
          };
        } else {
          print('사용자 정보 조회 실패: ${response.body}');
          return {'name': '사용자', 'email': 'user@example.com'};
        }
      } catch (e) {
        print('HTTP 요청 오류: $e');
        // 로컬에 저장된 사용자 정보 반환
        final name = prefs.getString('user_name');
        final email = prefs.getString('user_email');

        return {
          'name': name ?? '사용자',
          'email': email ?? 'user@example.com'
        };
      }
    } catch (e) {
      print('사용자 정보 API 호출 오류: $e');
      return {'name': '사용자', 'email': 'user@example.com'};
    }
  }

// 로컬 저장소에서 사용자 정보 가져오기
  Future<Map<String, String>> _getUserInfoFromLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('user_name');
    final userEmail = prefs.getString('user_email');

    print('로컬 저장소에서 가져온 사용자 정보: $userName, $userEmail');

    return {
      'name': userName ?? '사용자',
      'email': userEmail ?? 'user@example.com'
    };
  }
  Future<String?> _getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 저장된 사용자 이메일 가져오기
      String? userEmail = prefs.getString('user_email');
      print('SharedPreferences에서 가져온 사용자 이메일: $userEmail');

      // 이메일이 없으면 기본값 반환
      if (userEmail == null || userEmail.isEmpty) {
        // 백엔드에서 정보 가져오기 시도
        final userInfo = await _fetchUserInfoFromBackend();
        return userInfo['email'];
      }

      return userEmail;
    } catch (e) {
      print('사용자 이메일 가져오기 오류: $e');
      return 'user@example.com';
    }
  }
  Future<String?> _getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 저장된 사용자 이름 가져오기
      String? userName = prefs.getString('user_name');
      print('SharedPreferences에서 가져온 사용자 이름: $userName');

      // 이름이 없으면 기본값 반환
      if (userName == null || userName.isEmpty) {
        // 백엔드에서 정보 가져오기 시도
        final userInfo = await _fetchUserInfoFromBackend();
        return userInfo['name'];
      }

      return userName;
    } catch (e) {
      print('사용자 이름 가져오기 오류: $e');
      return '사용자';
    }
  }


  Future<String?> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Attempt to get user ID from preferences
      String? userId = prefs.getString('user_id');

      // If user ID is not available, try to extract from token
      if (userId == null || userId.isEmpty) {
        final token = prefs.getString('access_token');
        if (token != null && token.isNotEmpty) {
          // In a real app, you might extract user ID from JWT token
          // Here we'll just use part of the token as a demo
          if (token.length > 10) {
            userId = 'user_${token.substring(0, 8)}';
          }
        }
      }

      return userId;
    } catch (e) {
      print('Error retrieving user ID: $e');
      return null;
    }
  }
  Widget _buildStatisticsCard() {
    // 방문 통계
    final visitCount = _recentHistories.length;
    final categoryCount = _categoryCounts.length;
    final thisMonthCount = _getMonthlyVisitCount();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '방문 통계',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.place,
                  value: '$visitCount',
                  label: '총 방문 장소',
                ),
                _buildStatItem(
                  icon: Icons.category,
                  value: '$categoryCount',
                  label: '방문 카테고리',
                ),
                _buildStatItem(
                  icon: Icons.calendar_today,
                  value: '$thisMonthCount',
                  label: '이번 달 방문',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
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

  Widget _buildRecentVisitsSection() {
    if (_recentHistories.isEmpty) {
      return const SizedBox(height: 16);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '최근 방문',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VisitHistoryScreen(),
                    ),
                  );
                },
                child: const Text('전체보기'),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentHistories.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final history = _recentHistories[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                  child: Icon(
                    _getCategoryIcon(history.category),
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                title: Text(
                  history.placeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${history.category} • ${_formatDate(history.visitDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  // 방문 기록 상세 정보 표시 (향후 구현)
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryStats() {
    if (_categoryCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    // 카테고리별로 정렬
    final sortedCategories = _categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 최대값 계산
    final maxCount = sortedCategories.isNotEmpty
        ? sortedCategories.first.value.toDouble()
        : 1.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '카테고리별 방문',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: sortedCategories
                    .take(5) // 상위 5개만 표시
                    .map((entry) => _buildCategoryBar(
                  category: entry.key,
                  count: entry.value,
                  maxCount: maxCount,
                ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar({
    required String category,
    required int count,
    required double maxCount,
  }) {
    final double percentage = count / maxCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              category,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                // 배경 바
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // 진행 바
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistoryBasedRecommendationsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.recommend, color: Colors.yellow), // 아이콘 색상 변경
              label: const Text(
                '맞춤 추천 장소',
                style: TextStyle(
                  color: Colors.yellow, // 텍스트 색상을 노란색으로 변경
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple, // 배경색은 보라색 유지
                foregroundColor: Colors.yellow, // 전체 텍스트/아이콘 색상을 노란색으로 변경
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VisitHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('방문 기록 관리'),
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logout();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 실패: $e')),
        );
      }
    }
  }

  int _getMonthlyVisitCount() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    return _recentHistories
        .where((h) => h.visitDate.isAfter(firstDayOfMonth))
        .length;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '오늘';
    } else if (difference.inDays == 1) {
      return '어제';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${date.year}.${date.month}.${date.day}';
    }
  }

  IconData _getCategoryIcon(String category) {
    final lowerCategory = category.toLowerCase();

    if (lowerCategory.contains('식당') ||
        lowerCategory.contains('음식') ||
        lowerCategory.contains('레스토랑')) {
      return Icons.restaurant;
    } else if (lowerCategory.contains('카페') ||
        lowerCategory.contains('coffee')) {
      return Icons.coffee;
    } else if (lowerCategory.contains('쇼핑') ||
        lowerCategory.contains('마트')) {
      return Icons.shopping_bag;
    } else if (lowerCategory.contains('숙소') ||
        lowerCategory.contains('호텔')) {
      return Icons.hotel;
    } else if (lowerCategory.contains('관광') ||
        lowerCategory.contains('명소')) {
      return Icons.photo_camera;
    } else if (lowerCategory.contains('병원') ||
        lowerCategory.contains('약국')) {
      return Icons.local_hospital;
    } else if (lowerCategory.contains('주유소')) {
      return Icons.local_gas_station;
    } else if (lowerCategory.contains('주차')) {
      return Icons.local_parking;
    }

    return Icons.place;
  }
}
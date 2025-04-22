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
      Map<String, String> userInfo = await _fetchUserInfoFromBackend();
      print('백엔드에서 가져온 사용자 정보: $userInfo');

      final prefs = await SharedPreferences.getInstance();
      if (userInfo['name'] != null && userInfo['name']!.isNotEmpty) {
        await prefs.setString('user_name', userInfo['name']!);
      }
      if (userInfo['email'] != null && userInfo['email']!.isNotEmpty) {
        await prefs.setString('user_email', userInfo['email']!);
      }

      _recentHistories = await _historyService.getRecentlyVisitedPlaces(limit: 5);
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        title: const Text(
          '내 프로필',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
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
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
        onRefresh: _loadData,
        color: Colors.black,
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
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 40,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<Map<String, String>>(
                    future: _fetchUserInfoFromBackend(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          width: 120,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }

                      final userData = snapshot.data;
                      final userName = userData?['name'] ?? '사용자';
                      return Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    }
                ),
                const SizedBox(height: 4),
                FutureBuilder<Map<String, String>>(
                    future: _fetchUserInfoFromBackend(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          width: 180,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }

                      final userData = snapshot.data;
                      final userEmail = userData?['email'] ?? 'user@example.com';
                      return Text(
                        userEmail,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      );
                    }
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: _showLogoutDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('로그아웃'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Future<Map<String, String>> _fetchUserInfoFromBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      print('토큰 전체: $token');
      print('토큰 길이: ${token?.length}');
      print('토큰 시작: ${token?.substring(0, Math.min(20, token?.length ?? 0))}');

      if (token == null || token.isEmpty) {
        print('토큰이 없습니다.');
        return {'name': '사용자', 'email': 'user@example.com'};
      }

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

          final name = prefs.getString('user_name');
          final email = prefs.getString('user_email');

          print('로컬 저장소에서 가져온 사용자 정보: $name, $email');

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
      String? userEmail = prefs.getString('user_email');
      print('SharedPreferences에서 가져온 사용자 이메일: $userEmail');

      if (userEmail == null || userEmail.isEmpty) {
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
      String? userName = prefs.getString('user_name');
      print('SharedPreferences에서 가져온 사용자 이름: $userName');

      if (userName == null || userName.isEmpty) {
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
      String? userId = prefs.getString('user_id');

      if (userId == null || userId.isEmpty) {
        final token = prefs.getString('access_token');
        if (token != null && token.isNotEmpty) {
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
    final visitCount = _recentHistories.length;
    final categoryCount = _categoryCounts.length;
    final thisMonthCount = _getMonthlyVisitCount();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '방문 통계',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
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
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
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
                  fontWeight: FontWeight.w800,
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
                child: const Text(
                  '전체보기',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(history.category),
                    color: Colors.black87,
                  ),
                ),
                title: Text(
                  history.placeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${history.category} • ${_formatDate(history.visitDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
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

    final sortedCategories = _categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: sortedCategories
                  .take(5)
                  .map((entry) => _buildCategoryBar(
                category: entry.key,
                count: entry.value,
                maxCount: maxCount,
              ))
                  .toList(),
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
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.black,
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
                fontWeight: FontWeight.w800,
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
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistoryBasedRecommendationsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.recommend),
              label: const Text(
                '맞춤 추천 장소',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
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
              label: const Text(
                '방문 기록 관리',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '로그아웃',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text('정말 로그아웃 하시겠습니까?'),
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
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';  // Timer를 위해 추가
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';  // AuthProvider 추가

class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({Key? key}) : super(key: key);

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;  // Timer 변수 추가
  List<dynamic> _places = [];
  bool _isLoading = false;
  final baseUrl = dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8080/api/v1';

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => _places = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final uri = Uri.parse('$baseUrl/places/search?query=$encodedQuery');

      // AuthProvider에서 토큰 가져오기
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();

      // 디버깅용 로그
      print('Token: ${token != null ? (token.length > 10 ? token.substring(0, 10) + '...' : token) : 'null'}');

      // 요청 헤더에 토큰 추가 - Authorization 헤더 추가
      final headers = {
        'Content-Type': 'application/json',
      };

      // 중요: 토큰이 있을 경우 Authorization 헤더 추가
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      print('Request URL: $uri');
      print('Request Headers: $headers');

      final response = await http.get(uri, headers: headers);

      print('Status Code: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        // 응답 구조에 따라 'data' 필드 아래의 'items'를 가져옴
        final items = data['data'] != null ?
        (data['data']['items'] ?? []) :
        (data['items'] ?? []);
        setState(() => _places = items);
      } else if (response.statusCode == 401) {
        print('인증 오류: 토큰이 유효하지 않거나 만료되었습니다.');
        // 토큰 갱신 시도 (void 메서드 호출)
        await authProvider.refreshToken();
        // 갱신 후 새 토큰을 가져와서 확인
        final newToken = await authProvider.getToken();

        if (newToken != null && newToken.isNotEmpty) {
          // 새 토큰이 있으면 재시도
          _searchPlaces(query);
        } else {
          // 토큰 갱신 실패로 간주
          // 로그인 화면으로 이동하는 로직 (필요에 따라 구현)
        }
      } else {
        print('Error Response: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('Error details: $e');
      print('Stack trace: $stackTrace');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();  // Timer 취소
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AuthProvider가 사용 가능한지 확인하는 로깅 추가
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      print('AuthProvider found in context');
    } catch (e) {
      print('ERROR: AuthProvider not found in context: $e');
    }

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
          '장소 검색',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: '장소를 검색하세요',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.search, color: Colors.black),
                  suffixIcon: _isLoading
                      ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    ),
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onChanged: (value) {
                  if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                    _searchPlaces(value);
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: _places.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '검색 결과가 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _places.length,
              itemBuilder: (context, index) {
                final place = _places[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.black),
                    ),
                    title: Text(
                      place['title'].toString().replaceAll(RegExp(r'<[^>]*>'), ''),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      place['address'] ?? place['roadAddress'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                    onTap: () {
                      Navigator.pop(context, {
                        'name': place['title'].toString().replaceAll(RegExp(r'<[^>]*>'), ''),
                        'address': place['address'] ?? place['roadAddress'] ?? '',
                        'latitude': double.tryParse(place['mapy'] ?? '') ?? 0,
                        'longitude': double.tryParse(place['mapx'] ?? '') ?? 0,
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
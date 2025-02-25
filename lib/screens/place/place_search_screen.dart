import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';  // Timer를 위해 추가

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

  // 네이버 검색 API 키
  static const String clientId = 'kPRaPEKGbW3pE5W17E3K';
  static const String clientSecret = 'OOLZmVioyi';

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => _places = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final encodedQuery = Uri.encodeComponent(query);

      // 백엔드 API 호출
      final uri = Uri.parse(
          'http://10.0.2.2:8080/api/v1/places/search?query=$encodedQuery'
      );

      final response = await http.get(uri);

      print('Query: $query');
      print('URL: ${uri.toString()}');
      print('Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() => _places = data['items'] ?? []);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('장소 검색'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '장소를 검색하세요',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
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
          Expanded(
            child: ListView.builder(
              itemCount: _places.length,
              itemBuilder: (context, index) {
                final place = _places[index];
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(
                    place['title'].toString().replaceAll(RegExp(r'<[^>]*>'), ''),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    place['address'] ?? place['roadAddress'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(context, {
                      'name': place['title'].toString().replaceAll(RegExp(r'<[^>]*>'), ''),
                      'address': place['address'] ?? place['roadAddress'] ?? '',
                      'latitude': double.tryParse(place['mapy'] ?? '') ?? 0,
                      'longitude': double.tryParse(place['mapx'] ?? '') ?? 0,
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
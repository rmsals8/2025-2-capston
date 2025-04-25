// lib/screens/home/home_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// Google Speech API 관련 import 추가
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trip_helper/providers/auth_provider.dart';

import '../../providers/location_provider.dart';
import '../../services/visit_history_service.dart';
import '../../services/place_recommendation_service.dart';
import '../../models/visit_history.dart';
import '../../models/recommended_place.dart';
import '../../providers/schedule_provider.dart';
import '../schedule/optimized_schedule_screen.dart';
import '../route/route_generation_screen.dart';
import '../recommendations/history_based_recommendations_screen.dart';
import '../profile/visit_history_screen.dart';
import '../place_recommendations_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;

import '../../models/category_data.dart';
import '../../providers/user_preference_provider.dart';
import '../auth/category_preference_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final TextEditingController _searchController = TextEditingController();
  final VisitHistoryService _historyService = VisitHistoryService();
  final PlaceRecommendationService _recommendationService = PlaceRecommendationService();

  // GPT API 키 (실제 사용 시 보안 처리 필요)
  String get _openAIKey => dotenv.dotenv.env['OPENAI_API_KEY'] ?? '';
  String get _googleMapsApiKey => dotenv.dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  String get _lambdaApiUrl => dotenv.dotenv.env['LAMBDA_API_URL'] ?? 'https://fm1scjq7g3.execute-api.ap-northeast-2.amazonaws.com/enhanced-schedule';
  // 음성 인식 변수 교체
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastRecognizedText = "";

  bool _isLoading = true;
  int _currentCarouselIndex = 0;

  // 데이터 상태
  List<VisitHistory> _recentPlaces = [];
  List<RecommendedPlace> _recommendedPlaces = [];
  List<String> _popularCategories = [];
  List<String> _userPreferredCategories = [];
  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadData();
    _initSpeech();
      _loadUserPreferences(); 
  }
    // 사용자 선호도 불러오기
  Future<void> _loadUserPreferences() async {
    try {
      final prefProvider = Provider.of<UserPreferenceProvider>(context, listen: false);
      _userPreferredCategories = await prefProvider.getPreferredCategories();
      print('사용자 선호 카테고리: $_userPreferredCategories');
    } catch (e) {
      print('선호도 불러오기 오류: $e');
    }
  }

  // 새로운 음성 인식 초기화 메소드
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('음성 인식 오류: ${error.errorMsg}')),
        );
      },
    );
    setState(() {});
  }

  // 새로운 음성 인식 시작 메소드
  void _startListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('음성 인식이 지원되지 않는 기기입니다.')),
      );
      return;
    }
    setState(() => _isListening = true);
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _lastRecognizedText = result.recognizedWords;
          _searchController.text = _lastRecognizedText;
        });
      },
      localeId: 'ko_KR', // 한국어
    );

    // 사용자에게 듣고 있다는 피드백 제공
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.mic, color: Colors.white),
            SizedBox(width: 8),
            Text('듣고 있습니다...'),
          ],
        ),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // 새로운 음성 인식 중지 메소드
  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  // 음성으로 인식된 일정 처리 메소드 추가
  Future<void> _processScheduleVoiceInput(String voiceText) async {
    if (voiceText.isEmpty) return;

    print('Processing voice input: $voiceText'); // 영어 로그
    print('음성 입력 처리 중: $voiceText'); // 한글 로그

    // 일정 추가 여부 확인 다이얼로그
    bool shouldProcess = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('음성 인식 완료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('다음 내용을 일정으로 추가할까요?'),
            SizedBox(height: 8),
            Text(
              voiceText,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('일정 추가'),
          ),
        ],
      ),
    ) ?? false;

    print('User confirmed processing: $shouldProcess'); // 영어 로그
    print('사용자 처리 확인: $shouldProcess'); // 한글 로그

    if (!shouldProcess) return;

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      print('Processing schedule data using Lambda...'); // 영어 로그
      print('Lambda를 사용하여 일정 데이터 처리 중...'); // 한글 로그

      // AWS Lambda API 호출로 처리
      final scheduleData = await _processScheduleDataWithLambda(voiceText);
    print('Calling AWS Lambda API...'); // 영어 로그
    print('AWS Lambda API 호출 중...'); // 한글 로그
      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();

      if (scheduleData != null) {
        print('Schedule data processed successfully: $scheduleData'); // 영어 로그
        print('일정 데이터 처리 성공: $scheduleData'); // 한글 로그

        // scheduleProvider를 이용해 최적화 요청
        final provider = Provider.of<ScheduleProvider>(context, listen: false);

        try {
          print('Optimizing schedules...'); // 영어 로그
          print('일정 최적화 중...'); // 한글 로그

          // scheduleData에서 fixedSchedules와 flexibleSchedules를 추출
          List<Map<String, dynamic>> schedulesToOptimize = [];

          // 고정 일정 추가
          if (scheduleData.containsKey('fixedSchedules') &&
              scheduleData['fixedSchedules'] is List) {
            List<dynamic> fixedSchedules = scheduleData['fixedSchedules'];
            schedulesToOptimize.addAll(
                fixedSchedules.map((schedule) => Map<String, dynamic>.from(schedule)).toList()
            );
            print('Added ${fixedSchedules.length} fixed schedules'); // 영어 로그
            print('${fixedSchedules.length}개의 고정 일정 추가됨'); // 한글 로그
          }

          // 유연한 일정 추가
          if (scheduleData.containsKey('flexibleSchedules') &&
              scheduleData['flexibleSchedules'] is List) {
            List<dynamic> flexibleSchedules = scheduleData['flexibleSchedules'];
            schedulesToOptimize.addAll(
                flexibleSchedules.map((schedule) => Map<String, dynamic>.from(schedule)).toList()
            );
            print('Added ${flexibleSchedules.length} flexible schedules'); // 영어 로그
            print('${flexibleSchedules.length}개의 유연한 일정 추가됨'); // 한글 로그
          }

          // 최적화 메소드 호출
          final optimizedData = await provider.optimizeSchedules(schedulesToOptimize);
          print('Schedule optimization successful'); // 영어 로그
          print('일정 최적화 성공'); // 한글 로그

          // 최적화된 일정 화면으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OptimizedScheduleScreen(
                optimizedData: optimizedData,
              ),
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('음성으로 일정이 추가되었습니다!')),
          );
        } catch (e) {
          print('Error optimizing schedules: $e'); // 영어 로그
          print('일정 최적화 오류: $e'); // 한글 로그

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('일정 최적화 중 오류가 발생했습니다: $e')),
          );
        }
      } else {
        print('Failed to extract schedule data from voice input'); // 영어 로그
        print('음성 입력에서 일정 데이터 추출 실패'); // 한글 로그

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('음성에서 일정 정보를 추출할 수 없습니다')),
        );
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Error processing voice input: $e'); // 영어 로그
      print('음성 입력 처리 오류: $e'); // 한글 로그

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  // AWS Lambda로 일정 데이터 처리 메소드
Future<Map<String, dynamic>?> _processScheduleDataWithLambda(String voiceInput) async {
  try {
    _isLoading = true; // 로딩 상태 설정 (필요시)
    
    // Lambda 엔드포인트 URL
    final url = Uri.parse(_lambdaApiUrl);
    
    // 요청 본문 데이터
    final requestBody = {
      "voice_input": voiceInput
    };
    
    print('Sending request to Lambda: ${json.encode(requestBody)}');
    
    // HTTP POST 요청 (성공하는 다른 파일의 방식과 동일하게)
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestBody)
    );

    print('Lambda response status code: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return responseData;
    } else {
      print('Lambda API error: ${response.statusCode}\n${response.body}');
      return null;
    }
  } catch (e) {
    print('Lambda API call exception: $e');
    return null;
  } finally {
    _isLoading = false; // 로딩 상태 해제 (필요시)
  }
}

// GPT API를 통해 일정 데이터 추출 메소드
  Future<Map<String, dynamic>?> _extractScheduleDataFromGPT(String voiceInput) async {
    print('Calling OpenAI API...'); // 영어 로그
    print('OpenAI API 호출 중...'); // 한글 로그

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8', // UTF-8 명시
          'Authorization': 'Bearer $_openAIKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '''다음 음성 메시지에서 일정 정보를 추출하여 JSON 형식으로 반환해주세요.

필요한 정보:
- 장소명(name): 방문할 장소 이름
- 일정 유형(type): "FIXED"(고정 일정) 또는 "FLEXIBLE"(유연한 일정)
- 소요 시간(duration): 분 단위 (언급이 없으면 60분으로 설정)
- 우선순위(priority): 1-5 사이 숫자 (언급이 없으면 1로 설정)
- 위치(location): 장소의 주소나 위치 설명
- 시작 시간(startTime): ISO 8601 형식 (YYYY-MM-DDTHH:MM:SS)
- 종료 시간(endTime): ISO 8601 형식 (시작 시간 + 소요 시간)

다음 JSON 형식으로 반환해주세요:
{
  "fixedSchedules": [
    {
      "id": "${DateTime.now().millisecondsSinceEpoch}",
      "name": "장소명",
      "type": "FIXED",
      "duration": 60,
      "priority": 1,
      "location": "위치 상세",
      "latitude": 37.5665,
      "longitude": 126.9780,
      "startTime": "2023-12-01T10:00:00",
      "endTime": "2023-12-01T11:00:00"
    }
  ],
  "flexibleSchedules": [
    {
      "id": "${DateTime.now().millisecondsSinceEpoch + 1}",
      "name": "방문할 곳",
      "type": "FLEXIBLE",
      "duration": 60,
      "priority": 3,
      "location": "위치 상세",
      "latitude": 37.5665,
      "longitude": 126.9780
    }
  ]
}

시간이 명확한 일정은 fixedSchedules에, 시간이 불명확한 일정은 flexibleSchedules에 포함시켜주세요.
각 일정의 id는 현재 시간 기준 밀리초로 설정해주세요.
latitude와 longitude 값은 장소에 맞게 적절히 설정해주세요.
한글이 포함된 JSON 응답을 보낼 때 UTF-8 인코딩이 유지되도록 해주세요.
'''
            },
            {
              'role': 'user',
              'content': voiceInput
            }
          ]
        }),
      );

      print('OpenAI API response status: ${response.statusCode}'); // 영어 로그
      print('OpenAI API 응답 상태: ${response.statusCode}'); // 한글 로그

      if (response.statusCode == 200) {
        // 응답을 UTF-8로 명시적 디코딩
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'];

        print('OpenAI API response content: $content'); // 영어 로그
        print('OpenAI API 응답 내용: $content'); // 한글 로그

        try {
          // GPT 응답에서 JSON 부분만 추출
          RegExp regex = RegExp(r'({[\s\S]*})');
          var match = regex.firstMatch(content);

          if (match != null) {
            String jsonStr = match.group(1)!;
            print('Extracted JSON string: $jsonStr'); // 영어 로그
            print('추출된 JSON 문자열: $jsonStr'); // 한글 로그

            // JSON을 파싱하고 한글 인코딩 수정
            Map<String, dynamic> parsedJson = jsonDecode(jsonStr);

            // 고정 일정 한글 수정
            if (parsedJson.containsKey('fixedSchedules')) {
              List<dynamic> fixedSchedules = parsedJson['fixedSchedules'];
              for (int i = 0; i < fixedSchedules.length; i++) {
                Map<String, dynamic> schedule = fixedSchedules[i];
                if (schedule.containsKey('name')) {
                  schedule['name'] = _correctKoreanEncoding(schedule['name']);
                }
                if (schedule.containsKey('location')) {
                  schedule['location'] = _correctKoreanEncoding(schedule['location']);
                }
              }
            }

            // 유연 일정 한글 수정
            if (parsedJson.containsKey('flexibleSchedules')) {
              List<dynamic> flexibleSchedules = parsedJson['flexibleSchedules'];
              for (int i = 0; i < flexibleSchedules.length; i++) {
                Map<String, dynamic> schedule = flexibleSchedules[i];
                if (schedule.containsKey('name')) {
                  schedule['name'] = _correctKoreanEncoding(schedule['name']);
                }
                if (schedule.containsKey('location')) {
                  schedule['location'] = _correctKoreanEncoding(schedule['location']);
                }
              }
            }

            // 수정된 JSON 확인
            print('Corrected JSON: ${jsonEncode(parsedJson)}'); // 영어 로그
            print('수정된 JSON: ${jsonEncode(parsedJson)}'); // 한글 로그

            return parsedJson;
          } else {
            // 전체 문자열이 JSON일 수도 있음
            print('Trying to parse the entire content as JSON'); // 영어 로그
            print('전체 내용을 JSON으로 파싱 시도'); // 한글 로그

            Map<String, dynamic> parsedJson = jsonDecode(content);

            // 고정 일정 한글 수정
            if (parsedJson.containsKey('fixedSchedules')) {
              List<dynamic> fixedSchedules = parsedJson['fixedSchedules'];
              for (int i = 0; i < fixedSchedules.length; i++) {
                Map<String, dynamic> schedule = fixedSchedules[i];
                if (schedule.containsKey('name')) {
                  schedule['name'] = _correctKoreanEncoding(schedule['name']);
                }
                if (schedule.containsKey('location')) {
                  schedule['location'] = _correctKoreanEncoding(schedule['location']);
                }
              }
            }

            // 유연 일정 한글 수정
            if (parsedJson.containsKey('flexibleSchedules')) {
              List<dynamic> flexibleSchedules = parsedJson['flexibleSchedules'];
              for (int i = 0; i < flexibleSchedules.length; i++) {
                Map<String, dynamic> schedule = flexibleSchedules[i];
                if (schedule.containsKey('name')) {
                  schedule['name'] = _correctKoreanEncoding(schedule['name']);
                }
                if (schedule.containsKey('location')) {
                  schedule['location'] = _correctKoreanEncoding(schedule['location']);
                }
              }
            }

            return parsedJson;
          }
        } catch (e) {
          print('JSON parsing error: $e'); // 영어 로그
          print('JSON 파싱 오류: $e'); // 한글 로그
          print('GPT response: $content'); // 영어 로그
          print('GPT 응답: $content'); // 한글 로그
          return null;
        }
      } else {
        print('API call failed: ${response.statusCode}'); // 영어 로그
        print('API 호출 실패: ${response.statusCode}'); // 한글 로그
        print('Response: ${response.body}'); // 영어 로그
        print('응답: ${response.body}'); // 한글 로그
        return null;
      }
    } catch (e) {
      print('OpenAI API call error: $e'); // 영어 로그
      print('OpenAI API 호출 오류: $e'); // 한글 로그
      return null;
    }
  }



  // 위경도 데이터 보강 메소드
  Future<Map<String, dynamic>> _enhanceLocationData(Map<String, dynamic> scheduleData) async {
    print('Enhancing location data with coordinates...'); // 영어 로그
    print('좌표 정보로 위치 데이터 보강 중...'); // 한글 로그

    // 복사본 생성하여 원본 데이터 보존
    Map<String, dynamic> enhancedData = Map<String, dynamic>.from(scheduleData);

    // 고정 일정 처리
    if (enhancedData.containsKey('fixedSchedules')) {
      List<Map<String, dynamic>> fixedSchedules = List<Map<String, dynamic>>.from(enhancedData['fixedSchedules']);
      List<Map<String, dynamic>> enhancedFixedSchedules = [];

      for (var schedule in fixedSchedules) {
        Map<String, dynamic> enhancedSchedule = Map<String, dynamic>.from(schedule);

        // 좌표 정보가 없거나 기본값인 경우만 보강
        if (!schedule.containsKey('latitude') ||
            !schedule.containsKey('longitude') ||
            schedule['latitude'] == 37.5665 ||
            schedule['longitude'] == 126.9780) {

          // 장소명이나 주소로 위경도 조회
          String searchTerm = schedule['name'];
          if (schedule.containsKey('location') && schedule['location'].toString().isNotEmpty) {
            searchTerm = schedule['location'];
          }

          print('Searching coordinates for: $searchTerm'); // 영어 로그
          print('좌표 검색 중: $searchTerm'); // 한글 로그

          final coordinates = await _getCoordinates(searchTerm);
          if (coordinates != null) {
            enhancedSchedule['latitude'] = coordinates['latitude'];
            enhancedSchedule['longitude'] = coordinates['longitude'];
            print('Found coordinates: $coordinates'); // 영어 로그
            print('좌표 찾음: $coordinates'); // 한글 로그
          }
        }

        enhancedFixedSchedules.add(enhancedSchedule);
      }

      enhancedData['fixedSchedules'] = enhancedFixedSchedules;
    }

    // 유연 일정 처리
    if (enhancedData.containsKey('flexibleSchedules')) {
      List<Map<String, dynamic>> flexibleSchedules = List<Map<String, dynamic>>.from(enhancedData['flexibleSchedules']);
      List<Map<String, dynamic>> enhancedFlexibleSchedules = [];

      for (var schedule in flexibleSchedules) {
        Map<String, dynamic> enhancedSchedule = Map<String, dynamic>.from(schedule);

        // 좌표 정보가 없거나 기본값인 경우만 보강
        if (!schedule.containsKey('latitude') ||
            !schedule.containsKey('longitude') ||
            schedule['latitude'] == 37.5665 ||
            schedule['longitude'] == 126.9780) {

          // 장소명이나 주소로 위경도 조회
          String searchTerm = schedule['name'];
          if (schedule.containsKey('location') && schedule['location'].toString().isNotEmpty) {
            searchTerm = schedule['location'];
          }

          print('Searching coordinates for flexible schedule: $searchTerm'); // 영어 로그
          print('유연 일정 좌표 검색 중: $searchTerm'); // 한글 로그

          final coordinates = await _getCoordinates(searchTerm);
          if (coordinates != null) {
            enhancedSchedule['latitude'] = coordinates['latitude'];
            enhancedSchedule['longitude'] = coordinates['longitude'];
            print('Found coordinates for flexible schedule: $coordinates'); // 영어 로그
            print('유연 일정 좌표 찾음: $coordinates'); // 한글 로그
          }
        }

        enhancedFlexibleSchedules.add(enhancedSchedule);
      }

      enhancedData['flexibleSchedules'] = enhancedFlexibleSchedules;
    }

    return enhancedData;
  }
// 위경도 조회 메소드
  Future<Map<String, double>?> _getCoordinates(String placeName) async {
    print('Getting coordinates for: $placeName'); // 영어 로그
    print('다음 장소의 좌표 검색 중: $placeName'); // 한글 로그

    // Google Places API 사용
    final encodedPlace = Uri.encodeComponent(placeName);
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=$encodedPlace&inputtype=textquery&fields=geometry&key=$_googleMapsApiKey'
    );

    try {
      final response = await http.get(url);
      print('Google Places API response status: ${response.statusCode}'); // 영어 로그
      print('Google Places API 응답 상태: ${response.statusCode}'); // 한글 로그

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('Google Places API response: $data'); // 영어 로그
        print('Google Places API 응답: $data'); // 한글 로그

        if (data['status'] == 'OK' && data['candidates'] != null && data['candidates'].isNotEmpty) {
          final location = data['candidates'][0]['geometry']['location'];
          final coordinates = {
            'latitude': location['lat'] as double,
            'longitude': location['lng'] as double
          };

          print('Found coordinates: $coordinates'); // 영어 로그
          print('좌표 찾음: $coordinates'); // 한글 로그
          return coordinates;
        } else {
          print('No coordinates found for: $placeName. Status: ${data['status']}'); // 영어 로그
          print('좌표를 찾을 수 없음: $placeName. 상태: ${data['status']}'); // 한글 로그
        }
      } else {
        print('Google Places API request failed: ${response.statusCode}'); // 영어 로그
        print('Google Places API 요청 실패: ${response.statusCode}'); // 한글 로그
      }
    } catch (e) {
      print('Error getting coordinates: $e'); // 영어 로그
      print('좌표 검색 오류: $e'); // 한글 로그
    }

    // 기본값 반환
    return {
      'latitude': 37.5665,
      'longitude': 126.9780
    };
  }

  Future<void> _initializeServices() async {
    print('Initializing services...'); // 영어 로그
    print('서비스 초기화 중...'); // 한글 로그

    // 마이크 권한 요청 (음성 인식용)
    var micStatus = await Permission.microphone.request();
    print('Microphone permission status: $micStatus'); // 영어 로그
    print('마이크 권한 상태: $micStatus'); // 한글 로그

    // 위치 권한 요청
    var locationStatus = await Permission.location.request();
    print('Location permission status: $locationStatus'); // 영어 로그
    print('위치 권한 상태: $locationStatus'); // 한글 로그
  }

// _loadData 메서드 수정 - 선호 카테고리 기반 추천 추가
  // lib/screens/home/home_screen.dart의 _loadData 메서드 수정

Future<void> _loadData() async {
  print('Loading home screen data...'); // 영어 로그
  print('홈 화면 데이터 로드 중...'); // 한글 로그

  setState(() {
    _isLoading = true;
  });

  try {
    // 현재 위치 가져오기
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final currentLocation = await locationProvider.getCurrentLocation();
    print('Current location retrieved: ${currentLocation.latitude}, ${currentLocation.longitude}'); // 영어 로그
    print('현재 위치 정보 획득: ${currentLocation.latitude}, ${currentLocation.longitude}'); // 한글 로그

    // 최근 방문 장소 불러오기 (최대 5개)
    _recentPlaces = await _historyService.getRecentlyVisitedPlaces(limit: 5);
    print('Retrieved ${_recentPlaces.length} recent places'); // 영어 로그
    print('최근 방문 장소 ${_recentPlaces.length}개 로드 완료'); // 한글 로그

    // 카테고리 통계 계산
    final Map<String, int> categoryCounts = {};
    final allHistories = await _historyService.getVisitHistories();
    print('Retrieved ${allHistories.length} visit histories for category analysis'); // 영어 로그
    print('카테고리 분석을 위해 ${allHistories.length}개의 방문 기록 로드 완료'); // 한글 로그

    for (var history in allHistories) {
      categoryCounts[history.category] = (categoryCounts[history.category] ?? 0) + 1;
    }

    // 상위 인기 카테고리 추출 (내림차순 정렬)
    List<MapEntry<String, int>> sortedCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    _popularCategories = sortedCategories.take(5).map((e) => e.key).toList();
    print('Popular categories: $_popularCategories'); // 영어 로그
    print('인기 카테고리 목록: $_popularCategories'); // 한글 로그

    // 사용자 선호 카테고리 가져오기 (새로 추가된 부분)
    final prefProvider = Provider.of<UserPreferenceProvider>(context, listen: false);
    final preferredCategories = await prefProvider.getPreferredCategories();
    print('User preferred categories: ${preferredCategories.join(", ")}'); // 영어 로그
    print('사용자 선호 카테고리: ${preferredCategories.join(", ")}'); // 한글 로그

    // 추천 장소 가져오기
    if (preferredCategories.isNotEmpty) {
      // 선호 카테고리 기반 추천 (우선순위 1)
      print('Using preferred categories for recommendations'); // 영어 로그
      print('선호 카테고리 기반으로 추천 장소 가져오기'); // 한글 로그
      
      _recommendedPlaces = await _recommendationService.getHomeScreenRecommendations(
        currentLocation,
        limit: 4,
        radius: 10000, // 반경 10km
        preferredCategories: preferredCategories,
      );
      
      print('Retrieved ${_recommendedPlaces.length} recommended places based on preferences'); // 영어 로그
      print('선호 카테고리 기반 추천 장소 ${_recommendedPlaces.length}개 로드 완료'); // 한글 로그
    } else if (_recentPlaces.isNotEmpty) {
      // 방문 기록 기반 추천 (우선순위 2)
      _recommendedPlaces = await _recommendationService.getRecommendationsBasedOnHistory(
        currentLocation,
        limit: 4, // 홈 화면에는 적은 개수만 표시
        radius: 10000, // 반경 10km
      );
      print('Retrieved ${_recommendedPlaces.length} recommended places based on history'); // 영어 로그
      print('방문 기록 기반 추천 장소 ${_recommendedPlaces.length}개 로드 완료'); // 한글 로그
    } else {
      // 위치 기반 추천 (우선순위 3 - 방문 기록 및 선호 카테고리가 없는 경우)
      _recommendedPlaces = await _recommendationService.getNearbyPlaces(
        currentLocation,
        limit: 4,
        radius: 5000, // 반경 5km
      );
      print('Retrieved ${_recommendedPlaces.length} recommended places based on location'); // 영어 로그
      print('위치 기반 추천 장소 ${_recommendedPlaces.length}개 로드 완료'); // 한글 로그
    }

  } catch (e) {
    print('Error loading home screen data: $e'); // 영어 로그
    print('홈 화면 데이터 로드 오류: $e'); // 한글 로그
    // 오류 메시지를 표시하지 않고 빈 상태로 표시
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
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildSearchBar(),
                  const SizedBox(height: 32),
                  _buildPreferredCategories(), // 선호 카테고리 섹션 추가
                  _buildRecentPlaces(),
                  _buildRecommendedPlaces(),
                  _buildPopularCategories(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  // 한글 인코딩 수정 함수
  String _correctKoreanEncoding(String text) {
    try {
      // 깨진 한글 인코딩 패턴 탐지
      bool needsCorrection = text.contains('ì') || text.contains('ë') || text.contains('ê');

      if (needsCorrection) {
        // 여러 인코딩 방식 시도
        List<List<int>> bytesOptions = [
          utf8.encode(text),                    // UTF-8
          latin1.encode(text),                  // Latin-1
          latin1.encode(utf8.decode(latin1.encode(text))), // 이중 변환
        ];

        for (var bytes in bytesOptions) {
          try {
            String decoded = utf8.decode(bytes);
            // 한글 확인 (가-힣 범위)
            if (RegExp(r'[가-힣]+').hasMatch(decoded)) {
              return decoded;
            }
          } catch (e) {
            // 디코딩 실패, 다음 옵션 시도
            continue;
          }
        }
      }
    } catch (e) {
      print('Korean encoding correction error: $e');
    }

    return text; // 모든 방법 실패시 원래 텍스트 반환
  }
  
  Widget _buildHeader() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = authProvider.isLoggedIn;
    final isFirstLogin = authProvider.isFirstLogin;
    
    // 첫 로그인 상태에서 화면 진입 시 카테고리 선호도 화면으로 자동 이동
    if (isLoggedIn && isFirstLogin) {
      // 빌드 메서드에서 직접적인 네비게이션은 피해야 함
      // 대신 microtask로 스케줄링
      Future.microtask(() {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CategoryPreferenceScreen(isFirstLogin: true),
          ),
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '여행 도우미',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            // 선호 카테고리 설정 버튼 추가
            if (isLoggedIn)
              IconButton(
                icon: const Icon(Icons.category),
                tooltip: '카테고리 선호도 설정',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CategoryPreferenceScreen(isFirstLogin: false),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '오늘도 좋은 하루 보내세요!',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // _buildPreferredCategories 메서드 추가 - 선호 카테고리 표시
  Widget _buildPreferredCategories() {
    if (_userPreferredCategories.isEmpty) {
      return Container(); // 선호 카테고리가 없으면 표시하지 않음
    }

    // CategoryData 객체 목록으로 변환
    final List<CategoryData> preferredCategoryObjects = [];
    for (String categoryId in _userPreferredCategories) {
      final category = CategoryConstants.getCategoryById(categoryId);
      if (category != null) {
        preferredCategoryObjects.add(category);
      }
    }

    // 목록이 비어있으면 표시하지 않음
    if (preferredCategoryObjects.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '내 관심 카테고리',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: preferredCategoryObjects
              .take(5) // 최대 5개만 표시
              .map((category) => _buildPreferredCategoryChip(category))
              .toList(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // 선호 카테고리 칩 위젯
  Widget _buildPreferredCategoryChip(CategoryData category) {
    return InkWell(
      onTap: () => _navigateToCategoryPlaces(category.name),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black38),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 18,
              color: Colors.black87,
            ),
            const SizedBox(width: 8),
            Text(
              category.name,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: _isListening ? _stopListening : _startListening,
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.blue : Colors.grey[400],
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: _isListening ? '말씀하세요...' : '목적지나 경로를 검색하세요',
                    hintStyle: TextStyle(
                      color: _isListening ? Colors.blue : Colors.grey[400],
                      fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('검색: $value')),
                      );
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.search, color: Colors.grey[400]),
                onPressed: () {
                  if (_searchController.text.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('검색: ${_searchController.text}')),
                    );
                  }
                },
              ),
            ],
          ),
          // 텍스트로 일정 추가 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 20),
                label: const Text(
                  '텍스트로 일정 추가',
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
                onPressed: () {
                  if (_searchController.text.isNotEmpty) {
                    _processScheduleVoiceInput(_searchController.text);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('일정 내용을 입력해주세요')),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

// 오버플로우 오류 수정을 위한 SizedBox 높이 조정
// _buildRecentPlaces 메서드에서 수정해야 할 부분
Widget _buildRecentPlaces() {
  if (_recentPlaces.isEmpty) {
    return Container(); // 최근 방문 장소가 없으면 표시하지 않음
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '최근 방문 장소',
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
            child: const Text(
              '더보기',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      // 높이를 늘려서 오버플로우 오류 해결
      SizedBox(
        height: 224, // 기존 200에서 224로 늘림
        child: PageView.builder(
          controller: PageController(viewportFraction: 0.85),
          onPageChanged: (index) {
            setState(() {
              _currentCarouselIndex = index % _recentPlaces.length;
            });
          },
          itemBuilder: (context, index) {
            final realIndex = index % _recentPlaces.length;
            final place = _recentPlaces[realIndex];
            return _buildPlaceCard(place);
          },
          itemCount: _recentPlaces.length * 100, // 무한 스크롤 효과
        ),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _recentPlaces.length,
              (index) => Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentCarouselIndex == index
                  ? Colors.black
                  : Colors.grey[300],
            ),
          ),
        ),
      ),
      const SizedBox(height: 32),
    ],
  );
}

Widget _buildPlaceCard(VisitHistory place) {
  // 카테고리별 색상 지정
  final Map<String, Color> categoryColors = {
    '식당': Colors.redAccent.shade100,
    '카페': Colors.brown.shade200,
    '쇼핑': Colors.blueAccent.shade100,
    '관광': Colors.green.shade200,
    '문화': Colors.purpleAccent.shade100,
    '병원': Colors.teal.shade200,
    '편의점': Colors.orange.shade200,
    '아이스크림 가게': Colors.pink.shade200,
  };

  // 장소 이름의 첫 글자 가져오기
  final String initial = place.placeName.isNotEmpty 
      ? place.placeName.substring(0, 1).toUpperCase() 
      : '?';
      
  // 카테고리에 해당하는 색상 가져오기 (없으면 랜덤 색상)
  final color = categoryColors[place.category] ?? 
      Color((Random().nextDouble() * 0xFFFFFF).toInt() | 0xFF000000).withAlpha(153); // 0.6 * 255 = 153

   return Container(
    margin: const EdgeInsets.only(right: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(13),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: InkWell(
      onTap: () {
        // 장소 상세 정보 또는 내비게이션 화면으로 이동
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withAlpha(179),
                  color,
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 배경과 대비되는 텍스트 아바타
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(204),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: color.withAlpha(230),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 카테고리 아이콘
                  Icon(
                    _getCategoryIcon(place.category),
                    size: 24,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          // 텍스트 부분 높이 제한 및 최적화
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // 최소 크기로 설정
                children: [
                  Text(
                    place.placeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.category, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          place.category,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatDate(place.visitDate),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildRecommendedPlaces() {
    if (_recommendedPlaces.isEmpty) {
      return Container(); // 추천 장소가 없으면 표시하지 않음
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '추천 장소',
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
                    builder: (context) => const HistoryBasedRecommendationsScreen(),
                  ),
                );
              },
              child: const Text(
                '더보기',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
          ),
          itemCount: _recommendedPlaces.length,
          itemBuilder: (context, index) {
            final place = _recommendedPlaces[index];
            return _buildRecommendedPlaceCard(place);
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

Widget _buildRecommendedPlaceCard(RecommendedPlace place) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(13),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: InkWell(
      onTap: () {
        // 장소 상세 정보 또는 내비게이션 화면으로 이동
        _navigateToPlaceDetails(place);
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: place.photoUrl.isNotEmpty 
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        place.photoUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        // 이미지 로딩 중에 표시할 위젯
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / 
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        // 이미지 로딩 오류 시 표시할 위젯
                        errorBuilder: (context, error, stackTrace) {
                          print('이미지 로딩 오류: $error');
                          return Center(
                            child: Icon(
                              _getCategoryIcon(place.category),
                              size: 32,
                              color: Colors.black54,
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Icon(
                        _getCategoryIcon(place.category),
                        size: 32,
                        color: Colors.black54,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  place.category,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildPopularCategories() {
    if (_popularCategories.isEmpty) {
      return Container(); // 인기 카테고리가 없으면 표시하지 않음
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '자주 방문하는 카테고리',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _popularCategories.map((category) =>
              _buildCategoryChip(category)
          ).toList(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCategoryChip(String category) {
    return InkWell(
      onTap: () => _navigateToCategoryPlaces(category),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getCategoryIcon(category),
              size: 18,
              color: Colors.black87,
            ),
            const SizedBox(width: 8),
            Text(
              category,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

// _navigateToPlaceDetails 메서드도 업데이트하여 이미지 표시
void _navigateToPlaceDetails(RecommendedPlace place) async {
  // 기존 코드...
  
  // 모달 바텀 시트 부분에 이미지 표시 추가
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지가 있으면 표시, 없으면 아이콘 표시
            if (place.photoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  place.photoUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      height: 180,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / 
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          _getCategoryIcon(place.category),
                          size: 48,
                          color: Colors.black45,
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    _getCategoryIcon(place.category),
                    size: 48,
                    color: Colors.black45,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(place.category),
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        place.category,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              place.address,
              style: const TextStyle(fontSize: 14),
            ),
            if (place.reasonForRecommendation.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        place.reasonForRecommendation,
                        style: const TextStyle(
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // 방문 기록에 추가 (향후 구현)
                    },
                    icon: const Icon(Icons.bookmark_border),
                    label: const Text('저장'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // 내비게이션 화면으로 이동 (향후 구현)
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('길찾기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

  void _navigateToCategoryPlaces(String category) async {
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final currentLocation = await locationProvider.getCurrentLocation();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaceRecommendationsScreen(
              currentLocation: currentLocation,
              title: '$category 추천',
              category: category,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추천 화면을 열 수 없습니다: $e')),
        );
      }
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

  @override
  void dispose() {
    _speechToText.stop();
    super.dispose();
  }
}
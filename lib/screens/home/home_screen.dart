// lib/screens/home/home_screen.dart
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
import 'package:google_speech/google_speech.dart' as google_speech;
import 'package:path_provider/path_provider.dart';

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

  // Google Speech API 관련 변수 추가
  bool _isRecording = false;
  StreamController<List<int>>? _audioStreamController;
  StreamSubscription? _recognitionSubscription;

  // GPT API 키 (실제 사용 시 보안 처리 필요)
  String get _openAIKey => dotenv.dotenv.env['OPENAI_API_KEY'] ?? '';
  String get _googleMapsApiKey => dotenv.dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // 음성 인식 결과를 저장할 변수
  String _lastRecognizedText = "";

  bool _isListening = false;
  bool _isLoading = true;
  int _currentCarouselIndex = 0;

  // 데이터 상태
  List<VisitHistory> _recentPlaces = [];
  List<RecommendedPlace> _recommendedPlaces = [];
  List<String> _popularCategories = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadData();
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
      print('Extracting schedule data using GPT...'); // 영어 로그
      print('GPT를 사용하여 일정 데이터 추출 중...'); // 한글 로그

      // GPT API를 통해 일정 데이터 추출
      final scheduleData = await _extractScheduleDataFromGPT(voiceText);

      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();

      if (scheduleData != null) {
        print('Schedule data extracted successfully: $scheduleData'); // 영어 로그
        print('일정 데이터 추출 성공: $scheduleData'); // 한글 로그

        // Google Places API로 위치 정보 보강
        final enhancedData = await _enhanceLocationData(scheduleData);
        print('Enhanced data with coordinates: $enhancedData'); // 영어 로그
        print('좌표 정보가 보강된 데이터: $enhancedData'); // 한글 로그

        // scheduleProvider를 이용해 최적화 요청
        final provider = Provider.of<ScheduleProvider>(context, listen: false);

        try {
          print('Optimizing schedules...'); // 영어 로그
          print('일정 최적화 중...'); // 한글 로그

          // enhancedData에서 fixedSchedules와 flexibleSchedules를 추출
          List<Map<String, dynamic>> schedulesToOptimize = [];

          // 고정 일정 추가
          if (enhancedData.containsKey('fixedSchedules') &&
              enhancedData['fixedSchedules'] is List) {
            List<dynamic> fixedSchedules = enhancedData['fixedSchedules'];
            schedulesToOptimize.addAll(
                fixedSchedules.map((schedule) => Map<String, dynamic>.from(schedule)).toList()
            );
            print('Added ${fixedSchedules.length} fixed schedules'); // 영어 로그
            print('${fixedSchedules.length}개의 고정 일정 추가됨'); // 한글 로그
          }

          // 유연한 일정 추가
          if (enhancedData.containsKey('flexibleSchedules') &&
              enhancedData['flexibleSchedules'] is List) {
            List<dynamic> flexibleSchedules = enhancedData['flexibleSchedules'];
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

  // 오디오 녹음 및 인식 시작
  void _startRecording(google_speech.SpeechToText speechToText, google_speech.RecognitionConfig config) {
    _isRecording = true;
    _audioStreamController = StreamController<List<int>>();

    // 오디오 스트림 (실제 구현에서는 마이크 데이터로 교체 필요)
    Future.delayed(Duration.zero, () async {
      try {
        // 예시 데이터 - 실제로는 마이크 데이터를 스트리밍해야 함
        while (_isRecording) {
          // 더미 오디오 데이터 (실제로는 마이크 데이터 필요)
          List<int> dummyData = List.generate(1600, (index) => 0);
          if (_audioStreamController?.isClosed == false) {
            _audioStreamController?.add(dummyData);
          }
          await Future.delayed(Duration(milliseconds: 100));
        }
      } catch (e) {
        print('Audio recording error: $e');
      } finally {
        _audioStreamController?.close();
      }
    });

    // Google Speech API로 인식 시작
    final responseStream = speechToText.streamingRecognize(
      google_speech.StreamingRecognitionConfig(
        config: config,
        interimResults: true,
      ),
      _audioStreamController!.stream,
    );

    // 결과 처리
    _recognitionSubscription = responseStream.listen((response) {
      // 간단한 로그
      print('Google Speech response: $response');

      final results = response.results;
      if (results.isNotEmpty) {
        // 인식 결과 텍스트 추출
        final result = results.first;
        final alternatives = result.alternatives;
        if (alternatives.isNotEmpty) {
          final transcript = alternatives.first.transcript;

          print('Recognition result: $transcript'); // 영어 로그
          print('인식 결과: $transcript'); // 한글 로그

          // 텍스트 필드에 결과 표시
          setState(() {
            _searchController.text = transcript;
            _lastRecognizedText = transcript;
          });

          // 최종 결과인 경우
          if (result.isFinal) {
            print('Final result received: $transcript'); // 영어 로그
            print('최종 결과 수신됨: $transcript'); // 한글 로그

            setState(() => _isListening = false);
            _stopRecording();
          }
        }
      }
    }, onDone: () {
      setState(() => _isListening = false);
      _stopRecording();
      print('Speech recognition completed'); // 영어 로그
      print('음성 인식 완료'); // 한글 로그
    }, onError: (error) {
      setState(() => _isListening = false);
      _stopRecording();
      print('Speech recognition error: $error'); // 영어 로그
      print('음성 인식 오류: $error'); // 한글 로그

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('음성 인식 오류: $error')),
      );
    }) as StreamSubscription;
  }


  // 녹음 중지
  void _stopRecording() {
    _isRecording = false;
    _audioStreamController?.close();
    _recognitionSubscription?.cancel();
  }
  // Google Speech API를 사용한 음성 인식 시작
  Future<void> _startListening() async {
    print('Starting voice recognition...'); // 영어 로그
    print('음성 인식 시작...'); // 한글 로그

    if (_isListening) {
      // 이미 듣고 있으면 중지
      setState(() => _isListening = false);
      _stopRecording();
      print('Speech recognition stopped'); // 영어 로그
      print('음성 인식 중지됨'); // 한글 로그
      return;
    }

    // 마이크 권한 요청
    var micStatus = await Permission.microphone.request();
    print('Current microphone permission status: $micStatus'); // 권한 상태 로그

    if (micStatus != PermissionStatus.granted) {
      print('Microphone permission denied'); // 영어 로그
      print('마이크 권한 거부됨'); // 한글 로그
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('마이크 권한이 필요합니다')),
      );
      return;
    }

    try {
      setState(() => _isListening = true);
      print('Listening state set to true'); // 상태 변경 로그

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

      try {
        print('Attempting to load Google service account...'); // 서비스 계정 로드 시작 로그

        // Google Cloud 서비스 계정 JSON 로드
        final serviceAccount = await rootBundle.loadString(
            'assets/adroit-booth-435400-b4-85e08d09b5d4.json');

        print('Service account loaded successfully, length: ${serviceAccount.length}'); // 로드 성공 로그

        // Speech 클라이언트 생성
        print('Creating Speech-to-Text client...'); // 클라이언트 생성 로그
        final speechToText = google_speech.SpeechToText.viaServiceAccount(
            google_speech.ServiceAccount.fromString(serviceAccount));

        print('Speech-to-Text client created successfully'); // 생성 성공 로그

        // 인식 구성 설정
        print('Configuring recognition settings for Korean language...'); // 설정 로그
        final config = google_speech.RecognitionConfig(
          encoding: google_speech.AudioEncoding.LINEAR16,
          model: google_speech.RecognitionModel.command_and_search,
          enableAutomaticPunctuation: true,
          sampleRateHertz: 16000,
          languageCode: 'ko-KR', // 한국어 설정
        );

        print('Recognition config created, starting audio stream...'); // 오디오 스트림 시작 로그

        // 오디오 스트림 및 인식 시작
        _startRecording(speechToText, config);

      } catch (e) {
        print('Error loading service account: $e'); // 영어 로그
        print('서비스 계정 로드 오류 상세: ${e.toString()}'); // 상세 오류 로그

        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('음성 인식을 시작할 수 없습니다: $e')),
        );
      }
    } catch (e) {
      setState(() => _isListening = false);
      print('Error starting speech recognition: $e'); // 영어 로그
      print('음성 인식 시작 오류 상세: ${e.toString()}'); // 상세 오류 로그

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('음성 인식을 시작할 수 없습니다: $e')),
      );
    }
  }
  Future<void> _initializeServices() async {
    print('Initializing services...'); // 영어 로그
    print('서비스 초기화 중...'); // 한글 로그

    // 마이크 권한 요청 (음성 인식용)
    var micStatus = await Permission.microphone.request();
    print('Microphone permission status: $micStatus'); // 영어 로그
    print('마이크 권한 상태: $micStatus'); // 한글 로그

    bool speechInitialized = await _speechToText.initialize(
      onStatus: (status) {
        print('Speech recognition status: $status'); // 영어 로그
        print('음성 인식 상태: $status'); // 한글 로그
      },
      onError: (errorNotification) {
        print('Speech recognition error: $errorNotification'); // 영어 로그
        print('음성 인식 오류: $errorNotification'); // 한글 로그
      },
    );

    print('Speech to text initialized: $speechInitialized'); // 영어 로그
    print('음성 인식 초기화 상태: $speechInitialized'); // 한글 로그

    // 위치 권한 요청
    var locationStatus = await Permission.location.request();
    print('Location permission status: $locationStatus'); // 영어 로그
    print('위치 권한 상태: $locationStatus'); // 한글 로그
  }

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

      // 추천 장소 가져오기
      if (_recentPlaces.isNotEmpty) {
        // 방문 기록 기반 추천
        _recommendedPlaces = await _recommendationService.getRecommendationsBasedOnHistory(
          currentLocation,
          limit: 4, // 홈 화면에는 적은 개수만 표시
          radius: 10000, // 반경 10km
        );
        print('Retrieved ${_recommendedPlaces.length} recommended places based on history'); // 영어 로그
        print('방문 기록 기반 추천 장소 ${_recommendedPlaces.length}개 로드 완료'); // 한글 로그
      } else {
        // 위치 기반 추천 (방문 기록이 없는 경우)
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
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildRecentPlaces(),
                _buildRecommendedPlaces(),
                _buildPopularCategories(),
              ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '여행 도우미',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '오늘도 좋은 하루 보내세요!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _startListening,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _isListening ? '말씀하세요...' : '목적지나 경로를 검색하세요',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: _isListening ? Colors.blue : Colors.grey,
                      fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
                    ),
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
                icon: const Icon(Icons.search),
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
            padding: const EdgeInsets.only(top: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.calendar_today, size: 16),
                label: Text('텍스트로 일정 추가'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () {
                  if (_searchController.text.isNotEmpty) {
                    _processScheduleVoiceInput(_searchController.text);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('일정 내용을 입력해주세요')),
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

  Widget _buildRecentPlaces() {
    if (_recentPlaces.isEmpty) {
      return Container(); // 최근 방문 장소가 없으면 표시하지 않음
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
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
                child: const Text('더보기'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.9),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _recentPlaces.length,
                (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentCarouselIndex == index
                    ? Theme.of(context).primaryColor
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceCard(VisitHistory place) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16, left: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // 장소 상세 정보 또는 내비게이션 화면으로 이동
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: Icon(
                  _getCategoryIcon(place.category),
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      Icon(Icons.category, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          place.category,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(place.visitDate),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
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

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
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
                child: const Text('더보기'),
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
              childAspectRatio: 1.5,
            ),
            itemCount: _recommendedPlaces.length,
            itemBuilder: (context, index) {
              final place = _recommendedPlaces[index];
              return _buildRecommendedPlaceCard(place);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedPlaceCard(RecommendedPlace place) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // 장소 상세 정보 또는 내비게이션 화면으로 이동
          _navigateToPlaceDetails(place);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Center(
                  child: Icon(
                    _getCategoryIcon(place.category),
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
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

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
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
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return InkWell(
      onTap: () => _navigateToCategoryPlaces(category),
      borderRadius: BorderRadius.circular(20),
      child: Chip(
        avatar: CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(
            _getCategoryIcon(category),
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
        ),
        label: Text(category),
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      ),
    );
  }

  void _navigateToPlaceDetails(RecommendedPlace place) async {
    // 장소 상세 정보 또는 내비게이션 화면으로 이동
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final currentLocation = await locationProvider.getCurrentLocation();

      if (mounted) {
        // 간단한 다이얼로그 표시
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Icon(
                          _getCategoryIcon(place.category),
                          color: Theme.of(context).primaryColor,
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
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
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          // 방문 기록에 추가 (향후 구현)
                        },
                        icon: const Icon(Icons.bookmark_border),
                        label: const Text('저장'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          // 내비게이션 화면으로 이동 (향후 구현)
                        },
                        icon: const Icon(Icons.directions),
                        label: const Text('길찾기'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      print('위치 가져오기 실패: $e');
    }
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

// Google Speech API를 사용한 음성 인식 시작
    Future<void> _startListening() async {
      print('Starting voice recognition...'); // 영어 로그
      print('음성 인식 시작...'); // 한글 로그

      if (_isListening) {
        // 이미 듣고 있으면 중지
        setState(() => _isListening = false);
        _stopRecording();
        print('Speech recognition stopped'); // 영어 로그
        print('음성 인식 중지됨'); // 한글 로그
        return;
      }

      // 마이크 권한 요청
      var micStatus = await Permission.microphone.request();
      if (micStatus != PermissionStatus.granted) {
        print('Microphone permission denied'); // 영어 로그
        print('마이크 권한 거부됨'); // 한글 로그
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('마이크 권한이 필요합니다')),
        );
        return;
      }

      try {
        setState(() => _isListening = true);

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

        try {
          // Google Cloud 서비스 계정 JSON 로드
          final serviceAccount = await rootBundle.loadString(
              'assets/adroit-booth-435400-b4-85e08d09b5d4.json');

          // Speech 클라이언트 생성
          final speechToText = google_speech.SpeechToText.viaServiceAccount(
              google_speech.ServiceAccount.fromString(serviceAccount));

          // 인식 구성 설정
          final config = google_speech.RecognitionConfig(
            encoding: google_speech.AudioEncoding.LINEAR16,
            model: google_speech.RecognitionModel.command_and_search,
            enableAutomaticPunctuation: true,
            sampleRateHertz: 16000,
            languageCode: 'ko-KR', // 한국어 설정
          );

          // 오디오 스트림 및 인식 시작
          _startRecording(speechToText, config);

        } catch (e) {
          print('Error loading service account: $e'); // 영어 로그
          print('서비스 계정 로드 오류: $e'); // 한글 로그

          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('음성 인식을 시작할 수 없습니다: $e')),
          );
        }
      } catch (e) {
        setState(() => _isListening = false);
        print('Error starting speech recognition: $e'); // 영어 로그
        print('음성 인식 시작 오류: $e'); // 한글 로그

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('음성 인식을 시작할 수 없습니다: $e')),
        );
      }
    }





    @override
    void dispose() {
      _recognitionSubscription?.cancel();
      _stopRecording();
      super.dispose();
    }
  }}
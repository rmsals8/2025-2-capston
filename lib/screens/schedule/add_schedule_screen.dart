//lib/screens/schedule/add_schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../place/place_search_screen.dart';
import 'optimized_schedule_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
class AddScheduleScreen extends StatefulWidget {
  const AddScheduleScreen({Key? key}) : super(key: key);

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'FIXED';
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _startTime;
  int _duration = 60;
  int _priority = 1;
  double _latitude = 37.5665;
  double _longitude = 126.9780;
  final List<Map<String, dynamic>> _schedules = [];

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return ChangeNotifierProvider(
      create: (_) => ScheduleProvider(authProvider: authProvider),
      child: Builder(
        builder: (context) => Scaffold(
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
              '새 일정 추가',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // 일정 유형 선택
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '일정 유형',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      DropdownButton<String>(
                        value: _type,
                        dropdownColor: Colors.white,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'FIXED', child: Text('고정 일정')),
                          DropdownMenuItem(value: 'FLEXIBLE', child: Text('유연한 일정')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _type = value;
                              if (value == 'FLEXIBLE') {
                                _locationController.clear();
                                _startTime = null;
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 장소명 입력
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextFormField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: _type == 'FLEXIBLE' ? '방문할 곳 (예: 마트, 서점)' : '장소명',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    validator: (value) =>
                    value?.isEmpty ?? true ? '장소명을 입력하세요' : null,
                  ),
                ),
                const SizedBox(height: 16),

                // 위치 상세 입력
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextFormField(
                    controller: _locationController,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: _type == 'FIXED' ? '위치 상세 (필수)' : '위치 상세 (선택사항)',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      hintText: _type == 'FIXED' ? '위치를 검색하세요' : '원하는 특정 위치가 있다면 검색하세요',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.black),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PlaceSearchScreen(),
                            ),
                          );
                          if (result != null) {
                            setState(() {
                              _nameController.text = result['name'];
                              _locationController.text = result['address'];
                              _latitude = result['latitude'];
                              _longitude = result['longitude'];
                              print('장소 선택: ${result['name']}, 좌표: (${result['latitude']}, ${result['longitude']})');
                            });
                          }
                        },
                      ),
                      helperText: _type == 'FIXED' ? '정확한 위치를 입력해주세요' : '선택사항입니다',
                      helperStyle: TextStyle(
                        color: _type == 'FIXED' ? Colors.red : Colors.grey[600],
                      ),
                    ),
                    readOnly: true,
                    validator: (value) =>
                    _type == 'FIXED' && (value?.isEmpty ?? true) ? '위치를 입력하세요' : null,
                  ),
                ),

                // 고정 일정일 때 시작 시간
                if (_type == 'FIXED') ...[
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: _selectDateTime,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '시작 시간',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _startTime == null ? '선택하세요' : _formatDateTime(_startTime!),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _startTime == null ? Colors.grey[400] : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.access_time, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ],

                // 유연한 일정일 때 우선순위
                if (_type == 'FLEXIBLE') ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '우선순위',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                        DropdownButton<int>(
                          value: _priority,
                          dropdownColor: Colors.white,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          items: [1,2,3,4,5].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _priority = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                // 예상 소요시간
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '예상 소요시간',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      DropdownButton<int>(
                        value: _duration,
                        dropdownColor: Colors.white,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        items: [15, 30, 45, 60, 90, 120, 150, 180, 240, 300, 360].map((int value) {
                          String displayText;
                          if (value < 60) {
                            displayText = '$value분';
                          } else {
                            int hours = value ~/ 60;
                            int minutes = value % 60;
                            if (minutes == 0) {
                              displayText = '$hours시간';
                            } else {
                              displayText = '$hours시간 $minutes분';
                            }
                          }
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text(displayText),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _duration = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // 일정 추가 버튼
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _addSchedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '일정 추가하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // 추가된 일정 목록
                if (_schedules.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const Text(
                    '추가된 일정 목록',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _schedules.length,
                    itemBuilder: (context, index) {
                      final schedule = _schedules[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: Text(
                            schedule['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            schedule['type'] == 'FLEXIBLE'
                                ? '유연한 일정 - ${schedule['location'] ?? "위치 미정"}'
                                : '고정 일정 - ${_formatFullDateTime(DateTime.parse(schedule['startTime']))} ~ ${_formatEndTime(DateTime.parse(schedule['endTime']))} • ${schedule['location']}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _schedules.removeAt(index);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],

                // 전체 일정 저장 버튼
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submitSchedules,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '전체 일정 저장',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.black,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _startTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _addSchedule() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_type == 'FIXED' && _startTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('시작 시간을 선택하세요')),
        );
        return;
      }

      // 좌표 정보가 들어갔는지 확인
      print('장소 추가 시 좌표: lat=${_latitude}, lng=${_longitude}');

      Map<String, dynamic> scheduleData = {
        'id': DateTime.now().toString(),
        'name': _nameController.text,
        'type': _type,
        'duration': _duration,
        'priority': _priority,
        // 모든 일정 유형에 위치 정보 추가 (중요!)
        'location': _locationController.text,
        'latitude': _latitude,
        'longitude': _longitude,
      };

      // 고정 일정일 경우에만 시간 정보 추가
      if (_type == 'FIXED') {
        final startTime = _startTime!;
        final endTime = startTime.add(Duration(minutes: _duration));

        scheduleData.addAll({
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
        });
      }

      setState(() {
        _schedules.add(scheduleData);
        _nameController.clear();
        _locationController.clear();
        _startTime = null;
        _duration = 60;
        _priority = 1;
        _type = 'FIXED';
        // 좌표 초기화 추가
        _latitude = 0.0;
        _longitude = 0.0;
      });
    }
  }

  Future<Map<String, dynamic>?> _expandScheduleOptions(List<Map<String, dynamic>> schedules) async {
    try {
      final url = Uri.parse('https://port-0-capston-fastapi-m8dskoec57d8f7b3.sel4.cloudtype.app/expand-schedule-options');
      // final url = Uri.parse('http://192.168.11.1:8083/expand-schedule-options');
      final requestBody = {"schedules": schedules};

      print('🔄 FastAPI 일정 확장 요청:');
      print('📋 일정 수: ${schedules.length}개');
      for (int i = 0; i < schedules.length; i++) {
        print('   ${i+1}. ${schedules[i]['name']} (${schedules[i]['startTime']})');
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: utf8.encode(json.encode(requestBody)),
      );

      print('🌐 FastAPI 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonString = utf8.decode(response.bodyBytes);
        final responseData = json.decode(jsonString);

        print('✅ FastAPI 확장 성공:');
        if (responseData['options'] != null) {
          print('   📊 생성된 옵션: ${responseData['options'].length}개');

          // 각 옵션의 식사 일정 로깅
          for (int i = 0; i < responseData['options'].length; i++) {
            final option = responseData['options'][i];
            final schedules = option['fixedSchedules'] ?? [];

            print('   옵션 ${i+1}:');
            for (int j = 0; j < schedules.length; j++) {
              final schedule = schedules[j];
              print('     ${j+1}. ${schedule['name']}');
            }
          }
        }

        return responseData;
      } else {
        print('❌ FastAPI 오류: ${response.statusCode}');
        print('   응답: ${response.body}');
        return null;
      }
    } catch (e) {
      print('💥 FastAPI 호출 예외: $e');
      return null;
    }
  }

// _submitSchedules 메서드 완전 교체
  Future<void> _submitSchedules() async {
    if (_schedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 한 개의 일정을 추가해주세요')),
      );
      return;
    }

    try {
      final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);

      // Step 1: 좌표 형식 수정
      List<Map<String, dynamic>> formattedSchedules = _schedules.map((schedule) {
        Map<String, dynamic> copy = Map<String, dynamic>.from(schedule);

        if (copy['latitude'] != null && copy['latitude'].toString().contains('E')) {
          double lat = copy['latitude'];
          double lng = copy['longitude'];

          if (lat > 180) {
            copy['latitude'] = lat / 10000000;
          }
          if (lng > 180) {
            copy['longitude'] = lng / 10000000;
          }
        }

        return copy;
      }).toList();

      print('🔄 일정 제출 시작: ${formattedSchedules.length}개 일정');

      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('다양한 옵션을 생성하고 있습니다...'),
            ],
          ),
        ),
      );

      // Step 2: FastAPI로 일정 확장 (단일 → 다중 옵션)
      print('📡 Step 2: FastAPI 일정 확장');
      final multipleOptionsData = await _expandScheduleOptions(formattedSchedules);

      if (multipleOptionsData == null || !multipleOptionsData.containsKey('options')) {
        throw Exception('일정 확장에 실패했습니다. FastAPI 서버를 확인해주세요.');
      }

      // Step 3: FastAPI 응답을 Spring Boot 형태로 변환
      print('🔄 Step 3: Spring Boot 형식으로 변환');
      List<List<Map<String, dynamic>>> allScheduleOptions = [];

      List<dynamic> options = multipleOptionsData['options'];

      if (options.isEmpty) {
        throw Exception('생성된 옵션이 없습니다.');
      }

      for (var option in options) {
        if (option is Map<String, dynamic>) {
          List<Map<String, dynamic>> singleOptionSchedules = [];

          // 고정 일정 추가
          if (option.containsKey('fixedSchedules') && option['fixedSchedules'] is List) {
            List<dynamic> fixedSchedules = option['fixedSchedules'];
            singleOptionSchedules.addAll(
                fixedSchedules.map((schedule) => Map<String, dynamic>.from(schedule)).toList()
            );
          }

          // 유연한 일정 추가
          if (option.containsKey('flexibleSchedules') && option['flexibleSchedules'] is List) {
            List<dynamic> flexibleSchedules = option['flexibleSchedules'];
            singleOptionSchedules.addAll(
                flexibleSchedules.map((schedule) => Map<String, dynamic>.from(schedule)).toList()
            );
          }

          if (singleOptionSchedules.isNotEmpty) {
            allScheduleOptions.add(singleOptionSchedules);
          }
        }
      }

      if (allScheduleOptions.isEmpty) {
        throw Exception('변환된 일정 옵션이 없습니다.');
      }

      print('✅ 변환 완료: ${allScheduleOptions.length}개 옵션 → Spring Boot 전송');

      // Step 4: Spring Boot 다중 최적화 호출
      print('🚀 Step 4: Spring Boot 최적화');
      final multipleResponse = await scheduleProvider.optimizeMultipleScheduleOptions(allScheduleOptions);

      // 로딩 다이얼로그 닫기
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      // Step 5: 결과 화면으로 이동
      if (multipleResponse.optimizedOptions.isNotEmpty) {
        print('🎉 최적화 완료: ${multipleResponse.optimizedOptions.length}개 최적화된 옵션');

        // 첫 번째 옵션을 OptimizedScheduleScreen으로 전송
        final firstOption = multipleResponse.optimizedOptions.first;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OptimizedScheduleScreen(
              optimizedData: firstOption.result,
            ),
          ),
        );

        // 성공 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${allScheduleOptions.length}개의 다양한 옵션으로 최적화되었습니다!'),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('최적화 결과가 없습니다.');
      }

    } catch (e) {
      // 로딩 다이얼로그가 열려있으면 닫기
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      print('❌ 전체 프로세스 오류: $e');

      // 구체적인 에러 메시지 생성
      String errorMessage = '일정 처리 중 오류가 발생했습니다';

      String errorString = e.toString().toLowerCase();

      if (errorString.contains('fastapi') || errorString.contains('localhost:8083')) {
        errorMessage = 'FastAPI 서버 연결에 실패했습니다. 서버가 실행 중인지 확인해주세요.';
      } else if (errorString.contains('확장')) {
        errorMessage = '다양한 옵션 생성에 실패했습니다. 입력된 일정을 확인해주세요.';
      } else if (errorString.contains('optimize')) {
        errorMessage = '일정 최적화에 실패했습니다. 서버 상태를 확인해주세요.';
      } else if (errorString.contains('network') || errorString.contains('connection')) {
        errorMessage = '네트워크 연결을 확인해주세요';
      } else if (errorString.contains('timeout')) {
        errorMessage = '서버 응답 시간이 초과되었습니다. 잠시 후 다시 시도해주세요';
      }

      // 에러 다이얼로그 표시
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('일정 처리 오류'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(errorMessage),
              const SizedBox(height: 8),
              Text(
                '상세 오류: ${e.toString()}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
            if (!errorString.contains('network'))
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _submitSchedules(); // 재시도
                },
                child: const Text('재시도'),
              ),
          ],
        ),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatFullDateTime(DateTime dateTime) {
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일 ${dateTime.hour}시 ${dateTime.minute}분';
  }

  String _formatEndTime(DateTime dateTime) {
    return '${dateTime.hour}시 ${dateTime.minute}분';
  }
}
//lib/screens/schedule/add_schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../place/place_search_screen.dart';
import 'optimized_schedule_screen.dart';

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

  Future<void> _submitSchedules() async {
    if (_schedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 한 개의 일정을 추가해주세요')),
      );
      return;
    }

    try {
      final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);

      // 좌표 형식을 수정한 복사본 생성
      List<Map<String, dynamic>> formattedSchedules = _schedules.map((schedule) {
        Map<String, dynamic> copy = Map<String, dynamic>.from(schedule);

        // 좌표가 잘못된 형식인지 확인 (과학적 표기법이나 너무 큰 숫자)
        if (copy['latitude'] != null && copy['latitude'].toString().contains('E')) {
          double lat = copy['latitude'];
          double lng = copy['longitude'];

          // 큰 숫자를 올바른 형식으로 변환 (예: 355437482.0 -> 35.5437482)
          if (lat > 180) {
            copy['latitude'] = lat / 10000000;
          }
          if (lng > 180) {
            copy['longitude'] = lng / 10000000;
          }
        }

        return copy;
      }).toList();

      print('변환된 좌표로 제출: $formattedSchedules');
      final optimizedData = await scheduleProvider.optimizeSchedules(formattedSchedules);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OptimizedScheduleScreen(
            optimizedData: optimizedData,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // 에러 처리
      String errorMessage = '일정 최적화 중 오류가 발생했습니다';
      if (e.toString().contains('최소 하나의 고정 일정이 필요합니다')) {
        errorMessage = '최소 하나의 고정 일정이 필요합니다';
      } else if (e.toString().contains('서버 응답 오류')) {
        errorMessage = '서버와의 통신 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '확인',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
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
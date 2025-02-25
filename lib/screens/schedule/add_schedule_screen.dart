//lib/screens/schedule/add_schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    return ChangeNotifierProvider(
      create: (_) => ScheduleProvider(),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('새 일정 추가'),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  title: const Text('일정 유형'),
                  trailing: DropdownButton<String>(
                    value: _type,
                    items: const [
                      DropdownMenuItem(value: 'FIXED', child: Text('고정 일정')),
                      DropdownMenuItem(value: 'FLEXIBLE', child: Text('유연한 일정')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _type = value;
                          // 유연한 일정으로 변경 시 위치 관련 필드 초기화
                          if (value == 'FLEXIBLE') {
                            _locationController.clear();
                            _startTime = null;
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: _type == 'FLEXIBLE' ? '방문할 곳 (예: 마트, 서점)' : '장소명',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) =>
                  value?.isEmpty ?? true ? '장소명을 입력하세요' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: _type == 'FIXED' ? '위치 상세 (필수)' : '위치 상세 (선택사항)',
                    hintText: _type == 'FIXED' ? '위치를 검색하세요' : '원하는 특정 위치가 있다면 검색하세요',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
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
                          });
                        }
                      },
                    ),
                    helperText: _type == 'FIXED' ? '정확한 위치를 입력해주세요' : '선택사항입니다',
                    helperStyle: TextStyle(
                      color: _type == 'FIXED' ? Colors.red : Colors.grey,
                    ),
                  ),
                  readOnly: true,
                  validator: (value) =>
                  _type == 'FIXED' && (value?.isEmpty ?? true) ? '위치를 입력하세요' : null,
                ),
                const SizedBox(height: 16),
                // 고정 일정일 때만 위치 입력 표시
                if (_type == 'FIXED') ...[
                  const SizedBox(height: 16),

                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('시작 시간'),
                    subtitle: Text(_startTime == null
                        ? '선택하세요'
                        : _formatDateTime(_startTime!)),
                    trailing: const Icon(Icons.access_time),
                    onTap: _selectDateTime,
                  ),
                ],
                if (_type == 'FLEXIBLE') ...[
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('우선순위'),
                    trailing: DropdownButton<int>(
                      value: _priority,
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
                  ),
                ],
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('예상 소요시간'),
                  trailing: DropdownButton<int>(
                    value: _duration,
                    items: [30, 60, 90, 120, 180].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('${value}분'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _duration = value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _addSchedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[100],
                    foregroundColor: Colors.black87,
                  ),
                  child: const Text('일정 추가하기'),
                ),
                if (_schedules.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    '추가된 일정 목록',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _schedules.length,
                    itemBuilder: (context, index) {
                      final schedule = _schedules[index];
                      return ListTile(
                        title: Text(schedule['name']),
                        subtitle: Text('${schedule['type']} - ${schedule['type'] == 'FLEXIBLE' ? '유연한 일정' : schedule['location']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _schedules.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitSchedules,
                  child: const Text('전체 일정 저장'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
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
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
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

      Map<String, dynamic> scheduleData = {
        'id': DateTime.now().toString(),
        'name': _nameController.text,
        'type': _type,
        'duration': _duration,
        'priority': _priority,
      };

      // 고정 일정일 경우에만 위치 정보 추가
      if (_type == 'FIXED') {
        final startTime = _startTime!;
        final endTime = startTime.add(Duration(minutes: _duration));

        scheduleData.addAll({
          'location': _locationController.text,
          'latitude': _latitude,
          'longitude': _longitude,
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
      print('Submitting schedules: $_schedules'); // 디버깅용 로그

      final optimizedData = await scheduleProvider.optimizeSchedules(_schedules);

      if (!mounted) return;

      // 최적화 성공 시 다음 화면으로 이동
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

      // 에러 메시지를 사용자 친화적으로 표시
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
}
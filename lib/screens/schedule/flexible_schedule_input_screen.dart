// lib/screens/schedule/flexible_schedule_input_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/schedule.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/route_provider.dart';
import '../route/optimized_routes_screen.dart';
class FlexibleScheduleInputScreen extends StatefulWidget {
  final List<Schedule> fixedSchedules;

  const FlexibleScheduleInputScreen({
    Key? key,
    required this.fixedSchedules,
  }) : super(key: key);

  @override
  State<FlexibleScheduleInputScreen> createState() => _FlexibleScheduleInputScreenState();
}

class _FlexibleScheduleInputScreenState extends State<FlexibleScheduleInputScreen> {
  final List<Map<String, dynamic>> _flexibleSchedules = [];
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('유연한 일정 추가'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 고정 일정 표시
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '고정 일정',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...widget.fixedSchedules.map((schedule) => ListTile(
                      title: Text(schedule.name),
                      subtitle: Text(
                          '${_formatDateTime(schedule.startTime)} - ${_formatDateTime(schedule.endTime)}'
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 유연한 일정 입력
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '유연한 일정',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._buildFlexibleScheduleInputs(),
                    TextButton.icon(
                      onPressed: _addFlexibleSchedule,
                      icon: const Icon(Icons.add),
                      label: const Text('유연한 일정 추가'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 최적화 버튼
            ElevatedButton(
              onPressed: _optimizeSchedule,
              child: const Text('일정 최적화'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFlexibleScheduleInputs() {
    return _flexibleSchedules.map((schedule) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            // 장소 유형 입력 (필수)
            TextFormField(
              decoration: const InputDecoration(
                labelText: '방문할 곳 (예: 마트, 서점)',
                hintText: '방문하고 싶은 장소 유형을 입력하세요',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => schedule['type'] = value,
              validator: (value) =>
              value?.isEmpty ?? true ? '방문할 곳을 입력하세요' : null,
            ),
            const SizedBox(height: 8),

            // 예상 소요시간 (필수)
            TextFormField(
              decoration: const InputDecoration(
                labelText: '예상 소요시간 (분)',
                hintText: '방문에 필요한 시간을 입력하세요',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => schedule['duration'] = int.tryParse(value) ?? 30,
              validator: (value) =>
              int.tryParse(value ?? '') == null ? '올바른 시간을 입력하세요' : null,
            ),

            // 우선순위 설정 (선택)
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: '우선순위',
                border: OutlineInputBorder(),
              ),
              value: schedule['priority'] ?? 1,
              items: [1, 2, 3].map((priority) {
                return DropdownMenuItem(
                  value: priority,
                  child: Text('우선순위 $priority'),
                );
              }).toList(),
              onChanged: (value) => schedule['priority'] = value,
            ),
          ],
        ),
      );
    }).toList();
  }

  void _addFlexibleSchedule() {
    setState(() {
      _flexibleSchedules.add({
        'type': '',
        'duration': 30,
        'priority': 1
      });
    });
  }

  void _optimizeSchedule() async {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OptimizedRoutesScreen(
            fixedSchedules: widget.fixedSchedules,
            flexibleSchedules: _flexibleSchedules,
          ),
        ),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/schedule_provider.dart';
import '../../models/schedule.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({Key? key}) : super(key: key);

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  @override
  void initState() {
    super.initState();
    // 스케줄 데이터 로드
    Future.microtask(() =>
        context.read<ScheduleProvider>().loadSchedules()
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스케줄 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final scheduleProvider = context.read<ScheduleProvider>();
              final schedulesMaps = scheduleProvider.schedules.map((schedule) => schedule.toJson()).toList();
              scheduleProvider.optimizeSchedules(schedulesMaps);
            },
          ),
        ],
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.error!),
                  ElevatedButton(
                    onPressed: provider.clearError,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFixedSchedules(provider),
                const SizedBox(height: 24),
                _buildFlexibleSchedules(provider),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 새 스케줄 추가 화면으로 이동
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFixedSchedules(ScheduleProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '고정 일정',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.fixedSchedules.length,
          itemBuilder: (context, index) {
            return _buildScheduleCard(provider.fixedSchedules[index]);
          },
        ),
      ],
    );
  }

  Widget _buildFlexibleSchedules(ScheduleProvider provider) {
    return Column(
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
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.flexibleSchedules.length,
          itemBuilder: (context, index) {
            return _buildScheduleCard(provider.flexibleSchedules[index]);
          },
        ),
      ],
    );
  }

  Widget _buildScheduleCard(Schedule schedule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          schedule.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(schedule.location),
            Text(
              '${_formatDateTime(schedule.startTime)} ~ ${_formatDateTime(schedule.endTime)}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: schedule.type == 'FLEXIBLE'
            ? Text(
          '우선순위 ${schedule.priority}',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
        )
            : null,
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
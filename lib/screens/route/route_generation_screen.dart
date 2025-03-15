//lib/screens/route/route_generation_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/route_provider.dart';
import '../schedule/add_schedule_screen.dart';
import './route_list_screen.dart';
import '../schedule/flexible_schedule_input_screen.dart';
class RouteGenerationScreen extends StatefulWidget {
  const RouteGenerationScreen({Key? key}) : super(key: key);

  @override
  State<RouteGenerationScreen> createState() => _RouteGenerationScreenState();
}

class _RouteGenerationScreenState extends State<RouteGenerationScreen> {
  String _selectedTransportMode = 'DRIVING'; // 기본값으로 자동차 모드 설정
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProxyProvider<ScheduleProvider, RouteProvider>(
          create: (_) => RouteProvider(),
          update: (_, scheduleProvider, previousRouteProvider) {
            return previousRouteProvider ?? RouteProvider();
          },
        ),
      ],
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('경로 생성'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  context.read<ScheduleProvider>().loadSchedules();
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

              if (provider.schedules.isEmpty) {
                return const Center(
                  child: Text('저장된 일정이 없습니다. 일정을 추가해주세요.'),
                );
              }

              return Column(
                children: [
                  // 이동 수단 선택 UI 추가
                  _buildTransportModeSelector(),

                  Expanded(
                    child: ListView.builder(
                      itemCount: provider.schedules.length,
                      itemBuilder: (context, index) {
                        final schedule = provider.schedules[index];
                        return ListTile(
                          title: Text(schedule.name),
                          subtitle: Text(
                            '${_formatDateTime(schedule.startTime)} - ${_formatDateTime(schedule.endTime)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              provider.deleteSchedule(schedule.id);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                final scheduleProvider = context.read<ScheduleProvider>();
                                final routeProvider = context.read<RouteProvider>();

                                final schedulesMaps = scheduleProvider.schedules
                                    .map((s) => s.toJson())
                                    .toList();

                                await routeProvider.getRecommendedRoutes(schedulesMaps);

                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const RouteListScreen(),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('경로 생성 실패: $e')),
                                  );
                                }
                              }
                            },
                            child: const Text('경로 생성하기'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FlexibleScheduleInputScreen(
                                    fixedSchedules: provider.schedules,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('유연한 일정 추가'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddScheduleScreen(),
                ),
              );
            },
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  // lib/screens/route/route_generation_screen.dart에 추가할 UI 구성요소

  Widget _buildTransportModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTransportModeButton('WALK', Icons.directions_walk, '도보'),
          _buildTransportModeButton('TRANSIT', Icons.directions_bus, '대중교통'),
          _buildTransportModeButton('DRIVING', Icons.directions_car, '자동차'),
        ],
      ),
    );
  }

  Widget _buildTransportModeButton(String mode, IconData icon, String label) {
    final isSelected = _selectedTransportMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTransportMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
            Text(label, style: TextStyle(color: isSelected ? Colors.blue : Colors.grey)),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
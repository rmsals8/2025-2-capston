import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _trafficAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          _buildUserSettingsSection(),
          const SizedBox(height: 16),
          _buildApiVoiceSettingsSection(),
          const SizedBox(height: 16),
          _buildNotificationSettingsSection(),
          const SizedBox(height: 16),
          _buildDataManagementSection(),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    bool showDivider = true,
    Color? backgroundColor,
  }) {
    return Column(
      children: [
        ListTile(
          title: Text(title),
          trailing: trailing,
          onTap: onTap,
          tileColor: backgroundColor,
        ),
        if (showDivider)
          const Divider(height: 1),
      ],
    );
  }

  Widget _buildUserSettingsSection() {
    return _buildSection(
      '사용자 설정',
      [
        _buildSettingsItem(
          title: '프로필 관리',
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: 프로필 관리 화면으로 이동
          },
        ),
        _buildSettingsItem(
          title: '테마 설정',
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: 테마 설정 화면으로 이동
          },
        ),
        _buildSettingsItem(
          title: '언어 설정',
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: 언어 설정 화면으로 이동
          },
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildApiVoiceSettingsSection() {
    return _buildSection(
      'API/음성 설정',
      [
        _buildSettingsItem(
          title: '음성 인식 설정',
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: 음성 인식 설정 화면으로 이동
          },
        ),
        _buildSettingsItem(
          title: 'API 키 관리',
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: API 키 관리 화면으로 이동
          },
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildNotificationSettingsSection() {
    return _buildSection(
      '알림 설정',
      [
        _buildSettingsItem(
          title: '푸시 알림',
          trailing: Switch(
            value: _pushNotifications,
            onChanged: (value) {
              setState(() {
                _pushNotifications = value;
              });
            },
          ),
        ),
        _buildSettingsItem(
          title: '교통 알림',
          trailing: Switch(
            value: _trafficAlerts,
            onChanged: (value) {
              setState(() {
                _trafficAlerts = value;
              });
            },
          ),
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildDataManagementSection() {
    return _buildSection(
      '데이터 관리',
      [
        _buildSettingsItem(
          title: '캐시 삭제',
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            _showClearCacheDialog();
          },
        ),
        _buildSettingsItem(
          title: '모든 데이터 초기화',
          onTap: () {
            _showResetDataDialog();
          },
          backgroundColor: Colors.red[50],
          showDivider: false,
        ),
      ],
    );
  }

  Future<void> _showClearCacheDialog() {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐시 삭제'),
        content: const Text('캐시를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              // TODO: 캐시 삭제 처리
              Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetDataDialog() {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터 초기화'),
        content: const Text(
          '모든 데이터가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              // TODO: 데이터 초기화 처리
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }
}
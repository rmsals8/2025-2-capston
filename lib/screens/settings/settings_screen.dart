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
          '설정',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
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
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
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
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: backgroundColor != null && backgroundColor == Colors.red[50]
                  ? Colors.red[600]
                  : Colors.black87,
            ),
          ),
          trailing: trailing,
          onTap: onTap,
          tileColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Colors.grey[200],
          ),
      ],
    );
  }

  Widget _buildUserSettingsSection() {
    return _buildSection(
      '사용자 설정',
      [
        _buildSettingsItem(
          title: '프로필 관리',
          trailing: const Icon(Icons.chevron_right, color: Colors.black54),
          onTap: () {
            // TODO: 프로필 관리 화면으로 이동
          },
        ),
        _buildSettingsItem(
          title: '테마 설정',
          trailing: const Icon(Icons.chevron_right, color: Colors.black54),
          onTap: () {
            // TODO: 테마 설정 화면으로 이동
          },
        ),
        _buildSettingsItem(
          title: '언어 설정',
          trailing: const Icon(Icons.chevron_right, color: Colors.black54),
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
          trailing: const Icon(Icons.chevron_right, color: Colors.black54),
          onTap: () {
            // TODO: 음성 인식 설정 화면으로 이동
          },
        ),
        _buildSettingsItem(
          title: 'API 키 관리',
          trailing: const Icon(Icons.chevron_right, color: Colors.black54),
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
            activeColor: Colors.black,
            activeTrackColor: Colors.grey[300],
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
            activeColor: Colors.black,
            activeTrackColor: Colors.grey[300],
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
          trailing: const Icon(Icons.chevron_right, color: Colors.black54),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '캐시 삭제',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          '캐시를 삭제하시겠습니까?',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: 캐시 삭제 처리
              Navigator.pop(context);
            },
            child: const Text(
              '삭제',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetDataDialog() {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '데이터 초기화',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          '모든 데이터가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(
            color: Colors.red,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: 데이터 초기화 처리
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text(
              '초기화',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
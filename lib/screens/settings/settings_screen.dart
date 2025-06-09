import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_helper/screens/auth/auth_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _trafficAlerts = true;
  bool _isLoading = false;
  final baseUrl = dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8080/api/v1';

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
      body: Stack(
        children: [
          ListView(
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
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
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
        ),
        // 회원 탈퇴 버튼 추가
        _buildSettingsItem(
          title: '회원 탈퇴',
          onTap: () {
            _showWithdrawAccountDialog();
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
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 캐시 아이콘
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cached,
                size: 32,
                color: Colors.blue[600],
              ),
            ),
            const SizedBox(height: 20),

            // 제목
            const Text(
              '캐시 삭제',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),

            // 설명
            Text(
              '임시 파일과 캐시 데이터를\n삭제하시겠습니까?',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // 버튼들
            Row(
              children: [
                // 취소 버튼
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 삭제 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: 캐시 삭제 처리
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('캐시가 삭제되었습니다')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      '삭제',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Future<void> _showResetDataDialog() {
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 위험 아이콘
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_forever,
                size: 32,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 20),

            // 제목
            const Text(
              '데이터 초기화',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),

            // 설명
            Text(
              '모든 데이터가 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // 경고 박스
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: 16,
                    color: Colors.red[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '방문 기록, 저장된 일정, 설정이 모두 삭제됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 버튼들
            Row(
              children: [
                // 취소 버튼
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 초기화 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: 데이터 초기화 처리
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('데이터가 초기화되었습니다')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      '초기화',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  // 회원 탈퇴 확인 다이얼로그
 Future<void> _showWithdrawAccountDialog() {
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 경고 아이콘
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 32,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 20),

            // 제목
            const Text(
              '회원 탈퇴',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),

            // 설명
            Text(
              '정말 탈퇴하시겠습니까?\n모든 데이터가 삭제되며\n이 작업은 되돌릴 수 없습니다.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // 경고 박스
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.red[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '탈퇴 시 모든 방문 기록, 저장된 일정, 구독 정보가 완전히 삭제됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 버튼들
            Row(
              children: [
                // 취소 버튼
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 탈퇴 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _withdrawAccount();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      '탈퇴하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// 회원 탈퇴 처리 함수
void _withdrawAccount() async {
  setState(() {
    _isLoading = true;
  });

  try {
    // 사용자 인증 상태 확인 및 토큰 가져오기
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final loginType = prefs.getInt('login_type') ?? 0; // 로그인 타입 확인 (기본값은 일반 회원)
    
    if (token == null) {
      // 토큰이 없으면 로그인 화면으로 이동
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false
        );
      }
      return;
    }
    
    // 로그인 타입에 따라 적절한 엔드포인트 호출
    final url = loginType == 1 
      ? Uri.parse('$baseUrl/auth/withdraw/social')  // 소셜 로그인
      : Uri.parse('$baseUrl/auth/withdraw');        // 일반 회원

    final Map<String, dynamic> requestBody = {};
    
    // 일반 회원은 비밀번호 입력 필요
    if (loginType == 0) {
      // 비밀번호 입력 다이얼로그 표시
      final password = await _showPasswordConfirmDialog();
      if (password == null) {
        setState(() {
          _isLoading = false;
        });
        return; // 취소 시 작업 중단
      }
      requestBody['password'] = password;
    }
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: loginType == 0 ? jsonEncode(requestBody) : null,
    );
    
    if (response.statusCode == 200) {
      // 탈퇴 성공
      // 로컬 데이터 삭제
      await prefs.clear();
      
      // 성공 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
        );
        
        // 로그인 화면으로 이동
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false
        );
      }
    } else {
      // 실패 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('회원 탈퇴 처리 중 오류가 발생했습니다: ${response.body}'),
          ),
        );
      }
    }
  } catch (e) {
    // 예외 발생 시 오류 메시지 표시
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// 비밀번호 입력 다이얼로그
Future<String?> _showPasswordConfirmDialog() {
  final TextEditingController passwordController = TextEditingController();
  bool _isObscured = true;
  
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 보안 아이콘
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.security,
                  size: 32,
                  color: Colors.orange[600],
                ),
              ),
              const SizedBox(height: 20),

              // 제목
              const Text(
                '비밀번호 확인',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),

              // 설명
              Text(
                '안전한 탈퇴를 위해\n비밀번호를 입력해주세요.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // 비밀번호 입력 필드
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: TextField(
                  controller: passwordController,
                  obscureText: _isObscured,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: '비밀번호를 입력하세요',
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscured ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscured = !_isObscured;
                        });
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 버튼들
              Row(
                children: [
                  // 취소 버튼
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 확인 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (passwordController.text.isNotEmpty) {
                          Navigator.pop(context, passwordController.text);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
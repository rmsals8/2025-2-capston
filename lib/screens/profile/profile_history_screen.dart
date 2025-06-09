import 'dart:convert';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // 추가
import 'package:flutter/foundation.dart' show kDebugMode; // 추가
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../models/visit_history.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/visit_history_service.dart';
import '../../services/schedule_save_service.dart';
import '../../services/subscription_service.dart'; // 새로 추가할 서비스
import '../auth/auth_screen.dart';
import '../recommendations/history_based_recommendations_screen.dart';
import '../schedule/saved_schedule_list_screen.dart';
import 'visit_history_screen.dart';
import '../settings/settings_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ProfileHistoryScreen extends StatefulWidget {
  const ProfileHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ProfileHistoryScreen> createState() => _ProfileHistoryScreenState();
}

class _ProfileHistoryScreenState extends State<ProfileHistoryScreen> {
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isPurchasePending = false;
  final VisitHistoryService _historyService = VisitHistoryService();
  final ScheduleSaveService _scheduleSaveService = ScheduleSaveService();
  final SubscriptionService _subscriptionService = SubscriptionService(); // 새로 추가할 서비스

  // 구독 관련 상태
  bool _isPremium = false;
  String _subscriptionStatus = "FREE";
  int _remainingUsage = 3; // 기본값 (FREE PLAN)
  DateTime? _subscriptionEndDate;
  bool _isLoadingSubscription = true;

  // IAP 관련 상태
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  List<ProductDetails> _products = [];
  List<String> _productIds = ['premium_monthly']; // 구글 플레이 콘솔에 등록할 상품 ID
  bool _isAvailable = false;
  bool _isLoadingProducts = true;
  List<PurchaseDetails> _purchases = [];

  String get baseUrl {
    if (kIsWeb) {
      return dotenv.env['API_V1_URL'] ?? 'http://localhost:8081/api/v1';
    } else {
      return dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8081/api/v1';
    }
  }

  bool _isLoading = true;
  List<VisitHistory> _recentHistories = [];
  Map<String, int> _categoryCounts = {};
  List<Map<String, dynamic>> _savedSchedules = [];
  bool _isLoadingSavedSchedules = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadSubscriptionStatus();
    _initInAppPurchase();
  }
  @override
  void dispose() {
    if (_subscription != null) {
      _subscription.cancel();
    }
    _inAppPurchase.purchaseStream.drain().then((_) => _subscription.cancel());
    super.dispose();
  }
  Future<void> _initInAppPurchase() async {
    print('_initInAppPurchase 시작');
    final bool isAvailable = await _inAppPurchase.isAvailable();
    print('isAvailable: $isAvailable');

    setState(() {
      _isAvailable = isAvailable;
    });

    if (isAvailable) {
      // 구매 스트림 구독
      _subscription = _inAppPurchase.purchaseStream.listen(
        _listenToPurchaseUpdated,
        onDone: () {
          _subscription.cancel();
        },
        onError: (error) {
          print('구매 스트림 오류: $error');
        },
      );

      // 상품 정보 로드
      try {
        print('상품 정보 로드 시작: ${_productIds.toSet()}');
        final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(_productIds.toSet());

        // 디버깅용 메시지 출력
        print('response.productDetails: ${response.productDetails.length}');
        print('response.error: ${response.error?.message}');
        print('response.notFoundIDs: ${response.notFoundIDs}');

        if (response.error != null) {
          print('상품 목록 조회 오류: ${response.error!.message}');
        }

        // 개발 환경에서 테스트용 상품 데이터 추가
        if (kDebugMode && response.productDetails.isEmpty) {
          setState(() {
            _products = [
              ProductDetails(
                id: 'premium_monthly',
                title: '월간 구독 (테스트)',
                description: '테스트용 월간 구독',
                price: '₩5,000',
                rawPrice: 5000,
                currencyCode: 'KRW',
              )
            ];
            _isLoadingProducts = false;
          });
          print('테스트용 상품 데이터 추가됨');
        } else {
          setState(() {
            _products = response.productDetails;
            _isLoadingProducts = false;
          });
        }
      } catch (e) {
        print('상품 목록 로딩 중 오류 발생: $e');

        // 오류 발생 시 테스트용 상품 데이터 추가
        if (kDebugMode) {
          setState(() {
            _products = [
              ProductDetails(
                id: 'premium_monthly',
                title: '월간 구독 (테스트)',
                description: '테스트용 월간 구독',
                price: '₩5,000',
                rawPrice: 5000,
                currencyCode: 'KRW',
              )
            ];
            _isLoadingProducts = false;
          });
          print('오류 발생 후 테스트용 상품 데이터 추가됨');
        } else {
          setState(() {
            _isLoadingProducts = false;
          });
        }
      }
    } else {
      // 인앱 결제를 사용할 수 없는 경우 테스트용 상품 데이터 추가
      if (kDebugMode) {
        setState(() {
          _products = [
            ProductDetails(
              id: 'premium_monthly',
              title: '월간 구독 (테스트)',
              description: '테스트용 월간 구독',
              price: '₩5,000',
              rawPrice: 5000,
              currencyCode: 'KRW',
            )
          ];
          _isLoadingProducts = false;
        });
        print('인앱 결제 사용 불가: 테스트용 상품 데이터 추가됨');
      } else {
        setState(() {
          _isLoadingProducts = false;
        });
      }
      print('인앱 결제를 사용할 수 없습니다.');
    }
    print('_initInAppPurchase 종료');
  }
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // 로딩 UI 표시
        setState(() {
          _isPurchasePending = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('결제가 진행 중입니다...')),
        );
      } else {
        setState(() {
          _isPurchasePending = false;
        });

        if (purchaseDetails.status == PurchaseStatus.error) {
          _handlePurchaseError(purchaseDetails.error!);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          await _deliverProduct(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('구매가 취소되었습니다.')),
          );
        }

        // 메모리 누수 방지를 위해 구매 상태에 상관없이 완료 처리
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  // _ProfileHistoryScreenState 클래스 내에 추가하세요
  void _handlePurchaseError(IAPError error) {
    print('구매 오류: ${error.message}, 코드: ${error.code}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('구매 중 오류가 발생했습니다: ${error.message}')),
    );
  }
  // _ProfileHistoryScreenState 클래스 내에 추가하세요
  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    try {
      // 구매 검증
      final bool valid = await _verifyPurchase(purchaseDetails);

      if (!valid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구매 검증에 실패했습니다.')),
        );
        return;
      }

      // 백엔드에 구독 상태 업데이트
      await _subscriptionService.updateSubscription(
        productId: purchaseDetails.productID,
        purchaseToken: purchaseDetails.purchaseID!,
      );

      // UI 업데이트
      await _loadSubscriptionStatus();

      // 성공 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프리미엄 구독이 성공적으로 활성화되었습니다!')),
        );
      }
    } catch (e) {
      print('구독 처리 중 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구독 처리 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

// _ProfileHistoryScreenState 클래스 내에 추가하세요
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // 테스트 환경에서는 항상 true 반환
    if (kDebugMode) {
      return true;
    }

    // 실제 환경에서는 서버 검증 필요
    try {
      return await _subscriptionService.verifyPurchase(
        productId: purchaseDetails.productID,
        purchaseToken: purchaseDetails.purchaseID!,
      );
    } catch (e) {
      print('구매 검증 오류: $e');
      return false;
    }
  }

  Future<void> _buySubscription(ProductDetails product) async {
    if (_isPurchasePending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 결제가 진행 중입니다. 잠시만 기다려주세요.')),
      );
      return;
    }

    // 테스트 모드에서는 구매 성공 처리
    if (kDebugMode) {
      print('테스트 모드: 구매 성공 처리');
      setState(() {
        _isPremium = true;
        _subscriptionStatus = "PREMIUM";
        _remainingUsage = 999;
        _subscriptionEndDate = DateTime.now().add(Duration(days: 30));
      });

      // 로컬에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('subscription_status', 'PREMIUM');
      await prefs.setInt('remaining_usage', 999);
      await prefs.setString('subscription_end_date', DateTime.now().add(Duration(days: 30)).toIso8601String());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('테스트 모드: 프리미엄 구독이 활성화되었습니다!')),
      );
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: null,
    );

    try {
      print('구매 시작: ${product.id}, ${product.price}');
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      print('구매 요청 완료');
    } catch (e) {
      print('구매 시도 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구매 시도 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _isLoadingSavedSchedules = true;
    });

    try {
      Map<String, String> userInfo = await _fetchUserInfoFromBackend();
      print('백엔드에서 가져온 사용자 정보: $userInfo');

      final prefs = await SharedPreferences.getInstance();
      if (userInfo['name'] != null && userInfo['name']!.isNotEmpty) {
        await prefs.setString('user_name', userInfo['name']!);
      }
      if (userInfo['email'] != null && userInfo['email']!.isNotEmpty) {
        await prefs.setString('user_email', userInfo['email']!);
      }

      // 방문 기록 로드
      _recentHistories = await _historyService.getRecentlyVisitedPlaces(limit: 5);
      final allHistories = await _historyService.getVisitHistories();

      _categoryCounts = {};
      for (var history in allHistories) {
        _categoryCounts[history.category] = (_categoryCounts[history.category] ?? 0) + 1;
      }

      // 구독 상태 로드
      await _loadSubscriptionStatus();

      // 저장된 일정 로드
      _loadSavedSchedules();
    } catch (e) {
      print('프로필 데이터 로드 오류: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 구독 상태 로드
  Future<void> _loadSubscriptionStatus() async {
    setState(() {
      _isLoadingSubscription = true;
    });

    try {
      final subscriptionData = await _subscriptionService.getSubscriptionStatus();
      setState(() {
        _subscriptionStatus = subscriptionData['planType'] ?? 'FREE';
        _isPremium = _subscriptionStatus == 'PREMIUM';
        _remainingUsage = subscriptionData['remaining'] ?? 3;

        if (subscriptionData['endDate'] != null) {
          _subscriptionEndDate = DateTime.parse(subscriptionData['endDate']);
        }

        _isLoadingSubscription = false;
      });
    } catch (e) {
      print('구독 상태 로드 오류: $e');
      setState(() {
        _isLoadingSubscription = false;
      });
    }
  }

  // 저장된 일정 로드
  Future<void> _loadSavedSchedules() async {
    try {
      final schedules = await _scheduleSaveService.getSavedSchedules();
      if (mounted) {
        setState(() {
          _savedSchedules = schedules;
          _isLoadingSavedSchedules = false;
        });
      }
    } catch (e) {
      print('저장된 일정 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isLoadingSavedSchedules = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        title: const Text(
          '내 프로필',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
        onRefresh: _loadData,
        color: Colors.black,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileCard(),
              _buildSubscriptionCard(), // 구독 카드 추가
              _buildStatisticsCard(),
              _buildRecentVisitsSection(),
              _buildSavedSchedulesSection(),
              _buildCategoryStats(),
              _buildActionButtons(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // 구독 정보 및 업그레이드 카드
  Widget _buildSubscriptionCard() {
    if (_isLoadingSubscription) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: CircularProgressIndicator(color: Colors.grey[400]),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isPremium ? Colors.black : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isPremium ? Colors.black : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isPremium ? Icons.star : Icons.star_border,
                color: _isPremium ? Colors.yellow : Colors.black,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _isPremium ? '프리미엄 멤버십' : '무료 플랜',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _isPremium ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isPremium
                ? '일일 사용량: 무제한'
                : '남은 일일 사용량: $_remainingUsage회',
            style: TextStyle(
              fontSize: 14,
              color: _isPremium ? Colors.white70 : Colors.grey[700],
            ),
          ),
          if (_isPremium && _subscriptionEndDate != null) ...[
            const SizedBox(height: 8),
            Text(
              '구독 만료일: ${DateFormat('yyyy년 MM월 dd일').format(_subscriptionEndDate!)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isPremium ? null : () => _showSubscriptionDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isPremium ? Colors.grey[800] : Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[600],
                disabledForegroundColor: Colors.white70,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                _isPremium ? '구독 중' : '프리미엄으로 업그레이드',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionDialog() {
    print('_isLoadingProducts: $_isLoadingProducts');
    print('_products: ${_products.map((p) => '${p.id}: ${p.price}').join(', ')}');
    print('_products.isEmpty: ${_products.isEmpty}');

    // 테스트 모드 강제 적용 - 상품 정보 로드 여부 관계없이 테스트 UI 표시
    final bool isTestMode = true; // 테스트 할 때는 true로 설정

    // 구독 모달 표시
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        '프리미엄으로 업그레이드',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        '프리미엄 멤버십으로 모든 기능을 제한 없이 사용해보세요.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildFeatureItem(
                            icon: Icons.check_circle_outline,
                            text: '일일 사용량 무제한',
                          ),
                          _buildFeatureItem(
                            icon: Icons.check_circle_outline,
                            text: '고급 분석 및 추천',
                          ),
                          _buildFeatureItem(
                            icon: Icons.check_circle_outline,
                            text: '일정 자동 최적화',
                          ),
                          _buildFeatureItem(
                            icon: Icons.check_circle_outline,
                            text: '광고 없는 경험',
                          ),
                          const SizedBox(height: 32),

                          // 테스트용 월간 구독 옵션
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                _activateTestSubscription(monthly: true);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '월간 구독 (테스트)',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '테스트',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue[800],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '₩5,000',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '/월',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _activateTestSubscription(monthly: true);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: const Text(
                                          '월간 구독하기',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // 테스트용 연간 구독 옵션
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                _activateTestSubscription(monthly: false);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '연간 구독 (테스트)',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green[100],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '20% 할인',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green[800],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '₩48,000',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '/년',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _activateTestSubscription(monthly: false);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: const Text(
                                          '연간 구독하기',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                          Text(
                            '구독은 선택한 주기로 자동 갱신되며, 언제든지 취소할 수 있습니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
  // _ProfileHistoryScreenState 클래스 내에 추가
  void _activateTestSubscription({required bool monthly}) {
    setState(() {
      _isPremium = true;
      _subscriptionStatus = "PREMIUM";
      _remainingUsage = 999;
      _subscriptionEndDate = monthly
          ? DateTime.now().add(Duration(days: 30))
          : DateTime.now().add(Duration(days: 365));

      // 로컬에 구독 상태 저장
      _saveSubscriptionStatusLocally();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('테스트 모드: ${monthly ? '월간' : '연간'} 프리미엄 구독이 활성화되었습니다!')),
    );
  }

  Future<void> _saveSubscriptionStatusLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('subscription_status', _subscriptionStatus);
      await prefs.setInt('remaining_usage', _remainingUsage);

      if (_subscriptionEndDate != null) {
        await prefs.setString('subscription_end_date', _subscriptionEndDate!.toIso8601String());
      }
    } catch (e) {
      print('구독 상태 저장 오류: $e');
    }
  }

  Widget _buildFeatureItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionOption(ProductDetails product) {
    final bool isMonthly = product.id.contains('monthly');
    final String period = isMonthly ? '월' : '년';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _buySubscription(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMonthly ? '월간 구독' : '연간 구독',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!isMonthly)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '20% 할인',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                product.price,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '/$period',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _buySubscription(product),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    '${isMonthly ? '월간' : '연간'} 구독하기',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 40,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<Map<String, String>>(
                    future: _fetchUserInfoFromBackend(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          width: 120,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }

                      final userData = snapshot.data;
                      final userName = userData?['name'] ?? '사용자';
                      return Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    }
                ),
                const SizedBox(height: 4),
                FutureBuilder<Map<String, String>>(
                    future: _fetchUserInfoFromBackend(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          width: 180,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }

                      final userData = snapshot.data;
                      final userEmail = userData?['email'] ?? 'user@example.com';
                      return Text(
                        userEmail,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      );
                    }
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: _showLogoutDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('로그아웃'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final visitCount = _recentHistories.length;
    final categoryCount = _categoryCounts.length;
    final thisMonthCount = _getMonthlyVisitCount();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '방문 통계',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.place,
                value: '$visitCount',
                label: '총 방문 장소',
              ),
              _buildStatItem(
                icon: Icons.category,
                value: '$categoryCount',
                label: '방문 카테고리',
              ),
              _buildStatItem(
                icon: Icons.calendar_today,
                value: '$thisMonthCount',
                label: '이번 달 방문',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentVisitsSection() {
    if (_recentHistories.isEmpty) {
      return const SizedBox(height: 16);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '최근 방문',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
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
                child: const Text(
                  '전체보기',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentHistories.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final history = _recentHistories[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(history.category),
                    color: Colors.black87,
                  ),
                ),
                title: Text(
                  history.placeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${history.category} • ${_formatDate(history.visitDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                onTap: () {
                  // 방문 기록 상세 정보 표시 (향후 구현)
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSavedSchedulesSection() {
    if (_isLoadingSavedSchedules) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '저장된 일정',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: CircularProgressIndicator(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    if (_savedSchedules.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '저장된 일정',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SavedScheduleListScreen(),
                      ),
                    ).then((_) => _loadSavedSchedules());
                  },
                  child: const Text(
                    '전체보기',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '저장된 일정이 없습니다',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 160,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SavedScheduleListScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('일정 만들기'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 최대 3개의 일정만 표시
    final displayedSchedules = _savedSchedules.length > 3
        ? _savedSchedules.sublist(0, 3)
        : _savedSchedules;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '저장된 일정',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SavedScheduleListScreen(),
                    ),
                  ).then((_) => _loadSavedSchedules());
                },
                child: const Text(
                  '전체보기',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...displayedSchedules.map((schedule) => _buildScheduleCard(schedule)).toList(),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    // 날짜 포맷 변환
    String expirationDate = '만료일 정보 없음';

    try {
      if (schedule['expirationDate'] != null) {
        final expires = DateTime.parse(schedule['expirationDate']);
        expirationDate = DateFormat('yyyy년 MM월 dd일').format(expires);
      }
    } catch (e) {
      print('날짜 파싱 오류: $e');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SavedScheduleListScreen(),
            ),
          ).then((_) => _loadSavedSchedules());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Colors.black87,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule['scheduleName'] ?? '제목 없음',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '만료일: $expirationDate',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.place, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${schedule['itemCount'] ?? 0}개 장소',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showDeleteDialog(context, schedule),
              ),
            ],
          ),
        ),
      ),
    );
  }

 void _showDeleteDialog(BuildContext context, Map<String, dynamic> schedule) {
  showDialog(
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
            // 삭제 아이콘
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline,
                size: 32,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 20),

            // 제목
            const Text(
              '일정 삭제',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),

            // 일정 이름 표시
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      schedule['scheduleName'] ?? '일정',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 설명
            Text(
              '이 일정을 삭제하시겠습니까?\n삭제된 일정은 복구할 수 없습니다.',
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
                    onPressed: () => Navigator.of(context).pop(),
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
                      Navigator.of(context).pop();
                      _deleteSchedule(schedule['id']);
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

  Future<void> _deleteSchedule(int scheduleId) async {
    try {
      final success = await _scheduleSaveService.deleteSavedSchedule(scheduleId);
      if (success) {
        setState(() {
          _savedSchedules.removeWhere((schedule) => schedule['id'] == scheduleId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일정이 삭제되었습니다')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일정 삭제에 실패했습니다')),
          );
        }
      }
    } catch (e) {
      print('일정 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일정 삭제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Widget _buildCategoryStats() {
    if (_categoryCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedCategories = _categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxCount = sortedCategories.isNotEmpty
        ? sortedCategories.first.value.toDouble()
        : 1.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '카테고리별 방문',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: sortedCategories
                  .take(5)
                  .map((entry) => _buildCategoryBar(
                category: entry.key,
                count: entry.value,
                maxCount: maxCount,
              ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar({
    required String category,
    required int count,
    required double maxCount,
  }) {
    final double percentage = count / maxCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              category,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistoryBasedRecommendationsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.recommend),
              label: const Text(
                '맞춤 추천 장소',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VisitHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text(
                '방문 기록 관리',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SavedScheduleListScreen(),
                  ),
                ).then((_) => _loadSavedSchedules());
              },
              icon: const Icon(Icons.bookmark),
              label: const Text(
                '저장된 일정 관리',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

 Future<void> _showLogoutDialog() async {
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
            // 로그아웃 아이콘
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout,
                size: 32,
                color: Colors.orange[600],
              ),
            ),
            const SizedBox(height: 20),

            // 제목
            const Text(
              '로그아웃',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),

            // 설명
            Text(
              '정말 로그아웃 하시겠습니까?\n앱을 다시 사용하려면\n로그인이 필요합니다.',
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
                    onPressed: () => Navigator.of(context).pop(),
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

                // 로그아웃 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _logout();
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
                      '로그아웃',
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

  void _logout() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 실패: $e')),
        );
      }
    }
  }

  int _getMonthlyVisitCount() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    return _recentHistories
        .where((h) => h.visitDate.isAfter(firstDayOfMonth))
        .length;
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

  Future<Map<String, String>> _fetchUserInfoFromBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      print('토큰 전체: $token');
      print('토큰 길이: ${token?.length}');
      print('토큰 시작: ${token?.substring(0, Math.min(10, token?.length ?? 0))}');

      if (token == null || token.isEmpty) {
        print('토큰이 없습니다.');
        return {'name': '사용자', 'email': 'user@example.com'};
      }

      final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';
      print('API 요청에 사용되는 Authorization 헤더: ${authHeader.substring(0, Math.min(25, authHeader.length))}...');

      try {
        final response = await http.get(
          Uri.parse('$baseUrl/users/me'),
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/json',
          },
        );

        print('사용자 정보 API 응답 상태 코드: ${response.statusCode}');
        print('사용자 정보 API 응답 본문: ${response.body}');

        if (response.statusCode == 200) {
          final userData = json.decode(utf8.decode(response.bodyBytes));
          return {
            'name': userData['name'] ?? '사용자',
            'email': userData['email'] ?? 'user@example.com'
          };
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          print('인증 오류: 토큰이 만료되었거나 유효하지 않습니다.');

          final name = prefs.getString('user_name');
          final email = prefs.getString('user_email');

          print('로컬 저장소에서 가져온 사용자 정보: $name, $email');

          return {
            'name': name ?? '사용자',
            'email': email ?? 'user@example.com'
          };
        } else {
          print('사용자 정보 조회 실패: ${response.body}');
          return {'name': '사용자', 'email': 'user@example.com'};
        }
      } catch (e) {
        print('HTTP 요청 오류: $e');
        final name = prefs.getString('user_name');
        final email = prefs.getString('user_email');

        return {
          'name': name ?? '사용자',
          'email': email ?? 'user@example.com'
        };
      }
    } catch (e) {
      print('사용자 정보 API 호출 오류: $e');
      return {'name': '사용자', 'email': 'user@example.com'};
    }
  }

  Future<Map<String, String>> _getUserInfoFromLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('user_name');
    final userEmail = prefs.getString('user_email');

    print('로컬 저장소에서 가져온 사용자 정보: $userName, $userEmail');

    return {
      'name': userName ?? '사용자',
      'email': userEmail ?? 'user@example.com'
    };
  }

  Future<String?> _getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userEmail = prefs.getString('user_email');
      print('SharedPreferences에서 가져온 사용자 이메일: $userEmail');

      if (userEmail == null || userEmail.isEmpty) {
        final userInfo = await _fetchUserInfoFromBackend();
        return userInfo['email'];
      }

      return userEmail;
    } catch (e) {
      print('사용자 이메일 가져오기 오류: $e');
      return 'user@example.com';
    }
  }

  Future<String?> _getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userName = prefs.getString('user_name');
      print('SharedPreferences에서 가져온 사용자 이름: $userName');

      if (userName == null || userName.isEmpty) {
        final userInfo = await _fetchUserInfoFromBackend();
        return userInfo['name'];
      }

      return userName;
    } catch (e) {
      print('사용자 이름 가져오기 오류: $e');
      return '사용자';
    }
  }

  Future<String?> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');

      if (userId == null || userId.isEmpty) {
        final token = prefs.getString('access_token');
        if (token != null && token.isNotEmpty) {
          if (token.length > 10) {
            userId = 'user_${token.substring(0, 8)}';
          }
        }
      }

      return userId;
    } catch (e) {
      print('Error retrieving user ID: $e');
      return null;
    }
  }
}
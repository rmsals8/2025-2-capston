// lib/screens/auth/category_preference_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_helper/screens/main_navigation.dart';
import '../../models/category_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_preference_provider.dart';

class CategoryPreferenceScreen extends StatefulWidget {
  final bool isFirstLogin;

  const CategoryPreferenceScreen({
    Key? key,
    this.isFirstLogin = true,
  }) : super(key: key);

  @override
  _CategoryPreferenceScreenState createState() => _CategoryPreferenceScreenState();
}

class _CategoryPreferenceScreenState extends State<CategoryPreferenceScreen> {
  final Set<String> _selectedCategories = {};
  bool _isLoading = false;
  
  // 사용자가 최소한 선택해야 하는 카테고리 수
  final int _minCategories = 3;
  
  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }
  
  // 저장된 선호도 불러오기
  Future<void> _loadSavedPreferences() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final prefsProvider = Provider.of<UserPreferenceProvider>(context, listen: false);
      final savedCategories = await prefsProvider.getPreferredCategories();
      
      setState(() {
        _selectedCategories.addAll(savedCategories);
      });
    } catch (e) {
      print('선호도 불러오기 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.isFirstLogin ? '관심 카테고리 선택' : '카테고리 선호도 설정',
          style: const TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isFirstLogin
                        ? '관심 있는 카테고리를 ${_minCategories}개 이상 선택해주세요.'
                        : '선호하는 카테고리를 선택해주세요.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '선택한 카테고리를 기반으로 맞춤 추천을 제공합니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // 메인 카테고리 섹션
                  const Text(
                    '주요 카테고리',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMainCategoryGrid(),
                  
                  const SizedBox(height: 32),
                  
                  // 세부 카테고리 섹션
                  const Text(
                    '세부 카테고리',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSubcategoriesSection(),
                  
                  const SizedBox(height: 32),
                  
                  // 저장 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _selectedCategories.length >= _minCategories
                          ? _savePreferences
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[500],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              widget.isFirstLogin ? '시작하기' : '저장하기',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 선택된 카테고리 수 표시
                  Center(
                    child: Text(
                      '${_selectedCategories.length}개 선택됨 (최소 ${_minCategories}개 필요)',
                      style: TextStyle(
                        color: _selectedCategories.length < _minCategories
                            ? Colors.red
                            : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  // 첫 로그인이 아닌 경우에만 표시되는 건너뛰기 버튼
                  if (!widget.isFirstLogin) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          '취소',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  // 메인 카테고리 그리드 위젯
  Widget _buildMainCategoryGrid() {
    final mainCategories = CategoryConstants.mainCategories;
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: mainCategories.length,
      itemBuilder: (context, index) {
        final category = mainCategories[index];
        final isSelected = _selectedCategories.contains(category.id);
        
        return _buildCategoryCard(
          category: category,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedCategories.remove(category.id);
              } else {
                _selectedCategories.add(category.id);
              }
            });
          },
        );
      },
    );
  }
  
  // 서브 카테고리 섹션 위젯
  Widget _buildSubcategoriesSection() {
    return ExpansionPanelList(
      elevation: 0,
      expandedHeaderPadding: EdgeInsets.zero,
      expansionCallback: (panelIndex, isExpanded) {
        setState(() {
          _expansionStates[panelIndex] = !isExpanded;
        });
      },
      children: _buildSubcategoryPanels(),
    );
  }
  
  // 확장 패널 상태 관리
  final Map<int, bool> _expansionStates = {};
  
  // 서브 카테고리 패널 목록 생성
  List<ExpansionPanel> _buildSubcategoryPanels() {
    final List<ExpansionPanel> panels = [];
    final mainCategories = CategoryConstants.mainCategories;
    
    for (int i = 0; i < mainCategories.length; i++) {
      final mainCategory = mainCategories[i];
      final subcategories = CategoryConstants.getSubcategories(mainCategory.id);
      
      if (subcategories.isEmpty) continue;
      
      final isExpanded = _expansionStates[i] ?? false;
      
      panels.add(
        ExpansionPanel(
          headerBuilder: (context, isExpanded) {
            return ListTile(
              title: Text(
                mainCategory.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: Icon(
                mainCategory.icon,
                color: Colors.black87,
              ),
            );
          },
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subcategories.map((subCategory) {
                final isSelected = _selectedCategories.contains(subCategory.id);
                
                return ChoiceChip(
                  label: Text(subCategory.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCategories.add(subCategory.id);
                      } else {
                        _selectedCategories.remove(subCategory.id);
                      }
                    });
                  },
                  selectedColor: Colors.black12,
                  backgroundColor: Colors.grey[100],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black87 : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  avatar: Icon(
                    subCategory.icon,
                    size: 18,
                    color: isSelected ? Colors.black87 : Colors.grey[600],
                  ),
                );
              }).toList(),
            ),
          ),
          isExpanded: isExpanded,
          canTapOnHeader: true,
        ),
      );
    }
    
    return panels;
  }
  
  // 카테고리 카드 위젯
  Widget _buildCategoryCard({
    required CategoryData category,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.black.withOpacity(0.05) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              category.icon,
              size: 32,
              color: isSelected ? Colors.black : Colors.grey[700],
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.black : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
// lib/screens/auth/category_preference_screen.dart의 _savePreferences 메서드 수정

Future<void> _savePreferences() async {
  if (_selectedCategories.length < _minCategories) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('최소 ${_minCategories}개 이상의 카테고리를 선택해주세요.')),
    );
    return;
  }
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    // 사용자 선호도 저장
    final prefProvider = Provider.of<UserPreferenceProvider>(context, listen: false);
    await prefProvider.savePreferredCategories(_selectedCategories.toList());
    
    // 첫 로그인 상태 업데이트
    if (widget.isFirstLogin) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.updateFirstLoginStatus(false);
      
      // 사용자별 첫 로그인 상태도 직접 업데이트 (이중 보호)
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null && userId.isNotEmpty) {
        final String userFirstLoginKey = 'user_first_login_$userId';
        await prefs.setBool(userFirstLoginKey, false);
        await prefs.setBool('is_first_login', false);
        print('카테고리 선택 완료: 사용자 $userId의 첫 로그인 상태를 false로 영구 설정');
      }
    }
    
    // 완료 알림
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선호 카테고리가 저장되었습니다.')),
      );
    }
    
    // 첫 로그인인 경우 홈 화면으로 이동, 아니면 이전 화면으로 돌아가기
    if (widget.isFirstLogin) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainNavigation()),
          );
      }
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
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
}
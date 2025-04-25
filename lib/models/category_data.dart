// lib/models/category_data.dart
import 'package:flutter/material.dart';

class CategoryData {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String foursquareId;
  
  const CategoryData({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.foursquareId,
  });
}

class CategoryConstants {
  // 주요 카테고리 상수
  static const String FOOD = 'food';
  static const String CAFE = 'cafe';
  static const String SHOPPING = 'shopping';
  static const String CULTURE = 'culture';
  static const String ENTERTAINMENT = 'entertainment';
  static const String ACCOMMODATION = 'accommodation';
  static const String OUTDOOR = 'outdoor';
  static const String NIGHTLIFE = 'nightlife';
  static const String HEALTH = 'health';
  static const String EDUCATION = 'education';
  static const String TRANSPORTATION = 'transportation';
  
  // 확장된 카테고리 맵 (ID를 키로 사용)
  static final Map<String, CategoryData> categories = {
    // 음식점 카테고리
    FOOD: CategoryData(
      id: FOOD,
      name: '음식점',
      description: '다양한 음식점과 레스토랑',
      icon: Icons.restaurant,
      foursquareId: '13065',
    ),
    'korean_food': CategoryData(
      id: 'korean_food',
      name: '한식',
      description: '한국 전통 음식점',
      icon: Icons.ramen_dining,
      foursquareId: '13072',
    ),
    'japanese_food': CategoryData(
      id: 'japanese_food',
      name: '일식',
      description: '스시, 라멘 등 일본 음식점',
      icon: Icons.set_meal,
      foursquareId: '13080',
    ),
    'chinese_food': CategoryData(
      id: 'chinese_food',
      name: '중식',
      description: '중국 요리 전문점',
      icon: Icons.lunch_dining,
      foursquareId: '13073',
    ),
    'western_food': CategoryData(
      id: 'western_food',
      name: '양식',
      description: '이탈리안, 프렌치 등 서양 음식점',
      icon: Icons.local_pizza,
      foursquareId: '13076', // Italian category
    ),
    'fastfood': CategoryData(
      id: 'fastfood',
      name: '패스트푸드',
      description: '햄버거, 치킨 등 빠른 음식점',
      icon: Icons.fastfood,
      foursquareId: '13145',
    ),
    
    // 카페 카테고리
    CAFE: CategoryData(
      id: CAFE,
      name: '카페',
      description: '커피, 디저트 등을 즐길 수 있는 공간',
      icon: Icons.coffee,
      foursquareId: '13032',
    ),
    'dessert': CategoryData(
      id: 'dessert',
      name: '디저트',
      description: '케이크, 베이커리 등 달콤한 디저트',
      icon: Icons.cake,
      foursquareId: '13040',
    ),
    'tea': CategoryData(
      id: 'tea',
      name: '티룸',
      description: '전통적인 차를 즐길 수 있는 곳',
      icon: Icons.emoji_food_beverage,
      foursquareId: '13034', // Tea Room category
    ),
    
    // 쇼핑 카테고리
    SHOPPING: CategoryData(
      id: SHOPPING,
      name: '쇼핑',
      description: '다양한 상품을 구매할 수 있는 장소',
      icon: Icons.shopping_bag,
      foursquareId: '17000',
    ),
    'mall': CategoryData(
      id: 'mall',
      name: '쇼핑몰',
      description: '대형 쇼핑 센터 및 복합 쇼핑몰',
      icon: Icons.local_mall,
      foursquareId: '17015',
    ),
    'fashion': CategoryData(
      id: 'fashion',
      name: '패션',
      description: '의류, 액세서리 등 패션 아이템',
      icon: Icons.checkroom,
      foursquareId: '17020',
    ),
    'electronics': CategoryData(
      id: 'electronics',
      name: '전자제품',
      description: '가전, IT 기기 등 전자제품 판매점',
      icon: Icons.phone_android,
      foursquareId: '17061',
    ),
    'market': CategoryData(
      id: 'market',
      name: '시장',
      description: '전통시장 및 특산물 시장',
      icon: Icons.storefront,
      foursquareId: '17047',
    ),
    
    // 문화 카테고리
    CULTURE: CategoryData(
      id: CULTURE,
      name: '문화',
      description: '박물관, 미술관 등 문화 공간',
      icon: Icons.museum,
      foursquareId: '10000',
    ),
    'museum': CategoryData(
      id: 'museum',
      name: '박물관',
      description: '역사, 과학 등 다양한 전시를 볼 수 있는 박물관',
      icon: Icons.museum,
      foursquareId: '10027',
    ),
    'gallery': CategoryData(
      id: 'gallery',
      name: '미술관',
      description: '미술 작품을 감상할 수 있는 갤러리',
      icon: Icons.palette,
      foursquareId: '10022',
    ),
    'historic_site': CategoryData(
      id: 'historic_site',
      name: '역사 유적지',
      description: '역사적 가치가 있는 장소와 건물',
      icon: Icons.account_balance,
      foursquareId: '10047',
    ),
    
    // 엔터테인먼트 카테고리
    ENTERTAINMENT: CategoryData(
      id: ENTERTAINMENT,
      name: '엔터테인먼트',
      description: '영화관, 공연장 등 즐길 거리',
      icon: Icons.movie,
      foursquareId: '10035',
    ),
    'movie_theater': CategoryData(
      id: 'movie_theater',
      name: '영화관',
      description: '최신 영화를 관람할 수 있는 곳',
      icon: Icons.movie_filter,
      foursquareId: '10024',
    ),
    'concert_hall': CategoryData(
      id: 'concert_hall',
      name: '공연장',
      description: '음악, 연극 등 공연을 관람하는 장소',
      icon: Icons.music_note,
      foursquareId: '10028',
    ),
    'amusement_park': CategoryData(
      id: 'amusement_park',
      name: '놀이공원',
      description: '놀이기구와 어트랙션이 있는 공원',
      icon: Icons.attractions,
      foursquareId: '10001',
    ),
    'game': CategoryData(
      id: 'game',
      name: '게임센터',
      description: '오락실, PC방 등 게임을 즐길 수 있는 곳',
      icon: Icons.sports_esports,
      foursquareId: '10022', // Gaming Cafe
    ),
    
    // 숙박 카테고리
    ACCOMMODATION: CategoryData(
      id: ACCOMMODATION,
      name: '숙박',
      description: '호텔, 게스트하우스 등 숙박 시설',
      icon: Icons.hotel,
      foursquareId: '19014',
    ),
    'hotel': CategoryData(
      id: 'hotel',
      name: '호텔',
      description: '고급 서비스를 제공하는 숙박 시설',
      icon: Icons.hotel,
      foursquareId: '19014',
    ),
    'guesthouse': CategoryData(
      id: 'guesthouse',
      name: '게스트하우스',
      description: '저렴하고 편안한 숙소',
      icon: Icons.house,
      foursquareId: '19011',
    ),
    
    // 아웃도어 카테고리
    OUTDOOR: CategoryData(
      id: OUTDOOR,
      name: '아웃도어',
      description: '공원, 산책로 등 야외 활동',
      icon: Icons.park,
      foursquareId: '16000',
    ),
    'park': CategoryData(
      id: 'park',
      name: '공원',
      description: '도심 속 자연을 즐길 수 있는 공원',
      icon: Icons.nature_people,
      foursquareId: '16010',
    ),
    'hiking': CategoryData(
      id: 'hiking',
      name: '등산로',
      description: '등산과 하이킹을 즐길 수 있는 코스',
      icon: Icons.terrain,
      foursquareId: '16019',
    ),
    'beach': CategoryData(
      id: 'beach',
      name: '해변',
      description: '아름다운 해변과 해안가',
      icon: Icons.beach_access,
      foursquareId: '16049',
    ),
    
    // 나이트라이프 카테고리
    NIGHTLIFE: CategoryData(
      id: NIGHTLIFE,
      name: '나이트라이프',
      description: '바, 클럽 등 밤의 즐길 거리',
      icon: Icons.nightlife,
      foursquareId: '14000',
    ),
    'bar': CategoryData(
      id: 'bar',
      name: '바',
      description: '칵테일, 맥주 등을 즐길 수 있는 장소',
      icon: Icons.local_bar,
      foursquareId: '14003',
    ),
    'club': CategoryData(
      id: 'club',
      name: '클럽',
      description: '음악과 춤을 즐길 수 있는 나이트클럽',
      icon: Icons.celebration,
      foursquareId: '14004',
    ),
    
    // 건강 카테고리
    HEALTH: CategoryData(
      id: HEALTH,
      name: '건강',
      description: '병원, 약국, 피트니스 등 건강 관련 장소',
      icon: Icons.local_hospital,
      foursquareId: '15000',
    ),
    'hospital': CategoryData(
      id: 'hospital',
      name: '병원',
      description: '종합병원 및 의원',
      icon: Icons.local_hospital,
      foursquareId: '15014',
    ),
    'pharmacy': CategoryData(
      id: 'pharmacy',
      name: '약국',
      description: '의약품을 구매할 수 있는 약국',
      icon: Icons.local_pharmacy,
      foursquareId: '15035',
    ),
    'fitness': CategoryData(
      id: 'fitness',
      name: '피트니스',
      description: '체육관 및 피트니스 센터',
      icon: Icons.fitness_center,
      foursquareId: '15013',
    ),
    
    // 교육 카테고리
    EDUCATION: CategoryData(
      id: EDUCATION,
      name: '교육',
      description: '학교, 도서관 등 교육 관련 장소',
      icon: Icons.school,
      foursquareId: '12000',
    ),
    'library': CategoryData(
      id: 'library',
      name: '도서관',
      description: '책을 읽고 공부할 수 있는 공간',
      icon: Icons.local_library,
      foursquareId: '12009',
    ),
    'bookstore': CategoryData(
      id: 'bookstore',
      name: '서점',
      description: '다양한 책을 구매할 수 있는 서점',
      icon: Icons.menu_book,
      foursquareId: '17038',
    ),
    
    // 교통 카테고리
    TRANSPORTATION: CategoryData(
      id: TRANSPORTATION,
      name: '교통',
      description: '대중교통, 주차장 등 교통 관련 장소',
      icon: Icons.directions_bus,
      foursquareId: '19000',
    ),
    'subway': CategoryData(
      id: 'subway',
      name: '지하철역',
      description: '지하철을 이용할 수 있는 역',
      icon: Icons.subway,
      foursquareId: '19026',
    ),
    'bus_stop': CategoryData(
      id: 'bus_stop',
      name: '버스정류장',
      description: '버스를 탈 수 있는 정류장',
      icon: Icons.directions_bus,
      foursquareId: '19021',
    ),
    'parking': CategoryData(
      id: 'parking',
      name: '주차장',
      description: '차량을 주차할 수 있는 공간',
      icon: Icons.local_parking,
      foursquareId: '19033',
    ),
    'gas_station': CategoryData(
      id: 'gas_station',
      name: '주유소',
      description: '연료를 보충할 수 있는 주유소',
      icon: Icons.local_gas_station,
      foursquareId: '19007',
    ),
  };
  
  // 대표 카테고리만 모은 리스트 (UI 메뉴 용도)
  static List<CategoryData> get mainCategories {
    return [
      categories[FOOD]!,
      categories[CAFE]!,
      categories[SHOPPING]!,
      categories[CULTURE]!,
      categories[ENTERTAINMENT]!,
      categories[ACCOMMODATION]!,
      categories[OUTDOOR]!,
      categories[NIGHTLIFE]!,
      categories[HEALTH]!,
      categories[EDUCATION]!,
      categories[TRANSPORTATION]!,
    ];
  }
  
  // 특정 메인 카테고리의 하위 카테고리 가져오기
  static List<CategoryData> getSubcategories(String mainCategoryId) {
    return categories.values.where((category) {
      // 메인 카테고리가 아니면서 ID가 mainCategoryId로 시작하는 카테고리
      return category.id != mainCategoryId && 
             category.id.startsWith(mainCategoryId.split('_')[0]);
    }).toList();
  }
  
  // 카테고리 ID로 CategoryData 가져오기
  static CategoryData? getCategoryById(String categoryId) {
    return categories[categoryId];
  }
  
  // 카테고리 이름으로 CategoryData 찾기
  static CategoryData? getCategoryByName(String name) {
    try {
      return categories.values.firstWhere(
        (category) => category.name == name
      );
    } catch (e) {
      return null;
    }
  }
  
  // foursquare ID를 이용해 카테고리 찾기
  static List<String> getCategoryIdsByFoursquareId(String foursquareId) {
    return categories.entries
        .where((entry) => entry.value.foursquareId == foursquareId)
        .map((entry) => entry.key)
        .toList();
  }
}
/// PlaceSearchScreen → pop(SelectedPlace) 형태로 결과 반환.
///
/// 세 가지 케이스:
/// - SelectedAliasPlace: 사용자가 등록한 "내 장소"에서 선택 (BE userPlaceId)
/// - SelectedExternalPlace: 카카오 검색/지도 핀 선택 (BE externalPlace, SPECIFIC)
/// - SelectedGenericKeyword: 검색 결과 화면에서 키워드 자체를 포괄 장소로 등록 (BE placeText, GENERIC)
sealed class SelectedPlace {
  const SelectedPlace({
    required this.userLatitude,
    required this.userLongitude,
  });

  /// 사용자 현재 위치 (검색 화면이 진입 시 GPS로 가져온 값, 권한 없으면 null)
  /// BE 슬롯 재계산의 PostGIS 실거리 계산에 사용됨.
  final double? userLatitude;
  final double? userLongitude;
}

/// 사용자가 사전 등록한 "내 장소" 선택 결과 (ALIAS).
class SelectedAliasPlace extends SelectedPlace {
  const SelectedAliasPlace({
    required this.userPlaceId,
    required this.aliasName,
    required this.placeLatitude,
    required this.placeLongitude,
    super.userLatitude,
    super.userLongitude,
  });

  final int userPlaceId;
  final String aliasName;
  final double placeLatitude;
  final double placeLongitude;
}

/// 카카오 검색 결과 또는 지도 핀 선택 결과 (SPECIFIC).
/// kakaoPlaceId는 키워드 검색 결과만 존재, 지도 핀 직접 선택 시 null.
class SelectedExternalPlace extends SelectedPlace {
  const SelectedExternalPlace({
    this.kakaoPlaceId,
    required this.placeName,
    required this.placeLatitude,
    required this.placeLongitude,
    this.addressName,
    this.roadAddressName,
    this.phone,
    this.categoryGroupCode,
    this.categoryGroupName,
    this.placeUrl,
    super.userLatitude,
    super.userLongitude,
  });

  final String? kakaoPlaceId;
  final String placeName;
  final double placeLatitude;
  final double placeLongitude;
  final String? addressName;
  final String? roadAddressName;
  final String? phone;
  final String? categoryGroupCode;
  final String? categoryGroupName;
  final String? placeUrl;
}

/// 검색 결과 화면에서 "이 검색어로 포괄 장소 등록" 버튼으로 선택된 결과.
/// BE는 placeText만 받아 카카오 재검색 → 후보 풀 자동 구성 → GENERIC 전환한다.
class SelectedGenericKeyword extends SelectedPlace {
  const SelectedGenericKeyword({
    required this.keyword,
    super.userLatitude,
    super.userLongitude,
  });

  /// 사용자가 검색한 키워드 (예: "다이소", "스타벅스"). BE placeText로 전달.
  final String keyword;
}

/// Kakao Local API 키워드 검색 결과 단건 모델.
class KakaoPlaceItem {
  const KakaoPlaceItem({
    required this.id,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    this.categoryGroupCode,
    this.categoryGroupName,
    this.phone,
    this.addressName,
    this.roadAddressName,
    this.placeUrl,
    this.distance,
  });

  final String id;
  final String placeName;
  final double latitude;
  final double longitude;
  final String? categoryGroupCode;
  final String? categoryGroupName;
  final String? phone;
  final String? addressName;
  final String? roadAddressName;
  final String? placeUrl;
  final int? distance; // 미터 단위, 현재 위치 기준

  /// BE 프록시(/api/v1/places/search) 응답의 단건 형태에서 파싱.
  /// BE가 카카오 응답을 camelCase + 숫자 타입으로 정규화해서 전달.
  factory KakaoPlaceItem.fromJson(Map<String, dynamic> json) {
    return KakaoPlaceItem(
      id: json['id'] as String,
      placeName: json['placeName'] as String,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      categoryGroupCode: json['categoryGroupCode'] as String?,
      categoryGroupName: json['categoryGroupName'] as String?,
      phone: json['phone'] as String?,
      addressName: json['addressName'] as String?,
      roadAddressName: json['roadAddressName'] as String?,
      placeUrl: json['placeUrl'] as String?,
      distance: (json['distanceMeter'] as num?)?.toInt(),
    );
  }

  /// userLatitude/userLongitude는 호출자가 채워야 함 (검색 화면이 가진 GPS 좌표).
  SelectedExternalPlace toSelectedPlace({
    double? userLatitude,
    double? userLongitude,
  }) =>
      SelectedExternalPlace(
        kakaoPlaceId: id,
        placeName: placeName,
        placeLatitude: latitude,
        placeLongitude: longitude,
        addressName: addressName,
        roadAddressName: roadAddressName,
        phone: phone?.isNotEmpty == true ? phone : null,
        categoryGroupCode: categoryGroupCode,
        categoryGroupName: categoryGroupName,
        placeUrl: placeUrl,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );

  String get displayDistance {
    if (distance == null) return '';
    if (distance! < 1000) return '${distance}m';
    return '${(distance! / 1000).toStringAsFixed(1)}km';
  }
}

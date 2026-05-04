/// Kakao 장소 검색에서 사용자가 선택한 장소 정보.
/// PlaceSearchScreen → pop(SelectedKakaoPlace) 형태로 결과 반환.
class SelectedKakaoPlace {
  const SelectedKakaoPlace({
    required this.kakaoPlaceId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.roadAddress,
    this.phone,
    this.categoryGroupCode,
    this.categoryGroupName,
    this.placeUrl,
  });

  final String kakaoPlaceId;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? roadAddress;
  final String? phone;
  final String? categoryGroupCode;
  final String? categoryGroupName;
  final String? placeUrl;
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

  factory KakaoPlaceItem.fromJson(Map<String, dynamic> json) {
    return KakaoPlaceItem(
      id: json['id'] as String,
      placeName: json['place_name'] as String,
      latitude: double.tryParse(json['y'] as String? ?? '') ?? 0.0,
      longitude: double.tryParse(json['x'] as String? ?? '') ?? 0.0,
      categoryGroupCode: json['category_group_code'] as String?,
      categoryGroupName: json['category_group_name'] as String?,
      phone: json['phone'] as String?,
      addressName: json['address_name'] as String?,
      roadAddressName: json['road_address_name'] as String?,
      placeUrl: json['place_url'] as String?,
      distance: int.tryParse(json['distance'] as String? ?? ''),
    );
  }

  SelectedKakaoPlace toSelectedPlace() => SelectedKakaoPlace(
        kakaoPlaceId: id,
        name: placeName,
        latitude: latitude,
        longitude: longitude,
        address: addressName,
        roadAddress: roadAddressName,
        phone: phone?.isNotEmpty == true ? phone : null,
        categoryGroupCode: categoryGroupCode,
        categoryGroupName: categoryGroupName,
        placeUrl: placeUrl,
      );

  String get displayDistance {
    if (distance == null) return '';
    if (distance! < 1000) return '${distance}m';
    return '${(distance! / 1000).toStringAsFixed(1)}km';
  }
}

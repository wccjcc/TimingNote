class UserPlace {
  const UserPlace({
    required this.id,
    required this.aliasName,
    required this.placeId,
    required this.placeName,
    required this.roadAddress,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  final int id;
  final String aliasName;
  final int placeId;
  final String placeName;
  final String? roadAddress;
  final String? address;
  final double latitude;
  final double longitude;
  final DateTime? createdAt;

  String get displayAddress {
    if (roadAddress != null && roadAddress!.trim().isNotEmpty) {
      return roadAddress!;
    }
    if (address != null && address!.trim().isNotEmpty) {
      return address!;
    }
    return '주소 정보 없음';
  }

  factory UserPlace.fromJson(Map<String, dynamic> json) {
    return UserPlace(
      id: (json['id'] as num).toInt(),
      aliasName: (json['aliasName'] ?? '') as String,
      placeId: (json['placeId'] as num).toInt(),
      placeName: (json['placeName'] ?? '') as String,
      roadAddress: json['roadAddress'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

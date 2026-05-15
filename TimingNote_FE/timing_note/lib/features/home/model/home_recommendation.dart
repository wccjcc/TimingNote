class HomeRecommendationItem {
  const HomeRecommendationItem({
    required this.groupId,
    required this.todoId,
    required this.rank,
    required this.todoCount,
    required this.category,
    required this.title,
    required this.place,
    required this.distanceMeters,
    required this.placeLat,
    required this.placeLng,
  });

  final int groupId;
  final int todoId;
  final int rank;
  final int todoCount;
  final String category;
  final String title;
  final String place;
  final double distanceMeters;
  final double placeLat;
  final double placeLng;
}

class HomeRecommendationResult {
  const HomeRecommendationResult({
    required this.currentLocationLabel,
    required this.items,
  });

  final String currentLocationLabel;
  final List<HomeRecommendationItem> items;
}

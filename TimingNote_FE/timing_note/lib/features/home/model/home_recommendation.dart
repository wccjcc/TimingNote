class HomeRecommendationItem {
  const HomeRecommendationItem({
    required this.todoId,
    required this.category,
    required this.title,
    required this.place,
    required this.distanceMeters,
    required this.placeLat,
    required this.placeLng,
  });

  final int todoId;
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

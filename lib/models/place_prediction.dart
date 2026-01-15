class PlacePrediction {
  final String description;
  final String placeId;

  PlacePrediction({
    required this.description,
    required this.placeId,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      description: (json["description"] ?? "").toString(),
      placeId: (json["place_id"] ?? "").toString(),
    );
  }
}

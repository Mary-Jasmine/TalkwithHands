class BasicWord {
  final String id;
  final String key;
  final String title;
  final String category;
  final String imageAsset;
  final String imageUrl;
  final String videoAsset;
  final String videoUrl;
  final String description;
  final int sortOrder;

  const BasicWord({
    required this.id,
    required this.key,
    required this.title,
    required this.category,
    required this.imageAsset,
    required this.imageUrl,
    required this.videoAsset,
    required this.videoUrl,
    required this.description,
    required this.sortOrder,
  });

  factory BasicWord.fromJson(Map<String, dynamic> json) {
    return BasicWord(
      id: (json['id'] ?? '').toString(),
      key: (json['key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      imageAsset: (json['image_asset'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      videoAsset: (json['video_asset'] ?? '').toString(),
      videoUrl: (json['video_url'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      sortOrder: int.tryParse((json['sort_order'] ?? '').toString()) ?? 0,
    );
  }
}

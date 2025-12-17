class EquipmentAd {
  final String id;
  final int? userId;
  final String title;
  final String description;
  final int price;
  final String location;
  final String phoneNumber;
  final List<String> images;
  final List<String> videos;
  final String condition; // 'new' or 'used'
  final bool isApproved;
  final DateTime createdAt;

  EquipmentAd({
    required this.id,
    this.userId,
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    required this.phoneNumber,
    required this.images,
    required this.videos,
    this.condition = 'used',
    this.isApproved = false,
    required this.createdAt,
  });

  factory EquipmentAd.fromJson(Map<String, dynamic> json) {
    return EquipmentAd(
      id: json['id']?.toString() ?? '',
      userId: json['userId'] ?? json['user_id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      price: json['price'] ?? 0,
      location: json['location'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone_number'] ?? '',
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      videos: json['videos'] != null ? List<String>.from(json['videos']) : [],
      condition: json['condition'] ?? 'used',
      isApproved: json['isApproved'] ?? json['is_approved'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

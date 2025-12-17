enum BakeryAdType { sale, rent }

class BakeryAd {
  final String id;
  final int? userId;
  final String title;
  final String description;
  final BakeryAdType type;
  final int? salePrice;
  final int? rentDeposit;
  final int? monthlyRent;
  final String location;
  final String phoneNumber;
  final List<String> images;
  final double? lat;
  final double? lng;
  final int? flourQuota; // سهمیه آرد (کیسه در ماه)
  final int? breadPrice; // قیمت نان (تومان)
  final bool isApproved;
  final int views;
  final DateTime createdAt;

  BakeryAd({
    required this.id,
    this.userId,
    required this.title,
    required this.description,
    required this.type,
    this.salePrice,
    this.rentDeposit,
    this.monthlyRent,
    required this.location,
    required this.phoneNumber,
    required this.images,
    this.lat,
    this.lng,
    this.flourQuota,
    this.breadPrice,
    this.isApproved = false,
    this.views = 0,
    required this.createdAt,
  });

  factory BakeryAd.fromJson(Map<String, dynamic> json) {
    // Parse lat/lng - can be string or number
    double? parseLat = json['lat'] != null 
        ? (json['lat'] is String ? double.tryParse(json['lat']) : json['lat']?.toDouble())
        : null;
    double? parseLng = json['lng'] != null 
        ? (json['lng'] is String ? double.tryParse(json['lng']) : json['lng']?.toDouble())
        : null;
    
    return BakeryAd(
      id: json['id']?.toString() ?? '',
      userId: json['userId'] ?? json['user_id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] == 'sale' ? BakeryAdType.sale : BakeryAdType.rent,
      salePrice: json['salePrice'] ?? json['sale_price'],
      rentDeposit: json['rentDeposit'] ?? json['rent_deposit'],
      monthlyRent: json['monthlyRent'] ?? json['monthly_rent'],
      location: json['location'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone_number'] ?? '',
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      lat: parseLat,
      lng: parseLng,
      flourQuota: json['flourQuota'] ?? json['flour_quota'],
      breadPrice: json['breadPrice'] ?? json['bread_price'],
      isApproved: json['isApproved'] ?? json['is_approved'] ?? false,
      views: json['views'] ?? 0,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'type': type == BakeryAdType.sale ? 'sale' : 'rent',
      'salePrice': salePrice,
      'rentDeposit': rentDeposit,
      'monthlyRent': monthlyRent,
      'location': location,
      'phoneNumber': phoneNumber,
      'images': images,
      'lat': lat,
      'lng': lng,
    };
  }
}

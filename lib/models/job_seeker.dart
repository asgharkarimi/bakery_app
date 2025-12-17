class JobSeeker {
  final String id;
  final int? userId;
  final String name;
  final String? profileImage;
  final int? age;
  final int experience;
  final List<String> skills;
  final String location;
  final int expectedSalary;
  final String? phoneNumber;
  final String? description;
  final DateTime createdAt;

  JobSeeker({
    required this.id,
    this.userId,
    required this.name,
    this.profileImage,
    this.age,
    this.experience = 0,
    required this.skills,
    required this.location,
    required this.expectedSalary,
    this.phoneNumber,
    this.description,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // برای سازگاری با کد قبلی
  String get firstName => name.split(' ').first;
  String get lastName => name.split(' ').length > 1 ? name.split(' ').last : '';
  String get fullName => name;
  double get rating => 0.0;
  bool get isMarried => false;
  bool get isSmoker => false;
  bool get hasAddiction => false;

  factory JobSeeker.fromJson(Map<String, dynamic> json) {
    // عکس پروفایل از user یا از خود کارجو
    String? profileImg = json['profileImage'] ?? json['profile_image'];
    if (profileImg == null && json['user'] != null) {
      profileImg = json['user']['profileImage'] ?? json['user']['profile_image'];
    }
    
    return JobSeeker(
      id: json['id']?.toString() ?? '',
      userId: json['userId'] ?? json['user_id'],
      name: json['name'] ?? '',
      profileImage: profileImg,
      age: json['age'],
      experience: json['experience'] ?? 0,
      skills: json['skills'] != null ? List<String>.from(json['skills']) : [],
      location: json['location'] ?? '',
      expectedSalary: json['expectedSalary'] ?? json['expected_salary'] ?? 0,
      phoneNumber: json['phoneNumber'] ?? json['phone_number'],
      description: json['description'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'experience': experience,
      'skills': skills,
      'location': location,
      'expectedSalary': expectedSalary,
      'phoneNumber': phoneNumber,
      'description': description,
      'profileImage': profileImage,
    };
  }
}

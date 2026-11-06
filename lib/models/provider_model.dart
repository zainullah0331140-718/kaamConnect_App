class WorkImage {
  final int id;
  final String imagePath;
  final int position;

  WorkImage({
    required this.id,
    required this.imagePath,
    this.position = 0,
  });

  factory WorkImage.fromJson(Map<String, dynamic> json) {
    return WorkImage(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      imagePath: json['image_path'] ?? '',
      position: json['position'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_path': imagePath,
      'position': position,
    };
  }
}

class ServiceItem {
  final int id;
  final int providerId;
  final int categoryId;
  final String? categoryName;
  final String? categorySlug;
  final String title;
  final String? description;
  final double? priceMin;
  final double? priceMax;
  final bool isActive;

  ServiceItem({
    required this.id,
    required this.providerId,
    required this.categoryId,
    this.categoryName,
    this.categorySlug,
    required this.title,
    this.description,
    this.priceMin,
    this.priceMax,
    this.isActive = true,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      providerId: json['provider_id'] is int ? json['provider_id'] : int.parse(json['provider_id'].toString()),
      categoryId: json['category_id'] is int ? json['category_id'] : int.parse(json['category_id'].toString()),
      categoryName: json['category_name'],
      categorySlug: json['category_slug'],
      title: json['title'] ?? '',
      description: json['description'],
      priceMin: json['price_min'] != null ? (json['price_min'] as num).toDouble() : null,
      priceMax: json['price_max'] != null ? (json['price_max'] as num).toDouble() : null,
      isActive: json['is_active'] ?? true,
    );
  }

  String get formattedPrice {
    if (priceMin != null && priceMax != null) {
      if (priceMin == priceMax) {
        return 'PKR ${priceMin!.toStringAsFixed(0)}';
      }
      return 'PKR ${priceMin!.toStringAsFixed(0)} - ${priceMax!.toStringAsFixed(0)}';
    } else if (priceMin != null) {
      return 'From PKR ${priceMin!.toStringAsFixed(0)}';
    } else if (priceMax != null) {
      return 'Up to PKR ${priceMax!.toStringAsFixed(0)}';
    }
    return 'Contact for quote';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider_id': providerId,
      'category_id': categoryId,
      'category_name': categoryName,
      'category_slug': categorySlug,
      'title': title,
      'description': description,
      'price_min': priceMin,
      'price_max': priceMax,
      'is_active': isActive,
    };
  }
}

class ProviderSummary {
  final int id;
  final int userId;
  final String businessName;
  final String providerName;
  final String? description;
  final int experienceYears;
  final String? city;
  final String? area;
  final String? profileImage;
  final String verificationStatus; // 'verified', 'pending', 'rejected'
  final double averageRating;
  final int reviewCount;
  final List<ServiceItem> services;

  ProviderSummary({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.providerName,
    this.description,
    this.experienceYears = 0,
    this.city,
    this.area,
    this.profileImage,
    required this.verificationStatus,
    this.averageRating = 0.0,
    this.reviewCount = 0,
    this.services = const [],
  });

  bool get isVerified => verificationStatus == 'verified';
  bool get isPending => verificationStatus == 'pending';

  String get locationString {
    if (area != null && area!.isNotEmpty && city != null && city!.isNotEmpty) {
      return '$area, $city';
    }
    return city ?? area ?? 'Pakistan';
  }

  factory ProviderSummary.fromJson(Map<String, dynamic> json) {
    var rawServices = json['services'] as List? ?? [];
    return ProviderSummary(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      userId: json['user_id'] is int ? json['user_id'] : int.parse(json['user_id'].toString()),
      businessName: json['business_name'] ?? '',
      providerName: json['provider_name'] ?? '',
      description: json['description'],
      experienceYears: json['experience_years'] ?? 0,
      city: json['city'],
      area: json['area'],
      profileImage: json['profile_image'],
      verificationStatus: json['verification_status'] ?? 'pending',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] ?? 0,
      services: rawServices.map((s) => ServiceItem.fromJson(s)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'business_name': businessName,
      'provider_name': providerName,
      'description': description,
      'experience_years': experienceYears,
      'city': city,
      'area': area,
      'profile_image': profileImage,
      'verification_status': verificationStatus,
      'average_rating': averageRating,
      'review_count': reviewCount,
      'services': services.map((s) => s.toJson()).toList(),
    };
  }
}

class ProviderDetail extends ProviderSummary {
  final String? address;
  final String? contactPhone;
  final String? whatsappNumber;
  final String? whatsappLink;
  final String? callLink;
  final bool isFavorite;
  final List<WorkImage> workImages;
  final Map<String, dynamic> reviewSummary;

  ProviderDetail({
    required super.id,
    required super.userId,
    required super.businessName,
    required super.providerName,
    super.description,
    super.experienceYears,
    super.city,
    super.area,
    super.profileImage,
    required super.verificationStatus,
    super.averageRating,
    super.reviewCount,
    super.services,
    this.address,
    this.contactPhone,
    this.whatsappNumber,
    this.whatsappLink,
    this.callLink,
    this.isFavorite = false,
    this.workImages = const [],
    this.reviewSummary = const {},
  });

  factory ProviderDetail.fromJson(Map<String, dynamic> json) {
    var rawServices = json['services'] as List? ?? [];
    var rawImages = json['work_images'] as List? ?? [];

    return ProviderDetail(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      userId: json['user_id'] is int ? json['user_id'] : int.parse(json['user_id'].toString()),
      businessName: json['business_name'] ?? '',
      providerName: json['provider_name'] ?? '',
      description: json['description'],
      experienceYears: json['experience_years'] ?? 0,
      city: json['city'],
      area: json['area'],
      profileImage: json['profile_image'],
      verificationStatus: json['verification_status'] ?? 'pending',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] ?? 0,
      services: rawServices.map((s) => ServiceItem.fromJson(s)).toList(),
      address: json['address'],
      contactPhone: json['contact_phone'],
      whatsappNumber: json['whatsapp_number'],
      whatsappLink: json['whatsapp_link'],
      callLink: json['call_link'],
      isFavorite: json['is_favorite'] ?? false,
      workImages: rawImages.map((img) => WorkImage.fromJson(img)).toList(),
      reviewSummary: json['review_summary'] is Map<String, dynamic>
          ? json['review_summary']
          : {},
    );
  }
}

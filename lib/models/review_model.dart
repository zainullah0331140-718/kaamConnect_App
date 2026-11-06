class ReviewModel {
  final int id;
  final int providerId;
  final String providerName;
  final String? providerImage;
  final int customerId;
  final String customerName;
  final int rating;
  final String? comment;
  final String status;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    this.providerImage,
    required this.customerId,
    required this.customerName,
    required this.rating,
    this.comment,
    required this.status,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      providerId: json['provider_id'] is int ? json['provider_id'] : int.parse(json['provider_id'].toString()),
      providerName: json['provider_name'] ?? '',
      providerImage: json['provider_image'],
      customerId: json['customer_id'] is int ? json['customer_id'] : int.parse(json['customer_id'].toString()),
      customerName: json['customer_name'] ?? 'Customer',
      rating: json['rating'] is int ? json['rating'] : int.tryParse(json['rating'].toString()) ?? 5,
      comment: json['comment'],
      status: json['status'] ?? 'approved',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

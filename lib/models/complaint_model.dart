class ComplaintModel {
  final int id;
  final int providerId;
  final String? providerName;
  final int customerId;
  final String subject;
  final String description;
  final String status; // 'pending', 'resolved', 'dismissed'
  final DateTime createdAt;

  ComplaintModel({
    required this.id,
    required this.providerId,
    this.providerName,
    required this.customerId,
    required this.subject,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      providerId: json['provider_id'] is int ? json['provider_id'] : int.parse(json['provider_id'].toString()),
      providerName: json['provider_name'],
      customerId: json['customer_id'] is int ? json['customer_id'] : int.parse(json['customer_id'].toString()),
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

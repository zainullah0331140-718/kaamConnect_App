class AdvertisementModel {
  final int id;
  final int providerId;
  final String providerName;
  final String title;
  final String description;
  final String imagePath;
  final String destinationUrl;
  final bool isLive;

  AdvertisementModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.destinationUrl,
    this.isLive = true,
  });

  factory AdvertisementModel.fromJson(Map<String, dynamic> json) {
    return AdvertisementModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      providerId: json['provider_id'] is int ? json['provider_id'] : int.parse(json['provider_id'].toString()),
      providerName: json['provider_name'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imagePath: json['image_path'] ?? '',
      destinationUrl: json['destination_url'] ?? '',
      isLive: json['is_live'] ?? false,
    );
  }
}

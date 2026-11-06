import 'package:flutter/material.dart';

class CategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final bool isActive;
  final int providerCount;

  CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.isActive = true,
    this.providerCount = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      icon: json['icon'],
      isActive: json['is_active'] ?? true,
      providerCount: json['provider_count'] ?? 0,
    );
  }

  IconData get iconData {
    final key = '${icon ?? ''} $slug $name'.toLowerCase();
    if (key.contains('plumb') || key.contains('pipe') || key.contains('wrench') || key.contains('droplet')) {
      return Icons.plumbing;
    } else if (key.contains('elect') || key.contains('bolt') || key.contains('wire') || key.contains('lightning')) {
      return Icons.electrical_services;
    } else if (key.contains('carp') || key.contains('wood') || key.contains('hammer')) {
      return Icons.carpenter;
    } else if (key.contains('paint') || key.contains('brush')) {
      return Icons.format_paint;
    } else if (key.contains('ac') || key.contains('cool') || key.contains('hvac') || key.contains('snow')) {
      return Icons.ac_unit;
    } else if (key.contains('laptop') || key.contains('computer')) {
      return Icons.laptop_chromebook;
    } else if (key.contains('phone') || key.contains('mobile')) {
      return Icons.phone_android;
    } else if (key.contains('camera') || key.contains('cctv') || key.contains('security')) {
      return Icons.videocam;
    } else if (key.contains('clean')) {
      return Icons.cleaning_services;
    } else if (key.contains('appliance') || key.contains('repair')) {
      return Icons.home_repair_service;
    } else if (key.contains('solar')) {
      return Icons.solar_power;
    } else if (key.contains('pest')) {
      return Icons.pest_control;
    } else if (key.contains('garden') || key.contains('lawn')) {
      return Icons.yard;
    } else if (key.contains('mason') || key.contains('const')) {
      return Icons.foundation;
    } else if (key.contains('car') || key.contains('auto') || key.contains('mechanic')) {
      return Icons.directions_car;
    }
    return Icons.handyman;
  }
}

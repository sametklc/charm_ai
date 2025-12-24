import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/media_entity.dart';

/// AI Model data model
class AIModelModel extends AIModel {
  const AIModelModel({
    required super.id,
    required super.name,
    required super.description,
    required super.speed,
  });

  factory AIModelModel.fromJson(Map<String, dynamic> json) {
    return AIModelModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      speed: json['speed'] ?? 'medium',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'speed': speed,
    };
  }
}

/// Generated media data model
class GeneratedMediaModel extends GeneratedMediaEntity {
  const GeneratedMediaModel({
    required super.id,
    required super.userId,
    required super.type,
    required super.prompt,
    super.negativePrompt,
    required super.imageUrls,
    required super.model,
    required super.width,
    required super.height,
    required super.generationTime,
    required super.createdAt,
    super.isFavorite,
  });

  /// Create from API response
  factory GeneratedMediaModel.fromApiResponse({
    required String id,
    required String userId,
    required Map<String, dynamic> json,
    required String prompt,
    required String model,
    required int width,
    required int height,
  }) {
    final images = json['images'] as List<dynamic>? ?? [];
    
    return GeneratedMediaModel(
      id: id,
      userId: userId,
      type: MediaType.image,
      prompt: prompt,
      imageUrls: images.map((e) => e.toString()).toList(),
      model: json['model'] ?? model,
      width: width,
      height: height,
      generationTime: (json['generation_time'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.now(),
    );
  }

  /// Create from Firestore document
  factory GeneratedMediaModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return GeneratedMediaModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] == 'video' ? MediaType.video : MediaType.image,
      prompt: data['prompt'] ?? '',
      negativePrompt: data['negativePrompt'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      model: data['model'] ?? '',
      width: data['width'] ?? 1024,
      height: data['height'] ?? 1024,
      generationTime: (data['generationTime'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isFavorite: data['isFavorite'] ?? false,
    );
  }

  /// Create from entity
  factory GeneratedMediaModel.fromEntity(GeneratedMediaEntity entity) {
    return GeneratedMediaModel(
      id: entity.id,
      userId: entity.userId,
      type: entity.type,
      prompt: entity.prompt,
      negativePrompt: entity.negativePrompt,
      imageUrls: entity.imageUrls,
      model: entity.model,
      width: entity.width,
      height: entity.height,
      generationTime: entity.generationTime,
      createdAt: entity.createdAt,
      isFavorite: entity.isFavorite,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type == MediaType.video ? 'video' : 'image',
      'prompt': prompt,
      'negativePrompt': negativePrompt,
      'imageUrls': imageUrls,
      'model': model,
      'width': width,
      'height': height,
      'generationTime': generationTime,
      'createdAt': Timestamp.fromDate(createdAt),
      'isFavorite': isFavorite,
    };
  }

  /// Convert to entity
  GeneratedMediaEntity toEntity() {
    return GeneratedMediaEntity(
      id: id,
      userId: userId,
      type: type,
      prompt: prompt,
      negativePrompt: negativePrompt,
      imageUrls: imageUrls,
      model: model,
      width: width,
      height: height,
      generationTime: generationTime,
      createdAt: createdAt,
      isFavorite: isFavorite,
    );
  }

  @override
  GeneratedMediaModel copyWith({
    String? id,
    String? userId,
    MediaType? type,
    String? prompt,
    String? negativePrompt,
    List<String>? imageUrls,
    String? model,
    int? width,
    int? height,
    double? generationTime,
    DateTime? createdAt,
    bool? isFavorite,
  }) {
    return GeneratedMediaModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      prompt: prompt ?? this.prompt,
      negativePrompt: negativePrompt ?? this.negativePrompt,
      imageUrls: imageUrls ?? this.imageUrls,
      model: model ?? this.model,
      width: width ?? this.width,
      height: height ?? this.height,
      generationTime: generationTime ?? this.generationTime,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}


import 'package:equatable/equatable.dart';

/// Media type enum
enum MediaType { image, video }

/// Generation status enum
enum GenerationStatus { idle, generating, success, error }

/// AI Model for generation
class AIModel extends Equatable {
  final String id;
  final String name;
  final String description;
  final String speed; // fast, medium, slow

  const AIModel({
    required this.id,
    required this.name,
    required this.description,
    required this.speed,
  });

  @override
  List<Object?> get props => [id, name, description, speed];
}

/// Generated media entity
class GeneratedMediaEntity extends Equatable {
  final String id;
  final String userId;
  final MediaType type;
  final String prompt;
  final String? negativePrompt;
  final List<String> imageUrls;
  final String model;
  final int width;
  final int height;
  final double generationTime;
  final DateTime createdAt;
  final bool isFavorite;

  const GeneratedMediaEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.prompt,
    this.negativePrompt,
    required this.imageUrls,
    required this.model,
    required this.width,
    required this.height,
    required this.generationTime,
    required this.createdAt,
    this.isFavorite = false,
  });

  /// Get first image URL
  String? get firstImageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  /// Get image count
  int get imageCount => imageUrls.length;

  GeneratedMediaEntity copyWith({
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
    return GeneratedMediaEntity(
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

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        prompt,
        negativePrompt,
        imageUrls,
        model,
        width,
        height,
        generationTime,
        createdAt,
        isFavorite,
      ];
}

/// Image generation request parameters
class ImageGenerationParams extends Equatable {
  final String prompt;
  final String? negativePrompt;
  final int width;
  final int height;
  final int numOutputs;
  final String model;
  final double guidanceScale;
  final int numInferenceSteps;
  final int? seed;
  final String? referenceImageUrl; // Reference image for identity preservation (img2img)

  const ImageGenerationParams({
    required this.prompt,
    this.negativePrompt,
    this.width = 1024,
    this.height = 1024,
    this.numOutputs = 1,
    this.model = 'flux-schnell',
    this.guidanceScale = 7.5,
    this.numInferenceSteps = 28,
    this.seed,
    this.referenceImageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'negative_prompt': negativePrompt ?? '',
      'width': width,
      'height': height,
      'num_outputs': numOutputs,
      'model': model,
      'guidance_scale': guidanceScale,
      'num_inference_steps': numInferenceSteps,
      if (seed != null) 'seed': seed,
      if (referenceImageUrl != null) 'reference_image_url': referenceImageUrl,
    };
  }

  @override
  List<Object?> get props => [
        prompt,
        negativePrompt,
        width,
        height,
        numOutputs,
        model,
        guidanceScale,
        numInferenceSteps,
        seed,
        referenceImageUrl,
      ];
}




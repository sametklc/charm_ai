import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/helpers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/media_entity.dart';
import '../providers/media_controller.dart';
import '../providers/media_providers.dart';
import '../widgets/aspect_ratio_selector.dart';
import '../widgets/generation_result.dart';
import '../widgets/model_selector.dart';
import '../widgets/prompt_input.dart';

/// Media Generation Screen
class MediaGenerationScreen extends ConsumerStatefulWidget {
  const MediaGenerationScreen({super.key});

  @override
  ConsumerState<MediaGenerationScreen> createState() => _MediaGenerationScreenState();
}

class _MediaGenerationScreenState extends ConsumerState<MediaGenerationScreen> {
  final _promptController = TextEditingController();
  final _negativeController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showNegativePrompt = false;

  @override
  void initState() {
    super.initState();
    _promptController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      Helpers.showSnackBar(context, 'Please sign in first', isError: true);
      return;
    }

    if (_promptController.text.trim().isEmpty) {
      Helpers.showSnackBar(context, 'Please enter a prompt', isError: true);
      return;
    }

    final selectedModel = ref.read(selectedModelProvider);
    final selectedRatio = ref.read(selectedAspectRatioProvider);
    final (width, height) = getDimensionsForRatio(selectedRatio);

    await ref.read(mediaGenerationControllerProvider.notifier).generateImage(
      userId: user.uid,
      prompt: _promptController.text.trim(),
      negativePrompt: _showNegativePrompt ? _negativeController.text.trim() : null,
      model: selectedModel,
      width: width,
      height: height,
    );

    // Scroll to result
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleRegenerate() {
    _handleGenerate();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mediaGenerationControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.secondary, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Create'),
          ],
        ),
        actions: [
          // History button
          IconButton(
            onPressed: () => _showHistory(context),
            icon: const Icon(Icons.history),
            tooltip: 'History',
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prompt input
            PromptInput(
              controller: _promptController,
              negativeController: _negativeController,
              enabled: !state.isGenerating,
              showNegativePrompt: _showNegativePrompt,
              onToggleNegative: () {
                setState(() => _showNegativePrompt = !_showNegativePrompt);
              },
            ),
            const SizedBox(height: 24),

            // Model selector
            ModelSelector(enabled: !state.isGenerating),
            const SizedBox(height: 24),

            // Aspect ratio selector
            AspectRatioSelector(enabled: !state.isGenerating),
            const SizedBox(height: 24),

            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isGenerating ? null : _handleGenerate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: state.isGenerating
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                              value: state.progress > 0 ? state.progress : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Generating... ${(state.progress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Generate Image',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Error display
            if (state.hasError && state.error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        ref.read(mediaGenerationControllerProvider.notifier).clearError();
                      },
                      icon: Icon(Icons.close, color: AppColors.error),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Result display
            if (state.hasResult && state.currentMedia != null) ...[
              Text(
                'Result',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              GenerationResult(
                media: state.currentMedia!,
                onFavorite: () {
                  ref.read(mediaGenerationControllerProvider.notifier)
                      .toggleFavorite(state.currentMedia!.id);
                },
                onRegenerate: _handleRegenerate,
                onDownload: () {
                  Helpers.showSnackBar(context, 'Download feature coming soon!');
                },
                onShare: () {
                  Helpers.showSnackBar(context, 'Share feature coming soon!');
                },
              ),
              const SizedBox(height: 24),
            ],

            // Quick prompts for inspiration
            if (!state.hasResult && !state.isGenerating) ...[
              _buildInspirationSection(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInspirationSection(bool isDark) {
    final prompts = [
      'A majestic dragon soaring over a crystal mountain at sunset',
      'Cyberpunk city street with neon lights and rain reflections',
      'Serene Japanese garden with cherry blossoms and koi pond',
      'Astronaut floating in colorful nebula among distant stars',
      'Cozy cabin in snowy forest with warm light from windows',
      'Ancient library with floating magical books and candlelight',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 20,
              color: AppColors.warning,
            ),
            const SizedBox(width: 8),
            Text(
              'Need inspiration?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: prompts.map((prompt) {
            return InkWell(
              onTap: () {
                _promptController.text = prompt;
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.textTertiaryDark.withValues(alpha: 0.2)
                        : AppColors.textTertiary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  prompt.length > 40 ? '${prompt.substring(0, 40)}...' : prompt,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _HistorySheet(),
    );
  }
}

/// History bottom sheet
class _HistorySheet extends ConsumerWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(userMediaHistoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Generation History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: historyAsync.when(
              data: (history) {
                if (history.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          size: 64,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No generations yet',
                          style: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final media = history[index];
                    return _HistoryItem(media: media);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Text(
                  'Failed to load history',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final GeneratedMediaEntity media;

  const _HistoryItem({required this.media});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            media.firstImageUrl ?? '',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.surfaceVariant,
              child: const Icon(Icons.broken_image),
            ),
          ),
          if (media.isFavorite)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.favorite,
                  color: AppColors.error,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}


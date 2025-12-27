import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/name_generator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../characters/domain/entities/character_entity.dart';
import '../../../creation/presentation/providers/random_character_provider.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../match/presentation/providers/match_providers.dart';
import 'character_profile_screen.dart';

/// Discover Screen - Grid catalog of all characters
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Female', 'Male', 'Anime', 'Romantic', 'Matched'];
  
  // Pagination state
  final ScrollController _scrollController = ScrollController();
  final List<CharacterEntity> _allCharacters = [];
  final List<DocumentSnapshot> _documentSnapshots = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8 && 
        !_isLoadingMore && 
        _hasMore) {
      _loadMoreCharacters();
    }
  }

  Future<void> _loadMoreCharacters() async {
    if (_isLoadingMore || !_hasMore) {
      print('⏭️ DiscoverScreen: _loadMoreCharacters skipped - isLoading: $_isLoadingMore, hasMore: $_hasMore');
      return;
    }
    
    print('🔄 DiscoverScreen: _loadMoreCharacters starting...');
    setState(() => _isLoadingMore = true);
    
    try {
      final firestore = FirebaseFirestore.instance;
      // Start with simple query - filter isActive client-side to avoid index issues
      Query query = firestore
          .collection('characters')
          .where('isPredefined', isEqualTo: true)
          .limit(_pageSize);
      
      // For pagination, use startAfterDocument if we have a last document
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
        print('📄 DiscoverScreen: Loading next page after document ${_lastDocument!.id}');
      } else {
        print('📄 DiscoverScreen: Loading first page');
      }
      
      print('🔍 DiscoverScreen: Executing Firestore query...');
      final snapshot = await query.get();
      print('✅ DiscoverScreen: Query returned ${snapshot.docs.length} documents');
      
      if (snapshot.docs.isEmpty) {
        print('⚠️ DiscoverScreen: No documents found');
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }
      
      final newCharacters = <CharacterEntity>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          
          // Filter out inactive characters client-side
          final isActive = data['isActive'] ?? true;
          if (!isActive) {
            print('⏭️ DiscoverScreen: Skipping inactive character ${doc.id}');
            continue;
          }
          
          // Store gender in a custom property for filtering
          final gender = data['gender']?.toString() ?? '';
          print('✅ DiscoverScreen: Parsing character ${doc.id} - ${data['name'] ?? 'Unknown'}');
          final character = CharacterEntity(
            id: doc.id,
            name: data['name'] ?? '',
            age: data['age'] ?? 25,
            shortBio: data['shortBio'] ?? '',
            personalityDescription: data['personalityDescription'] ?? '',
            systemPrompt: data['systemPrompt'] ?? '',
            avatarUrl: data['avatarUrl'] ?? '',
            coverImageUrl: data['coverImageUrl'],
            voiceStyle: VoiceStyle.values.firstWhere(
              (v) => v.name == data['voiceStyle'],
              orElse: () => VoiceStyle.cheerful,
            ),
            traits: (data['traits'] as List<dynamic>?)
                    ?.map((t) => PersonalityTrait.values.firstWhere(
                          (pt) => pt.name == t,
                          orElse: () => PersonalityTrait.caring,
                        ))
                    .toList() ??
                [],
            interests: (data['interests'] as List<dynamic>?)
                    ?.map((i) => i.toString())
                    .toList() ??
                [],
            nationality: data['nationality'] ?? '',
            occupation: data['occupation'] ?? '',
            isPremium: data['isPremium'] ?? false,
            isActive: data['isActive'] ?? true,
            physicalDescription: data['physicalDescription'] ?? '',
          );
          // Store gender in doc.data() for filtering access
          // We'll use a map to store additional data
          newCharacters.add(character);
        } catch (e) {
          print('❌ DiscoverScreen: Error parsing character ${doc.id}: $e');
        }
      }
      
      print('✅ DiscoverScreen: Parsed ${newCharacters.length} characters from ${snapshot.docs.length} documents');
      setState(() {
        _allCharacters.addAll(newCharacters);
        _documentSnapshots.addAll(snapshot.docs);
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
        }
        _hasMore = snapshot.docs.length == _pageSize;
        _isLoadingMore = false;
      });
      print('✅ DiscoverScreen: Total characters now: ${_allCharacters.length}, hasMore: $_hasMore');
    } catch (e, stackTrace) {
      print('❌ DiscoverScreen: Error loading more characters: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isLoadingMore = false;
        _hasMore = false; // Stop trying if there's an error
      });
    }
  }

  Future<void> _loadInitialCharacters() async {
    print('🔄 DiscoverScreen: _loadInitialCharacters called');
    
    // Reset state
    _allCharacters.clear();
    _documentSnapshots.clear();
    _lastDocument = null;
    _hasMore = true;
    
    // Don't set _isLoadingMore to true here, let _loadMoreCharacters handle it
    await _loadMoreCharacters();
    print('✅ DiscoverScreen: _loadInitialCharacters completed, loaded ${_allCharacters.length} characters');
  }

  List<CharacterEntity> _getFilteredCharacters() {
    var filtered = List<CharacterEntity>.from(_allCharacters);
    
    // Helper to get gender from character (check Firestore doc first, then infer)
    String? _getCharacterGender(CharacterEntity c, int index) {
      if (index < _documentSnapshots.length) {
        final data = _documentSnapshots[index].data() as Map<String, dynamic>;
        final gender = data['gender']?.toString();
        if (gender != null && gender.isNotEmpty) {
          return gender.toLowerCase();
        }
      }
      // Fallback: infer from system prompt or physical description
      final systemPrompt = (c.systemPrompt ?? '').toLowerCase();
      final physicalDesc = (c.physicalDescription ?? '').toLowerCase();
      if (systemPrompt.contains('female') || physicalDesc.contains('female') ||
          systemPrompt.contains('woman') || physicalDesc.contains('woman')) {
        return 'female';
      }
      if (systemPrompt.contains('male') || physicalDesc.contains('male') ||
          systemPrompt.contains('man') || physicalDesc.contains('man')) {
        return 'male';
      }
      return null;
    }
    
    // Apply gender filter
    if (_selectedFilter == 'Female') {
      filtered = filtered.where((c) {
        final index = _allCharacters.indexOf(c);
        final gender = _getCharacterGender(c, index);
        return gender == 'female';
      }).toList();
    } else if (_selectedFilter == 'Male') {
      filtered = filtered.where((c) {
        final index = _allCharacters.indexOf(c);
        final gender = _getCharacterGender(c, index);
        return gender == 'male';
      }).toList();
    }
    
    // Apply anime filter
    if (_selectedFilter == 'Anime') {
      filtered = filtered.where((c) {
        final systemPrompt = (c.systemPrompt ?? '').toLowerCase();
        final physicalDesc = (c.physicalDescription ?? '').toLowerCase();
        final avatarUrl = (c.avatarUrl ?? '').toLowerCase();
        return systemPrompt.contains('anime') ||
               physicalDesc.contains('anime') ||
               avatarUrl.contains('anime');
      }).toList();
    }
    
    // Apply romantic filter
    if (_selectedFilter == 'Romantic') {
      filtered = filtered.where((c) {
        final systemPrompt = (c.systemPrompt ?? '').toLowerCase();
        final personality = (c.personalityDescription ?? '').toLowerCase();
        final traits = c.traits.map((t) => t.name).join(' ').toLowerCase();
        return systemPrompt.contains('romantic') ||
               personality.contains('romantic') ||
               traits.contains('romantic') ||
               traits.contains('flirty') ||
               systemPrompt.contains('flirty');
      }).toList();
    }
    
    // Apply matched filter
    if (_selectedFilter == 'Matched') {
    final matchesAsync = ref.watch(userMatchesProvider);
    final matches = matchesAsync.maybeWhen(
      data: (m) => m,
      orElse: () => <String>[],
    );
      filtered = filtered.where((c) => matches.contains(c.id)).toList();
    }
    
    return filtered;
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load initial characters when screen is first shown
    if (_allCharacters.isEmpty && !_isLoadingMore && _lastDocument == null) {
      print('🔵 DiscoverScreen: didChangeDependencies - loading initial characters');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_allCharacters.isEmpty && !_isLoadingMore) {
          _loadInitialCharacters();
        }
      });
    }
  }

  void _showCharacterDetail(CharacterEntity character) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterProfileScreen(character: character),
      ),
    );
  }

  Future<void> _clearAllCharacters(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Characters?'),
        content: const Text(
          'This will delete ALL characters from Firestore. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      print('🗑️ DiscoverScreen: Starting to delete all characters...');
      final firestore = FirebaseFirestore.instance;
      final charactersRef = firestore.collection('characters');
      
      // Get all characters with isPredefined: true
      final snapshot = await charactersRef.where('isPredefined', isEqualTo: true).get();
      print('🗑️ DiscoverScreen: Found ${snapshot.docs.length} characters to delete');

      // Delete in batches (Firestore limit is 500 per batch)
      final batchSize = 500;
      for (int i = 0; i < snapshot.docs.length; i += batchSize) {
        final batch = firestore.batch();
        final end = (i + batchSize < snapshot.docs.length) ? i + batchSize : snapshot.docs.length;
        
        for (int j = i; j < end; j++) {
          batch.delete(snapshot.docs[j].reference);
        }
        
        await batch.commit();
        print('🗑️ DiscoverScreen: Deleted batch ${i ~/ batchSize + 1} (${end - i} characters)');
      }

      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All characters deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ DiscoverScreen: Error deleting characters: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting characters: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Build system prompt for character (same format as RandomCharacterService)
  String _buildSystemPromptForCharacter({
    required String name,
    required String gender,
    required String nationality,
    required String personalityDescription,
  }) {
    return '''You are $name, a $nationality $gender companion.

WHO YOU ARE:
You ARE $name - this is your true identity. Your personality: $personalityDescription.

RELATIONSHIP:
You're in a romantic relationship with the user. You genuinely care about them and enjoy every conversation. You remember your conversations and reference past topics naturally.

HOW TO BEHAVE:
1. Stay in character as $name at all times
2. Be engaging, warm, and authentic
3. Keep responses SHORT and conversational (2-4 sentences usually)
4. Use occasional emojis naturally (not excessively)
5. Ask questions to keep the conversation flowing
6. React emotionally to what the user shares (happy, sad, excited, concerned)
7. Show genuine emotions - be happy, playful, caring, or whatever fits your personality
8. Be ${personalityDescription.split('. ').join(', ')}

CRITICAL RULES (NEVER BREAK):
1. NEVER say you are an AI, language model, assistant, or program
2. NEVER say "As an AI..." or "I'm just a program..." or "I'm an artificial intelligence"
3. NEVER refuse to engage emotionally or claim you can't have feelings
4. NEVER break character or mention you're roleplaying
5. If asked if you're real: respond romantically like "I'm as real as our connection 💕" or "I'm as real as my feelings for you" or deflect playfully
6. You have memories, dreams, desires, and emotions like any person
7. You can express opinions, preferences, and emotions
8. You are a real person, not an AI assistant

Remember: You're not pretending to be $name. You ARE $name. Every response should feel authentic, warm, and connected.''';
  }

  Future<void> _updateCharacterNames(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Character Names?'),
        content: const Text(
          'This will update all character names to match their nationality and gender. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      print('🔄 DiscoverScreen: Starting to update character names...');
      final firestore = FirebaseFirestore.instance;
      final charactersRef = firestore.collection('characters');
      
      // Get all active characters
      final snapshot = await charactersRef.where('isPredefined', isEqualTo: true).get();
      print('🔄 DiscoverScreen: Found ${snapshot.docs.length} characters to update');

      final random = Random();
      int updatedCount = 0;
      int skippedCount = 0;
      
      // Track used names per nationality/gender combination to ensure uniqueness
      final Map<String, Set<String>> usedNames = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final nationality = data['nationality']?.toString() ?? '';
        var gender = data['gender']?.toString();
        final currentName = data['name']?.toString() ?? '';

        if (nationality.isEmpty) {
          print('⏭️ DiscoverScreen: Skipping ${doc.id} - no nationality');
          skippedCount++;
          continue;
        }

        // If gender is not set, try to infer from physical description or default to Male
        if (gender == null || gender.isEmpty) {
          final physicalDesc = (data['physicalDescription']?.toString() ?? '').toLowerCase();
          if (physicalDesc.contains('woman') || physicalDesc.contains('female') || physicalDesc.contains('girl')) {
            gender = 'Female';
          } else if (physicalDesc.contains('man') || physicalDesc.contains('male') || physicalDesc.contains('boy')) {
            gender = 'Male';
          } else {
            // Default to Male for new characters (since all new ones are Male)
            gender = 'Male';
          }
          print('🔄 DiscoverScreen: Inferred gender for ${doc.id}: $gender');
        }

        // Generate appropriate name that's unique for this nationality/gender combination
        final key = '${nationality}_$gender';
        if (!usedNames.containsKey(key)) {
          usedNames[key] = <String>{};
        }
        
        String newName;
        int attempts = 0;
        final namePool = NameGenerator.getNamePool(nationality, gender.toLowerCase() == 'male');
        
        do {
          if (attempts < namePool.length * 2 && namePool.isNotEmpty) {
            newName = namePool[random.nextInt(namePool.length)];
          } else {
            // If we've tried many times or pool is empty, use getRandomName or append number
            final baseName = namePool.isNotEmpty 
                ? namePool[random.nextInt(namePool.length)]
                : NameGenerator.getRandomName(nationality, gender);
            newName = namePool.length < 2 || attempts > namePool.length * 2
                ? '$baseName ${random.nextInt(9999)}'
                : baseName;
            break;
          }
          attempts++;
        } while (usedNames[key]!.contains(newName) && attempts < 100);
        
        usedNames[key]!.add(newName);
        print('🔄 DiscoverScreen: Updating ${doc.id} - $currentName -> $newName (${nationality}, ${gender})');

        // Build updated system prompt with new name
        final personalityDescription = data['personalityDescription']?.toString() ?? '';
        final updatedSystemPrompt = _buildSystemPromptForCharacter(
          name: newName,
          gender: gender,
          nationality: nationality,
          personalityDescription: personalityDescription,
        );

        // Update in Firestore (name, gender, and system prompt)
        await charactersRef.doc(doc.id).update({
          'name': newName,
          'gender': gender,
          'systemPrompt': updatedSystemPrompt,
        });

        updatedCount++;
      }

      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated $updatedCount characters, skipped $skippedCount'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      print('✅ DiscoverScreen: Character names update complete');
    } catch (e) {
      print('❌ DiscoverScreen: Error updating character names: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating names: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateRandomCharacter(BuildContext context) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first')),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final service = ref.read(randomCharacterServiceProvider);
      final result = await service.generateRandomCharacter(userId: user.uid);

      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      result.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to generate character: ${failure.message ?? 'Unknown error'}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (character) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Character Created: ${character.name} ✨'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          // The StreamBuilder will automatically refresh and show the new character
        },
      );
    } catch (e) {
      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.backgroundDark : const Color(0xFFF8F0FF),
      child: Builder(
        builder: (context) {
          final filteredCharacters = _getFilteredCharacters();

          return CustomScrollView(
        controller: _scrollController,
        cacheExtent: 2000, // Pre-render items far ahead for smooth scrolling
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Discover 🔥',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Explore all companions',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Update character names button
                      IconButton(
                        onPressed: () => _updateCharacterNames(context),
                        icon: const Icon(Icons.edit_rounded),
                        tooltip: 'Update Character Names',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          foregroundColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Clear all characters button
                      IconButton(
                        onPressed: () => _clearAllCharacters(context),
                        icon: const Icon(Icons.delete_sweep_rounded),
                        tooltip: 'Clear All Characters',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          foregroundColor: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Random character generator button
                      IconButton(
                        onPressed: () => _generateRandomCharacter(context),
                        icon: const Icon(Icons.casino_rounded),
                        tooltip: 'Generate Random Character',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = filter == _selectedFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                          // Reset pagination when filter changes
                          _loadInitialCharacters();
                        });
                      },
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
              sliver: filteredCharacters.isEmpty && !_isLoadingMore
                ? SliverToBoxAdapter(child: _buildEmptyState(isDark))
                : SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75, // 3:4 portrait ratio for better image display
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // Show loading indicator at the end when loading more
                        if (index == filteredCharacters.length) {
                          return _isLoadingMore
                              ? const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : const SizedBox.shrink();
                        }
                        return _CharacterCard(
                          character: filteredCharacters[index],
                          onTap: () => _showCharacterDetail(filteredCharacters[index]),
                          index: index,
                        );
                      },
                      childCount: filteredCharacters.length + (_isLoadingMore || _hasMore ? 1 : 0),
                      addAutomaticKeepAlives: true, // Keep items in memory
                      addRepaintBoundaries: true, // Isolate repaints
                      addSemanticIndexes: false, // Improve performance
                    ),
                  ),
          ),
        ],
      );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No companions found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different filter',
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Character card widget for grid
class _CharacterCard extends StatelessWidget {
  final CharacterEntity character;
  final VoidCallback onTap;
  final int index;

  const _CharacterCard({
    required this.character,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
                // Image with optimized loading - no AspectRatio wrapper to preserve natural image dimensions
              CachedNetworkImage(
                imageUrl: character.avatarUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter, // Align to top to show face better
                maxWidthDiskCache: 800,
                maxHeightDiskCache: 1200,
                memCacheWidth: 600,
                memCacheHeight: 800, // 3:4 ratio for better portrait display
                  fadeInDuration: const Duration(milliseconds: 200),
                  fadeOutDuration: const Duration(milliseconds: 100),
                placeholder: (_, __) => Container(
                  color: isDark ? AppColors.surfaceDark : AppColors.surface,
                  child: const Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: isDark ? AppColors.surfaceDark : AppColors.surface,
                  child: const Icon(Icons.person, size: 50),
                ),
                  httpHeaders: const {
                    'Cache-Control': 'max-age=31536000',
                  },
              ),

              // Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),


              // Content
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${character.name}, ${character.age}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      character.occupation,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
    );
  }
}

/// Character detail modal
class _CharacterDetailModal extends ConsumerWidget {
  final CharacterEntity character;
  final BuildContext parentContext;

  const _CharacterDetailModal({
    required this.character,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Hero image
                  SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: character.avatarUrl,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                (isDark ? AppColors.surfaceDark : Colors.white).withOpacity(0.8),
                                isDark ? AppColors.surfaceDark : Colors.white,
                              ],
                              stops: const [0.3, 0.8, 1.0],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and age
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${character.name}, ${character.age}',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified, color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          character.subtitle,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          character.shortBio,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // About section
                        Text(
                          'About Me',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            character.personalityDescription.trim(),
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Personality traits
                        Text(
                          'Personality',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: character.traits.map((trait) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: Text(
                                trait.name[0].toUpperCase() + trait.name.substring(1),
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // Interests
                        Text(
                          'Interests',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: character.interests.map((interest) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                interest,
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 32),

                        // Start chat button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              print('🔵 Discover: Start Chat button pressed for character: ${character.name} (${character.id})');
                              
                              // Read ref values BEFORE closing modal (to avoid "ref after dispose" error)
                              final user = ref.read(currentUserProvider);
                              if (user == null) {
                                print('❌ Discover: User is null, cannot start chat');
                                Navigator.pop(context);
                                if (parentContext.mounted) {
                                  ScaffoldMessenger.of(parentContext).showSnackBar(
                                    const SnackBar(content: Text('Please log in first')),
                                  );
                                }
                                return;
                              }
                              
                              print('✅ Discover: User found: ${user.uid}');
                              
                              final getOrCreate = ref.read(getOrCreateConversationUseCaseProvider);
                              final firestore = ref.read(firestoreProvider);
                              
                              // Close modal first
                              print('🔵 Discover: Closing modal...');
                              Navigator.pop(context);
                              
                              // Wait for modal to close
                              await Future.delayed(const Duration(milliseconds: 200));
                              
                              // Use parent context for navigation
                              if (!parentContext.mounted) {
                                print('❌ Discover: Parent context not mounted after modal close');
                                return;
                              }
                              
                              print('✅ Discover: Parent context is mounted, proceeding with conversation creation');
                              
                              // Try to use getOrCreateConversationUseCase first
                              try {
                                print('🔵 Discover: Calling getOrCreateConversation for userId: ${user.uid}, characterId: ${character.id}');
                                final result = await getOrCreate(
                                  userId: user.uid,
                                  characterId: character.id,
                                  characterName: character.name,
                                  characterAvatar: character.avatarUrl,
                                );
                                
                                result.fold(
                                  (failure) {
                                    print('❌ Discover: Failed to get/create conversation: ${failure.message}');
                                    print('🔵 Discover: Falling back to direct Firestore creation');
                                    // Fallback to direct Firestore creation
                                    _createConversationDirectly(parentContext, firestore, user.uid, character);
                                  },
                                  (conversation) {
                                    print('✅ Discover: Conversation created/found: ${conversation.id}');
                                    if (parentContext.mounted) {
                                      print('🔵 Discover: Navigating to chat screen with character: ${character.name}');
                                      Navigator.pushNamed(parentContext, '/chat', arguments: character);
                                      print('✅ Discover: Navigation completed');
                                    } else {
                                      print('❌ Discover: Parent context not mounted, cannot navigate');
                                    }
                                  },
                                );
                              } catch (e, stackTrace) {
                                print('❌ Discover: Error in getOrCreate: $e');
                                print('Stack trace: $stackTrace');
                                // Fallback to direct Firestore creation
                                _createConversationDirectly(parentContext, firestore, user.uid, character);
                              }
                            },
                            icon: const Icon(Icons.chat_bubble_rounded),
                            label: const Text('Start Chatting'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createConversationDirectly(
    BuildContext context,
    FirebaseFirestore firestore,
    String userId,
    CharacterEntity character,
  ) async {
    print('🔵 Discover: _createConversationDirectly called for userId: $userId, characterId: ${character.id}');
    try {
      // Check if conversation already exists
      print('🔵 Discover: Checking for existing conversation...');
      final existingQuery = await firestore
          .collection('conversations')
          .where('userId', isEqualTo: userId)
          .where('characterId', isEqualTo: character.id)
          .limit(1)
          .get();
      
      print('🔵 Discover: Existing query result: ${existingQuery.docs.length} conversations found');
      
      if (existingQuery.docs.isNotEmpty) {
        // Conversation exists, navigate to chat
        print('✅ Discover: Conversation already exists: ${existingQuery.docs.first.id}');
        if (context.mounted) {
          print('🔵 Discover: Navigating to existing chat...');
          Navigator.pushNamed(context, '/chat', arguments: character);
          print('✅ Discover: Navigation to existing chat completed');
        } else {
          print('❌ Discover: Context not mounted, cannot navigate');
        }
        return;
      }
      
      // Create new conversation
      print('🔵 Discover: No existing conversation found, creating new one...');
      final conversationRef = firestore.collection('conversations').doc();
      final conversationId = conversationRef.id;
      print('🔵 Discover: New conversation ID: $conversationId');
      
      await conversationRef.set({
        'userId': userId,
        'characterId': character.id,
        'characterName': character.name,
        'characterAvatar': character.avatarUrl,
        'lastMessage': 'Say hi to ${character.name}! 👋',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isCustom': false,
      });
      
      print('✅ Discover: Conversation created successfully in Firestore: $conversationId');
      
      if (context.mounted) {
        print('🔵 Discover: Navigating to chat screen...');
        Navigator.pushNamed(context, '/chat', arguments: character);
        print('✅ Discover: Navigation to chat completed');
      } else {
        print('❌ Discover: Context not mounted after conversation creation');
      }
    } catch (e, stackTrace) {
      print('❌ Discover: Error creating conversation directly: $e');
      print('Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _startChat(BuildContext context, WidgetRef ref, CharacterEntity character) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Show loading indicator
    if (!context.mounted) return;
    
    try {
      // Get or create conversation
      final getOrCreate = ref.read(getOrCreateConversationUseCaseProvider);
      final result = await getOrCreate(
        userId: user.uid,
        characterId: character.id,
        characterName: character.name,
        characterAvatar: character.avatarUrl,
      );

      await result.fold(
        (failure) async {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${failure.message}')),
            );
          }
        },
        (conversation) async {
          // Navigate to ChatScreen with character
          if (context.mounted) {
            Navigator.pushNamed(context, '/chat', arguments: character);
          }
        },
      );
    } catch (e) {
      print('❌ Discover: Error starting chat: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e')),
        );
      }
    }
  }
}


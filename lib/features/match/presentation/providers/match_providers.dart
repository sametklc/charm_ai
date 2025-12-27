import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Save a match to Firestore
final saveMatchProvider = Provider<Future<void> Function(String userId, String characterId)>((ref) {
  final firestore = ref.watch(firestoreProvider);
  
  return (String userId, String characterId) async {
    try {
      await firestore.collection('user_matches').doc(userId).set({
        'matches': FieldValue.arrayUnion([characterId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Silent fail - match saving is not critical
    }
  };
});

/// Get user's matches stream
final userMatchesProvider = StreamProvider<List<String>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  
  final firestore = ref.watch(firestoreProvider);
  
  return firestore
      .collection('user_matches')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return <String>[];
        final data = doc.data();
        if (data == null) return <String>[];
        return List<String>.from(data['matches'] ?? []);
      });
});

/// Check if a character is matched
final isMatchedProvider = Provider.family<bool, String>((ref, characterId) {
  final matchesAsync = ref.watch(userMatchesProvider);
  return matchesAsync.maybeWhen(
    data: (matches) => matches.contains(characterId),
    orElse: () => false,
  );
});




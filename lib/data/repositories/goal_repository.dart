import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/goal.dart';

/// Goal Repository
/// Handles all database operations for goals
class GoalRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Save a new goal
  Future<String> saveGoal(Goal goal) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Ensure the goal has the correct userId
    final goalWithUserId = goal.copyWith(userId: _currentUserId!);
    print('💾 Saving goal for user: $_currentUserId');
    
    final docRef = await _firestore.collection('goals').add(goalWithUserId.toFirestore());
    print('✅ Goal saved with ID: ${docRef.id}');
    return docRef.id;
  }

  /// Get all goals for current user
  Future<List<Goal>> getGoals({bool? isActive}) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    print('🔍 Fetching goals for user: $_currentUserId');

    var query = _firestore
        .collection('goals')
        .where('userId', isEqualTo: _currentUserId);

    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }

    final snapshot = await query.get();
    
    print('📦 Found ${snapshot.docs.length} goal documents');
    
    final goals = snapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList();
    
    // Sort in memory instead of using orderBy (avoids index requirement)
    goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return goals;
  }

  /// Get active goals only
  Future<List<Goal>> getActiveGoals() async {
    return getGoals(isActive: true);
  }

  /// Update goal progress
  Future<void> updateGoalProgress(String goalId, double newValue) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final goalRef = _firestore.collection('goals').doc(goalId);
    final goalDoc = await goalRef.get();
    
    if (!goalDoc.exists) {
      throw Exception('Goal not found');
    }

    final goal = Goal.fromFirestore(goalDoc);
    final updates = <String, dynamic>{
      'currentValue': newValue,
    };

    // Mark as completed if target reached
    if (newValue >= goal.targetValue && goal.completedAt == null) {
      updates['completedAt'] = FieldValue.serverTimestamp();
      updates['isActive'] = false;
    }

    await goalRef.update(updates);
  }

  /// Update goal
  Future<void> updateGoal(Goal goal) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore.collection('goals').doc(goal.id).update(goal.toFirestore());
  }

  /// Delete goal
  Future<void> deleteGoal(String goalId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore.collection('goals').doc(goalId).delete();
  }

  /// Archive (deactivate) goal
  Future<void> archiveGoal(String goalId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore.collection('goals').doc(goalId).update({
      'isActive': false,
    });
  }

  /// Recalculate progress for all active goals based on user's ride stats
  Future<void> recalculateGoalProgress() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final goals = await getActiveGoals();
      print('🔄 Recalculating progress for ${goals.length} goals');
      
      for (final goal in goals) {
        try {
          if (goal.isExpired) {
            // Deactivate expired goals
            await archiveGoal(goal.id);
            continue;
          }

          // Get ALL rides for user first (avoid complex Firestore query)
          final allRides = await _firestore
              .collection('rides')
              .where('userId', isEqualTo: _currentUserId)
              .get();

          // Filter rides in memory by date range
          final ridesInPeriod = allRides.docs.where((doc) {
            final data = doc.data();
            final startTime = (data['startTime'] as Timestamp).toDate();
            return startTime.isAfter(goal.startDate) && startTime.isBefore(goal.endDate);
          }).toList();

          double progressValue = 0;

          if (goal.type == 'distance') {
            // Sum distance in km
            progressValue = ridesInPeriod.fold<double>(
              0,
              (sum, doc) => sum + ((doc.data()['distance'] ?? 0) / 1000),
            );
          } else if (goal.type == 'rides') {
            // Count rides
            progressValue = ridesInPeriod.length.toDouble();
          } else if (goal.type == 'calories') {
            // Calculate calories (rough estimate: 50 kcal per km)
            final totalDistance = ridesInPeriod.fold<double>(
              0,
              (sum, doc) => sum + ((doc.data()['distance'] ?? 0) / 1000),
            );
            progressValue = totalDistance * 50;
          }

          print('📊 Goal ${goal.id}: ${goal.type} = $progressValue');
          await updateGoalProgress(goal.id, progressValue);
        } catch (e) {
          print('⚠️ Error updating goal ${goal.id}: $e');
          // Continue with other goals even if one fails
        }
      }
    } catch (e) {
      print('❌ Error in recalculateGoalProgress: $e');
      throw e;
    }
  }

  /// Create a new goal period for recurring goals
  Future<String> renewGoal(Goal oldGoal) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Calculate new period dates
    final now = DateTime.now();
    DateTime newStartDate;
    DateTime newEndDate;

    if (oldGoal.period == 'weekly') {
      newStartDate = now;
      newEndDate = now.add(const Duration(days: 7));
    } else {
      // Monthly
      newStartDate = now;
      newEndDate = DateTime(now.year, now.month + 1, now.day);
    }

    // Create new goal with same target
    final newGoal = Goal(
      id: '',
      userId: _currentUserId!,
      name: oldGoal.name,
      type: oldGoal.type,
      targetValue: oldGoal.targetValue,
      currentValue: 0,
      period: oldGoal.period,
      startDate: newStartDate,
      endDate: newEndDate,
      isActive: true,
      createdAt: DateTime.now(),
    );

    return await saveGoal(newGoal);
  }

  /// Get goals stream for real-time updates
  Stream<List<Goal>> getGoalsStream({bool? isActive}) {
    print('📡 Setting up goals stream for user: $_currentUserId');
    
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    var query = _firestore
        .collection('goals')
        .where('userId', isEqualTo: _currentUserId);

    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }

    // Remove orderBy to avoid composite index requirement
    // Sort in memory instead
    return query.snapshots().map((snapshot) {
      print('📡 Stream received ${snapshot.docs.length} documents');
      final goals = snapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList();
      // Sort by createdAt descending (newest first)
      goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return goals;
    });
  }
}

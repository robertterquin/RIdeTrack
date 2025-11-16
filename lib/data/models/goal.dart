import 'package:cloud_firestore/cloud_firestore.dart';

/// Goal Model
/// Represents a user's riding goal (distance, frequency, or calories)
class Goal {
  final String id;
  final String userId;
  final String name; // User-defined goal name
  final String type; // 'distance', 'rides', or 'calories'
  final double targetValue; // Target to achieve (km for distance, count for rides, kcal for calories)
  final double currentValue; // Current progress
  final String period; // 'weekly' or 'monthly'
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? completedAt;

  Goal({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.targetValue,
    this.currentValue = 0.0,
    required this.period,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    required this.createdAt,
    this.completedAt,
  });

  /// Calculate progress percentage (0-100)
  double get progressPercentage {
    if (targetValue == 0) return 0;
    final percentage = (currentValue / targetValue) * 100;
    return percentage > 100 ? 100 : percentage;
  }

  /// Check if goal is completed
  bool get isCompleted => currentValue >= targetValue;

  /// Get remaining value to achieve goal
  double get remainingValue {
    final remaining = targetValue - currentValue;
    return remaining < 0 ? 0 : remaining;
  }

  /// Check if goal period has expired
  bool get isExpired => DateTime.now().isAfter(endDate);

  /// Get user-friendly goal description
  String get description {
    switch (type) {
      case 'distance':
        return '$targetValue km ${period == 'weekly' ? 'per week' : 'per month'}';
      case 'rides':
        return '${targetValue.toInt()} rides ${period == 'weekly' ? 'per week' : 'per month'}';
      case 'calories':
        return '${targetValue.toInt()} kcal ${period == 'weekly' ? 'per week' : 'per month'}';
      default:
        return '';
    }
  }

  /// Get icon name for goal type
  String get iconName {
    switch (type) {
      case 'distance':
        return 'straighten';
      case 'rides':
        return 'directions_bike';
      case 'calories':
        return 'local_fire_department';
      default:
        return 'flag';
    }
  }

  /// Create Goal from Firestore document
  factory Goal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Goal(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      type: data['type'] ?? 'distance',
      targetValue: (data['targetValue'] ?? 0).toDouble(),
      currentValue: (data['currentValue'] ?? 0).toDouble(),
      period: data['period'] ?? 'weekly',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert Goal to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'type': type,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'period': period,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  /// Copy with method for creating modified copies
  Goal copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    double? targetValue,
    double? currentValue,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

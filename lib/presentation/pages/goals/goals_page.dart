import 'package:flutter/material.dart';
import 'package:bikeapp/core/constants/app_colors.dart';
import 'package:bikeapp/data/models/goal.dart';
import 'package:bikeapp/data/repositories/goal_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Goals Page
/// Allows users to set and track their riding goals
class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final GoalRepository _goalRepository = GoalRepository();
  List<Goal> _activeGoals = [];
  List<Goal> _completedGoals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    print('🔄 Loading goals...');
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all goals first
      final allGoals = await _goalRepository.getGoals();
      print('📊 Loaded ${allGoals.length} goals');
      
      // Recalculate progress in background (don't block UI)
      _goalRepository.recalculateGoalProgress().catchError((e) {
        print('⚠️ Error recalculating progress: $e');
      });
      
      if (mounted) {
        setState(() {
          _activeGoals = allGoals.where((g) => g.isActive && !g.isExpired).toList();
          _completedGoals = allGoals.where((g) => g.isCompleted || !g.isActive || g.isExpired).toList();
          print('✅ Active goals: ${_activeGoals.length}, Completed: ${_completedGoals.length}');
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading goals: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAddGoalDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddGoalDialog(
        onGoalCreated: () {
          _loadGoals();
        },
      ),
    );
  }

  void _showGoalDetails(Goal goal) {
    showDialog(
      context: context,
      builder: (context) => _GoalDetailsDialog(
        goal: goal,
        onDeleted: () {
          _loadGoals();
        },
        onRenewed: () {
          _loadGoals();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Goals',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryOrange),
            onPressed: _loadGoals,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            )
          : RefreshIndicator(
              onRefresh: _loadGoals,
              color: AppColors.primaryOrange,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    
                    // Active Goals Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Active Goals',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${_activeGoals.length}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),

                    if (_activeGoals.isEmpty)
                      _buildEmptyState()
                    else
                      ..._activeGoals.map((goal) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: _buildGoalCard(goal),
                      )),

                    const SizedBox(height: 24),

                    // Completed Goals Section
                    if (_completedGoals.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Completed',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${_completedGoals.length}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._completedGoals.map((goal) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: _buildGoalCard(goal, isCompleted: true),
                      )),
                    ],

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddGoalDialog,
        backgroundColor: AppColors.primaryOrange,
        icon: const Icon(Icons.add),
        label: const Text('New Goal'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.flag_outlined,
            size: 64,
            color: AppColors.primaryPurple.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Active Goals',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set your first goal to track your progress',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(Goal goal, {bool isCompleted = false}) {
    IconData icon;
    switch (goal.type) {
      case 'distance':
        icon = Icons.straighten;
        break;
      case 'rides':
        icon = Icons.directions_bike;
        break;
      default:
        icon = Icons.flag;
    }

    final Color cardColor = isCompleted
        ? Colors.grey.shade100
        : Colors.white;
    
    final Color progressColor = goal.isExpired
        ? Colors.grey
        : (goal.progressPercentage >= 100
            ? AppColors.success
            : AppColors.primaryOrange);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showGoalDetails(goal),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and type
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: progressColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: progressColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGoalTitle(goal.type),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            goal.period == 'weekly' ? 'Weekly Goal' : 'Monthly Goal',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (goal.isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle, color: AppColors.success, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Done',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (goal.isExpired)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Expired',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),

                // Progress bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: goal.progressPercentage / 100,
                          backgroundColor: AppColors.lightGrey.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                          minHeight: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${goal.progressPercentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Current/Target display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatGoalValue(goal.currentValue, goal.type),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Target: ${_formatGoalValue(goal.targetValue, goal.type)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                // Time remaining
                if (!goal.isCompleted && !goal.isExpired) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _getTimeRemaining(goal.endDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getGoalTitle(String type) {
    switch (type) {
      case 'distance':
        return 'Distance Goal';
      case 'rides':
        return 'Rides Goal';
      default:
        return 'Goal';
    }
  }

  String _formatGoalValue(double value, String type) {
    switch (type) {
      case 'distance':
        return '${value.toStringAsFixed(1)} km';
      case 'rides':
        return '${value.toInt()} rides';
      default:
        return value.toString();
    }
  }

  String _getTimeRemaining(DateTime endDate) {
    final now = DateTime.now();
    final difference = endDate.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours left';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes left';
    } else {
      return 'Ending soon';
    }
  }
}

/// Add Goal Dialog
class _AddGoalDialog extends StatefulWidget {
  final VoidCallback onGoalCreated;

  const _AddGoalDialog({required this.onGoalCreated});

  @override
  State<_AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<_AddGoalDialog> {
  final GoalRepository _goalRepository = GoalRepository();
  final _distanceController = TextEditingController();
  final _ridesController = TextEditingController();
  
  String _selectedType = 'distance';
  String _selectedPeriod = 'weekly';
  bool _isSaving = false;

  @override
  void dispose() {
    _distanceController.dispose();
    _ridesController.dispose();
    super.dispose();
  }

  Future<void> _createGoal() async {
    final controller = _selectedType == 'distance' ? _distanceController : _ridesController;
    
    if (controller.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a target value')),
      );
      return;
    }

    final targetValue = double.tryParse(controller.text);
    if (targetValue == null || targetValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid target value')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final now = DateTime.now();
      final endDate = _selectedPeriod == 'weekly'
          ? now.add(const Duration(days: 7))
          : DateTime(now.year, now.month + 1, now.day);

      final goal = Goal(
        id: '',
        userId: currentUserId,
        type: _selectedType,
        targetValue: targetValue,
        currentValue: 0,
        period: _selectedPeriod,
        startDate: now,
        endDate: endDate,
        isActive: true,
        createdAt: now,
      );

      print('📝 Creating goal with userId: $currentUserId');
      await _goalRepository.saveGoal(goal);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onGoalCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Goal created successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      print('❌ Error creating goal: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating goal: $e')),
        );
      }
    }
  }

  String _getUnit() {
    switch (_selectedType) {
      case 'distance':
        return 'km';
      case 'rides':
        return 'rides';
      default:
        return '';
    }
  }

  String _getHint() {
    switch (_selectedType) {
      case 'distance':
        return 'Enter distance';
      case 'rides':
        return 'Enter number of rides';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _selectedType == 'distance' ? _distanceController : _ridesController;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create New Goal',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 28),

                // Goal Type Selection
                const Text(
                  'Goal Type',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeButton('distance', 'Distance', Icons.straighten),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTypeButton('rides', 'Rides', Icons.directions_bike),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Period Selection
                const Text(
                  'Period',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildPeriodButton('weekly', 'Weekly'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPeriodButton('monthly', 'Monthly'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Target Value Input
                const Text(
                  'Target',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: _getHint(),
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.5),
                      fontWeight: FontWeight.normal,
                    ),
                    suffixText: _getUnit(),
                    suffixStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  ),
                ),

                const SizedBox(height: 32),

                // Create Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _createGoal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      disabledBackgroundColor: AppColors.primaryOrange.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Create Goal',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange : AppColors.backgroundGrey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String period, String label) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPurple : AppColors.backgroundGrey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryPurple : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Goal Details Dialog
class _GoalDetailsDialog extends StatelessWidget {
  final Goal goal;
  final VoidCallback onDeleted;
  final VoidCallback onRenewed;

  const _GoalDetailsDialog({
    required this.goal,
    required this.onDeleted,
    required this.onRenewed,
  });

  Future<void> _deleteGoal(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: const Text('Are you sure you want to delete this goal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await GoalRepository().deleteGoal(goal.id);
        if (context.mounted) {
          Navigator.of(context).pop();
          onDeleted();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Goal deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting goal: $e')),
          );
        }
      }
    }
  }

  Future<void> _renewGoal(BuildContext context) async {
    try {
      await GoalRepository().renewGoal(goal);
      if (context.mounted) {
        Navigator.of(context).pop();
        onRenewed();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal renewed for new period!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error renewing goal: $e')),
        );
      }
    }
  }

  String _formatGoalValue(double value, String type) {
    switch (type) {
      case 'distance':
        return '${value.toStringAsFixed(1)} km';
      case 'rides':
        return '${value.toInt()} rides';
      default:
        return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    
    switch (goal.type) {
      case 'distance':
        icon = Icons.straighten;
        iconColor = AppColors.primaryPurple;
        break;
      case 'rides':
        icon = Icons.directions_bike;
        iconColor = AppColors.primaryOrange;
        break;
      default:
        icon = Icons.flag;
        iconColor = AppColors.primaryPurple;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: iconColor, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.type[0].toUpperCase() + goal.type.substring(1) + ' Goal',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          goal.period == 'weekly' ? 'Weekly' : 'Monthly',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Progress Circle
              Center(
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    children: [
                      CircularProgressIndicator(
                        value: goal.progressPercentage / 100,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          goal.isCompleted ? AppColors.success : iconColor,
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${goal.progressPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _formatGoalValue(goal.currentValue, goal.type),
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Stats
              _buildStatRow('Target', _formatGoalValue(goal.targetValue, goal.type)),
              const Divider(height: 24),
              _buildStatRow('Current', _formatGoalValue(goal.currentValue, goal.type)),
              const Divider(height: 24),
              _buildStatRow('Remaining', _formatGoalValue(goal.remainingValue, goal.type)),
              const Divider(height: 24),
              _buildStatRow('Period', '${DateFormat('MMM d').format(goal.startDate)} - ${DateFormat('MMM d').format(goal.endDate)}'),

              const SizedBox(height: 24),

              // Actions
              if (goal.isCompleted || goal.isExpired)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _renewGoal(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Create New Goal',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _deleteGoal(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Goal', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

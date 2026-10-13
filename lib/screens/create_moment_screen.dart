import 'dart:math';

import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/status_views.dart';

const _accentPalette = ['#E6E6FA', '#FFFACD', '#E0F8E6', '#FFE5B4', '#E1F5FE'];

/// "Tonight" reveals at 11 PM, or an hour from now if it's already that late.
DateTime tonightRevealTime(DateTime now) {
  final elevenPm = DateTime(now.year, now.month, now.day, 23);
  final soonest = now.add(const Duration(hours: 1));
  return soonest.isAfter(elevenPm) ? soonest : elevenPm;
}

DateTime tomorrowRevealTime(DateTime now) => DateTime(now.year, now.month, now.day + 1, 9);

class CreateMomentScreen extends StatefulWidget {
  const CreateMomentScreen({super.key});

  @override
  State<CreateMomentScreen> createState() => _CreateMomentScreenState();
}

class _CreateMomentScreenState extends State<CreateMomentScreen> {
  final TextEditingController _titleController = TextEditingController();
  final Set<String> _selectedFriendIds = {};
  late Future<List<AppUser>> _friends;
  String _selectedTime = "Tonight";
  DateTime? _customTime;
  bool _isButtonPressed = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _friends = SonderApi.instance.getFriends();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  DateTime? get _unlockAt {
    final now = DateTime.now();
    return switch (_selectedTime) {
      "Tonight" => tonightRevealTime(now),
      "Tomorrow" => tomorrowRevealTime(now),
      _ => _customTime,
    };
  }

  Future<void> _pickCustomTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _customTime ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_customTime ?? now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!picked.isAfter(DateTime.now())) {
      showErrorSnack(context, 'Pick a time in the future.');
      return;
    }
    setState(() {
      _customTime = picked;
      _selectedTime = "Custom";
    });
  }

  Future<void> _create() async {
    final unlockAt = _unlockAt;
    if (unlockAt == null) {
      showErrorSnack(context, 'Choose when the moment should reveal.');
      return;
    }
    if (!unlockAt.isAfter(DateTime.now())) {
      showErrorSnack(context, 'That reveal time has already passed. Pick another one.');
      return;
    }
    final titleText = _titleController.text.trim().isEmpty ? "Unnamed Moment" : _titleController.text.trim();

    setState(() => _creating = true);
    try {
      final moment = await SonderApi.instance.createMoment(
        title: titleText,
        participantIds: _selectedFriendIds.toList(),
        unlockAt: unlockAt,
        accentColor: _accentPalette[Random().nextInt(_accentPalette.length)],
      );
      if (mounted) Navigator.pop(context, moment);
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        showErrorSnack(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockAt = _unlockAt;
    return Scaffold(
      backgroundColor: AppTheme.kBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.kBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.kTextPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Create a moment",
          style: TextStyle(
            color: AppTheme.kTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("MOMENT NAME", style: _sectionTitleStyle),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.kBorder, width: 2),
                boxShadow: const [BoxShadow(color: AppTheme.kLavender, offset: Offset(4, 4))],
              ),
              child: TextField(
                key: const Key('moment-title-field'),
                controller: _titleController,
                maxLength: 120,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "e.g. Birthday Night",
                  hintStyle: TextStyle(color: AppTheme.kTextSecondary.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text("WHO IS COMING?", style: _sectionTitleStyle),
            const SizedBox(height: 16),
            FutureBuilder<List<AppUser>>(
              future: _friends,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
                if (snapshot.hasError) {
                  return ErrorView(
                    message: snapshot.error.toString(),
                    onRetry: () => setState(() {
                      _friends = SonderApi.instance.getFriends();
                    }),
                  );
                }
                final friends = snapshot.data!;
                if (friends.isEmpty) {
                  return const Text(
                    "No friends yet. The moment will just be you for now.",
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.kTextSecondary),
                  );
                }
                return Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    for (final friend in friends)
                      _buildBouncyFriendChip(friend, _selectedFriendIds.contains(friend.id)),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
            const Text("WHEN SHOULD IT REVEAL?", style: _sectionTitleStyle),
            const SizedBox(height: 12),
            Row(
              children: ["Tonight", "Tomorrow", "Custom"].map((time) {
                final isSelected = _selectedTime == time;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (time == "Custom") {
                        _pickCustomTime();
                      } else {
                        setState(() => _selectedTime = time);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.kPaleYellow : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.kBorder, width: 2),
                        boxShadow: isSelected
                            ? const [BoxShadow(color: AppTheme.kBorder, offset: Offset(2, 2))]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          time,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            color: AppTheme.kTextPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (unlockAt != null) ...[
              const SizedBox(height: 12),
              Text(
                "🔒 ${revealDescription(unlockAt)}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.kTextSecondary),
              ),
            ],
            const SizedBox(height: 60),

            // CREATE BUTTON
            GestureDetector(
              onTapDown: (_) => setState(() => _isButtonPressed = true),
              onTapUp: (_) {
                setState(() => _isButtonPressed = false);
                if (!_creating) _create();
              },
              onTapCancel: () => setState(() => _isButtonPressed = false),
              child: AnimatedScale(
                scale: _isButtonPressed ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.kTextPrimary,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.kBorder, width: 2),
                    boxShadow: _isButtonPressed
                        ? []
                        : const [BoxShadow(color: AppTheme.kSoftMint, offset: Offset(6, 6))],
                  ),
                  child: Center(
                    child: _creating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : const Text(
                            "CREATE MOMENT",
                            style: TextStyle(
                              color: AppTheme.kBackground,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBouncyFriendChip(AppUser friend, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isSelected ? _selectedFriendIds.remove(friend.id) : _selectedFriendIds.add(friend.id);
        });
      },
      child: AnimatedScale(
        scale: isSelected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.kTextPrimary : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.kBorder, width: 2),
            boxShadow: isSelected
                ? const [BoxShadow(color: AppTheme.kPaleYellow, offset: Offset(4, 4))]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.white : AppTheme.kTextSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                friend.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.kTextPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const TextStyle _sectionTitleStyle = TextStyle(
    color: AppTheme.kTextSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
  );
}

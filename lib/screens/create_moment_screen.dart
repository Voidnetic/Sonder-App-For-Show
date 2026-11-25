import 'dart:math';

import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/motion.dart';
import '../widgets/status_views.dart';
import 'friends_screen.dart';

const _accentPalette = ['#E6E6FA', '#FFFACD', '#E0F8E6', '#FFE5B4', '#E1F5FE'];

/// "Tonight" reveals at 11 PM, or an hour from now if it's already that late.
DateTime tonightRevealTime(DateTime now) {
  final elevenPm = DateTime(now.year, now.month, now.day, 23);
  final soonest = now.add(const Duration(hours: 1));
  return soonest.isAfter(elevenPm) ? soonest : elevenPm;
}

DateTime tomorrowRevealTime(DateTime now) => DateTime(now.year, now.month, now.day + 1, 9);

class CreateMomentScreen extends StatefulWidget {
  /// When set, the screen edits this moment instead of creating one: rename it, move the reveal time and
  /// invite more friends. People already in it stay in. Pops with the updated moment.
  final Moment? editing;

  const CreateMomentScreen({super.key, this.editing});

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

  Moment? get _editing => widget.editing;

  /// Already in the moment (joined, or invited and not answered yet): shown ticked, can't be untapped.
  final Map<String, String> _alreadyIn = {};

  @override
  void initState() {
    super.initState();
    _friends = SonderApi.instance.getFriends();
    final m = _editing;
    if (m != null) {
      _titleController.text = m.title;
      _selectedTime = "Custom";
      _customTime = m.unlockAt.toLocal();
      for (final p in m.participants) {
        if (p.id != m.creator.id) _alreadyIn[p.id] = 'Joined';
      }
      for (final p in m.invited) {
        _alreadyIn[p.id] = 'Invited';
      }
    }
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

  Future<void> _save() async {
    final m = _editing!;
    final unlockAt = _unlockAt;
    if (unlockAt == null || !unlockAt.isAfter(DateTime.now())) {
      showErrorSnack(context, 'Pick a reveal time in the future.');
      return;
    }
    final title = _titleController.text.trim();
    final newTitle = title.isNotEmpty && title != m.title ? title : null;
    final newTime = unlockAt.toUtc() == m.unlockAt.toUtc() ? null : unlockAt;
    final newPeople = _selectedFriendIds.where((id) => !_alreadyIn.containsKey(id)).toList();
    if (newTitle == null && newTime == null && newPeople.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _creating = true);
    try {
      final updated = await SonderApi.instance.editMoment(
        m.id,
        title: newTitle,
        unlockAt: newTime,
        addParticipantIds: newPeople,
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        showErrorSnack(context, e);
      }
    }
  }

  Future<void> _create() async {
    if (_editing != null) return _save();
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
      backgroundColor: AppTheme.kCanvas,
      appBar: AppBar(
        backgroundColor: AppTheme.kCanvas,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppTheme.kTextPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _editing == null ? "Create a moment" : "Edit moment",
          style: TextStyle(fontFamily: AppTheme.displayFont, color: AppTheme.kTextPrimary, fontSize: 22),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("MOMENT NAME", style: _sectionTitleStyle),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.kBorder, width: 2),
                boxShadow: [BoxShadow(color: AppTheme.kLavender, offset: Offset(4, 4))],
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
            Text("WHO IS COMING?", style: _sectionTitleStyle),
            const SizedBox(height: 6),
            Text(
              _editing == null
                  ? "They'll get an invite to accept before they join."
                  : "Tap friends to invite them too. Everyone already in stays in.",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.kTextSecondary),
            ),
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
                final friends = [
                  ...snapshot.data!,
                  // People in the moment who aren't (or are no longer) your friends still show as being in it.
                  for (final p in [...?_editing?.participants, ...?_editing?.invited])
                    if (_alreadyIn.containsKey(p.id) && !snapshot.data!.any((f) => f.id == p.id)) p,
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (friends.isEmpty && _editing == null)
                      Text(
                        "No friends yet. The moment will just be you for now.",
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.kTextSecondary),
                      ),
                    for (final friend in friends)
                      _alreadyIn.containsKey(friend.id)
                          ? _alreadyInChip(friend, _alreadyIn[friend.id]!)
                          : _buildBouncyFriendChip(friend, _selectedFriendIds.contains(friend.id)),
                    _addFriendsChip(),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
            Text("WHEN SHOULD IT REVEAL?", style: _sectionTitleStyle),
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
                      decoration: AppTheme.sticker(
                        isSelected ? AppTheme.kPaleYellow : AppTheme.kSurface,
                        radius: 16,
                        offset: isSelected ? 2 : 0,
                      ),
                      child: Center(
                        child: Text(
                          time,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            color: isSelected ? AppTheme.kInk : AppTheme.kTextPrimary,
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
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.kTextSecondary),
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
                    color: AppTheme.kPrimaryFill,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.kBorder, width: 2),
                    boxShadow: _isButtonPressed ? [] : [BoxShadow(color: AppTheme.kSoftMint, offset: Offset(6, 6))],
                  ),
                  child: Center(
                    child: _creating
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: AppTheme.kOnPrimary, strokeWidth: 3),
                          )
                        : Text(
                            _editing == null ? "CREATE MOMENT" : "SAVE CHANGES",
                            style: TextStyle(
                              color: AppTheme.kOnPrimary,
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

  Widget _alreadyInChip(AppUser person, String label) {
    return Container(
      key: Key('already-in-${person.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.kBorder.withValues(alpha: 0.35), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: AppTheme.kTextSecondary, size: 20),
          const SizedBox(width: 8),
          Text(
            person.name,
            style: TextStyle(color: AppTheme.kTextSecondary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: AppTheme.kTextSecondary, fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _addFriendsChip() {
    return Pressable(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsScreen(initialTab: 2)));
        if (mounted) setState(() => _friends = SonderApi.instance.getFriends());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: AppTheme.sticker(AppTheme.kPaleYellow, radius: 20, offset: 0),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppTheme.kInk),
            SizedBox(width: 6),
            Text(
              'Add friends',
              style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.kInk),
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
            color: isSelected ? AppTheme.kPrimaryFill : AppTheme.kSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.kBorder, width: 2),
            boxShadow: isSelected ? [BoxShadow(color: AppTheme.kPaleYellow, offset: Offset(4, 4))] : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? AppTheme.kOnPrimary : AppTheme.kTextSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                friend.name,
                style: TextStyle(
                  color: isSelected ? AppTheme.kOnPrimary : AppTheme.kTextPrimary,
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

  static TextStyle get _sectionTitleStyle =>
      TextStyle(color: AppTheme.kTextSecondary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5);
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';
import '../widgets/safety_sheets.dart';
import '../widgets/status_views.dart';
import 'blocked_users_screen.dart';
import 'friends_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileData {
  final UserProfile profile;
  final List<AppUser> friends;

  const _ProfileData(this.profile, this.friends);
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<_ProfileData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_ProfileData> _load() async {
    final api = SonderApi.instance;
    final results = await Future.wait<Object>([api.getProfile(), api.getFriends()]);
    return _ProfileData(results[0] as UserProfile, results[1] as List<AppUser>);
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _data = next;
    });
    try {
      await next;
    } catch (_) {
      // Shown by the FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_ProfileData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
            if (snapshot.hasError) return ErrorView(message: snapshot.error.toString(), onRetry: _reload);
            return RefreshIndicator(
              color: AppTheme.kTextPrimary,
              onRefresh: _reload,
              child: _buildContent(snapshot.data!),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(_ProfileData data) {
    final profile = data.profile;
    final user = profile.user;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      children: [
        // TAB INDICATION & TITLE
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                "ACCOUNT & PROFILE",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: AppTheme.kTextSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.kPaleYellow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.kBorder, width: 1.5),
              ),
              child: const Text("Tab 4 / 4", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // USER INFO CARD
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.kLavender,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppTheme.kBorder, width: 2),
            boxShadow: [BoxShadow(color: AppTheme.kBorder, offset: Offset(4, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.tint(user.color),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.kBorder, width: 2),
                ),
                child: const Center(child: Icon(Icons.face_6_rounded, size: 40)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: AppTheme.display(26)),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.kTextSecondary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: profile.emailVerified ? AppTheme.kSoftMint : AppTheme.kPaleYellow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.kBorder, width: 1),
                      ),
                      child: Text(
                        profile.googleLinked
                            ? "Verified with Google ✓"
                            : profile.emailVerified
                            ? "Verified Account ✓"
                            : "Email & password account",
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // STATS ROW
        Row(
          children: [
            Expanded(child: _buildStatBox("${profile.memoryCount}", "Memories", AppTheme.kSoftMint)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatBox("${profile.activeMomentCount}", "Active Moments", AppTheme.kPaleYellow)),
          ],
        ),
        const SizedBox(height: 32),

        // FRIENDS LIST SECTION
        Row(
          children: [
            Expanded(
              child: Text(
                "CONNECTED CIRCLE (FRIENDS)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: AppTheme.kTextSecondary,
                ),
              ),
            ),
            Pressable(
              onTap: () => _openFriends(data.friends.isEmpty ? 2 : 0),
              child: Container(
                key: const Key('manage-friends'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.kTextPrimary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.kBorder, width: 1.5),
                  boxShadow: [BoxShadow(color: AppTheme.kSunshine, offset: Offset(2, 2))],
                ),
                child: Text(
                  data.friends.isEmpty ? "+ ADD FRIENDS" : "MANAGE",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.kOnPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.kSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.kBorder, width: 2),
          ),
          child: data.friends.isEmpty
              ? Text(
                  "No friends yet. Add friends to start a moment together.",
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.kTextSecondary),
                )
              : Column(children: [for (final friend in data.friends) _buildFriendRow(friend)]),
        ),
        const SizedBox(height: 32),

        // APP SETTINGS SECTION
        Text(
          "SETTINGS & PREFERENCES",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppTheme.kTextSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.kSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.kBorder, width: 2),
          ),
          child: Column(
            children: [
              _buildSettingTile(Icons.notifications_active_outlined, "Unlock Reminders", "On"),
              Divider(height: 1, color: AppTheme.kBorder, thickness: 1.5),
              _buildSettingTile(
                Icons.dark_mode_outlined,
                "Theme",
                _themeLabel(ThemeController.instance.mode.value),
                onTap: _pickTheme,
              ),
              Divider(height: 1, color: AppTheme.kBorder, thickness: 1.5),
              _buildSettingTile(Icons.group_outlined, "Friends & requests", "", onTap: () => _openFriends(0)),
              Divider(height: 1, color: AppTheme.kBorder, thickness: 1.5),
              _buildSettingTile(Icons.block_rounded, "Blocked people", "", onTap: _openBlocked),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // LOG OUT BUTTON
        GestureDetector(
          onTap: () => SonderApi.instance.logout(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppTheme.kTextPrimary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.kBorder, width: 2),
              boxShadow: [BoxShadow(color: AppTheme.kPaleYellow, offset: Offset(3, 3))],
            ),
            child: Center(
              child: Text(
                "LOG OUT",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppTheme.kOnPrimary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // PRIVACY SECTION
        Text(
          "PRIVACY & SAFETY",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppTheme.kTextSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.kSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.kBorder, width: 2),
          ),
          child: Column(
            children: [
              _buildSettingTile(
                Icons.privacy_tip_outlined,
                "Privacy policy",
                "",
                onTap: () => _openLink(SonderApi.instance.privacyPolicyUrl),
              ),
              Divider(height: 1, color: AppTheme.kBorder, thickness: 1.5),
              _buildSettingTile(
                Icons.gavel_rounded,
                "Terms & community rules",
                "",
                onTap: () => _openLink(SonderApi.instance.termsUrl),
              ),
              Divider(height: 1, color: AppTheme.kBorder, thickness: 1.5),
              _buildSettingTile(
                Icons.delete_forever_outlined,
                "Delete account",
                "",
                onTap: () => _confirmDelete(profile),
                danger: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => "Light",
        ThemeMode.dark => "Dark",
        ThemeMode.system => "System",
      };

  Future<void> _pickTheme() async {
    final current = ThemeController.instance.mode.value;
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: AppTheme.kBackground,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: AppTheme.kBorder, width: 2),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Theme", style: AppTheme.display(26)),
              const SizedBox(height: 12),
              for (final (mode, icon, hint) in [
                (ThemeMode.system, Icons.brightness_auto_outlined, "Match your phone's setting"),
                (ThemeMode.light, Icons.light_mode_outlined, "Cream and pastels"),
                (ThemeMode.dark, Icons.dark_mode_outlined, "Deep ink with cream outlines"),
              ])
                ListTile(
                  key: Key('theme-${mode.name}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(icon, color: AppTheme.kTextPrimary),
                  title: Text(
                    _themeLabel(mode),
                    style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.kTextPrimary),
                  ),
                  subtitle: Text(hint, style: TextStyle(color: AppTheme.kTextSecondary)),
                  trailing: mode == current ? Icon(Icons.check_circle_rounded, color: AppTheme.kTextPrimary) : null,
                  onTap: () => Navigator.pop(context, mode),
                ),
            ],
          ),
        ),
      ),
    );
    // Saving it rebuilds the whole app in the new colours (see SonderApp); this tab stays open.
    if (picked != null && picked != current) await ThemeController.instance.set(picked);
  }

  Future<void> _openFriends(int tab) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => FriendsScreen(initialTab: tab)));
    if (mounted) await _reload();
  }

  Future<void> _openBlocked() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const BlockedUsersScreen()));
    if (mounted) await _reload();
  }

  Future<void> _openLink(String url) async {
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened && mounted) showSnack(context, "Couldn't open $url");
  }

  Future<void> _confirmDelete(UserProfile profile) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => const _DeleteAccountDialog());
    if (confirmed != true || !mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: Colors.white)),
    );
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SonderApi.instance.deleteAccount(signOut: false);
    } catch (e) {
      navigator.pop();
      if (mounted) showSnack(context, e.toString());
      return;
    }
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Your account and all its data were deleted.')));
    // AuthGate swaps to the login screen once the session is cleared.
    await SonderApi.instance.logout();
  }

  Widget _buildFriendRow(AppUser friend) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.tint(friend.color),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.kBorder, width: 1.5),
                  ),
                  child: Center(
                    child: Text(friend.initial, style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    friend.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.kTextPrimary),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.kSoftMint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.kBorder, width: 1),
            ),
            child: const Text("Synced", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String count, String label, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.kBorder, width: 2),
        boxShadow: [BoxShadow(color: AppTheme.kBorder, offset: Offset(3, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.kTextPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.kTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    IconData icon,
    String title,
    String trailingValue, {
    VoidCallback? onTap,
    bool danger = false,
  }) {
    final color = danger ? AppTheme.kDanger : AppTheme.kTextPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            // Rows that only link somewhere use the full width for their title.
            if (trailingValue.isEmpty)
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                ),
              )
            else ...[
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  trailingValue,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.kTextSecondary),
                ),
              ),
            ],
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

/// Makes the person type DELETE, so an account is never deleted by a stray tap.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.text.trim().toUpperCase() == 'DELETE';
    return AlertDialog(
      backgroundColor: AppTheme.kBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: AppTheme.kBorder, width: 2),
      ),
      title: const Text('Delete your account?', style: TextStyle(fontWeight: FontWeight.w900)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes your account, every photo you captured, your messages, friends and '
            "blocks. Moments you made that friends are in are kept for them. This can't be undone.",
          ),
          const SizedBox(height: 16),
          const Text('Type DELETE to confirm', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('delete-confirm-field'),
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            cursorColor: AppTheme.kTextPrimary,
            decoration: InputDecoration(
              hintText: 'DELETE',
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.kTextPrimary, width: 2)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.kTextPrimary),
          ),
        ),
        TextButton(
          onPressed: ready ? () => Navigator.pop(context, true) : null,
          child: Text(
            'Delete forever',
            style: TextStyle(fontWeight: FontWeight.w900, color: ready ? AppTheme.kDanger : Colors.grey),
          ),
        ),
      ],
    );
  }
}

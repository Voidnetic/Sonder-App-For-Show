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
            const Flexible(
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
            boxShadow: const [BoxShadow(color: AppTheme.kBorder, offset: Offset(4, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: user.color,
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.kTextSecondary),
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
            const Expanded(
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
                  boxShadow: const [BoxShadow(color: AppTheme.kSunshine, offset: Offset(2, 2))],
                ),
                child: Text(
                  data.friends.isEmpty ? "+ ADD FRIENDS" : "MANAGE",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.kBorder, width: 2),
          ),
          child: data.friends.isEmpty
              ? const Text(
                  "No friends yet. Add friends to start a moment together.",
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.kTextSecondary),
                )
              : Column(children: [for (final friend in data.friends) _buildFriendRow(friend)]),
        ),
        const SizedBox(height: 32),

        // APP SETTINGS SECTION
        const Text(
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.kBorder, width: 2),
          ),
          child: Column(
            children: [
              _buildSettingTile(Icons.notifications_active_outlined, "Unlock Reminders", "On"),
              const Divider(height: 1, color: AppTheme.kBorder, thickness: 1.5),
              _buildSettingTile(Icons.palette_outlined, "Neo-Brutalist Theme", "Default"),
              const Divider(height: 1, color: AppTheme.kBorder, thickness: 1.5),
              _buildSettingTile(
                Icons.dns_outlined,
                "Server",
                Uri.tryParse(SonderApi.instance.serverUrl)?.authority ?? SonderApi.instance.serverUrl,
              ),
              const Divider(height: 1, color: AppTheme.kBorder, thickness: 1.5),
              _buildSettingTile(Icons.group_outlined, "Friends & requests", "", onTap: () => _openFriends(0)),
              const Divider(height: 1, color: AppTheme.kBorder, thickness: 1.5),
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
              boxShadow: const [BoxShadow(color: AppTheme.kPaleYellow, offset: Offset(3, 3))],
            ),
            child: const Center(
              child: Text(
                "LOG OUT",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // PRIVACY SECTION
        const Text(
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
            color: Colors.white,
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
              const Divider(height: 1, color: AppTheme.kBorder, thickness: 1.5),
              _buildSettingTile(
                Icons.gavel_rounded,
                "Terms & community rules",
                "",
                onTap: () => _openLink(SonderApi.instance.termsUrl),
              ),
              const Divider(height: 1, color: AppTheme.kBorder, thickness: 1.5),
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
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
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
                    color: friend.color,
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.kTextPrimary),
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
        boxShadow: const [BoxShadow(color: AppTheme.kBorder, offset: Offset(3, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.kTextPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.kTextSecondary),
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
    final color = danger ? const Color(0xFFB00020) : AppTheme.kTextPrimary;
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
              Flexible(
                flex: 3,
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  trailingValue,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.kTextSecondary),
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
        side: const BorderSide(color: AppTheme.kBorder, width: 2),
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
            decoration: const InputDecoration(
              hintText: 'DELETE',
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.kTextPrimary, width: 2)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.kTextPrimary),
          ),
        ),
        TextButton(
          onPressed: ready ? () => Navigator.pop(context, true) : null,
          child: Text(
            'Delete forever',
            style: TextStyle(fontWeight: FontWeight.w900, color: ready ? const Color(0xFFB00020) : Colors.grey),
          ),
        ),
      ],
    );
  }
}

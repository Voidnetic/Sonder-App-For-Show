import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/status_views.dart';

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
              child: const Text(
                "Tab 4 / 4",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
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
            boxShadow: const [
              BoxShadow(
                color: AppTheme.kBorder,
                offset: Offset(4, 4),
              ),
            ],
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
                child: const Center(
                  child: Icon(Icons.face_6_rounded, size: 40),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.kTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.kSoftMint,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.kBorder, width: 1),
                      ),
                      child: const Text(
                        "Verified Account ✓",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
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
            Expanded(
              child: _buildStatBox("${profile.memoryCount}", "Memories", AppTheme.kSoftMint),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatBox("${profile.activeMomentCount}", "Active Moments", AppTheme.kPaleYellow),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // FRIENDS LIST SECTION
        const Text(
          "CONNECTED CIRCLE (FRIENDS)",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppTheme.kTextSecondary,
          ),
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
                  "No friends yet.",
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
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
                    child: Text(
                      friend.initial,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    friend.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.kTextPrimary,
                    ),
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
            child: const Text(
              "Synced",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
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

  Widget _buildSettingTile(IconData icon, String title, String trailingValue) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.kTextPrimary, size: 22),
          const SizedBox(width: 16),
          Flexible(
            flex: 3,
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.kTextPrimary),
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
      ),
    );
  }
}

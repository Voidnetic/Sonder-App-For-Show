import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/safety_sheets.dart';
import '../widgets/status_views.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late Future<List<AppUser>> _blocked = SonderApi.instance.getBlockedUsers();

  void _reload() => setState(() => _blocked = SonderApi.instance.getBlockedUsers());

  Future<void> _unblock(AppUser user) async {
    try {
      await SonderApi.instance.unblockUser(user.id);
      if (mounted) showSnack(context, '${user.name} is unblocked. You can add them as a friend again.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString());
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.kBackground,
        surfaceTintColor: Colors.transparent,
        title: Text('Blocked people', style: AppTheme.display(22)),
      ),
      body: FutureBuilder<List<AppUser>>(
        future: _blocked,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
          if (snapshot.hasError) return ErrorView(message: snapshot.error.toString(), onRetry: _reload);
          final users = snapshot.data!;
          if (users.isEmpty) {
            return const EmptyView(
              icon: Icons.verified_user_outlined,
              title: "You haven't blocked anyone",
              subtitle: 'Block someone from their photo, message or friend menu.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              for (final user in users)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.kBorder, width: 2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(user.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                      TextButton(
                        onPressed: () => _unblock(user),
                        child: const Text(
                          'Unblock',
                          style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.kTextPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

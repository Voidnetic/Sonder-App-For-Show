import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';
import '../widgets/safety_sheets.dart';
import '../widgets/status_views.dart';

/// Friends, friend requests and finding new friends, in three tabs.
class FriendsScreen extends StatefulWidget {
  /// 0 = Friends, 1 = Requests, 2 = Add.
  final int initialTab;

  const FriendsScreen({super.key, this.initialTab = 0});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  SonderApi get _api => SonderApi.instance;

  late int _tab = widget.initialTab;

  List<AppUser>? _friends;
  List<FriendRequest>? _incoming;
  List<FriendRequest>? _outgoing;
  Object? _error;

  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<UserSearchResult>? _results;
  bool _searching = false;
  Object? _searchError;

  /// Request/user ids with an action in flight, so their buttons show a spinner.
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        _api.getFriends(),
        _api.getFriendRequests(incoming: true),
        _api.getFriendRequests(incoming: false),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0] as List<AppUser>;
        _incoming = results[1] as List<FriendRequest>;
        _outgoing = results[2] as List<FriendRequest>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _query = query;
        _results = null;
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    _query = query;
    try {
      final results = await _api.searchUsers(query);
      if (!mounted || query != _query) return;
      setState(() {
        _results = results;
        _searching = false;
        _searchError = null;
      });
    } catch (e) {
      if (!mounted || query != _query) return;
      setState(() {
        _searching = false;
        _searchError = e;
      });
    }
  }

  /// Runs [action] with a spinner on [busyKey], then refreshes the lists (and the search results).
  Future<void> _run(String busyKey, Future<void> Function() action, {String? done}) async {
    setState(() => _busy.add(busyKey));
    try {
      await action();
      if (done != null && mounted) showSnack(context, done);
    } catch (e) {
      if (mounted) showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy.remove(busyKey));
    }
    await _load();
    if (_query.length >= 2) await _runSearch(_query);
  }

  Future<void> _friendMenu(AppUser friend) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.kBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: AppTheme.kBorder, width: 2),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  _Avatar(friend, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(friend.name, style: AppTheme.display(22), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined),
              title: const Text('Remove friend', style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report', style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(context, 'report'),
            ),
            ListTile(
              leading: Icon(Icons.block_rounded, color: AppTheme.kDanger),
              title: Text(
                'Block',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.kDanger),
              ),
              onTap: () => Navigator.pop(context, 'block'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'remove':
        await _run(friend.id, () => _api.removeFriend(friend.id), done: '${friend.name} was removed.');
      case 'report':
        await showReportSheet(context, target: ReportTarget.user, targetId: friend.id, author: friend);
        await _load();
      case 'block':
        if (await confirmBlock(context, friend)) await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestCount = _incoming?.length ?? 0;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.kCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(24, 0, 24, 4), child: BubblyText('Your circle 🫶')),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Text(
                'Only friends can be added to your moments.',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.kTextSecondary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _tabChip('Friends', 0, count: _friends?.length),
                  const SizedBox(width: 8),
                  _tabChip('Requests', 1, count: requestCount, highlight: requestCount > 0),
                  const SizedBox(width: 8),
                  _tabChip('Add', 2, icon: Icons.person_add_alt_1_rounded),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(String label, int index, {int? count, bool highlight = false, IconData? icon}) {
    final selected = _tab == index;
    return Expanded(
      child: Pressable(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.kPrimaryFill : AppTheme.kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.kBorder, width: 2),
            boxShadow: selected ? [BoxShadow(color: AppTheme.kSunshine, offset: Offset(3, 3))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: selected ? AppTheme.kOnPrimary : AppTheme.kTextPrimary),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: selected ? AppTheme.kOnPrimary : AppTheme.kTextPrimary,
                  ),
                ),
              ),
              if (count != null && (count > 0 || index == 0)) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: AppTheme.sticker(
                    highlight ? AppTheme.kCoral : AppTheme.kPaleYellow,
                    radius: 10,
                    border: 1.2,
                    offset: 0,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.kInk),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_tab == 2) return _addTab();
    if (_error != null && _friends == null) return ErrorView(message: _error.toString(), onRetry: _load);
    if (_friends == null) return const LoadingView();
    return RefreshIndicator(
      color: AppTheme.kTextPrimary,
      onRefresh: _load,
      child: _tab == 0 ? _friendsTab() : _requestsTab(),
    );
  }

  Widget _friendsTab() {
    final friends = _friends!;
    if (friends.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const EmptyView(
            icon: Icons.group_add_outlined,
            title: 'No friends yet',
            subtitle: 'Find friends by name or email, then add them to your moments.',
          ),
          const SizedBox(height: 16),
          Center(child: _pillButton('FIND FRIENDS', () => setState(() => _tab = 2))),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: friends.length,
      itemBuilder: (context, i) {
        final friend = friends[i];
        return PopIn(
          index: i,
          child: _personCard(
            friend,
            trailing: _busy.contains(friend.id)
                ? const _Spinner()
                : IconButton(
                    tooltip: 'Options',
                    icon: const Icon(Icons.more_horiz_rounded),
                    onPressed: () => _friendMenu(friend),
                  ),
          ),
        );
      },
    );
  }

  Widget _requestsTab() {
    final incoming = _incoming ?? const [];
    final outgoing = _outgoing ?? const [];
    if (incoming.isEmpty && outgoing.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          EmptyView(
            icon: Icons.mark_email_unread_outlined,
            title: 'No requests',
            subtitle: 'Friend requests you get or send show up here.',
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        if (incoming.isNotEmpty) ...[
          _sectionLabel('WANTS TO BE FRIENDS'),
          for (final r in incoming)
            _personCard(
              r.requester,
              color: AppTheme.kSoftMint,
              trailing: _busy.contains(r.id)
                  ? const _Spinner()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _roundButton(
                          Icons.close_rounded,
                          'Decline',
                          () => _run(r.id, () => _api.declineFriendRequest(r.id)),
                        ),
                        const SizedBox(width: 8),
                        _roundButton(
                          Icons.check_rounded,
                          'Accept',
                          () => _run(
                            r.id,
                            () => _api.acceptFriendRequest(r.id),
                            done: 'You and ${r.requester.name} are now friends 🎉',
                          ),
                          filled: true,
                        ),
                      ],
                    ),
            ),
          const SizedBox(height: 16),
        ],
        if (outgoing.isNotEmpty) ...[
          _sectionLabel('SENT'),
          for (final r in outgoing)
            _personCard(
              r.recipient,
              trailing: _busy.contains(r.id)
                  ? const _Spinner()
                  : TextButton(
                      onPressed: () => _run(r.id, () => _api.cancelFriendRequest(r.id)),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.kTextPrimary),
                      ),
                    ),
            ),
        ],
      ],
    );
  }

  Widget _addTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.kSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.kBorder, width: 2),
            boxShadow: [BoxShadow(color: AppTheme.kPeriwinkle, offset: Offset(4, 4))],
          ),
          child: TextField(
            key: const Key('friend-search'),
            controller: _search,
            onChanged: _onSearchChanged,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searching
                  ? const Padding(padding: EdgeInsets.all(14), child: _Spinner())
                  : _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        _onSearchChanged('');
                      },
                    ),
              hintText: 'Name, @username or exact email',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ..._searchResults(),
      ],
    );
  }

  List<Widget> _searchResults() {
    if (_query.length < 2) {
      return [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: AppTheme.sticker(AppTheme.kPaleYellow, radius: 20, offset: 0),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡', style: TextStyle(fontSize: 22)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Type a friend's name, or the whole email they signed up with. They'll get a request to accept.",
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.kInk),
                ),
              ),
            ],
          ),
        ),
      ];
    }
    if (_searchError != null) return [ErrorView(message: _searchError.toString(), onRetry: () => _runSearch(_query))];
    final results = _results;
    if (results == null) return const [];
    if (results.isEmpty) {
      return const [
        EmptyView(
          icon: Icons.person_search_outlined,
          title: 'Nobody found',
          subtitle: 'Check the spelling, or ask them for the email they used for Sonder.',
        ),
      ];
    }
    return [for (var i = 0; i < results.length; i++) PopIn(index: i, child: _resultCard(results[i]))];
  }

  Widget _resultCard(UserSearchResult result) {
    final user = result.user;
    final busyKey = result.requestId ?? user.id;
    final Widget action;
    if (_busy.contains(busyKey)) {
      action = const _Spinner();
    } else {
      action = switch (result.relationship) {
        Relationship.none => _pillButton(
          'ADD',
          () => _run(user.id, () => _api.sendFriendRequest(user.id), done: 'Request sent to ${user.name}'),
          small: true,
        ),
        Relationship.outgoing => _statusTag('Requested'),
        Relationship.incoming => _pillButton(
          'ACCEPT',
          () => _run(
            busyKey,
            () => _api.acceptFriendRequest(result.requestId!),
            done: 'You and ${user.name} are now friends 🎉',
          ),
          small: true,
        ),
        Relationship.friend => _statusTag('Friends ✓', color: AppTheme.kSoftMint),
      };
    }
    return _personCard(user, trailing: action);
  }

  // ---------------------------------------------------------------- pieces

  Widget _personCard(AppUser user, {required Widget trailing, Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: AppTheme.sticker(color ?? AppTheme.kSurface, radius: 20, offset: 3),
      child: Row(
        children: [
          _Avatar(user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  overflow: TextOverflow.ellipsis,
                  // Pastel cards (requests) carry ink; plain panels the theme's text colour.
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color != null ? AppTheme.kInk : AppTheme.kTextPrimary,
                  ),
                ),
                if (user.handle != null)
                  Text(
                    user.handle!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: color != null ? AppTheme.kInkSoft : AppTheme.kTextSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.kTextSecondary),
    ),
  );

  Widget _pillButton(String label, VoidCallback onTap, {bool small = false}) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 16 : 22, vertical: small ? 10 : 14),
        decoration: BoxDecoration(
          color: AppTheme.kPrimaryFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.kBorder, width: 2),
          boxShadow: [BoxShadow(color: AppTheme.kSunshine, offset: Offset(3, 3))],
        ),
        child: Text(
          label,
          style: TextStyle(color: AppTheme.kOnPrimary, fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
      ),
    );
  }

  Widget _statusTag(String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppTheme.sticker(color ?? AppTheme.kLavender, radius: 14, border: 1.5, offset: 0),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.kInk),
      ),
    );
  }

  Widget _roundButton(IconData icon, String tooltip, VoidCallback onTap, {bool filled = false}) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: filled ? AppTheme.kPrimaryFill : AppTheme.kSurface,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.kBorder, width: 2),
          ),
          child: Icon(icon, color: filled ? AppTheme.kOnPrimary : AppTheme.kTextPrimary, semanticLabel: tooltip),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final AppUser user;
  final double size;

  const _Avatar(this.user, {this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: AppTheme.sticker(AppTheme.tint(user.color), circle: true, border: 1.5, offset: 0),
      child: Center(
        child: Text(
          user.initial,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * 0.42, color: AppTheme.kInk),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.kTextPrimary));
}

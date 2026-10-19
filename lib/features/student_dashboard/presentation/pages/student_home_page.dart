import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../widgets/student_feed_tab.dart';
import '../widgets/student_home_tab.dart';
import '../widgets/student_mine_tab.dart';

/// Student shell: Home · Feed · (+ report) · Mine · Profile.
class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  static const _home = 0;
  static const _feed = 1;

  static const _items = [
    DsNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    DsNavItem(
      label: 'Feed',
      icon: Icons.dynamic_feed_outlined,
      selectedIcon: Icons.dynamic_feed_rounded,
    ),
    DsNavItem(
      label: 'Mine',
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment_rounded,
    ),
    DsNavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  int _tab = _home;

  /// Tabs are built on first visit, then kept alive by the IndexedStack.
  final Set<int> _visited = {_home};
  final _feedSearchFocus = FocusNode(debugLabel: 'feedSearch');

  @override
  void dispose() {
    _feedSearchFocus.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index != _feed) _feedSearchFocus.unfocus();
    setState(() {
      _tab = index;
      _visited.add(index);
    });
  }

  void _openFeedSearch() {
    _select(_feed);
    // The feed may be building for the first time; focus after layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tab == _feed) _feedSearchFocus.requestFocus();
    });
  }

  Widget _tabBody(int index) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => StudentHomeTab(onSearchTap: _openFeedSearch),
      1 => StudentFeedTab(searchFocus: _feedSearchFocus),
      2 => const StudentMineTab(),
      _ => const ProfilePage(embedded: true),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back from another tab returns Home before leaving the app.
      canPop: _tab == _home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(_home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            for (var i = 0; i < _items.length; i++)
              // Hidden tabs are excluded from focus traversal/semantics.
              TickerMode(
                enabled: i == _tab,
                child: ExcludeFocus(excluding: i != _tab, child: _tabBody(i)),
              ),
          ],
        ),
        bottomNavigationBar: DsBottomNav(
          items: _items,
          currentIndex: _tab,
          onTap: _select,
          onCenterTap: () => context.push(Routes.report),
        ),
      ),
    );
  }
}

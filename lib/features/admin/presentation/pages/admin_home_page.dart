import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../injection_container.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../reports/domain/repositories/issue_repository.dart';
import '../../../reports/presentation/bloc/issue_list_bloc.dart';
import '../../../reports/presentation/widgets/issue_card.dart';
import '../../../reports/presentation/widgets/issue_feed_view.dart';
import '../bloc/admin_dashboard_cubit.dart';
import '../widgets/admin_overview_tab.dart';
import '../widgets/triage_queue_tab.dart';

/// Admin shell: Overview · Queue · All issues · Profile. Tabs stay alive
/// (IndexedStack) so scroll positions and filters survive switching.
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  static const _overview = 0;
  static const _queue = 1;

  static const _items = [
    DsNavItem(
      label: 'Overview',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard,
    ),
    DsNavItem(
      label: 'Queue',
      icon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox,
    ),
    DsNavItem(
      label: 'All issues',
      icon: Icons.view_list_outlined,
      selectedIcon: Icons.view_list,
    ),
    DsNavItem(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  int _index = _overview;

  late final AdminDashboardCubit _dashboard = getIt<AdminDashboardCubit>()
    ..start();
  late final IssueListBloc _queueBloc = getIt<IssueListBloc>()
    ..add(const IssueListSubscribed(queueDefaultFilter));
  late final IssueListBloc _allBloc = getIt<IssueListBloc>()
    ..add(const IssueListSubscribed(IssueFilter()));

  @override
  void dispose() {
    _dashboard.close();
    _queueBloc.close();
    _allBloc.close();
    super.dispose();
  }

  void _openQueue(QueuePreset preset) {
    _queueBloc.add(IssueListFilterChanged((_) => preset.filter));
    setState(() => _index = _queue);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _dashboard,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            AdminOverviewTab(onOpenQueue: _openQueue),
            BlocProvider.value(
              value: _queueBloc,
              child: const TriageQueueTab(),
            ),
            BlocProvider.value(value: _allBloc, child: const _AllIssuesTab()),
            const ProfilePage(embedded: true),
          ],
        ),
        bottomNavigationBar: DsBottomNav(
          items: _items,
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

class _AllIssuesTab extends StatelessWidget {
  const _AllIssuesTab();

  @override
  Widget build(BuildContext context) => const SafeArea(
    bottom: false,
    child: Column(
      children: [
        DsPageHeader(title: 'All issues', subtitle: 'Every report on campus'),
        SizedBox(height: 8),
        Expanded(
          child: IssueCardRouteScope(
            routeFor: Routes.adminIssueDetails,
            child: IssueFeedView(
              emptyMessage: 'No reports match these filters.',
            ),
          ),
        ),
      ],
    ),
  );
}

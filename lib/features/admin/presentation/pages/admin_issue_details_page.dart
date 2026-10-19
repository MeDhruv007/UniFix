import 'package:flutter/material.dart';

import '../../../reports/presentation/pages/issue_details_page.dart';
import '../widgets/admin_action_bar.dart';

/// The shared details page plus the admin action bar (Update issue /
/// Mark resolved).
class AdminIssueDetailsPage extends StatelessWidget {
  const AdminIssueDetailsPage({super.key, required this.issueId});

  final String issueId;

  @override
  Widget build(BuildContext context) {
    return IssueDetailsPage(
      issueId: issueId,
      adminPanel: (issue) => AdminActionBar(issue: issue),
    );
  }
}

/// JSON shaped exactly like the objects in docs/API.md.
library;

Map<String, dynamic> issueJson({
  String id = 'i1',
  String status = 'reported',
  String priority = 'medium',
  String category = 'electrical',
  List<String> photoPaths = const ['issues/i1/report/p1.jpg'],
  List<String> resolutionPhotoPaths = const [],
  String? resolutionNote,
  String? assignedTo,
  String? resolvedAt,
  int reopenCount = 0,
}) => {
  'id': id,
  'campusId': 'adit-main',
  'title': 'Fan not working in Room 204',
  'description': 'The ceiling fan does not start.',
  'category': category,
  'buildingId': 'engineering-block',
  'locationDetail': 'Second floor, Room 204',
  'photoPaths': photoPaths,
  'reporterId': 'u1',
  'reporterDisplayName': 'Asha Patel',
  'status': status,
  'priority': priority,
  'assignedTo': assignedTo,
  'resolutionNote': resolutionNote,
  'resolutionPhotoPaths': resolutionPhotoPaths,
  'createdAt': '2026-10-15T14:03:00.000Z',
  'updatedAt': '2026-10-15T15:30:00.000Z',
  'resolvedAt': resolvedAt,
  'reopenCount': reopenCount,
};

Map<String, dynamic> issueUpdateJson({
  String id = 'h1',
  String action = 'statusChanged',
  String? oldStatus = 'reported',
  String? newStatus = 'inProgress',
  String? oldPriority,
  String? newPriority,
  String? note = 'Electrician assigned',
}) => {
  'id': id,
  'actorId': 'admin1',
  'action': action,
  'oldStatus': oldStatus,
  'newStatus': newStatus,
  'oldPriority': oldPriority,
  'newPriority': newPriority,
  'note': note,
  'createdAt': '2026-10-15T14:03:00.000Z',
};

Map<String, dynamic> userJson({
  String id = 'u1',
  String displayName = 'Asha Patel',
  String role = 'student',
  bool isActive = true,
  String? department = 'Computer',
}) => {
  'id': id,
  'displayName': displayName,
  'email': 'asha@adit.ac.in',
  'role': role,
  'campusId': 'adit-main',
  'department': department,
  'isActive': isActive,
  'createdAt': '2026-10-01T09:00:00.000Z',
  'updatedAt': '2026-10-01T09:00:00.000Z',
};

Map<String, dynamic> feedbackJson({
  bool stillExists = false,
  String? comment,
}) => {
  'issueId': 'i1',
  'reporterId': 'u1',
  'stillExists': stillExists,
  'comment': comment,
  'createdAt': '2026-10-16T08:00:00.000Z',
};

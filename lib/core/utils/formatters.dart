import 'package:intl/intl.dart';

abstract final class Formatters {
  static final DateFormat _full = DateFormat('d MMM yyyy, h:mm a');
  static final DateFormat _short = DateFormat('d MMM');

  /// Null means a server timestamp still pending (just written offline).
  static String dateTime(DateTime? value) =>
      value == null ? 'Just now' : _full.format(value);

  static String relative(DateTime? value, {DateTime? now}) {
    if (value == null) return 'Just now';
    final diff = (now ?? DateTime.now()).difference(value);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _short.format(value);
  }
}

import 'package:intl/intl.dart';

final _money = NumberFormat.decimalPattern('en_US');

/// Number from a JSON value that may be an int, a double or a numeric string.
double asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

String asText(Object? value, [String fallback = '']) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? fallback : text;
}

String ugx(Object? amount) => 'UGX ${_money.format(asDouble(amount).round())}';

/// "25 Oct 2026" from a "2026-10-25" or "2026-10-25 09:30:00" value; '-' when empty.
String formatDate(Object? value, [String pattern = 'd MMM y']) {
  final parsed = DateTime.tryParse(asText(value));
  return parsed == null ? '-' : DateFormat(pattern).format(parsed);
}

/// "14:00" from "14:00:00".
String formatTime(Object? value) {
  final text = asText(value);
  return text.length >= 5 ? text.substring(0, 5) : text;
}

enum TechnicalLogLevel { info, request, response, error }

class TechnicalLogEntry {
  const TechnicalLogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.title,
    this.fields,
    this.body,
    this.statusCode,
    this.error,
    this.durationMs,
  });

  final DateTime timestamp;
  final TechnicalLogLevel level;
  final String category;
  final String title;
  final Map<String, String>? fields;
  final String? body;
  final int? statusCode;
  final String? error;
  final int? durationMs;
}

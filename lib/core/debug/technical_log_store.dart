import 'package:exel_ott/core/debug/technical_log_entry.dart';
import 'package:flutter/foundation.dart';

/// Almacén en memoria de logs técnicos. Solo registra cuando [isEnabled].
class TechnicalLogStore extends ChangeNotifier {
  TechnicalLogStore._();

  static final TechnicalLogStore instance = TechnicalLogStore._();

  static const maxEntries = 500;

  bool _enabled = false;
  bool _expanded = false;
  final List<TechnicalLogEntry> _entries = [];

  bool get isEnabled => _enabled;
  bool get isExpanded => _enabled && _expanded;
  bool get showFab => _enabled && !_expanded;
  List<TechnicalLogEntry> get entries => List.unmodifiable(_entries);

  void enable({bool expanded = true}) {
    _enabled = true;
    _expanded = expanded;
    notifyListeners();
  }

  void expand() {
    if (!_enabled) return;
    _expanded = true;
    notifyListeners();
  }

  void minimize() {
    _expanded = false;
    notifyListeners();
  }

  void disable() {
    _enabled = false;
    _expanded = false;
    _entries.clear();
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  void log(TechnicalLogEntry entry) {
    if (!_enabled) return;
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    notifyListeners();
  }

  void info(
    String category,
    String title, {
    Map<String, String>? fields,
    String? body,
  }) {
    log(
      TechnicalLogEntry(
        timestamp: DateTime.now(),
        level: TechnicalLogLevel.info,
        category: category,
        title: title,
        fields: fields,
        body: body,
      ),
    );
  }

  void error(
    String category,
    String title, {
    Map<String, String>? fields,
    String? body,
    String? error,
    int? statusCode,
  }) {
    log(
      TechnicalLogEntry(
        timestamp: DateTime.now(),
        level: TechnicalLogLevel.error,
        category: category,
        title: title,
        fields: fields,
        body: body,
        error: error,
        statusCode: statusCode,
      ),
    );
  }
}

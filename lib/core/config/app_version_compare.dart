/// Compara versiones semánticas (`1.0.17`, `1.0.0+17` → `1.0.0`).
bool isAppVersionOlderThanRequired(String appVersion, String? requiredVersion) {
  final required = _parseVersion(requiredVersion);
  if (required.isEmpty) return false;

  final app = _parseVersion(appVersion);
  if (app.isEmpty) return true;

  final maxLen = app.length > required.length ? app.length : required.length;
  for (var i = 0; i < maxLen; i++) {
    final a = i < app.length ? app[i] : 0;
    final r = i < required.length ? required[i] : 0;
    if (a < r) return true;
    if (a > r) return false;
  }
  return false;
}

List<int> _parseVersion(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return [];

  final withoutBuild = trimmed.split('+').first.trim();
  if (withoutBuild.isEmpty) return [];

  return withoutBuild
      .split('.')
      .map(_parsePart)
      .whereType<int>()
      .toList(growable: false);
}

int? _parsePart(String part) {
  final match = RegExp(r'^(\d+)').firstMatch(part.trim());
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

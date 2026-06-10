import 'package:intl/intl.dart';

final _mxCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

/// Formato moneda mexicana: $ ###,###.##
String formatCurrency(dynamic raw) {
  if (raw == null) return '';

  if (raw is num) {
    return _mxCurrency.format(raw);
  }

  final text = raw.toString().trim();
  if (text.isEmpty) return '';

  final normalized = text.replaceAll(RegExp(r'[^\d.,\-]'), '').replaceAll(',', '');
  final value = double.tryParse(normalized);
  if (value == null) {
    return text.startsWith('\$') ? text : '\$$text';
  }

  return _mxCurrency.format(value);
}

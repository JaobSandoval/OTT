import 'dart:math';

import 'package:exel_ott/features/otp/domain/otp_code.dart';
import 'package:exel_ott/features/otp/domain/otp_repository.dart';

class OtpMockRepository implements OtpRepository {
  OtpCode? _current;
  final _rng = Random();

  @override
  Future<OtpCode?> fetchCurrent() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (_current == null || _current!.isExpired) return null;
    return _current;
  }

  @override
  Future<OtpCode> rotateMock() async {
    final code = (_rng.nextInt(900000) + 100000).toString();
    _current = OtpCode(code: code, expiresAt: DateTime.now().add(const Duration(minutes: 2)));
    return _current!;
  }
}


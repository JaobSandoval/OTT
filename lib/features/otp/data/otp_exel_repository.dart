import 'package:exel_ott/features/otp/domain/otp_code.dart';
import 'package:exel_ott/features/otp/domain/otp_repository.dart';

/// Producción Exel: el código llega por notificación push; no se genera localmente.
class OtpExelRepository implements OtpRepository {
  @override
  Future<OtpCode?> fetchCurrent() async => null;

  @override
  Future<OtpCode> rotateMock() {
    throw UnsupportedError('rotateMock no aplica en producción');
  }
}

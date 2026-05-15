import 'package:exel_ott/features/otp/domain/otp_code.dart';

abstract class OtpRepository {
  Future<OtpCode?> fetchCurrent();
  Future<OtpCode> rotateMock(); // no-op in API impl
}


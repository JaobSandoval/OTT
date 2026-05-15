class OtpCode {
  const OtpCode({
    required this.code,
    required this.expiresAt,
  });

  final String code;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}


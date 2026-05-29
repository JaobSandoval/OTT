# Emulador Android: 10.0.2.2 = localhost del PC.
# Requisito: IIS con APISeguridad en http://localhost/APISeguridad y APIXLMovil en https://localhost:44399
Set-Location (Split-Path $PSScriptRoot -Parent)

flutter run -d android `
  --dart-define=SKIP_REMOTE_CONFIG=true `
  --dart-define=LOGIN_SOAP_URL=http://10.0.2.2/APISeguridad/WS.asmx `
  --dart-define=API_XL_MOVIL_URL=https://10.0.2.2:44399/APIXLMovil.asmx

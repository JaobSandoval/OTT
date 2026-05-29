# App apuntando a APIs locales en Visual Studio / IIS Express.
# Requisito: APISeguridad y APIXLMovil corriendo en el PC (F5 en cada proyecto).
Set-Location (Split-Path $PSScriptRoot -Parent)

flutter run -d windows `
  --dart-define=SKIP_REMOTE_CONFIG=true `
  --dart-define=LOGIN_SOAP_URL=http://localhost/APISeguridad/WS.asmx `
  --dart-define=API_XL_MOVIL_URL=https://localhost:44399/APIXLMovil.asmx

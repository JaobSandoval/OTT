$content = Get-Content pubspec.yaml -Raw

$content = $content -replace 'version:\s*(\d+\.\d+\.\d+)\+(\d+)', {
    param($m)
    "version: $($m.Groups[1].Value)+$([int]$m.Groups[2].Value + 1)"
}

Set-Content pubspec.yaml $content -Encoding UTF8

flutter clean
flutter pub get
flutter build appbundle
$pubspec = "pubspec.yaml"

$content = Get-Content $pubspec -Raw

if ($content -match 'version:\s*(\d+\.\d+\.\d+)\+(\d+)') {

    $versionName = $matches[1]
    $buildNumber = [int]$matches[2] + 1

    $newVersion = "version: $versionName+$buildNumber"

    $content = $content -replace 'version:\s*\d+\.\d+\.\d+\+\d+', $newVersion

    Set-Content $pubspec $content -Encoding UTF8

    Write-Host "Nueva version: $versionName+$buildNumber"
}
else {
    Write-Host "No se encontro version en pubspec.yaml"
    exit
}

flutter pub get
flutter build appbundle
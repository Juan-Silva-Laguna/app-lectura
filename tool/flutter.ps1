$ErrorActionPreference = 'Stop'
$sdk = Join-Path $env:LOCALAPPDATA 'app-lectura-toolchain\flutter\bin\flutter.bat'
if (-not (Test-Path $sdk)) {
    throw 'No se encontro el SDK aislado. Instala Flutter o usa flutter desde tu PATH.'
}
$previousAnalytics = $env:FLUTTER_SUPPRESS_ANALYTICS
try {
    $env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
    & $sdk @args
    $code = $LASTEXITCODE
} finally {
    $env:FLUTTER_SUPPRESS_ANALYTICS = $previousAnalytics
}
exit $code

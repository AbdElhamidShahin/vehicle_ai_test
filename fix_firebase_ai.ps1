# ============================================================
# سكريبت تصليح firebase_ai - شغّله مرة واحدة بس
# ============================================================

$file = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\firebase_ai-4.0.0\lib\src\live_session.dart"

if (-not (Test-Path $file)) {
    Write-Host "❌ الملف مش موجود: $file" -ForegroundColor Red
    Write-Host "تأكد إنك عملت: flutter pub get أولاً" -ForegroundColor Yellow
    exit 1
}

$content = Get-Content $file -Raw

if ($content -notmatch "import 'package:meta/meta\.dart'") {
    $content = "import 'package:meta/meta.dart';" + "`n" + $content
    Set-Content $file $content -NoNewline
    Write-Host "✅ تم تصليح firebase_ai بنجاح!" -ForegroundColor Green
} else {
    Write-Host "✅ firebase_ai متصلح بالفعل" -ForegroundColor Green
}

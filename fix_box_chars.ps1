# Script pour remplacer les box-drawing characters par des tirets simples
$files = Get-ChildItem -Path "api-v2" -Recurse -Include "*.js" | Where-Object { $_.FullName -notmatch "node_modules" }

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $modified = $false
    
    # Remplacer les caractères box-drawing par des tirets
    $newContent = $content -replace '─', '-'
    $newContent = $newContent -replace '│', '|'
    $newContent = $newContent -replace '[┌┐└┘├┤┬┴┼]', '+'
    
    if ($content -ne $newContent) {
        $modified = $true
        Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8 -NoNewline
        Write-Host "Fixed: $($file.Name)"
    }
}

Write-Host "`nDone!"

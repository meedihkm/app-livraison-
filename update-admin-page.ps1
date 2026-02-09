# Script pour remplacer la page admin inline par une route vers le fichier HTML

$filePath = "api-v2/index.js"
$content = Get-Content $filePath -Raw

# Trouver le début et la fin du code à remplacer
$startPattern = 'app\.use\("/api/super-admin", superAdminRoutes\);'
$endPattern = '\}\);[\r\n]+[\r\n]+// 404 handler'

# Nouveau code à insérer
$newCode = @'
app.use("/api/super-admin", superAdminRoutes);

// Page Super Admin HTML - Servir le fichier statique
const adminPageRouter = require("./routes/admin-page");
app.use("/api/admin", adminPageRouter);

// 404 handler
'@

# Remplacer le code
$pattern = "($startPattern)[\s\S]*?($endPattern)"
$replacement = $newCode
$newContent = $content -replace $pattern, $replacement

# Sauvegarder le fichier
Set-Content -Path $filePath -Value $newContent -Encoding UTF8

Write-Host "✅ Fichier api-v2/index.js mis à jour avec succès!" -ForegroundColor Green
Write-Host "La page admin utilise maintenant le fichier api-v2/public/super-admin.html" -ForegroundColor Cyan

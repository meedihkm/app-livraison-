# ==========================================
# Script de déploiement vers le repo GitHub
# ==========================================

param(
    [string]$RepoPath = "D:\app-sauvegarde\app-livraison\mehdirepo",
    [string]$SourcePath = "D:\app-sauvegarde\app-livraison\awid-deploy-final"
)

Write-Host "==============================================" -ForegroundColor Blue
Write-Host "  AWID v3.0 - Déploiement vers GitHub" -ForegroundColor Blue
Write-Host "==============================================" -ForegroundColor Blue
Write-Host ""

# Vérifier que le dossier source existe
if (-not (Test-Path $SourcePath)) {
    Write-Host "❌ Erreur: Dossier source introuvable: $SourcePath" -ForegroundColor Red
    exit 1
}

# Vérifier que le dossier repo existe
if (-not (Test-Path $RepoPath)) {
    Write-Host "📦 Clonage du repo..." -ForegroundColor Yellow
    git clone https://github.com/meedihkm/mehdirepo.git $RepoPath
    if (-not (Test-Path $RepoPath)) {
        Write-Host "❌ Erreur: Impossible de cloner le repo" -ForegroundColor Red
        exit 1
    }
}

Write-Host "📁 Repo: $RepoPath" -ForegroundColor Cyan
Write-Host "📁 Source: $SourcePath" -ForegroundColor Cyan
Write-Host ""

# Fonction pour copier un fichier avec vérification
function Copy-FileSafe {
    param($Source, $Destination)
    
    $destDir = Split-Path $Destination -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }
    
    Copy-Item -Path $Source -Destination $Destination -Force
    Write-Host "  ✅ $(Split-Path $Destination -Leaf)" -ForegroundColor Green
}

Write-Host "🚀 Copie des fichiers essentiels..." -ForegroundColor Yellow
Write-Host ""

# 1. Fichiers racine
Copy-FileSafe -Source "$SourcePath\docker-compose.yml" -Destination "$RepoPath\docker-compose.yml"
Copy-FileSafe -Source "$SourcePath\.env.example" -Destination "$RepoPath\.env.example"
Copy-FileSafe -Source "$SourcePath\DEPLOY.md" -Destination "$RepoPath\DEPLOY.md"

# 2. Backend Dockerfile
Copy-FileSafe -Source "$SourcePath\backend\Dockerfile" -Destination "$RepoPath\backend\Dockerfile"

# 3. Admin Dockerfile et nginx.conf
Copy-FileSafe -Source "$SourcePath\admin\Dockerfile" -Destination "$RepoPath\admin\Dockerfile"
Copy-FileSafe -Source "$SourcePath\admin\nginx.conf" -Destination "$RepoPath\admin\nginx.conf"

# 4. GitHub Actions
Copy-FileSafe -Source "$SourcePath\.github\workflows\deploy.yml" -Destination "$RepoPath\.github\workflows\deploy.yml"

Write-Host ""
Write-Host "==============================================" -ForegroundColor Blue
Write-Host "✅ Fichiers copiés avec succès!" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Blue
Write-Host ""
Write-Host "📊 Fichiers créés:" -ForegroundColor Cyan
Write-Host "  • docker-compose.yml" -ForegroundColor White
Write-Host "  • .env.example" -ForegroundColor White
Write-Host "  • DEPLOY.md" -ForegroundColor White
Write-Host "  • backend/Dockerfile" -ForegroundColor White
Write-Host "  • admin/Dockerfile" -ForegroundColor White
Write-Host "  • admin/nginx.conf" -ForegroundColor White
Write-Host "  • .github/workflows/deploy.yml" -ForegroundColor White
Write-Host ""
Write-Host "💡 Prochaines étapes:" -ForegroundColor Yellow
Write-Host "  1. cd $RepoPath" -ForegroundColor White
Write-Host "  2. git add ." -ForegroundColor White
Write-Host "  3. git commit -m 'Ajout configuration déploiement Coolify'" -ForegroundColor White
Write-Host "  4. git push origin main" -ForegroundColor White
Write-Host "  5. Suivre les instructions dans DEPLOY.md" -ForegroundColor White
Write-Host ""

# Option: Commit automatique
$commit = Read-Host "🤖 Faire le commit et push automatiquement? (o/n)"
if ($commit -eq "o" -or $commit -eq "O") {
    Write-Host ""
    Write-Host "📝 Commit et push..." -ForegroundColor Yellow
    
    Set-Location $RepoPath
    
    git add .
    git commit -m "feat: ajout configuration déploiement Coolify v3.0

- Docker Compose avec 7 services
- Dockerfiles backend et admin
- Configuration Nginx pour admin
- GitHub Actions pour CI/CD
- Variables d'environnement
- Documentation déploiement"
    
    git push origin main
    
    Write-Host ""
    Write-Host "🎉 Push terminé!" -ForegroundColor Green
    Write-Host "🔗 Voir le repo: https://github.com/meedihkm/mehdirepo" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Blue

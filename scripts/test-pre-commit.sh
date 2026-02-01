#!/bin/bash

# Script pour tester le hook pre-commit sans faire de commit
# Usage: ./scripts/test-pre-commit.sh

echo "🧪 Test du hook pre-commit..."
echo ""

# Vérifier que le hook existe
if [ ! -f .git/hooks/pre-commit ]; then
    echo "❌ Hook pre-commit introuvable!"
    echo "Créez-le d'abord avec: chmod +x .git/hooks/pre-commit"
    exit 1
fi

# Vérifier que le hook est exécutable
if [ ! -x .git/hooks/pre-commit ]; then
    echo "⚠️  Hook pre-commit n'est pas exécutable"
    echo "Correction en cours..."
    chmod +x .git/hooks/pre-commit
    echo "✅ Hook rendu exécutable"
fi

# Simuler un commit en exécutant le hook
echo "🔄 Exécution du hook..."
echo ""

.git/hooks/pre-commit

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Hook passé avec succès!"
    echo "Votre code est prêt à être commité."
else
    echo "❌ Hook échoué (code: $EXIT_CODE)"
    echo "Corrigez les erreurs ci-dessus avant de commit."
fi

exit $EXIT_CODE

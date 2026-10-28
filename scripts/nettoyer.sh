set -u
 
JOURS=7
CONFIRMER=1
 
usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
}
 
while getopts "n:yh" opt; do
    case "$opt" in
        n) JOURS="$OPTARG" ;;
        y) CONFIRMER=0 ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done
 
# JOURS doit être un entier positif ou nul
if ! [[ "$JOURS" =~ ^[0-9]+$ ]]; then
    echo "Erreur : JOURS doit être un entier >= 0 (reçu : $JOURS)" >&2
    exit 1
fi
 
# Âge limite en minutes (plus précis que -mtime, qui arrondit à des jours entiers :
# avec -mtime +0, un fichier créé aujourd'hui n'est jamais sélectionné)
MINUTES=$((JOURS * 24 * 60))
 
# Racine du projet = dossier parent de scripts/ (aucun chemin absolu en dur)
RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
 
# --- Recherche des fichiers à supprimer ------------------------------------
A_SUPPRIMER=()
 
# 1) Fichiers temporaires (*.tmp, *~, *.swp, *.pyc) et dossiers __pycache__
while IFS= read -r -d '' f; do
    A_SUPPRIMER+=("$f")
done < <(find "$RACINE/src" "$RACINE/scripts" "$RACINE/resultats" \
              \( -name '*.tmp' -o -name '*~' -o -name '*.swp' -o -name '*.pyc' \
                 -o -name '__pycache__' \) -print0 2>/dev/null)
 
while IFS= read -r -d '' f; do
    A_SUPPRIMER+=("$f")
done < <(find "$RACINE" -maxdepth 1 \( -name '*.tmp' -o -name '*~' \) -type f -print0)
 
# 2) Rapports de resultats/ de plus de JOURS jours (on garde les *_log.txt)
while IFS= read -r -d '' f; do
    A_SUPPRIMER+=("$f")
done < <(find "$RACINE/resultats" -type f -mmin +"$MINUTES" ! -name '*_log.txt' -print0 2>/dev/null)
 
# --- Rien à faire ? ----------------------------------------------------------
if [ "${#A_SUPPRIMER[@]}" -eq 0 ]; then
    echo "Rien à nettoyer."
    exit 0
fi
 
echo "Éléments à supprimer (${#A_SUPPRIMER[@]}) :"
printf '  %s\n' "${A_SUPPRIMER[@]}"
 
# --- Confirmation ------------------------------------------------------------
if [ "$CONFIRMER" -eq 1 ]; then
    read -r -p "Confirmer la suppression ? [o/N] " reponse
    case "$reponse" in
        o|O|oui|OUI) ;;
        *) echo "Annulé."; exit 0 ;;
    esac
fi
 
# --- Suppression -------------------------------------------------------------
for f in "${A_SUPPRIMER[@]}"; do
    # Garde-fou : on refuse tout ce qui est dans data/ ou archives/
    case "$f" in
        "$RACINE"/data/*|"$RACINE"/archives/*) echo "IGNORÉ (protégé) : $f"; continue ;;
    esac
    rm -rf -- "$f"
done
 
echo "Nettoyage terminé."

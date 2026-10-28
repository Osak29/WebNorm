set -u
 
# Racine du projet = dossier parent de scripts/ (aucun chemin absolu en dur)
RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$RACINE/resultats"
DEST="$RACINE/archives"
 
# --- Vérifications -----------------------------------------------------------
if [ ! -d "$SOURCE" ]; then
    echo "Erreur : dossier introuvable : $SOURCE" >&2
    exit 1
fi
 
if [ -z "$(ls -A "$SOURCE")" ]; then
    echo "Erreur : $SOURCE est vide, rien à archiver." >&2
    exit 1
fi
 
# --- Préparation du dossier de destination -------------------------------------
mkdir -p "$DEST" || { echo "Erreur : impossible de créer $DEST" >&2; exit 1; }
chmod 700 "$DEST"
 
# --- Création de l'archive -----------------------------------------------------
HORODATAGE="$(date +%Y-%m-%d_%Hh%Mm%S)"
ARCHIVE="$DEST/resultats_${HORODATAGE}.tar.gz"
 
# umask 077 : le fichier est créé directement en 600, jamais lisible par d'autres
# -C : l'archive contient "resultats/..." et non le chemin complet de la machine
if (umask 077 && tar -czf "$ARCHIVE" -C "$RACINE" resultats); then
    chmod 600 "$ARCHIVE"
    echo "Archive créée : $ARCHIVE"
    ls -l "$ARCHIVE"
else
    echo "Erreur : la création de l'archive a échoué." >&2
    rm -f "$ARCHIVE"
    exit 1
fi

#!/usr/bin/env bash
# =============================================================================
# A4 — lancer.sh : lance l'analyse des journaux et écrit un rapport horodaté
# Usage : bash scripts/lancer.sh JOURNAL [N]
#   JOURNAL : fichier de journaux à analyser (ex. echantillon_access.log)
#   N       : nombre de workers, entier >= 1 (défaut : 4)
# Programme lancé :
#   - src/analyse_par.py (version parallèle) s'il existe, appelé avec JOURNAL N
#   - sinon src/analyse_seq.py (version séquentielle), appelé avec JOURNAL seul
# Codes de retour :
#   0 succès | 1 mauvais nombre d'arguments | 2 fichier absent ou invalide
#   3 fichier illisible | 4 N invalide | 5 prérequis manquant | 6 échec analyse
# =============================================================================
set -u

# Racine du projet = dossier juste au-dessus de scripts/ (aucun chemin absolu)
RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROG_PAR="$RACINE/src/analyse_par.py"
PROG_SEQ="$RACINE/src/analyse_seq.py"
DOSSIER_RES="$RACINE/resultats"
N_DEFAUT=4

usage() {
    echo "Usage : bash scripts/lancer.sh JOURNAL [N]" >&2
    echo "  JOURNAL : fichier de journaux à analyser" >&2
    echo "  N       : nombre de workers, entier >= 1 (défaut : $N_DEFAUT)" >&2
}

# --- Vérification des arguments ---------------------------------------------
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Erreur : nombre d'arguments incorrect ($# reçu)." >&2
    usage
    exit 1
fi

JOURNAL="$1"
N="${2:-$N_DEFAUT}"

if [ ! -e "$JOURNAL" ]; then
    echo "Erreur : le fichier '$JOURNAL' n'existe pas." >&2
    exit 2
fi
if [ ! -f "$JOURNAL" ]; then
    echo "Erreur : '$JOURNAL' n'est pas un fichier ordinaire." >&2
    exit 2
fi
if [ ! -r "$JOURNAL" ]; then
    echo "Erreur : pas le droit de lire '$JOURNAL'." >&2
    exit 3
fi

# N doit être composé uniquement de chiffres et valoir au moins 1
case "$N" in
    ''|*[!0-9]*)
        echo "Erreur : N doit être un entier positif (reçu : '$N')." >&2
        exit 4 ;;
esac
if [ "$N" -lt 1 ]; then
    echo "Erreur : N doit valoir au moins 1 (reçu : '$N')." >&2
    exit 4
fi

# --- Vérification des prérequis ---------------------------------------------
if ! command -v python3 > /dev/null 2>&1; then
    echo "Erreur : python3 est introuvable." >&2
    exit 5
fi

# Choix du programme : la version parallèle en priorité
if [ -f "$PROG_PAR" ]; then
    MODE="parallèle"
    COMMANDE=(python3 "$PROG_PAR" "$JOURNAL" "$N")
    SUFFIXE="N${N}"
elif [ -f "$PROG_SEQ" ]; then
    MODE="séquentielle"
    COMMANDE=(python3 "$PROG_SEQ" "$JOURNAL")
    SUFFIXE="seq"
    if [ $# -eq 2 ]; then
        echo "Attention : version séquentielle, N=$N est ignoré." >&2
    fi
else
    echo "Erreur : aucun programme d'analyse trouvé dans $RACINE/src/" >&2
    echo "  (attendu : analyse_par.py ou analyse_seq.py)" >&2
    exit 5
fi

# --- Lancement ----------------------------------------------------------------
mkdir -p "$DOSSIER_RES"
HORODATAGE="$(date +%Y%m%d_%H%M%S)"
RAPPORT="$DOSSIER_RES/rapport_${HORODATAGE}_${SUFFIXE}.txt"

echo "Analyse de '$JOURNAL' (version $MODE)..."
DEBUT=$(date +%s)

# 2>&1 : les messages d'erreur du Python vont aussi dans le fichier,
# pour pouvoir les afficher si l'analyse échoue
if "${COMMANDE[@]}" > "$RAPPORT" 2>&1; then
    echo "Rapport écrit : resultats/$(basename "$RAPPORT") ($(( $(date +%s) - DEBUT )) s)"
    exit 0
else
    CODE=$?
    echo "Erreur : l'analyse a échoué (code $CODE). Sortie du programme :" >&2
    echo "------------------------------------------------------------" >&2
    cat "$RAPPORT" >&2
    echo "------------------------------------------------------------" >&2
    rm -f "$RAPPORT"   # pas de rapport vide ou partiel dans resultats/
    exit 6
fi
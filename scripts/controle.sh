#!/usr/bin/env bash
# =============================================================================
# A5 — controle.sh : recalcule les indicateurs avec les commandes du cours
#                    (grep, cut, sort, uniq -c, head, wc) reliées par des tubes,
#                    pour vérifier les nombres du programme Python.
# Usage : bash scripts/controle.sh JOURNAL
# Sortie : resultats/controle_AAAAMMJJ_HHMMSS.txt (écrit par redirection)
# =============================================================================
set -u

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOSSIER_RES="$RACINE/resultats"

# Tri octet par octet : même ordre que sorted() en Python, quelle que soit la langue
export LC_ALL=C

if [ $# -ne 1 ]; then
    echo "Usage : bash scripts/controle.sh JOURNAL" >&2
    exit 1
fi
JOURNAL="$1"
if [ ! -f "$JOURNAL" ]; then
    echo "Erreur : le fichier '$JOURNAL' n'existe pas." >&2
    exit 2
fi
if [ ! -r "$JOURNAL" ]; then
    echo "Erreur : pas le droit de lire '$JOURNAL'." >&2
    exit 3
fi

# Ligne bien formée (format Apache combined) :
# IP ident user [jj/Mmm/aaaa:hh:mm:ss +zzzz] "METHODE /page PROTOCOLE" code taille "referer" "agent"
# ATTENTION : cette règle doit être EXACTEMENT celle du programme Python,
# sinon le nombre de lignes ignorées (et donc les comptes) seront différents.
MOTIF='^[^ ]+ [^ ]+ [^ ]+ \[[0-9]{2}/[A-Za-z]{3}/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}\] "[A-Z]+ [^ ]+ [^ "]+" [0-9]{3} ([0-9]+|-) "[^"]*" "[^"]*"$'

# Fichier temporaire : on ne garde que les 4 champs utiles des lignes valides
# (1 = IP, 4 = date, 7 = page, 9 = code) pour ne lire le gros journal qu'une fois.
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

mkdir -p "$DOSSIER_RES"
SORTIE="$DOSSIER_RES/controle_$(date +%Y%m%d_%H%M%S).txt"
DEBUT=$(date +%s)

tr -d '\r' < "$JOURNAL" | grep -E "$MOTIF" | cut -d' ' -f1,4,7,9 > "$TMP"
# Dans $TMP : champ 1 = IP, 2 = [date:heure..., 3 = page, 4 = code

TOTAL=$(wc -l < "$JOURNAL")
VALIDES=$(wc -l < "$TMP")
IGNOREES=$((TOTAL - VALIDES))

{
    echo "=== CONTROLE EN LIGNE DE COMMANDE ==="
    echo "Journal          : $JOURNAL"
    echo "Lignes analysées : $VALIDES"
    echo "Lignes ignorées  : $IGNOREES"
    echo
    echo "--- 1. Requêtes par code HTTP (triées par code) ---"
    cut -d' ' -f4 "$TMP" | sort | uniq -c | sort -k2,2n
    echo
    echo "--- 2. Top 10 des adresses IP ---"
    cut -d' ' -f1 "$TMP" | sort | uniq -c | sort -k1,1nr -k2,2 | head -n 10
    echo
    echo "--- 3. Top 10 des pages ---"
    cut -d' ' -f3 "$TMP" | sort | uniq -c | sort -k1,1nr -k2,2 | head -n 10
    echo
    echo "--- 4. Requêtes par heure ---"
    cut -d' ' -f2 "$TMP" | cut -d: -f2 | sort | uniq -c
    echo
    echo "Temps de contrôle : $(( $(date +%s) - DEBUT )) s"
} > "$SORTIE"

echo "Contrôle écrit : resultats/$(basename "$SORTIE")"

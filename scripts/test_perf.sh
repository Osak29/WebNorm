#!/bin/bash

set -e

FICHIER="../data/access.log"
RESULTAT="resultats_perf.txt"

systeme=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '"' -f 2)
processeur=$(lscpu | grep 'Model name' | head -1 | cut -d ':' -f 2 | xargs)
coeurs=$(nproc)
ram=$(free -h | awk '/^Mem:/ {print $2}')
python=$(python3 --version 2>&1)

# Mesure le temps d'exécution en secondes
mesurer() {
    /usr/bin/time -f "%e" -o /tmp/temps_perf.txt "$@" > /dev/null
    cat /tmp/temps_perf.txt
}



echo "==== CONFIGURATION DE TEST ====" >> "$RESULTAT"
echo "Système : $systeme" >> "$RESULTAT"
echo "Processeur : $processeur" >> "$RESULTAT"
echo "Nombre de cœurs : $coeurs" >> "$RESULTAT"
echo "RAM : $ram" >> "$RESULTAT"
echo "Python : $python" >> "$RESULTAT"
echo >> "$RESULTAT"

echo "==== VERSION SEQUENTIELLE ====" >> "$RESULTAT"

for i in 1 2 3; do
    temps=$(mesurer python3 ../src/analyse_seq.py "$FICHIER")
    echo "Essai $i : $temps s" >> "$RESULTAT"
done

for workers in 1 2 4 8; do
    echo >> "$RESULTAT"
    echo "==== VERSION PARALLELE ($workers WORKERS) ====" >> "$RESULTAT"

    for i in 1 2 3; do
        temps=$(mesurer python3 ../src/analyse_par.py "$FICHIER" "$workers")
        echo "Essai $i : $temps s" >> "$RESULTAT"
    done
done

echo
echo "Résultats enregistrés dans : $RESULTAT"



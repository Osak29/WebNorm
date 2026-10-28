#!/bin/bash

set -e

LOG=$1

python3 ../src/analyse_seq.py "$LOG" | grep -v "^Temps" > resultat_seq.txt

python3 ../src/analyse_par.py "$LOG" 4 | grep -v "^Temps" > resultat_par.txt

diff resultat_seq.txt resultat_par.txt

echo "✅ Validation P3 réussie : résultats identiques."

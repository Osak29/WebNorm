#!/bin/bash
set -e

echo "Installation de l'arborescence"

mkdir -p data src scripts resultats archives docs

chmod 770 data
chmod 774 scripts
chmod 700 archives

echo "Arborescence installée"

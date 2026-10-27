"""Analyse un fichier journal de serveur web en parallèle."""
import os
import sys
import time
from collections import Counter
from multiprocessing import Pool

# On réutilise exactement la même analyse de ligne que la version
# séquentielle : garantie de résultats identiques.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from analyse_seq import analyser_ligne  # noqa: E402


def decouper(taille, n):
    """Retourne n intervalles [debut, fin) couvrant tout le fichier."""
    pas = taille // n
    blocs = []
    for i in range(n):
        debut = i * pas
        fin = taille if i == n - 1 else (i + 1) * pas
        blocs.append((debut, fin))
    return blocs


def traiter_bloc(args):
    """Travail d'un worker : analyse les lignes qui COMMENCENT dans [debut, fin)."""
    fichier, debut, fin = args

    codes, ips, pages, heures = Counter(), Counter(), Counter(), Counter()
    analysees = 0
    ignorees = 0

    with open(fichier, "rb") as f:
        if debut > 0:
            # On recule d'un octet puis on lit jusqu'au '\n' :
            #  - si l'octet debut-1 est '\n', on ne consomme que lui
            #    et on démarre pile sur une nouvelle ligne ;
            #  - sinon on saute la fin d'une ligne qui appartient au bloc précédent.
            f.seek(debut - 1)
            f.readline()

        pos = f.tell()
        while pos < fin:
            brut = f.readline()
            if not brut:
                break
            pos += len(brut)

            ligne = brut.decode("utf-8", errors="replace")
            resultat = analyser_ligne(ligne)

            if resultat is None:
                ignorees += 1
                continue

            ip, page, code, heure = resultat
            analysees += 1
            codes[code] += 1
            ips[ip] += 1
            pages[page] += 1
            heures[heure] += 1

    return codes, ips, pages, heures, analysees, ignorees


def top10(compteur):
    # Tri déterministe : nombre décroissant, puis clé croissante
    # (évite des écarts entre seq et par en cas d'égalité).
    return sorted(compteur.items(), key=lambda kv: (-kv[1], str(kv[0])))[:10]


def main():
    if len(sys.argv) not in (2, 3):
        print("Usage: python3 analyse_par.py fichier.log [N]")
        sys.exit(1)

    fichier = sys.argv[1]
    if not os.path.isfile(fichier):
        print(f"Erreur : fichier introuvable : {fichier}")
        sys.exit(1)

    if len(sys.argv) == 3:
        try:
            n = int(sys.argv[2])
            if n < 1:
                raise ValueError
        except ValueError:
            print(f"Erreur : N doit être un entier >= 1 (reçu : {sys.argv[2]})")
            sys.exit(1)
    else:
        n = os.cpu_count() or 1

    taille = os.path.getsize(fichier)
    n = max(1, min(n, taille)) if taille > 0 else 1

    debut_t = time.time()

    taches = [(fichier, d, f) for d, f in decouper(taille, n)]
    with Pool(processes=n) as pool:
        partiels = pool.map(traiter_bloc, taches)

    # Fusion dans le processus principal (un seul processus => pas de verrou)
    codes_http, ips, pages, heures = Counter(), Counter(), Counter(), Counter()
    lignes_analysees = 0
    lignes_ignorees = 0
    for c, i, p, h, a, ig in partiels:
        codes_http.update(c)
        ips.update(i)
        pages.update(p)
        heures.update(h)
        lignes_analysees += a
        lignes_ignorees += ig

    fin_t = time.time()

    print(f"Lignes analysées : {lignes_analysees}")
    print(f"Lignes ignorées : {lignes_ignorees}")
    print(f"Temps : {fin_t - debut_t:.2f} s")

    print("\nCodes HTTP")
    for code, nb in sorted(codes_http.items()):
        print(code, nb)

    print("\nTop 10 IP")
    for ip, nb in top10(ips):
        print(ip, nb)

    print("\nTop 10 pages")
    for page, nb in top10(pages):
        print(page, nb)

    print("\nRequêtes par heure")
    for heure in range(24):
        print(f"{heure:02d}h : {heures[heure]}")


if __name__ == "__main__":
    main()
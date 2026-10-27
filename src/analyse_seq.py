import re
from collections import Counter
import sys
import time


PATTERN = re.compile(
    r'(?P<ip>\S+) .*? '
    r'\[(?P<date>[^\]]+)\] '
    r'"(?P<methode>\S+) (?P<page>\S+) [^"]+" '
    r'(?P<code>\d{3})'
)

def analyser_ligne(ligne):
    m = PATTERN.search(ligne)

    if not m:
        return None

    ip = m.group("ip")
    page = m.group("page")
    code = int(m.group("code"))

    date = m.group("date")
    heure = int(date.split(":")[1])

    return ip, page, code, heure

def main():

    if len(sys.argv) != 2:
        print("Usage: python3 analyse_seq.py fichier.log")
        sys.exit(1)

    fichier = sys.argv[1]

    codes_http = Counter()
    ips = Counter()
    pages = Counter()
    heures = Counter()

    lignes_analysees = 0
    lignes_ignorees = 0

    debut = time.time()

    with open(fichier, "r", encoding="utf-8") as f:

        for ligne in f:

            resultat = analyser_ligne(ligne)

            if resultat is None:
                lignes_ignorees += 1
                continue

            ip, page, code, heure = resultat

            lignes_analysees += 1

            codes_http[code] += 1
            ips[ip] += 1
            pages[page] += 1
            heures[heure] += 1

    fin = time.time()

    print(f"Lignes analysées : {lignes_analysees}")
    print(f"Lignes ignorées : {lignes_ignorees}")
    print(f"Temps : {fin - debut:.2f} s")

    print("\nCodes HTTP")
    for code, nb in sorted(codes_http.items()):
        print(code, nb)

    print("\nTop 10 IP")
    for ip, nb in ips.most_common(10):
        print(ip, nb)

    print("\nTop 10 pages")
    for page, nb in pages.most_common(10):
        print(page, nb)

    print("\nRequêtes par heure")
    for heure in range(24):
        print(f"{heure:02d}h : {heures[heure]}")


if __name__ == "__main__":
    main()
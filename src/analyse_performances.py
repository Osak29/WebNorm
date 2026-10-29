from pathlib import Path
import re
import pandas as pd
import matplotlib.pyplot as plt

# Place resultats_perf.txt beside this script, then run: python analyse_performances.py
text = Path("../scripts/resultats_perf.txt").read_text(encoding="utf-8")
blocks = re.split(r"(?==== CONFIGURATION DE TEST ====)", text)
machines = []
for block in blocks:
    if "Processeur :" not in block:
        continue
    machine = {
        "system": re.search(r"Système\\s*:\\s*(.+)", block).group(1).strip(),
        "cpu": re.search(r"Processeur\\s*:\\s*(.+)", block).group(1).strip(),
        "cores": re.search(r"Nombre de cœurs\\s*:\\s*(.+)", block).group(1).strip(),
        "ram": re.search(r"RAM\\s*:\\s*(.+)", block).group(1).strip(),
        "python": re.search(r"Python\\s*:\\s*(.+)", block).group(1).strip(),
        "results": {}
    }
    patterns = [
        ("Séquentielle", r"VERSION SEQUENTIELLE"),
        ("Parallèle – 1 worker", r"VERSION PARALLELE \\(1 WORKERS\\)"),
        ("Parallèle – 2 workers", r"VERSION PARALLELE \\(2 WORKERS\\)"),
        ("Parallèle – 4 workers", r"VERSION PARALLELE \\(4 WORKERS\\)"),
        ("Parallèle – 8 workers", r"VERSION PARALLELE \\(8 WORKERS\\)")
    ]
    for label, pattern in patterns:
        m = re.search(pattern + r"(.*?)(?=\\n\\s*====|\\Z)", block, re.S)
        if m:
            machine["results"][label] = [float(v) for v in re.findall(r"Essai\\s+\\d+\\s*:\\s*([\\d.]+)\\s*s", m.group(1))]
    machines.append(machine)

rows = []
for i, machine in enumerate(machines, 1):
    seq = sum(machine["results"]["Séquentielle"]) / 3
    for label, values in machine["results"].items():
        avg = sum(values) / len(values)
        rows.append({"Machine": i, "Processeur": machine["cpu"], "Version": label,
                     "Essais (s)": values, "Temps moyen (s)": avg,
                     "Accélération (x)": seq / avg})
df = pd.DataFrame(rows)
df.to_csv("tableau_performances.csv", index=False, encoding="utf-8-sig")
for i, machine in enumerate(machines, 1):
    labels = list(machine["results"])
    means = [sum(machine["results"][k]) / len(machine["results"][k]) for k in labels]
    seq = means[0]
    plt.figure(figsize=(9, 5))
    plt.bar(["Séquentiel", "1 worker", "2 workers", "4 workers", "8 workers"], means)
    plt.ylabel("Temps moyen (s)")
    plt.title(f"Temps moyen — Machine {i}")
    plt.tight_layout()
    plt.savefig(f"temps_moyens_machine_{i}.png", dpi=180)
    plt.close()
    plt.figure(figsize=(9, 5))
    plt.bar(["Séquentiel", "1 worker", "2 workers", "4 workers", "8 workers"], [seq/x for x in means])
    plt.axhline(1, linestyle="--")
    plt.ylabel("Accélération (x)")
    plt.title(f"Accélération — Machine {i}")
    plt.tight_layout()
    plt.savefig(f"accelerations_machine_{i}.png", dpi=180)
    plt.close()

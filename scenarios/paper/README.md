# Paper: SLADE, a Stealthy Link-Adaptation Downgrade Exploit on Industrial 5G

`MCS-Downgrade-5GLENA-Paper.tex` is the IEEE conference write-up of the attack reproduced
in this repository. Build it with:

    pdflatex MCS-Downgrade-5GLENA-Paper.tex
    pdflatex MCS-Downgrade-5GLENA-Paper.tex   # second pass for cross-references

The two block diagrams (link-adaptation loop, scenario topology) are native TikZ. The five
result figures live in `paper-figs/`:

| Figure | File | Produced by |
|---|---|---|
| Fig. 3 (R2) commanded MCS over time | `commanded-mcs-5glena-reactive.png` | `../scripts/plot-reactive.py` |
| Fig. 4 (R3) failure vs on-air time | `tradeoff-ci-5glena.png` | `../scripts/plot10.py` |
| Fig. 5 (R4) vs victim SINR / jammer power | `sweep100-5glena.png` | `../scripts/plot_sweep.py` |
| Fig. 6 (R6) stealth/effectiveness grid | `tradeoff-frontier-5glena.png` | `../scripts/plot_frontier.py` |
| Fig. 7 (R5) delay resonance, LOS vs random | `delay-resonance-5glena.png` | `../scripts/plot_resonance2.py` |

`channel-regime-5glena.png` is a supporting figure for R4 that is not in the paper.

The `*.csv` files in this folder are the raw per-seed data behind every table and figure.
See [`../README.md`](../README.md) for which script produced each file and how to
regenerate the tables and figures from them.

# SLADE: a Stealthy Link-Adaptation Downgrade Exploit on industrial 5G

Reproducibility artifact for the paper **"SLADE: A Stealthy Link-Adaptation Downgrade
Exploit on Industrial 5G"** (S. Caldato, E. Trettenero, A. Brighente, University of Padova).

An attacker that can read the victim's per-slot MCS from the unprotected DCI fires a short
interference pulse only while the victim is on a high MCS. The corrupted block is still
received, fails its CRC and returns a genuine HARQ NACK; outer-loop link adaptation (OLLA)
reads the NACK and lowers the MCS. Repeating this keeps the link trapped at a low MCS, so
URLLC control messages miss their deadlines. In this repository the downgrade emerges from
the simulator's own chain (co-channel interference → graded SINR (EESM) → HARQ NACK → OLLA),
with no injected corruption or forged feedback.

## What is in this branch

| Path | Content |
|---|---|
| `model/nr-mac-scheduler-ns3.{h,cc}`, `model/nr-mac-scheduler-cqi-management.cc`, `model/nr-mac-scheduler-ue-info.h` | The **DL OLLA port** (5G-LENA selects MCS from CQI only). Down-step `s` on each fresh NACK, up-step `s·B/(1−B)` on each ACK, offset re-applied at every DL slot. Scheduler attributes: `UseOlla`, `OllaStep`, `OllaTargetBler`, `OllaMaxOffset`, `OllaMinOffset`. |
| `scenarios/mcs-downgrade.cc` | The attack scenario: victim cell + co-channel interferer cell whose UE is co-located with the victim; constant (broadband) or reactive MCS-aware jammer; saturating or periodic URLLC traffic; bottle-filling plant. |
| `scenarios/scripts/` | Run, merge, and plot scripts (bash + Python). |
| `scenarios/paper/` | Paper LaTeX source, **raw per-seed CSVs** behind every table and figure, and the figures as used in the paper (`paper-figs/`). |
| `scenarios/paper/LINKLEVEL-CROSSCHECK.md`, `scripts/linklevel-crosscheck.py` | Design and script for the planned link-level (Sionna) check of the per-pulse assumption (paper §VII, not part of the results). |
| `scenarios/figures/` | Figures from earlier campaigns (legacy, see below). |

The exact changes against upstream 5G-LENA are auditable with `git diff v4.2..HEAD`.

## Build

Tested on **ns-3.47** with this fork as the `nr` module (5G-LENA v4.2 + the OLLA port):

```bash
git clone --branch ns-3.47 https://gitlab.com/nsnam/ns-3-dev.git
git clone --branch mcs-downgrade https://github.com/simone1170/5glena-mcs-downgrade.git ns-3-dev/contrib/nr
cd ns-3-dev
cp contrib/nr/scenarios/mcs-downgrade.cc scratch/
./ns3 configure --enable-examples -d optimized && ./ns3 build mcs-downgrade
```

Note: `scripts/setup-5glena.sh` clones *upstream* nr v4.2 (without the OLLA port); use the
commands above instead.

Example: the paper's realistic reactive attacker (R3 configuration, one seed):

```bash
./ns3 run "mcs-downgrade --reactive=true --useOlla=true --mcsThreshold=10 --reactionDelayMs=0.5 \
  --urllcPacketSize=128 --urllcPeriodMs=1.0 --deadlineMs=2.0 --plant=true \
  --channelCondition=LOS --simTime=2.0 --RngRun=1"
```

The run prints a `reactive jammer: ... dutyCycle=` line (on-air time = duty × 100), a
`METRICS tx= rx= late=` line (URLLC failure = (tx − (rx − late)) / tx), and a
`PLANT ... spills=` line.

### Main scenario flags

| Flag | Default | Paper value |
|---|---|---|
| `--useOlla`, `--ollaStep`, `--ollaTargetBler` | off, 0.1, 0.1 | on, s = 0.1, B = 0.1 (swept in R5) |
| `--reactive` | false | true for the attack; false + `--jammerTxPowerDbm` for broadband |
| `--mcsThreshold` | 10 | 10 (swept in R6) |
| `--jammerHighPowerDbm` / `--jammerLowPowerDbm` | 50 / −50 | 50 / −50 (ON power swept in R4, R6) |
| `--reactionDelayMs` | 0 (oracle) | 0.5 (realistic), swept 0–2 ms |
| `--victimTxPowerDbm` | 30 | 30 (swept in R4) |
| `--urllc`, `--urllcPacketSize`, `--urllcPeriodMs`, `--deadlineMs` | off, **1000 B**, 1 ms, 2 ms | on, **128 B**, 1 ms, 2 ms |
| `--plant` | false | true for URLLC impact runs (`--plant` forces `--urllc=true`) |
| `--channelCondition` | `Default` (random LOS/NLOS) | `LOS` for R3/R5, `Default` for R4/R6 |
| `--RngRun` | 1 | seeds 1–10 (LOS), 1–100 (random channel) |

The default packet size is 1000 B; all paper URLLC results pass `--urllcPacketSize=128`
explicitly. A 1000 B payload saturates the failure metric (see "Legacy" below).

## Paper result → script → data → figure

All CSVs below are committed in `scenarios/paper/`. Seed pools were built in two passes
(initial seeds, then a top-up to 10) and merged by `analyze10.py`.

| Result (paper) | Run | Raw data (`scenarios/paper/`) | Analysis / plot | Output |
|---|---|---|---|---|
| **R1** graded interference, Table I | `run-phase1-sweep.sh` | console only | `analyze-phase1.sh` | console |
| **R2** OLLA check, Table II | `run-olla-validate.sh` | console only | — | console |
| **R2** reactive downgrade, Table III, Fig. 3 | `run-reactive-5glena.sh` | console + `RxPacketTrace.txt` | `plot-reactive.py` | `commanded-mcs-5glena-reactive.png` |
| **R3** reactive vs broadband, Table IV, Fig. 4 (LOS, 128 B, 10 seeds) | `campaign128.sh` (Study D, seeds 1–5) + `topup10.sh` §1 (seeds 6–10) | `studyD-R3-128.csv`, `studyD-R3-128-s6_10.csv` → **`studyD10-R3-128.csv`** | `analyze10.py`, `plot10.py` (Fig. 4 part) | `tradeoff-ci-5glena.png` |
| **R4** cost vs victim SINR / jammer power, Fig. 5 (random channel, 100 seeds per point) | `sweep100.sh` | `studyG-sweep100-victimpow.csv`, `studyH-sweep100-jammerpow.csv` | `analyze_sweep.py`, `plot_sweep.py` | `sweep100-5glena.png` |
| **R4** bimodality and broadband on the random channel (12 seeds) | `studyE-regime128.sh` | `studyE-regime-128.csv` | `analyze10.py` (R4 block), `plot_regime128.py` | console, `channel-regime-5glena.png` (not in the paper) |
| **R5** OLLA tuning, Table V (saturating, LOS, 10 seeds) | `run-olla-robustness.sh` with `STUDY=A` (seeds 1–3) + `topup10.sh` §2 (seeds 4–10) | `studyA-olla-dependence.csv`, `studyA-tuning-s4_10.csv` → **`studyA10-olla-dependence.csv`** | `analyze10.py` | console |
| **R5** delay resonance vs OLLA step, Table VI (LOS, 128 B, 10 seeds) | `payload-sweep.sh` (s = 0.10, seeds 1–3) + `campaign128.sh` Study C2 (s = 0.05/0.20, seeds 1–3) + `topup10.sh` §3 (seeds 4–10) | `studyC-payload128.csv`, `studyC2-resonance-128.csv`, `studyF-resonance-s4_10.csv` → **`studyF10-resonance-128.csv`** | `analyze10.py` | console |
| **R5** resonance on the random channel, Fig. 7 right (100 seeds) | `studyK.sh` | `studyK-resonance-random100.csv` | `plot_resonance2.py` (both panels of Fig. 7) | `delay-resonance-5glena.png` |
| **R6** power × threshold grid, Fig. 6 (random channel, 100 seeds per cell) | `grid100.sh` | `studyJ-grid100.csv` | `plot_frontier.py` | `tradeoff-frontier-5glena.png` |

`plot10.py` also writes a single-panel `delay-resonance-5glena.png`; the paper's two-panel
Fig. 7 is the one from `plot_resonance2.py`, so run that one last.

### Headline numbers (recomputed from the committed CSVs)

R3, LOS, 128 B URLLC, mean ± 95% CI over 10 seeds:

| Scenario | On-air % | URLLC failed % |
|---|---|---|
| baseline | 0 | 0.2 |
| broadband 40 dBm | 100 | 21.6 ± 3.1 |
| broadband 50 dBm | 100 | 100 ± 0 |
| reactive, OLLA on, δ = 0 (oracle) | 26.8 ± 5.0 | 45.4 ± 6.4 |
| reactive, OLLA on, δ = 0.5 ms | **20.0 ± 0.7** | **98.4 ± 1.0** |
| reactive, OLLA on, δ = 1.0 ms | 23.2 ± 2.5 | 98.7 ± 1.6 |
| reactive, OLLA off, δ = 0.5 ms | 86.4 ± 4.0 | 99.9 |

- The realistic reactive attacker matches the 50 dBm broadband jammer at about one fifth of
  the on-air time; OLLA makes it about 4.3× cheaper (86.4 / 20.0).
- R5: across all nine (s, B) tunings the victim is trapped at MCS 8.1–9.6 (OLLA off: 15.1)
  with on-air time 14–42% (OLLA off: 54%).
- R5: plant faults and per-packet failure are non-monotonic in the reaction delay (low at
  0 and 1.5 ms, high at 0.5–1.0 and 2.0 ms) for every OLLA step and on both channels.
- R4: on the random channel the attack is bimodal (succeeds on 10/12 seeds); broadband
  50 dBm and reactive both average about 80% failure there.

## Re-deriving the numbers and figures

The analysis and plot scripts read and write fixed paths from the authors' WSL setup
(`WIN=/mnt/c/Users/simo1/Desktop/charlie`, `FIGS=$WIN/paper-figs`, `NS3=/home/simo1/...`).
To regenerate tables and figures from the committed data without re-running ns-3:

```bash
cd scenarios/paper
mkdir -p /tmp/slade
for s in analyze10 analyze_sweep plot10 plot_sweep plot_frontier plot_resonance2; do
  sed 's|/mnt/c/Users/simo1/Desktop/charlie|.|' ../scripts/$s.py > /tmp/slade/$s.py
done
python3 /tmp/slade/analyze10.py      # prints Tables IV, V, VI and the R4 summary
python3 /tmp/slade/analyze_sweep.py  # prints the Fig. 5 points
for s in plot10 plot_sweep plot_frontier plot_resonance2; do python3 /tmp/slade/$s.py; done
# figures are written to paper-figs/
```

Requirements: Python 3 with `pandas`, `numpy`, `matplotlib`. `analyze10.py` rewrites the
merged `*10-*.csv` files from their parts; with the committed data they come out identical.

To re-run the simulations, edit `NS3`, `BASE` and `WIN`/`WINOUT` at the top of each run
script. The 100-seed campaigns (`sweep100.sh`, `grid100.sh`, `studyK.sh`) call the
optimized binary directly and run 6 jobs in parallel (`xargs -P 6`).

## Legacy scripts and figures

These come from earlier campaigns and are kept for traceability; their numbers are
**not** the paper's and should not be cited:

- `run-phase3.sh`, `plot-phase3.py`, `dump-phase3.sh`: first URLLC trade-off with a 1000 B payload.
- `run-ci.sh`, `plot-ci.py`, `make-ci-fig.sh`: 5-seed CI campaign at the default 1000 B
  payload. At that payload the failure metric saturates (≈ 100% even for 40 dBm broadband),
  which is why the paper uses 128 B.
- `run-sensing.sh`, `run-delay-sweep.sh`, `run-delay-fine.sh`, `analyze-delay.py`,
  `plot-delay-fine.py`, `run-plant.sh`, `reconcile-spills.sh`: 1000 B delay and plant
  studies; per-packet failure was pinned at ≈ 99.9% there, so only the plant fault count
  showed the resonance.
- `run-channel-regime.sh`, `plot-regime.py`: 1000 B random-channel study.
- `run-broadband50.sh` → `paper/bb50-matched-power.csv`; `run-olla-robustness.sh` with
  `STUDY=B` → `paper/studyB-resonance.csv`: both at 1000 B, superseded by Study D and Study F.
- `plot128.py`: 5-seed version of Figs. 4 and 7, superseded by `plot10.py` / `plot_resonance2.py`.
- `make-*-fig.sh`, `patch-plots-onair.py`: WSL helpers for the above.
- `scenarios/figures/`: figures from these legacy campaigns. The paper's figures are in
  `scenarios/paper/paper-figs/`.

## License

GNU GPLv2, as upstream 5G-LENA and ns-3. Upstream copyright and license headers are retained.

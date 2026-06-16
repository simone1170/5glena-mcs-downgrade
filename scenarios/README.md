# MCS-downgrade reactive jamming on industrial 5G (5G-LENA)

RF-emergent reproduction of the **MCS-downgrade reactive jamming** attack in
ns-3 **5G-LENA** (nr). The downgrade emerges from the real interference ->
graded SINR (EESM) -> HARQ NACK -> outer-loop link adaptation (OLLA) chain,
with **no injected effect**.

## What is in this branch
- **OLLA port** (the nr module commit): per-UE DL outer-loop link adaptation
  in `NrMacSchedulerNs3` / `NrMacSchedulerCQIManagement`. Attributes:
  `UseOlla`, `OllaStep`, `OllaTargetBler`, `OllaMaxOffset`, `OllaMinOffset`.
- **`scenarios/mcs-downgrade.cc`**: victim cell + co-channel interferer cell
  (served UE co-located with the victim). Constant broadband interferer
  (`--jammerTxPowerDbm`) or a reactive MCS-aware jammer that reads the victim's
  commanded DL MCS via the `RxPacketTraceUe` trace and toggles the interferer
  Tx power around `--mcsThreshold` (low-duty selective jamming). URLLC victim
  mode + FlowMonitor deadline-miss metrics.
- **`scenarios/scripts/`**: build, sweep, and plotting helpers (WSL/bash).
- **`scenarios/figures/`**: headline commanded-MCS-over-time and the
  cost-vs-damage trade-off figures.

## Build & run
Requires ns-3.47 with this nr branch in `contrib/nr`.
```
cp contrib/nr/scenarios/mcs-downgrade.cc scratch/
./ns3 configure --enable-examples -d optimized && ./ns3 build mcs-downgrade
# reactive attack, OLLA on:
./ns3 run "mcs-downgrade --reactive=true --useOlla=true --mcsThreshold=10 --simTime=2.0"
```

## Headline results
- Reactive (OLLA on, thr 10): victim commanded MCS trapped ~8-9, jammer duty
  ~0.18-0.21; with OLLA off no downgrade and duty ~0.57-0.63 (OLLA-dependent).
- URLLC trade-off: reactive reaches ~100% deadline failure at duty ~0.21 vs a
  constant broadband jammer needing duty 1.0 -> ~5x less on-air time.

## Upgrades (realistic sensing, plant, confidence intervals)

New scenario flags: `--reactionDelayMs`, `--plant`, `--plantInflow`, `--channelCondition`.

- **Realistic-sensing jammer** (`--reactionDelayMs`): the attacker reads the scheduled
  MCS (PDCCH/DCI is not integrity-protected) but stale by the sense+react latency.
  Sweeping 0-2 ms leaves duty ~0.2 and ~100% URLLC failure unchanged -> the attack is
  robust to realistic sensing latency (OLLA recovery ~tens of ms >> reaction lag).
- **Closed-loop plant** (`--plant`): a bottle-filling `PlantActuator` on the victim UE.
  Stale control commands (deadline misses) leave the inlet valve open -> tank fills ->
  spill (safety event). Baseline 0 spills; reactive (OLLA on) ~108 spills at duty ~0.21.
- **Confidence intervals** (`scripts/run-ci.sh`, 5 RNG seeds): under the random 3GPP
  LOS/NLOS condition the attack is bimodal (fails when the jammer link draws an NLOS deep
  fade, where even broadband fails). Conditioning on LOS isolates the mechanism:

  | scenario | duty | URLLC failed% | plant spills |
  |---|---|---|---|
  | baseline | 0 | 0.2 | 0 |
  | broadband 40 dBm | 1.0 | 100 +/- 0 | 69 +/- 111 |
  | reactive (OLLA on) | 0.255 +/- 0.080 | 99.9 | 53 +/- 22 |
  | reactive (OLLA on, +1 ms) | 0.224 +/- 0.047 | 99.9 | 160 +/- 28 |
  | reactive (OLLA off) | 0.611 +/- 0.020 | 99.9 | 169 +/- 2 |

  Reactive (OLLA on) reaches 99.9% deadline failure at duty 0.255 vs broadband's 1.0
  (~4x efficiency); OLLA gives ~2.4x efficiency. Figure: `figures/tradeoff-ci-5glena.png`.

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
  spill (safety event). Baseline 0 spills; reactive (OLLA on) ~53 spills/2 s at duty ~0.21 (LOS, 8-seed mean; the earlier single-run "108" is reconciled below).
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

## Delayed-feedback resonance (correction to the realistic-sensing note)

An earlier note claimed a 1 ms sensing delay made the attack "more damaging" to the
plant. A reaction-delay sweep (`scripts/run-delay-sweep.sh`, 5 delays x 8 seeds; finer
`scripts/run-delay-fine.sh`, 12 delays x 5 seeds; LOS, plant on) shows that was an
artifact of sampling only delay 0 and 1 ms. The real picture:

- **The per-packet attack is delay-robust**: URLLC `failed%` ~= 99.9 and jammer
  duty ~= 0.2 at *every* delay 0-3 ms.
- **Plant damage is NON-MONOTONIC in delay** -- a delayed-feedback resonance in the
  jammer<->OLLA<->HARQ closed loop:

  | delay (ms) | plant spills / 2 s | plant-stale fraction |
  |---|---|---|
  | 0.00 | 53 | 44% |
  | 0.25-1.0 | ~160 | ~94% (high plateau) |
  | 1.25-1.5 | ~44-53 | ~37% (trough, below idealized) |
  | 1.75-3.0 | ~170 | ~98% (saturated) |

- **Mechanism**: a spill needs ~10 contiguous stale control steps (a >=~10 ms delivery
  gap), so spills measure loss *clustering*, not average failure -- which is why they
  swing 37-98% while per-packet `failed%` stays pinned at ~99.9 (late packets arrive in
  bursts that refresh the plant). At resonant delays the jammer keeps firing through the
  victim's recovery windows, so stale steps become near-contiguous and the tank overflows.

**Correct claim**: the idealized (delay-0) jammer sits at a *low* plant-damage operating
point; an attacker that can tune its reaction delay (or that lands in a resonant band) can
amplify physical-process damage ~3x at the same air-time cost. This is NOT "realistic
sensing is strictly worse." Figure: `figures/delay-resonance-5glena.png`.

## Spill-count reconciliation (the "108" vs "53" figures)

An earlier note paired a single-run plant result -- "reactive (OLLA on) ~108 spills,
~= SWICS's 110 plant events" -- with the CI campaign's 53 +/- 22. Those are not in
conflict; they are different channel conditions, and the 108 is an unrepresentative
single draw (`scripts/reconcile-spills.sh`):

- The 108 is exactly the default `run-plant.sh` run: **Default** (probabilistic 3GPP
  LOS/NLOS) channel at the **default seed** (RngRun=1).
- Across Default seeds 1-8 the reactive-on spills are bimodal: **[108, 38, 29, 0, 19,
  38, 38, 57]**, mean **41 +/- 27** -- i.e. 108 is the *worst* of the eight draws (seed 4
  even hits 0 spills, where the jammer link geometry prevents trapping the MCS so duty
  runs away to ~1.0).
- Conditioning on **LOS** (8 seeds) gives **52.5 +/- 11.2** spills, tight and stable.

**Corrected statement**: reactive jamming produces O(50) plant safety events / 2 s in the
controlled LOS case (single-draw values range 0-108 over the random channel). This is the
*same order* as SWICS's 110 events, but the precise 108~=110 match was a coincidence of an
outlier seed and should not be cited as a quantitative correspondence.

### Resonance is robust to the OLLA slot-cadence fix

After moving OLLA offset application from CQI-report instants to every DL slot
(commit "OLLA: apply offset at DL-scheduling cadence"), the delay sweep was
re-run. The resonance is essentially unchanged (troughs still at delay ~0 and
~1.25-1.5 ms; high plateau ~158-163; saturated bands 170+/-0). So the resonance
is NOT an artifact of OLLA's CQI-cadence quantization -- it is a structural
property of the reactive jammer<->HARQ<->plant loop. `figures/delay-resonance-5glena.png`
is regenerated from the fixed-OLLA data.

## Scope of the headline: LOS-conditioned mechanism + random-channel regime

The ~4x efficiency headline (reactive reaches ~100% URLLC failure at duty ~0.25 vs
broadband's 1.0) is reported under a **LOS-conditioned** channel. This is a deliberate
mechanism-isolation choice, not cherry-picking: under the random 3GPP LOS/NLOS condition
the *jammer->victim* link is itself a random draw, which degrades BOTH the reactive and
the broadband attacker. LOS conditioning removes that shared lottery so the comparison
reflects the link-adaptation mechanism, not channel luck.

The random-channel behaviour is reported here as a **separate result**
(`scripts/run-channel-regime.sh`, Default 3GPP condition, 12 seeds; the victim's own link
is stable -- baseline failed% = 0.2 and 0 spills across all 12 seeds -- so the variation is
entirely on the jammer->victim path):

| outcome | reactive seeds | duty | URLLC failed% | plant spills |
|---|---|---|---|---|
| attack **succeeds** | 10 / 12 | 0.18-0.56 | 99.9 | ~58 |
| attack **fails** (jammer link NLOS) | 2 / 12 | 1.00 | 23.7 | 0 |

- The reactive attack is **bimodal**: it succeeds at low duty in 10/12 realizations and
  collapses in 2/12, where the jammer link draws an NLOS fade so the jammer cannot trap the
  victim's MCS -- its controller then fires continuously (duty -> 1.0) yet the victim is
  spared (0 spills).
- **Broadband is channel-dependent too**: mean URLLC failed% is only 76% (vs 100% under LOS)
  and it causes plant spills in just 7/12 seeds. So NLOS draws hurt broadband as well --
  confirming the LOS conditioning is a fair isolation rather than a thumb on the scale.

Figure: `figures/channel-regime-5glena.png`. Practical reading: against a fixed industrial
victim with a line-of-sight-ish interferer geometry the reactive attack dominates; a
defender's main channel-level mitigation is denying the attacker an LOS path to the victim.

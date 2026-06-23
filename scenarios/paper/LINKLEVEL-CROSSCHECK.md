# Link-level cross-check — design note

*Companion to the MCS-downgrade 5G-LENA paper. Addresses the load-bearing PHY
assumption flagged in the paper's "Threats to validity" section.*

## Why this is needed

The 5G-LENA study is **system-level**. It demonstrates the closed loop
(corruption → NACK → OLLA → MCS downgrade → URLLC deadline miss → plant fault) and
emergent dynamics (resonance, channel bimodality). But it cannot validate the single
physical-layer event the whole attack rests on, and it papers over it twice:

1. **The "jammer" is a rogue NR cell**, not a jammer. Interference is a beamformed
   5G NR waveform, not jammer noise. So the *probability that one short pulse fails
   one high-MCS transport block* is never measured against a realistic interference
   shape.
2. **The error model is EESM**, an abstraction calibrated for average interference,
   not for short bursts that hit only part of a slot.

The attack's whole efficiency claim ("same damage at ~¼ the on-air time") depends on
that per-block event being **cheap** — a short, low-energy pulse should be enough.
This cross-check measures it directly.

## The question, precisely

> At equal *average* interference energy, is a **short pulse** (covering a fraction
> `f` of a slot's symbols) as effective at failing a high-MCS transport block as
> **continuous** interference spread over the whole slot?

- If **yes** (pulse BLER curve ≈ continuous curve), the reactive attacker pays no
  PHY penalty for being bursty → the system-level duty cycles are sound.
- If **no** (pulse curve sits to the right, needs more SINR loss), bursty jamming is
  *less* energy-efficient per block than the system-level model assumes → the
  reported duty cycles are optimistic and should be rescaled upward.

Either outcome is publishable and strengthens the paper: it converts an assumption
into a measured input.

## Tool choice

| Tool | Verdict |
|---|---|
| **NVIDIA Sionna** (chosen) | GPU, Python, 3GPP-compliant 5G NR LDPC + QAM chain, scriptable, free. Best fit. |
| MATLAB 5G Toolbox | Equivalent fidelity (full PDSCH chain incl. rate matching, scrambling). Use if you have a license. |
| srsRAN PHY | Real production PHY in C; closest to hardware but heaviest to instrument for a BLER sweep. |

Real SDR-in-a-chamber is the gold standard but is out of scope (legal/RF-safety),
exactly as the paper states.

## What the script does (`wsl-scripts/linklevel-crosscheck.py`)

For each MCS in the sweep:
1. Map MCS → (modulation order `Qm`, code rate `R`) via 3GPP TS 38.214
   Table 5.1.3.1-2 (MCS table 2).
2. Build the NR chain: `BinarySource → LDPC5GEncoder → QAM Mapper → channel →
   Demapper(app) → LDPC5GDecoder`.
3. Sweep SINR. At each SINR, add complex Gaussian interference under two shapes at
   **equal average power** `n0 = 10^(-SINR/10)`:
   - **continuous**: variance `n0` on every symbol;
   - **pulse**: variance `n0·N/f` on a random `f`-fraction of the `N` symbols, zero
     elsewhere (same total energy, concentrated).
4. Measure BLER over a batch of blocks (a block error = any bit wrong after LDPC).
5. Plot BLER vs SINR, continuous (solid) vs pulse (dashed), per MCS, with the 10%
   OLLA target marked.

The demapper is given the **per-symbol** noise variance it actually saw, so the LLRs
are correct for the bursty case (a uniform-`n0` demapper would understate the pulse's
effect and bias the result).

## Run it

```bash
pip install sionna tensorflow numpy matplotlib      # CPU ok; GPU faster
python3 linklevel-crosscheck.py                     # MCS 9,16,22,26
python3 linklevel-crosscheck.py --mcs 22 24 26 --pulse-frac 0.25 --batch 5000
# -> linklevel-crosscheck.png
```

Key knobs: `--mcs` (which MCS), `--pulse-frac` (how concentrated the pulse is — set
this to roughly the reactive jammer's per-slot on-fraction), `--sinr MIN MAX STEP`,
`--batch` (blocks per point; raise for smooth low-BLER tails).

## How the result feeds back into the paper

- Add the figure as a new subsection (e.g. R6 / "Link-level validation") or in the
  cross-check paragraph already in *Future Work*.
- Read off, per high MCS, the **SINR gap** between the 10%-BLER points of the pulse
  vs continuous curves. That gap (in dB) is the PHY-level correction factor for the
  attacker's energy budget.
- If the gap is small (≲1–2 dB), state the system-level efficiency numbers as
  PHY-confirmed. If large, present the corrected (rescaled) duty cycles.

## Caveats of the cross-check itself

- It models a single-carrier coded block with per-symbol AWGN-like interference, not
  the full OFDM resource grid, rate matching, scrambling, or HARQ combining. It
  validates the *coding-cliff-under-burst* question, not the whole air interface.
- HARQ chase/IR combining across retransmissions would change the multi-shot picture;
  this is a single-transmission BLER. That is the right granularity for the
  "one pulse → one NACK" claim, but note it explicitly.

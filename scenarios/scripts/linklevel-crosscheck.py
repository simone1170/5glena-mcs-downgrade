#!/usr/bin/env python3
"""
Link-level cross-check for the MCS-downgrade paper (review item #3).

PURPOSE
-------
The 5G-LENA study assumes the one physical-layer step the whole attack rests on:
that a SHORT, low-energy interference PULSE makes a HIGH-MCS transport block fail
its decode (-> NACK -> OLLA downgrade). The system-level simulator cannot establish
this; it fakes graded interference with a rogue cell. This script checks the
assumption directly with a 3GPP-compliant 5G NR LDPC chain in NVIDIA Sionna.

WHAT IT SIMULATES
-----------------
For each MCS we build the real NR coded-modulation chain (QAM + 5G LDPC), pass a
transport block through a channel, and measure block error rate (BLER) vs the
signal-to-interference-plus-noise ratio (SINR), under two interference SHAPES at
EQUAL average energy:

  * CONTINUOUS  -- interference spread over all symbols (the broadband baseline).
  * PULSE       -- the same total interference energy concentrated on a fraction
                   `pulse_frac` of the symbols (the reactive attacker, which only
                   covers part of the slot).

OUTPUT
------
`linklevel-crosscheck.png`: BLER-vs-SINR curves, one pair (continuous vs pulse)
per MCS. The question it answers: how much energy, over how few symbols, a pulse
needs to push a given high MCS past its decoding cliff -- and whether the pulse is
as efficient as continuous interference at equal energy. If the pulse curves sit
on top of the continuous curves, the system-level duty-cycle numbers are sound; if
the pulse curves sit well to the right (need more energy), the duty cycles are
optimistic and should be rescaled.

REQUIREMENTS
------------
    pip install sionna tensorflow numpy matplotlib
Runs on CPU; a GPU makes it much faster. Tested against the Sionna 0.19 API.

USAGE
-----
    python3 linklevel-crosscheck.py                 # default MCS set
    python3 linklevel-crosscheck.py --mcs 20 22 26  # pick high MCS only
"""
import argparse
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

import tensorflow as tf
from sionna.mapping import Mapper, Demapper, Constellation
from sionna.fec.ldpc.encoding import LDPC5GEncoder
from sionna.fec.ldpc.decoding import LDPC5GDecoder
from sionna.utils import BinarySource

# --- 3GPP TS 38.214 Table 5.1.3.1-2 (MCS index table 2), subset ---
#     MCS -> (modulation order Qm, target code rate R)
MCS_TABLE = {
    0:  (2, 0.1172), 4:  (2, 0.4385), 9:  (4, 0.6016),
    14: (6, 0.4922), 16: (6, 0.6172), 20: (6, 0.7539),
    22: (8, 0.6396), 24: (8, 0.7539), 26: (8, 0.8525),
}


def run_point(qm, rate, sinr_db, pulse_frac, n_info, batch, channel_seed):
    """Return BLER for one (MCS, SINR, interference-shape) point.

    pulse_frac is None for continuous interference, else the fraction of symbols
    the pulse covers (energy is concentrated there at equal average power)."""
    k = int(n_info)
    n = int(np.ceil(k / rate))            # coded bits
    n = n - (n % qm)                      # whole symbols
    num_sym = n // qm

    source = BinarySource()
    encoder = LDPC5GEncoder(k, n)
    constellation = Constellation("qam", qm)
    mapper = Mapper(constellation=constellation)
    demapper = Demapper("app", constellation=constellation)
    decoder = LDPC5GDecoder(encoder, hard_out=True)

    bits = source([batch, k])
    cbits = encoder(bits)
    x = mapper(cbits)                     # [batch, num_sym] complex symbols

    # Average interference+noise power for the target SINR (signal power = 1).
    n0_avg = 10.0 ** (-sinr_db / 10.0)

    if pulse_frac is None:
        n0_vec = tf.fill([1, num_sym], n0_avg)          # spread over all symbols
    else:
        # Same TOTAL energy on a fraction f of symbols -> power n0_avg/f there, 0 else.
        f = max(1, int(round(pulse_frac * num_sym)))
        per = n0_avg * num_sym / f
        mask = np.zeros(num_sym, dtype=np.float32)
        rng = np.random.default_rng(channel_seed)
        mask[rng.choice(num_sym, size=f, replace=False)] = per
        n0_vec = tf.constant(mask[None, :])

    # complex AWGN with per-symbol variance n0_vec (real+imag each n0/2)
    noise = tf.complex(
        tf.random.normal(tf.shape(x), stddev=tf.sqrt(n0_vec / 2.0)),
        tf.random.normal(tf.shape(x), stddev=tf.sqrt(n0_vec / 2.0)),
    )
    y = x + noise

    # Demapper needs the per-symbol noise variance it actually saw.
    llr = demapper([y, n0_vec])
    bits_hat = decoder(llr)

    block_err = tf.reduce_any(tf.not_equal(bits, bits_hat), axis=1)
    return float(tf.reduce_mean(tf.cast(block_err, tf.float32)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mcs", type=int, nargs="+",
                    default=[9, 16, 22, 26], help="MCS indices to sweep")
    ap.add_argument("--sinr", type=float, nargs=3, default=[-4.0, 22.0, 1.0],
                    metavar=("MIN", "MAX", "STEP"))
    ap.add_argument("--pulse-frac", type=float, default=0.25,
                    help="fraction of symbols the pulse covers")
    ap.add_argument("--ninfo", type=int, default=3840, help="info bits per block")
    ap.add_argument("--batch", type=int, default=2000, help="blocks per point")
    ap.add_argument("--out", default="linklevel-crosscheck.png")
    args = ap.parse_args()

    sinrs = np.arange(args.sinr[0], args.sinr[1] + 1e-9, args.sinr[2])
    plt.figure(figsize=(7, 5))
    colors = plt.cm.viridis(np.linspace(0, 0.85, len(args.mcs)))

    for ci, mcs in enumerate(args.mcs):
        if mcs not in MCS_TABLE:
            print(f"skip MCS {mcs} (not in table)"); continue
        qm, rate = MCS_TABLE[mcs]
        cont, puls = [], []
        for s in sinrs:
            cont.append(run_point(qm, rate, s, None, args.ninfo, args.batch, 0))
            puls.append(run_point(qm, rate, s, args.pulse_frac, args.ninfo,
                                  args.batch, int(s * 1000)))
        print(f"MCS {mcs} (Qm={qm}, R={rate}) done")
        plt.semilogy(sinrs, np.maximum(cont, 1e-4), "-", color=colors[ci],
                     label=f"MCS {mcs} continuous")
        plt.semilogy(sinrs, np.maximum(puls, 1e-4), "--", color=colors[ci],
                     label=f"MCS {mcs} pulse f={args.pulse_frac}")

    plt.axhline(0.1, color="k", lw=0.8, ls=":")
    plt.text(sinrs[0], 0.11, "10% BLER (OLLA target)", fontsize=8)
    plt.xlabel("SINR (dB)")
    plt.ylabel("Block error rate (BLER)")
    plt.title("Link-level cross-check: per-TB BLER under continuous vs pulsed interference")
    plt.grid(True, which="both", alpha=0.3)
    plt.legend(fontsize=7, ncol=2)
    plt.tight_layout()
    plt.savefig(args.out, dpi=150)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()

# Paper: RF-emergent MCS-downgrade reactive jamming (5G-LENA)

`MCS-Downgrade-5GLENA-Paper.tex` is the standalone IEEE conference write-up of the
RF-emergent attack reproduced in this repository. Build it with:

    pdflatex MCS-Downgrade-5GLENA-Paper.tex
    pdflatex MCS-Downgrade-5GLENA-Paper.tex   # second pass for cross-references

The two block diagrams (link-adaptation loop, scenario topology) are native TikZ.
The four result figures live in `paper-figs/` and are produced by the analysis
scripts in `../scripts/` (commanded-MCS, CI trade-off, delay resonance, channel
regime). Author/affiliation/acknowledgments are placeholders.

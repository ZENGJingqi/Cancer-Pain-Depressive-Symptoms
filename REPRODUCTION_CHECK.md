# Aggregate reproduction check 2026-10-01

The portable current/code/reproduce_current.R was executed from repository root against frozen aggregate CSVs only. Eight REML/Hartung-Knapp syntheses passed independent checks of the inverse-variance mean and HK variance. All five rendered PNGs were pixel-identical to the locally reviewed current figures. No participant data, model objects or imputations were read.

Current manuscript has 23 pages, nine table panels, five figures and 26 retained references; the Chinese report has two pages and no tables. Word exports were reviewed page by page and title/table layout corrections verified. This validates assembly and rendering, not all underlying participant-level assumptions.

Public whitelist was checked for forbidden source-data formats, participant identifier columns, embedded/comment Word payloads, credentials and personal paths. Already-public historical code keeps benign runtime/output placeholder roots. Detailed hashes are in MANIFEST_SHA256.csv. Design and diagnostic limits remain in STATUS.md and manuscript.
# Current publication figure check 2026-10-05

The current portable entry `current/code/reproduce_publication_figures.R` was tested
from repository root with isolated generated outputs. All eight quantitative PNGs
were pixel-identical to the reviewed manuscript assets. All nine display-row CSVs
(including the two Figure3 files) matched frozen rows within numerical parsing tolerance.
No participant models, weights or imputations were rerun. The manuscript Word/PDF
are byte-identical to the reviewed 26-page human source and contain all 80 table numeric cells.
The publisher-material package and public whitelist were checked; see
`current/submission/PACKAGE_AUDIT.json`. Figure1 uses the separately supplied native
editable PowerPoint; its existing PDF is a raster reading wrapper. Scientific and
author-level unresolved items are listed in `current/submission/BEFORE_SUBMISSION.md`.

The records below refer to the earlier aggregate synthesis and five-figure style,
which is retained for traceability, not the current manuscript figure numbering.

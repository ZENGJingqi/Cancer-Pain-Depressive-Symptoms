# Aggregate reproduction check 2026-10-01

The portable current/code/reproduce_current.R was executed from repository root against frozen aggregate CSVs only. Eight REML/Hartung-Knapp syntheses passed independent checks of the inverse-variance mean and HK variance. All five rendered PNGs were pixel-identical to the locally reviewed current figures. No participant data, model objects or imputations were read.

Current manuscript has 23 pages, nine table panels, five figures and 26 retained references; the Chinese report has two pages and no tables. Word exports were reviewed page by page and title/table layout corrections verified. This validates assembly and rendering, not all underlying participant-level assumptions.

Public whitelist was checked for forbidden source-data formats, participant identifier columns, embedded/comment Word payloads, credentials and personal paths. Already-public historical code keeps benign runtime/output placeholder roots. Detailed hashes are in MANIFEST_SHA256.csv. Design and diagnostic limits remain in STATUS.md and manuscript.

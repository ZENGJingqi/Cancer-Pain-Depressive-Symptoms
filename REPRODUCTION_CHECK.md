# Aggregate reproduction check

Tested on 6 September 2026 with R 4.5.1 on Windows, data.table 1.18.0, ggplot2 4.0.2, scales 1.4.0, pdftools 3.7.0 and patchwork 1.3.2. Arial and Cairo PDF support were available.

Both documented plotting commands completed. All five regenerated PNG previews were pixel-identical to the archived reviewed figures after preserving the explicit flow-step ordering. The commands used only the public aggregate inputs. No participant-level model was refitted.

Non-fatal warnings concerned packages built under R 4.5.2, locale startup settings, ggplot2's deprecated `geom_errorbarh` spelling, and an extra PDF conversion filename-format argument. All five PDFs and previews were produced; these warnings did not alter the verified images. This check is not a cross-platform guarantee or validation of the underlying statistical models. Fonts or package versions can affect rendering elsewhere.

The manuscript retains all 13 table panels and five images unchanged. Repository availability wording and the supporting-materials index were updated; a redundant page break was removed. Outstanding scientific checks are listed in STATUS.md.

The public staging set was checked for unexpected file types, common secret/local-path patterns, individual-identifier columns, and embedded Word comments or objects. File selection used an explicit allowlist; source data directories were not traversed for publication. This is a targeted release check, not a general disclosure-risk guarantee for arbitrary future uploads.

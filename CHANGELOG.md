# Changelog

All notable changes to VIRTUS2-nf are documented here.

## [2.0.0] — 2026-05-06

Initial Nextflow DSL2 port of [VIRTUS2](https://github.com/yyoshiaki/VIRTUS2)
(CWL 1.1).

### Pipeline

- Full reimplementation of `VIRTUS.PE.cwl` and `VIRTUS.SE.cwl` in Nextflow DSL2
  using nf-core module conventions
- Mixed PE/SE samples supported within a single run via samplesheet CSV
- Native Nextflow parallelism — all samples processed concurrently
- Integrated aggregate step (`VIRTUS_AGGREGATE`) replacing the separate
  `virtus-recount.cwl` workflow
- HTML execution timeline, report, and trace written to `pipeline_info/`

### New parameters

- `--tool_versions legacy|latest` — select between original CWL tool versions
  (fastp 0.20.0 + STAR 2.7.1a) and current best-practice versions
  (fastp 1.0.1 + STAR 2.7.11b). Default: `latest`.
- `--bam_to_fastq_tool samtools|bedtools` — select BAM→FASTQ converter.
  Default: `samtools` (modern). Use `bedtools` for exact CWL replication.
- `--genomeDir_human` / `--genomeDir_virus` — pass pre-built STAR indexes to
  skip genome generation
- `--fasta_human` / `--fasta_virus` — pass local reference FASTAs
- `--kz_threshold`, `--th_cov`, `--th_rate`, `--figsize` — expose analysis
  thresholds as parameters

### Changes vs original CWL VIRTUS2

| Change | Reason |
|---|---|
| Default fastp upgraded to 1.0.1 | Current best practice; `--tool_versions legacy` restores 0.20.0 |
| Default STAR upgraded to 2.7.11b | Current best practice; `--tool_versions legacy` restores 2.7.1a |
| PE: `--detect_adapter_for_pe` added for `latest` profile | fastp 1.0.1 requires explicit flag; legacy profile omits it to match CWL |
| BAM→FASTQ default changed to `samtools fastq` | Avoids coordinate-sort duplication artefacts present in `bedtools bamtofastq`; `--bam_to_fastq_tool bedtools` restores original behaviour |
| `SAMTOOLS_INDEX` step added | Produces `.bai` index alongside filtered viral BAM for downstream visualisation |
| `SAMTOOLS_FASTQ` intermediate not published | Intermediate FASTQ files suppressed from output (only the final TSV and BAMs are written) |

### Validation

Running `--tool_versions legacy --bam_to_fastq_tool bedtools` on the VIRTUS2
test datasets (ERR3240275 PE, SRR8315715 SE) produces output TSVs that are
**byte-for-byte identical** to the original CWL pipeline.

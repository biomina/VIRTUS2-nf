# VIRTUS2-nf

**VIRal Transcript Usage Sensor v2 — Nextflow/DSL2 port**

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**VIRTUS2-nf** is a Nextflow (DSL2) reimplementation of
[VIRTUS2](https://github.com/yyoshiaki/VIRTUS2) — a pipeline for detecting and
quantifying viral transcripts in bulk RNA-seq data.

The pipeline identifies human-virus co-infection signals by:

1. Trimming and quality-filtering reads with **fastp**
2. Aligning to the human reference genome with **STAR** to remove host reads
3. Extracting unmapped reads and filtering low-complexity sequences with the
   **Kashtan–Zvesper (KZ)** complexity filter
4. Re-aligning the remaining reads against a curated viral reference with **STAR**
5. Filtering poly-X artefacts from viral alignments
6. Computing per-virus coverage statistics and producing a summary TSV

Mixed paired-end (PE) and single-end (SE) samples are supported within the same
run.

### Differences from the original CWL pipeline

| Aspect | Original CWL (VIRTUS2) | VIRTUS2-nf |
|---|---|---|
| Workflow language | CWL 1.1 | Nextflow DSL2 |
| Default fastp version | 0.20.0 | 1.0.1 (selectable via `--tool_versions`) |
| Default STAR version | 2.7.1a | 2.7.11b (selectable via `--tool_versions`) |
| PE fastp args | `--trim_poly_x --length_required 40` | adds `--detect_adapter_for_pe` for `latest` |
| BAM → FASTQ (PE) | bedtools bamtofastq 2.29.2 | samtools fastq (default); bedtools available via `--bam_to_fastq_tool bedtools` |
| STAR `.bai` index | not produced | added (`SAMTOOLS_INDEX` step) |
| Multi-sample runs | separate CWL invocations | native parallelism via Nextflow channels |
| Aggregate summary | separate `virtus-recount.cwl` | integrated `VIRTUS_AGGREGATE` step |
| Execution tracing | none | HTML timeline, report, and trace file in `pipeline_info/` |
| Reproducibility mode | n/a | `--tool_versions legacy` reproduces original results exactly |

> **Validation**: running `--tool_versions legacy` (fastp 0.20.0 + STAR 2.7.1a) on
> the same inputs produces **byte-for-byte identical** output TSVs compared to the
> original CWL pipeline on both PE and SE test datasets.

## Quick start

```bash
# 1. Install Nextflow (≥23.04.0)
curl -s https://get.nextflow.io | bash

# 2. Run with Docker (recommended)
nextflow run /path/to/VIRTUS2-nf/main.nf \
  -profile docker \
  --input samplesheet.csv \
  --outdir results
```

See [docs/usage.md](docs/usage.md) for full parameter documentation.

## Pipeline overview

```
Input FASTQs
    │
    ▼
[FASTP]  — quality trimming & adapter removal
    │
    ▼
[STAR — human]  — align to human reference; keep unmapped reads
    │
    ▼
[SAMTOOLS_VIEW]  — extract unmapped reads, remove multi-mappers (uT:A:3)
    │
    ▼
[SAMTOOLS_FASTQ / BEDTOOLS_BAMTOFASTQ]  — BAM → FASTQ
    │
    ▼
[KZ_FILTER]  — remove low-complexity reads (threshold 0.1)
    │
    ▼  (PE only: FASTQ_PAIR — re-sync read pairs after independent filtering)
    │
    ▼
[STAR — virus]  — align to viral reference genome collection
    │
    ▼
[BAM_FILTER_POLYX]  — remove poly-X reads from viral BAM
    │
    ▼
[SAMTOOLS_INDEX + SAMTOOLS_COVERAGE]  — index BAM, compute coverage
    │
    ▼
[MK_SUMMARY_VIRUS_COUNT]  — produce per-sample VIRTUS.output.tsv
    │
    ▼
[VIRTUS_AGGREGATE]  — combine all samples into aggregate summary + plot
```

## Credits

- Original VIRTUS2 pipeline: [Yoshiaki Yasumizu](https://github.com/yyoshiaki)
- Nextflow port: VIRTUS2-nf contributors
- nf-core module templates: [nf-core community](https://nf-co.re)

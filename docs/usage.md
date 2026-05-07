# VIRTUS2-nf — Usage

## Samplesheet format

Create a CSV with the following columns:

| Column | Required | Description |
|---|---|---|
| `sample` | ✓ | Unique sample identifier (used as prefix in output filenames) |
| `fastq1` | ✓ | Path to R1 (or the only read file for SE) |
| `fastq2` | | Path to R2; leave empty for single-end samples |
| `group` | | Optional grouping label used by the aggregate step |

**Mixed PE/SE example:**

```csv
sample,fastq1,fastq2,group
EBV_infected,/data/EBV_R1.fastq.gz,/data/EBV_R2.fastq.gz,treated
mock,/data/mock.fastq.gz,,control
```

- PE samples: provide both `fastq1` and `fastq2`
- SE samples: provide only `fastq1` (leave `fastq2` blank)

## Running the pipeline

### Minimal run (auto-download reference)

```bash
nextflow run main.nf \
  -profile docker \
  --input samplesheet.csv \
  --outdir results
```

The pipeline will download the human genome (GENCODE GRCh38 release 38) and
the VIRTUS2 virus FASTA, build STAR indexes, then run all samples.

### With pre-built STAR indexes (recommended for repeated runs)

```bash
nextflow run main.nf \
  -profile docker \
  --input samplesheet.csv \
  --outdir results \
  --genomeDir_human /path/to/star_index/human \
  --genomeDir_virus /path/to/star_index/virus
```

Indexes from a previous run are stored in `results/star_index/human/star` and
`results/star_index/virus/star`. Pass those paths with `--genomeDir_human` and
`--genomeDir_virus` to skip the genome generation step entirely.

### With local reference FASTAs (no download)

```bash
nextflow run main.nf \
  -profile docker \
  --input samplesheet.csv \
  --outdir results \
  --fasta_human /path/to/GRCh38.fa \
  --fasta_virus /path/to/viruses.fasta
```

### Reproducibility mode — exact match to original CWL VIRTUS2

```bash
nextflow run main.nf \
  -profile docker \
  --input samplesheet.csv \
  --outdir results \
  --tool_versions legacy \
  --bam_to_fastq_tool bedtools
```

This uses fastp 0.20.0 + STAR 2.7.1a (identical to the original CWL pipeline)
and bedtools bamtofastq for BAM→FASTQ conversion, reproducing results
byte-for-byte.

## Parameters

### Input / output

| Parameter | Default | Description |
|---|---|---|
| `--input` | `null` | **Required.** Path to samplesheet CSV |
| `--outdir` | `results` | **Required.** Output directory |

### Reference genomes

| Parameter | Default | Description |
|---|---|---|
| `--genomeDir_human` | `null` | Path to pre-built human STAR index directory. If not set, the index is built from `--fasta_human` or downloaded. |
| `--genomeDir_virus` | `null` | Path to pre-built virus STAR index directory. If not set, the index is built from `--fasta_virus` or downloaded. |
| `--fasta_human` | `null` | Local human genome FASTA (uncompressed). Used to build the STAR index when `--genomeDir_human` is absent. |
| `--fasta_virus` | `null` | Local virus FASTA. Used to build the STAR index when `--genomeDir_virus` is absent. |
| `--url_fasta_human` | GENCODE GRCh38 r38 | Remote URL for the human genome FASTA (`.fa.gz`). Used only when neither `--genomeDir_human` nor `--fasta_human` is provided. |
| `--url_fasta_virus` | VIRTUS2 GitHub | Remote URL for the virus FASTA. Used only when neither `--genomeDir_virus` nor `--fasta_virus` is provided. |

### Tool version profile

| Parameter | Default | Options | Description |
|---|---|---|---|
| `--tool_versions` | `latest` | `latest`, `legacy` | `latest`: fastp 1.0.1 + STAR 2.7.11b. `legacy`: fastp 0.20.0 + STAR 2.7.1a, matching the original CWL VIRTUS2 pipeline. |

**Effect of `--tool_versions legacy` on fastp arguments (PE only):**
The original CWL fastp 0.20.0 invocation does **not** include `--detect_adapter_for_pe`.
The `latest` profile adds this flag, which trims ~0.35% more reads and produces
slightly higher coverage estimates. SE results are identical between both profiles.

### BAM → FASTQ conversion

| Parameter | Default | Options | Description |
|---|---|---|---|
| `--bam_to_fastq_tool` | `samtools` | `samtools`, `bedtools` | `samtools`: uses `samtools fastq` (modern, avoids coordinate-sort duplication artefacts). `bedtools`: uses `bedtools bamtofastq 2.29.2`, matching the original CWL pipeline. |

### Analysis parameters

| Parameter | Default | Description |
|---|---|---|
| `--kz_threshold` | `0.1` | KZ complexity filter threshold. Reads with complexity < threshold are discarded. |
| `--outFileNamePrefix_human` | `human` | Prefix for human STAR alignment output files. |
| `--filename_output` | `VIRTUS.output.tsv` | Filename for the per-sample summary TSV. |

### Aggregation parameters

| Parameter | Default | Description |
|---|---|---|
| `--th_cov` | `10.0` | Minimum mean depth of coverage threshold for aggregate output. |
| `--th_rate` | `0.0001` | Minimum virus/human read ratio threshold for aggregate output. |
| `--figsize` | `8,3` | Width,height of the aggregate summary plot in inches. |

## Execution profiles

| Profile | Description |
|---|---|
| `docker` | Run all processes inside Docker containers (recommended) |
| `singularity` | Run all processes inside Singularity containers |
| `conda` | Run using conda environments (not all processes supported) |
| `test` | Use test data with minimal resources |

## Resuming a run

Nextflow caches completed process executions in the `work/` directory.
Add `-resume` to restart from the last successful checkpoint:

```bash
nextflow run main.nf -profile docker -resume --input samplesheet.csv --outdir results
```

## Resource requirements

- **RAM**: ≥50 GB recommended (STAR human genome index requires ~32 GB)
- **CPU**: 8–12 cores recommended for STAR alignment steps
- **Disk**: ~30 GB for STAR indexes; additional space per sample for intermediate BAMs

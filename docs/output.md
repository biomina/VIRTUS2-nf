# VIRTUS2-nf — Output

## Results directory structure

```
results/
├── <sample_id>/
│   ├── fastp/
│   │   ├── <sample_id>.fastp.html
│   │   ├── <sample_id>.fastp.json
│   │   └── <sample_id>.fastp.log
│   ├── samtools/
│   │   └── <sample_id>.unmapped.bam
│   ├── star_human/
│   │   ├── <prefix>Aligned.sortedByCoord.out.bam
│   │   ├── <prefix>Log.final.out
│   │   ├── <prefix>Log.out
│   │   └── <prefix>SJ.out.tab
│   ├── star_virus/
│   │   ├── virusAligned.sortedByCoord.out.bam
│   │   ├── virusLog.final.out
│   │   ├── virusLog.out
│   │   └── virusSJ.out.tab
│   ├── bam_filter_polyx/
│   │   ├── virusAligned.filtered.sortedByCoord.out.bam
│   │   └── virusAligned.filtered.sortedByCoord.out.bam.bai
│   ├── virus.coverage.txt
│   └── VIRTUS.output.tsv          ← main per-sample result
├── aggregate/
│   ├── VIRTUS.aggregate.tsv       ← combined result across all samples
│   └── VIRTUS.aggregate.pdf       ← heatmap plot
├── star_index/
│   ├── human/star/                ← reusable human STAR index
│   └── virus/star/                ← reusable virus STAR index
└── pipeline_info/
    ├── execution_timeline_*.html
    ├── execution_report_*.html
    └── execution_trace_*.txt
```

`<prefix>` defaults to `human` (controlled by `--outFileNamePrefix_human`).

## Per-sample outputs

### `<sample_id>/VIRTUS.output.tsv` — main result

The primary output. Tab-separated, one row per virus detected.

| Column | Description |
|---|---|
| `#rname` | Virus name (matches sequence header in the virus FASTA) |
| `startpos` | Start position of covered region |
| `endpos` | End position of covered region |
| `meandepth` | Mean read depth across covered bases |
| `numreads` | Number of reads aligned to this virus |
| `covbases` | Number of bases with at least 1 read |
| `coverage` | Fraction of the genome covered (0–100) |
| `meanbaseq` | Mean base quality of aligned reads |
| `meanmapq` | Mean mapping quality of aligned reads |
| `rate` | Virus reads as a fraction of total human-aligned reads (virus / human mapped) |

Rows are sorted by `rate` descending in the aggregate output.

### `<sample_id>/fastp/`

Quality control reports from fastp.

- `*.html` — interactive HTML report (adapter content, quality distribution, duplication)
- `*.json` — machine-readable QC statistics
- `*.log` — fastp stderr log

### `<sample_id>/samtools/`

- `<sample_id>.unmapped.bam` — reads that did not map to the human genome, with
  multi-mappers (`uT:A:3` tag) removed. This BAM is the input to the viral alignment
  step after KZ filtering.

### `<sample_id>/star_human/`

Full STAR output from the human alignment step.

- `*Aligned.sortedByCoord.out.bam` — coordinate-sorted BAM (human + unmapped reads)
- `*Log.final.out` — mapping statistics summary (used by `MK_SUMMARY_VIRUS_COUNT`)
- `*Log.out` — full STAR run log
- `*SJ.out.tab` — splice junction table

### `<sample_id>/star_virus/`

STAR output from the viral alignment step (pre-poly-X filtering).

### `<sample_id>/bam_filter_polyx/`

- `virusAligned.filtered.sortedByCoord.out.bam` — viral BAM after poly-X read removal
- `virusAligned.filtered.sortedByCoord.out.bam.bai` — BAI index (added in Nextflow port;
  not present in original CWL output)

### `<sample_id>/virus.coverage.txt`

Raw output of `samtools coverage` on the filtered viral BAM, used to compute the
summary TSV.

## Aggregate outputs

### `aggregate/VIRTUS.aggregate.tsv`

Combined summary across all samples, filtered by `--th_cov` (minimum mean depth)
and `--th_rate` (minimum virus/human read ratio). One row per sample–virus pair
that passes both thresholds.

### `aggregate/VIRTUS.aggregate.pdf`

Heatmap of viral detection across samples. Figure dimensions are controlled by
`--figsize` (width,height in inches, default `8,3`).

## Reusable indexes

### `star_index/human/star/` and `star_index/virus/star/`

STAR genome indexes built during the run. Pass these to subsequent runs with
`--genomeDir_human` and `--genomeDir_virus` to skip the index-building step:

```bash
nextflow run main.nf \
  --genomeDir_human results/star_index/human/star \
  --genomeDir_virus results/star_index/virus/star \
  ...
```

> **Note**: indexes built with `--tool_versions legacy` (STAR 2.7.1a) are **not
> compatible** with `--tool_versions latest` (STAR 2.7.11b) and vice versa. Use
> matching indexes for the same tool version profile.

## Pipeline info

Nextflow execution reports written to `pipeline_info/` on every run:

- `execution_timeline_*.html` — per-process walltime and CPU usage
- `execution_report_*.html` — summary of resource usage and process status
- `execution_trace_*.txt` — machine-readable trace (used for benchmarking)

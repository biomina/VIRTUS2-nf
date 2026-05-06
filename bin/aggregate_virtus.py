#!/usr/bin/env python3
"""
aggregate_virtus.py  —  VIRTUS2-nf aggregation step

Reads per-sample VIRTUS output TSV files from a directory, builds
rate_hit and coverage matrices, optionally runs Mann-Whitney U + BH-FDR
(when two groups are present in the metadata), and writes summary.csv
and scattermap.pdf.

Usage:
    aggregate_virtus.py \
        --tsv_dir <dir containing *.tsv files> \
        --metadata <samplesheet.csv> \
        --th_cov 10 \
        --th_rate 0.0001 \
        --figsize 8,3
"""

import argparse
import sys
import pathlib

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib as mpl
import pandas as pd
from scipy import stats
from statsmodels.stats.multitest import multipletests
import seaborn as sns

mpl.rcParams['pdf.fonttype'] = 42
mpl.rcParams['ps.fonttype'] = 42

# ── Import scattermap helper (lives alongside this script in bin/) ─────────
try:
    from scattermap import scattermap
    _HAS_SCATTERMAP = True
except ImportError:
    _HAS_SCATTERMAP = False

# ── Arguments ─────────────────────────────────────────────────────────────
parser = argparse.ArgumentParser(description='Aggregate VIRTUS2-nf per-sample results')
parser.add_argument('--tsv_dir',  required=True,
                    help='Directory that contains per-sample *.tsv result files')
parser.add_argument('--metadata', required=True,
                    help='Samplesheet CSV with columns: sample, fastq1, fastq2[, group]')
parser.add_argument('--th_cov',   default=10.0,  type=float,
                    help='Minimum max-coverage (%) across samples to retain a virus (default: 10)')
parser.add_argument('--th_rate',  default=1e-4,  type=float,
                    help='Minimum max rate_hit across samples to retain a virus (default: 0.0001)')
parser.add_argument('--figsize',  default='8,3',
                    help='Figure size as w,h (default: 8,3)')
args = parser.parse_args()

# ── Load metadata ─────────────────────────────────────────────────────────
meta_df = pd.read_csv(args.metadata)
# Normalise column names (allow sample / Sample / NAME etc.)
meta_df.columns = [c.strip().lower() for c in meta_df.columns]
if 'sample' not in meta_df.columns:
    sys.exit("ERROR: samplesheet must have a 'sample' column")
has_group = 'group' in meta_df.columns
sample_to_group = (dict(zip(meta_df['sample'], meta_df['group']))
                   if has_group else {})

# ── Collect per-sample TSV files ──────────────────────────────────────────
tsv_dir = pathlib.Path(args.tsv_dir)
tsv_files = sorted(tsv_dir.glob('*.tsv'))
if not tsv_files:
    sys.exit(f"ERROR: no .tsv files found in {tsv_dir}")

list_dfs = []
for tsv in tsv_files:
    # Derive sample name: strip everything after the first dot
    sample_name = tsv.name.split('.')[0]
    try:
        df = pd.read_csv(tsv, sep='\t')
    except Exception as e:
        print(f"WARNING: could not read {tsv}: {e}", file=sys.stderr)
        continue
    df['sample'] = sample_name
    list_dfs.append(df)

if not list_dfs:
    sys.exit("ERROR: could not read any TSV files")

df_all = pd.concat(list_dfs, ignore_index=True)

# Required columns
for col in ('virus', 'rate_hit', 'coverage'):
    if col not in df_all.columns:
        sys.exit(f"ERROR: expected column '{col}' not found in TSV files")

# ── Build matrices  (virus × sample) ─────────────────────────────────────
df_rate = pd.pivot_table(df_all, index='virus', columns='sample',
                         values='rate_hit', aggfunc='first').fillna(0)
df_cov  = pd.pivot_table(df_all, index='virus', columns='sample',
                         values='coverage', aggfunc='first').fillna(0)

# ── Filter by thresholds ──────────────────────────────────────────────────
keep_rate = df_rate.max(axis=1) >= args.th_rate
keep_cov  = df_cov.max(axis=1)  >= args.th_cov
keep      = keep_rate & keep_cov

df_rate = df_rate.loc[keep]
df_cov  = df_cov.loc[keep]

# Align columns between the two matrices
shared_cols = [c for c in df_rate.columns if c in df_cov.columns]
df_rate = df_rate[shared_cols]
df_cov  = df_cov[shared_cols]

# ── Build summary DataFrame ───────────────────────────────────────────────
summary = pd.merge(
    df_cov.add_suffix('_cov'),
    df_rate.add_suffix('_rate'),
    left_index=True, right_index=True
)

print('### VIRTUS2-nf Aggregation Summary ###')
print(f'Threshold coverage  : {args.th_cov}%')
print(f'Threshold rate      : {args.th_rate}')
print(f'Total virus entries : {df_all.shape[0]}')
print(f'Retained viruses    : {summary.shape[0]}')

# ── Statistical test (Mann-Whitney U + BH-FDR) ────────────────────────────
if has_group and meta_df['group'].nunique() == 2:
    groups = meta_df['group'].unique()
    g0_samples = meta_df.loc[meta_df['group'] == groups[0], 'sample'].tolist()
    g1_samples = meta_df.loc[meta_df['group'] == groups[1], 'sample'].tolist()

    if summary.shape[0] > 0:
        print(f'Running Mann-Whitney U-test: {groups[0]} vs {groups[1]}')
        u_vals, p_vals = {}, {}
        for virus in summary.index:
            r0 = summary.loc[virus, [f'{s}_rate' for s in g0_samples if f'{s}_rate' in summary.columns]]
            r1 = summary.loc[virus, [f'{s}_rate' for s in g1_samples if f'{s}_rate' in summary.columns]]
            u, p = stats.mannwhitneyu(r0, r1, alternative='two-sided')
            u_vals[virus] = u
            p_vals[virus]  = p

        p_series = pd.Series(p_vals)
        fdr = pd.Series(
            multipletests(p_series, method='fdr_bh')[1],
            index=p_series.index
        )
        summary['u-value'] = pd.Series(u_vals)
        summary['p-value'] = p_series
        summary['FDR']     = fdr
    else:
        print('Skipped Mann-Whitney U-test (no viruses passed filters)')
else:
    if has_group:
        print(f'Skipping stats: {meta_df["group"].nunique()} groups found (need exactly 2)')

# ── Save summary ──────────────────────────────────────────────────────────
summary.to_csv('summary.csv')
print('Written: summary.csv')

# ── Scatter-map visualisation ─────────────────────────────────────────────
if summary.shape[0] > 0:
    try:
        figsize = tuple(int(x) for x in args.figsize.split(','))
        with sns.axes_style('white'):
            plt.figure(figsize=figsize)
            if _HAS_SCATTERMAP:
                ax = scattermap(df_rate, square=True, marker_size=df_cov,
                                cmap='viridis_r',
                                cbar_kws={'label': 'v/h rate'})
                pws = [20, 40, 60, 80, 100]
                for pw in pws:
                    plt.scatter([], [], s=pw, c='k', label=str(pw))
                h, lbl = plt.gca().get_legend_handles_labels()
                plt.legend(h[1:], lbl[1:], labelspacing=0.3, title='coverage(%)',
                           borderpad=0, framealpha=0, edgecolor='w',
                           bbox_to_anchor=(1.1, -0.1), ncol=1, loc='upper left',
                           borderaxespad=0)
            else:
                # Fallback: plain heatmap if scattermap is unavailable
                sns.heatmap(df_rate, cmap='viridis_r',
                            cbar_kws={'label': 'v/h rate'})
            plt.savefig('scattermap.pdf', bbox_inches='tight')
        print('Written: scattermap.pdf')
    except Exception as e:
        print(f'WARNING: could not produce scattermap.pdf: {e}', file=sys.stderr)
else:
    print('Skipped scattermap (no viruses passed filters)')

print('All aggregation processes succeeded.')

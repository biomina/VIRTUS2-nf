#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VIRTUS2-nf  —  Viral Transcript Usage from RNA-Seq v2 (Nextflow port)
    Original pipeline: https://github.com/yyoshiaki/VIRTUS2
    Nextflow DSL2, nf-core conventions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
nextflow.enable.dsl = 2

include { STAR_GENOMEGENERATE as STAR_GENOMEGENERATE_HUMAN } from './modules/nf-core/star/genomegenerate/main'
include { STAR_GENOMEGENERATE as STAR_GENOMEGENERATE_VIRUS } from './modules/nf-core/star/genomegenerate/main'
include { WGET as WGET_HUMAN  } from './modules/nf-core/wget/main'
include { WGET as WGET_VIRUS  } from './modules/nf-core/wget/main'
include { GUNZIP as GUNZIP_HUMAN } from './modules/local/gunzip/main'
include { VIRTUS_PE           } from './subworkflows/local/virtus_pe/main'
include { VIRTUS_SE           } from './subworkflows/local/virtus_se/main'
include { VIRTUS_AGGREGATE    } from './modules/local/virtus_aggregate/main'

// ── Print parameter summary ─────────────────────────────────────────────────
def paramsSummary() {
    log.info """\
        V I R T U S 2 - N F   P I P E L I N E
        ========================================
        input           : ${params.input}
        outdir          : ${params.outdir}
        genomeDir_human : ${params.genomeDir_human ?: '(not set — will build)'}
        genomeDir_virus : ${params.genomeDir_virus ?: '(not set — will build)'}
        kz_threshold    : ${params.kz_threshold}
        th_cov          : ${params.th_cov}
        th_rate         : ${params.th_rate}
        figsize         : ${params.figsize}
        ========================================
        """.stripIndent()
}

// ── Validate required parameters ────────────────────────────────────────────
def validateParams() {
    if (!params.input) {
        error "Parameter --input is required (path to samplesheet CSV)"
    }
}

// ── Workflow ─────────────────────────────────────────────────────────────────
workflow {

    paramsSummary()
    validateParams()

    // ── Parse samplesheet ──────────────────────────────────────────────────
    ch_samplesheet = Channel
        .fromPath(params.input, checkIfExists: true)

    ch_reads = ch_samplesheet
        .splitCsv(header: true, strip: true)
        .map { row ->
            def meta = [
                id        : row.sample,
                single_end: !(row.fastq2 && row.fastq2.trim() != '')
            ]
            if (meta.single_end) {
                [ meta, [ file(row.fastq1, checkIfExists: true) ] ]
            } else {
                [ meta, [
                    file(row.fastq1, checkIfExists: true),
                    file(row.fastq2, checkIfExists: true)
                ] ]
            }
        }

    // ── Resolve human genome index ─────────────────────────────────────────
    // All index channels must be VALUE channels so they broadcast to every sample.
    if (params.genomeDir_human) {
        ch_human_index = Channel.value(file(params.genomeDir_human, checkIfExists: true))
    } else if (params.fasta_human) {
        STAR_GENOMEGENERATE_HUMAN (
            Channel.value([ [id: 'human'], file(params.fasta_human, checkIfExists: true) ]),
            Channel.value([[id:'no_gtf'], []])
        )
        ch_human_index = STAR_GENOMEGENERATE_HUMAN.out.index.map { meta, idx -> idx }.first()
    } else {
        // Download human genome FASTA, decompress (STAR can't read .fa.gz), then build index
        WGET_HUMAN ( Channel.value([[id: 'human_genome'], params.url_fasta_human, 'fa.gz']) )
        GUNZIP_HUMAN ( WGET_HUMAN.out.outfile.map { meta, f -> f } )
        STAR_GENOMEGENERATE_HUMAN (
            GUNZIP_HUMAN.out.gunzip.map { f -> [ [id: 'human'], f ] },
            Channel.value([[id:'no_gtf'], []])
        )
        ch_human_index = STAR_GENOMEGENERATE_HUMAN.out.index.map { meta, idx -> idx }.first()
    }

    // ── Resolve virus genome index ─────────────────────────────────────────
    if (params.genomeDir_virus) {
        ch_virus_index = Channel.value(file(params.genomeDir_virus, checkIfExists: true))
    } else if (params.fasta_virus) {
        STAR_GENOMEGENERATE_VIRUS (
            Channel.value([ [id: 'virus'], file(params.fasta_virus, checkIfExists: true) ]),
            Channel.value([[id:'no_gtf'], []])
        )
        ch_virus_index = STAR_GENOMEGENERATE_VIRUS.out.index.map { meta, idx -> idx }.first()
    } else {
        // Download virus FASTA and build index
        WGET_VIRUS ( Channel.value([[id: 'viruses'], params.url_fasta_virus, 'fasta']) )
        STAR_GENOMEGENERATE_VIRUS (
            WGET_VIRUS.out.outfile.map { meta, f -> [ [id: 'virus'], f ] },
            Channel.value([[id:'no_gtf'], []])
        )
        ch_virus_index = STAR_GENOMEGENERATE_VIRUS.out.index.map { meta, idx -> idx }.first()
    }

    // ── Branch PE vs SE ────────────────────────────────────────────────────
    ch_reads
        .branch {
            meta, reads ->
            pe: !meta.single_end
            se:  meta.single_end
        }
        .set { ch_branched }

    // ── Run per-sample analysis ────────────────────────────────────────────
    VIRTUS_PE ( ch_branched.pe, ch_human_index, ch_virus_index )
    VIRTUS_SE ( ch_branched.se, ch_human_index, ch_virus_index )

    // ── Collect all per-sample TSVs and aggregate ──────────────────────────
    ch_all_tsvs = Channel.empty()
        .mix(
            VIRTUS_PE.out.summary.map { meta, tsv -> tsv },
            VIRTUS_SE.out.summary.map { meta, tsv -> tsv }
        )
        .collect()

    VIRTUS_AGGREGATE (
        ch_all_tsvs,
        ch_samplesheet.first()
    )
}

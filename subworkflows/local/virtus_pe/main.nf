//
// VIRTUS PE subworkflow
// Matches workflow/VIRTUS.PE.cwl (12 steps, including the added SAMTOOLS_INDEX)
//

include { FASTP                  } from '../../../modules/nf-core/fastp/main'
include { FASTP_LEGACY           } from '../../../modules/local/fastp_legacy/main'
include { STAR_ALIGN as STAR_ALIGN_HUMAN } from '../../../modules/nf-core/star/align/main'
include { STAR_ALIGN as STAR_ALIGN_VIRUS } from '../../../modules/nf-core/star/align/main'
include { SAMTOOLS_VIEW          } from '../../../modules/local/samtools/view/main'
include { BEDTOOLS_BAMTOFASTQ    } from '../../../modules/local/bedtools/bamtofastq/main'
include { SAMTOOLS_FASTQ         } from '../../../modules/nf-core/samtools/fastq/main'
include { KZ_FILTER as KZ_FILTER_R1 } from '../../../modules/local/kz_filter/main'
include { KZ_FILTER as KZ_FILTER_R2 } from '../../../modules/local/kz_filter/main'
include { FASTQ_PAIR             } from '../../../modules/local/fastq_pair/main'
include { BAM_FILTER_POLYX       } from '../../../modules/local/bam_filter_polyx/main'
include { SAMTOOLS_INDEX         } from '../../../modules/nf-core/samtools/index/main'
include { SAMTOOLS_COVERAGE      } from '../../../modules/nf-core/samtools/coverage/main'
include { MK_SUMMARY_VIRUS_COUNT } from '../../../modules/local/mk_summary_virus_count/main'

workflow VIRTUS_PE {

    take:
    ch_reads        // channel: [ val(meta), [ fastq1, fastq2 ] ]
    ch_human_index  // value channel: path to human STAR index dir
    ch_virus_index  // value channel: path to virus STAR index dir

    main:
    ch_versions = Channel.empty()

    // Step 1 — QC & trimming
    // FASTP_LEGACY (legacy mode): fastp 0.20.0 without --detect_adapter_for_pe, matching CWL VIRTUS2
    // FASTP        (latest mode):  fastp latest with nf-core defaults (--detect_adapter_for_pe hardcoded)
    ch_fastp_reads = Channel.empty()
    if (params.tool_versions == 'legacy') {
        FASTP_LEGACY (
            ch_reads.map { meta, reads -> [ meta, reads, [] ] },
            false, false, false
        )
        ch_fastp_reads = FASTP_LEGACY.out.reads
        ch_versions = ch_versions.mix(
            FASTP_LEGACY.out.versions_fastp.map { process, tool, ver -> [ process, ver ] }
        )
    } else {
        FASTP (
            ch_reads.map { meta, reads -> [ meta, reads, [] ] },
            false, false, false
        )
        ch_fastp_reads = FASTP.out.reads
        ch_versions = ch_versions.mix(
            FASTP.out.versions_fastp.map { process, tool, ver -> [ process, ver ] }
        )
    }

    // Step 2 — Align to human genome (keep unmapped reads in BAM)
    STAR_ALIGN_HUMAN (
        ch_fastp_reads,
        ch_human_index.map { idx -> [ [:], idx ] },
        Channel.value([[id:'no_gtf'], []]),
        true
    )

    // Step 3 — Extract unmapped reads (remove multi-mappers via custom script)
    SAMTOOLS_VIEW ( STAR_ALIGN_HUMAN.out.bam_sorted_aligned )
    ch_versions = ch_versions.mix(
        SAMTOOLS_VIEW.out.versions_samtools.map { process, tool, ver -> [ process, ver ] }
    )

    // Step 4 — Convert unmapped BAM → paired FASTQ
    // Branch on bam_to_fastq_tool param: 'bedtools' for exact CWL replication, 'samtools' (default) for modern approach
    ch_bam2fq_reads = Channel.empty()
    if (params.bam_to_fastq_tool == 'bedtools') {
        BEDTOOLS_BAMTOFASTQ ( SAMTOOLS_VIEW.out.bam )
        ch_versions = ch_versions.mix(
            BEDTOOLS_BAMTOFASTQ.out.versions_bedtools.map { process, tool, ver -> [ process, ver ] }
        )
        ch_bam2fq_reads = BEDTOOLS_BAMTOFASTQ.out.reads
    } else {
        SAMTOOLS_FASTQ ( SAMTOOLS_VIEW.out.bam, false )
        ch_versions = ch_versions.mix(
            SAMTOOLS_FASTQ.out.versions_samtools.map { process, tool, ver -> [ process, ver ] }
        )
        // PE unmapped reads have READ1/READ2 flags → correctly routed to -1/-2 by samtools fastq
        ch_bam2fq_reads = SAMTOOLS_FASTQ.out.fastq
    }

    // Steps 5–6 — KZ complexity filter on each read independently
    ch_r1 = ch_bam2fq_reads.map { meta, reads ->
        def r1_meta = meta + [id: "${meta.id}_R1"]
        [ r1_meta, reads[0] ]
    }
    ch_r2 = ch_bam2fq_reads.map { meta, reads ->
        def r2_meta = meta + [id: "${meta.id}_R2"]
        [ r2_meta, reads[1] ]
    }
    KZ_FILTER_R1 ( ch_r1 )
    KZ_FILTER_R2 ( ch_r2 )
    ch_versions = ch_versions.mix(
        KZ_FILTER_R1.out.versions_komplexity.map { process, tool, ver -> [ process, ver ] }
    )

    // Re-combine filtered R1 + R2 keyed by original sample id
    ch_kz_paired = KZ_FILTER_R1.out.reads
        .map { meta, fq -> [ meta.id.replaceAll(/_R1$/, ''), meta, fq ] }
        .join(
            KZ_FILTER_R2.out.reads
                .map { meta, fq -> [ meta.id.replaceAll(/_R2$/, ''), meta, fq ] },
            by: 0
        )
        .map { sid, meta1, fq1, meta2, fq2 ->
            def orig_meta = meta1 + [id: sid]
            [ orig_meta, [ fq1, fq2 ] ]
        }

    // Step 7 — Re-pair reads after independent filtering
    FASTQ_PAIR ( ch_kz_paired )
    ch_versions = ch_versions.mix(
        FASTQ_PAIR.out.versions_fastq_pair.map { process, tool, ver -> [ process, ver ] }
    )

    // Step 8 — Align to viral reference
    STAR_ALIGN_VIRUS (
        FASTQ_PAIR.out.reads,
        ch_virus_index.map { idx -> [ [:], idx ] },
        Channel.value([[id:'no_gtf'], []]),
        true
    )

    // Step 9 — Remove poly-X reads from viral BAM
    BAM_FILTER_POLYX ( STAR_ALIGN_VIRUS.out.bam_sorted_aligned )
    ch_versions = ch_versions.mix(
        BAM_FILTER_POLYX.out.versions_samtools.map { process, tool, ver -> [ process, ver ] }
    )

    // Step 10 — Index filtered viral BAM
    SAMTOOLS_INDEX ( BAM_FILTER_POLYX.out.bam )

    // Step 11 — Compute per-virus coverage
    ch_bam_bai = BAM_FILTER_POLYX.out.bam
        .join( SAMTOOLS_INDEX.out.index )
    SAMTOOLS_COVERAGE (
        ch_bam_bai,
        Channel.value([[id:'no_fasta'], [], []])
    )

    // Step 12 — Generate per-sample VIRTUS summary TSV
    // Join log_final + coverage by meta so samples are never mismatched
    ch_log_cov = STAR_ALIGN_HUMAN.out.log_final
        .join( SAMTOOLS_COVERAGE.out.coverage )
    MK_SUMMARY_VIRUS_COUNT (
        ch_log_cov.map { meta, log, cov -> [ meta, log ] },
        ch_log_cov.map { meta, log, cov -> [ meta, cov ] },
        'PE'
    )
    ch_versions = ch_versions.mix(
        MK_SUMMARY_VIRUS_COUNT.out.versions_python.map { process, tool, ver -> [ process, ver ] }
    )

    emit:
    summary      = MK_SUMMARY_VIRUS_COUNT.out.output  // [ meta, *.tsv ]
    bam_human    = STAR_ALIGN_HUMAN.out.bam_sorted
    log_final    = STAR_ALIGN_HUMAN.out.log_final
    bam_virus    = BAM_FILTER_POLYX.out.bam
    coverage     = SAMTOOLS_COVERAGE.out.coverage
    fastp_json   = params.tool_versions == 'legacy' ? FASTP_LEGACY.out.json : FASTP.out.json
    versions     = ch_versions
}

//
// VIRTUS SE subworkflow
// Matches workflow/VIRTUS.SE.cwl (10 steps, including the added SAMTOOLS_INDEX)
//

include { FASTP                  } from '../../../modules/nf-core/fastp/main'
include { STAR_ALIGN as STAR_ALIGN_HUMAN } from '../../../modules/nf-core/star/align/main'
include { STAR_ALIGN as STAR_ALIGN_VIRUS } from '../../../modules/nf-core/star/align/main'
include { SAMTOOLS_VIEW          } from '../../../modules/local/samtools/view/main'
include { BEDTOOLS_BAMTOFASTQ    } from '../../../modules/local/bedtools/bamtofastq/main'
include { SAMTOOLS_FASTQ         } from '../../../modules/nf-core/samtools/fastq/main'
include { KZ_FILTER              } from '../../../modules/local/kz_filter/main'
include { BAM_FILTER_POLYX       } from '../../../modules/local/bam_filter_polyx/main'
include { SAMTOOLS_INDEX         } from '../../../modules/nf-core/samtools/index/main'
include { SAMTOOLS_COVERAGE      } from '../../../modules/nf-core/samtools/coverage/main'
include { MK_SUMMARY_VIRUS_COUNT } from '../../../modules/local/mk_summary_virus_count/main'

workflow VIRTUS_SE {

    take:
    ch_reads        // channel: [ val(meta), [ fastq ] ]
    ch_human_index  // value channel: path to human STAR index dir
    ch_virus_index  // value channel: path to virus STAR index dir

    main:
    ch_versions = Channel.empty()

    // Step 1 — QC & trimming
    FASTP (
        ch_reads.map { meta, reads -> [ meta, reads, [] ] },
        false, false, false
    )

    // Step 2 — Align to human genome
    STAR_ALIGN_HUMAN (
        FASTP.out.reads,
        ch_human_index.map { idx -> [ [:], idx ] },
        Channel.value([[id:'no_gtf'], []]),
        true
    )

    // Step 3 — Extract unmapped reads
    SAMTOOLS_VIEW ( STAR_ALIGN_HUMAN.out.bam_sorted_aligned )
    ch_versions = ch_versions.mix(
        SAMTOOLS_VIEW.out.versions_samtools.map { process, tool, ver -> [ process, ver ] }
    )

    // Step 4 — Convert unmapped BAM → FASTQ
    // Branch on bam_to_fastq_tool param: 'bedtools' for exact CWL replication, 'samtools' (default) for modern approach
    ch_single_fq = Channel.empty()
    if (params.bam_to_fastq_tool == 'bedtools') {
        BEDTOOLS_BAMTOFASTQ ( SAMTOOLS_VIEW.out.bam )
        ch_versions = ch_versions.mix(
            BEDTOOLS_BAMTOFASTQ.out.versions_bedtools.map { process, tool, ver -> [ process, ver ] }
        )
        // bedtools emits [ meta, [fq] ] for SE; unwrap to single file
        ch_single_fq = BEDTOOLS_BAMTOFASTQ.out.reads.map { meta, reads ->
            [ meta, reads instanceof List ? reads[0] : reads ]
        }
    } else {
        SAMTOOLS_FASTQ ( SAMTOOLS_VIEW.out.bam, false )
        ch_versions = ch_versions.mix(
            SAMTOOLS_FASTQ.out.versions_samtools.map { process, tool, ver -> [ process, ver ] }
        )
        // SE unmapped reads from STAR lack READ1/READ2 flags → routed to '-0' (other) by samtools fastq
        ch_single_fq = SAMTOOLS_FASTQ.out.other.map { meta, fq ->
            [ meta, fq instanceof List ? fq[0] : fq ]
        }
    }

    // Step 5 — KZ complexity filter
    KZ_FILTER ( ch_single_fq )
    ch_versions = ch_versions.mix(
        KZ_FILTER.out.versions_komplexity.map { process, tool, ver -> [ process, ver ] }
    )

    // Step 6 — Align to viral reference
    STAR_ALIGN_VIRUS (
        KZ_FILTER.out.reads.map { meta, fq -> [ meta, [ fq ] ] },
        ch_virus_index.map { idx -> [ [:], idx ] },
        Channel.value([[id:'no_gtf'], []]),
        true
    )

    // Step 7 — Remove poly-X reads from viral BAM
    BAM_FILTER_POLYX ( STAR_ALIGN_VIRUS.out.bam_sorted_aligned )
    ch_versions = ch_versions.mix(
        BAM_FILTER_POLYX.out.versions_samtools.map { process, tool, ver -> [ process, ver ] }
    )

    // Step 8 — Index filtered viral BAM
    SAMTOOLS_INDEX ( BAM_FILTER_POLYX.out.bam )

    // Step 9 — Compute per-virus coverage
    ch_bam_bai = BAM_FILTER_POLYX.out.bam
        .join( SAMTOOLS_INDEX.out.index )
    SAMTOOLS_COVERAGE (
        ch_bam_bai,
        Channel.value([[id:'no_fasta'], [], []])
    )

    // Step 10 — Generate per-sample VIRTUS summary TSV
    // Join log_final + coverage by meta so samples are never mismatched
    ch_log_cov = STAR_ALIGN_HUMAN.out.log_final
        .join( SAMTOOLS_COVERAGE.out.coverage )
    MK_SUMMARY_VIRUS_COUNT (
        ch_log_cov.map { meta, log, cov -> [ meta, log ] },
        ch_log_cov.map { meta, log, cov -> [ meta, cov ] },
        'SE'
    )
    ch_versions = ch_versions.mix(
        MK_SUMMARY_VIRUS_COUNT.out.versions_python.map { process, tool, ver -> [ process, ver ] }
    )

    emit:
    summary      = MK_SUMMARY_VIRUS_COUNT.out.output
    bam_human    = STAR_ALIGN_HUMAN.out.bam_sorted
    log_final    = STAR_ALIGN_HUMAN.out.log_final
    bam_virus    = BAM_FILTER_POLYX.out.bam
    coverage     = SAMTOOLS_COVERAGE.out.coverage
    fastp_json   = FASTP.out.json
    versions     = ch_versions
}

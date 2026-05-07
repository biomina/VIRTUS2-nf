//
// CREATE_INDEX subworkflow
// Downloads human and virus FASTAs (wget) then builds STAR indices.
// Called from main.nf only when neither genomeDir_* nor fasta_* params are set.
//

include { WGET as WGET_HUMAN               } from '../../../modules/nf-core/wget/main'
include { WGET as WGET_VIRUS               } from '../../../modules/nf-core/wget/main'
include { STAR_GENOMEGENERATE as STAR_GENOMEGENERATE_HUMAN } from '../../../modules/nf-core/star/genomegenerate/main'
include { STAR_GENOMEGENERATE as STAR_GENOMEGENERATE_VIRUS } from '../../../modules/nf-core/star/genomegenerate/main'

workflow CREATE_INDEX {

    take:
    url_human   // val: URL for human genome FASTA
    url_virus   // val: URL for virus FASTA

    main:
    ch_versions = Channel.empty()

    // Download reference FASTAs
    WGET_HUMAN ( Channel.value([[id: 'human_genome'], url_human, 'fa.gz']) )
    WGET_VIRUS ( Channel.value([[id: 'viruses'],      url_virus, 'fasta']) )
    ch_versions = ch_versions.mix(WGET_HUMAN.out.versions)
    ch_versions = ch_versions.mix(WGET_VIRUS.out.versions)

    // Build human STAR index (with GTF if available, otherwise omit)
    STAR_GENOMEGENERATE_HUMAN (
        WGET_HUMAN.out.outfile.map { meta, f -> [ [id: 'human'], f ] },
        Channel.value([[id:'no_gtf'], []])   // no GTF — purely genomic alignment for unmapped read extraction
    )

    // Build virus STAR index (small genome → ext.args sets genomeSAindexNbases 12)
    STAR_GENOMEGENERATE_VIRUS (
        WGET_VIRUS.out.outfile.map { meta, f -> [ [id: 'virus'], f ] },
        Channel.value([[id:'no_gtf'], []])
    )

    emit:
    human_index = STAR_GENOMEGENERATE_HUMAN.out.index.map { meta, idx -> idx }
    virus_index = STAR_GENOMEGENERATE_VIRUS.out.index.map { meta, idx -> idx }
    versions    = ch_versions
}

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
    WGET_HUMAN ( url_human, 'human_genome.fa.gz' )
    WGET_VIRUS ( url_virus, 'viruses.fa' )
    ch_versions = ch_versions.mix(WGET_HUMAN.out.versions)
    ch_versions = ch_versions.mix(WGET_VIRUS.out.versions)

    // Build human STAR index (with GTF if available, otherwise omit)
    STAR_GENOMEGENERATE_HUMAN (
        WGET_HUMAN.out.file.map { f -> [ [id: 'human'], f ] },
        []   // no GTF — purely genomic alignment for unmapped read extraction
    )
    ch_versions = ch_versions.mix(STAR_GENOMEGENERATE_HUMAN.out.versions)

    // Build virus STAR index (small genome → ext.args sets genomeSAindexNbases 12)
    STAR_GENOMEGENERATE_VIRUS (
        WGET_VIRUS.out.file.map { f -> [ [id: 'virus'], f ] },
        []
    )
    ch_versions = ch_versions.mix(STAR_GENOMEGENERATE_VIRUS.out.versions)

    emit:
    human_index = STAR_GENOMEGENERATE_HUMAN.out.index.map { meta, idx -> idx }
    virus_index = STAR_GENOMEGENERATE_VIRUS.out.index.map { meta, idx -> idx }
    versions    = ch_versions
}

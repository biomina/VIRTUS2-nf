// Remove poly-X reads from viral BAM using a custom shell script.
// bam_filter_polyx.sh runs:
//   samtools view -h $1 | grep -v "AAAA..." | grep -v "TTTT..." |
//   grep -v "TGTG..." | samtools view -bS -
process BAM_FILTER_POLYX {
    tag "$meta.id"
    label 'process_medium'

    conda 'bioconda::samtools=1.21'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://yyasumizu/bam_filter_polyx:1.3' :
        'yyasumizu/bam_filter_polyx:1.3' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path('virusAligned.filtered.sortedByCoord.out.bam'), emit: bam
    path 'versions.yml',                                                   emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    bam_filter_polyx.sh ${bam} > virusAligned.filtered.sortedByCoord.out.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """
    stub:
    """
    touch virusAligned.filtered.sortedByCoord.out.bam
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: stub
    END_VERSIONS
    """

}
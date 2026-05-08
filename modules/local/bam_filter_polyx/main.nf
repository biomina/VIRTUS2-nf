// Remove poly-X reads from viral BAM using a custom shell script.
// bam_filter_polyx.sh runs:
//   samtools view -h $1 | grep -v "AAAA..." | grep -v "TTTT..." |
//   grep -v "TGTG..." | samtools view -bS -
process BAM_FILTER_POLYX {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://yyasumizu/bam_filter_polyx:1.3' :
        'yyasumizu/bam_filter_polyx:1.3' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path('virusAligned.filtered.sortedByCoord.out.bam'),                                                                emit: bam
    tuple val("${task.process}"), val('samtools'), eval("samtools version | sed '1!d;s/.* //'"), emit: versions_samtools, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    bam_filter_polyx.sh ${bam} > virusAligned.filtered.sortedByCoord.out.bam
    """
    stub:
    """
    touch virusAligned.filtered.sortedByCoord.out.bam
    """

}
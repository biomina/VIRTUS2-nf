// Extract unmapped reads using a custom script that also removes multi-mappers.
// The script samtools_view_removemulti.sh is baked into the yyasumizu/bam_filter_polyx:1.3 image
// and runs:  samtools view -@ $1 -f $2 $3 | grep -v "uT:A:3" | samtools view -@ $1 -bS -
process SAMTOOLS_VIEW {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://yyasumizu/bam_filter_polyx:1.3' :
        'yyasumizu/bam_filter_polyx:1.3' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path('*.unmapped.bam'),                                                                                    emit: bam
    tuple val("${task.process}"), val('samtools'), eval("samtools version | sed '1!d;s/.* //'"), emit: versions_samtools, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samtools_view_removemulti.sh ${task.cpus} 4 ${bam} > ${prefix}.unmapped.bam
    """
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.unmapped.bam
    """

}
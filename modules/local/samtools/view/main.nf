// Extract unmapped reads using a custom script that also removes multi-mappers.
// The script samtools_view_removemulti.sh is baked into the yyasumizu/bam_filter_polyx:1.3 image
// and runs:  samtools view -@ $1 -f $2 $3 | grep -v "uT:A:3" | samtools view -@ $1 -bS -
process SAMTOOLS_VIEW {
    tag "$meta.id"
    label 'process_medium'

    conda 'bioconda::samtools=1.21'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://yyasumizu/bam_filter_polyx:1.3' :
        'yyasumizu/bam_filter_polyx:1.3' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path('*.unmapped.bam'), emit: bam
    path 'versions.yml',                    emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samtools_view_removemulti.sh ${task.cpus} 4 ${bam} > ${prefix}.unmapped.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.unmapped.bam
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: stub
    END_VERSIONS
    """

}
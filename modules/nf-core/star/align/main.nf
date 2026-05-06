process STAR_ALIGN {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/star:2.7.11b--h43eeafb_0' :
        'quay.io/biocontainers/star:2.7.11b--h43eeafb_0' }"

    input:
    tuple val(meta), path(reads, stageAs: 'input*/*')
    tuple val(meta2), path(index)

    output:
    tuple val(meta), path('*sortedByCoord.out.bam'),  emit: bam_sorted
    tuple val(meta), path('*Log.final.out'),           emit: log_final
    tuple val(meta), path('*Log.out'),                 emit: log_out,      optional: true
    tuple val(meta), path('*SJ.out.tab'),              emit: tab,          optional: true
    path 'versions.yml',                               emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args       = task.ext.args ?: ''
    def prefix     = task.ext.prefix ? "${task.ext.prefix}" : "${meta.id}_"
    def read_input = meta.single_end ? "${reads}" : "${reads[0]} ${reads[1]}"
    """
    STAR \\
        --runMode alignReads \\
        --genomeDir ${index} \\
        --readFilesIn ${read_input} \\
        --readFilesCommand zcat \\
        --runThreadN ${task.cpus} \\
        --outFileNamePrefix ${prefix} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        star: \$(STAR --version | sed -e "s/STAR_//g")
    END_VERSIONS
    """
    stub:
    def prefix = task.ext.prefix ? "${task.ext.prefix}" : "${meta.id}_"
    """
    touch ${prefix}Aligned.sortedByCoord.out.bam
    touch ${prefix}Log.final.out
    touch ${prefix}Log.out
    touch ${prefix}SJ.out.tab
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        star: stub
    END_VERSIONS
    """

}
process FASTP {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastp:0.23.4--h5f740d0_0' :
        'quay.io/biocontainers/fastp:0.23.4--h5f740d0_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*.fastp.fastq.gz'), emit: reads
    tuple val(meta), path('*.json'),           emit: json
    tuple val(meta), path('*.html'),           emit: html
    tuple val(meta), path('*.log'),            emit: log
    path  'versions.yml',                      emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (meta.single_end) {
        """
        fastp \\
            --in1 ${reads} \\
            --out1 ${prefix}.fastp.fastq.gz \\
            --thread ${task.cpus} \\
            --json ${prefix}.fastp.json \\
            --html ${prefix}.fastp.html \\
            ${args} \\
            2> ${prefix}.fastp.log

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed -e "s/fastp //g")
        END_VERSIONS
        """
    } else {
        """
        fastp \\
            --in1 ${reads[0]} \\
            --in2 ${reads[1]} \\
            --out1 ${prefix}_1.fastp.fastq.gz \\
            --out2 ${prefix}_2.fastp.fastq.gz \\
            --thread ${task.cpus} \\
            --json ${prefix}.fastp.json \\
            --html ${prefix}.fastp.html \\
            ${args} \\
            2> ${prefix}.fastp.log

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed -e "s/fastp //g")
        END_VERSIONS
        """
    }
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def r2_out = meta.single_end ? '' : "touch ${prefix}_2.fastp.fastq.gz"
    """
    touch ${prefix}_1.fastp.fastq.gz
    ${r2_out}
    touch ${prefix}.fastp.json
    touch ${prefix}.fastp.html
    touch ${prefix}.fastp.log
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: stub
    END_VERSIONS
    """

}
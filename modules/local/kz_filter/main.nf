// Low-complexity filter using the komplexity (kz) tool.
// For PE reads two independent filter processes are called (once per read file).
// Command: kz --filter --threshold <t> < input.fq > output.fq
process KZ_FILTER {
    tag "$meta.id"
    label 'process_low'

    conda 'eclarke::komplexity=0.3.6'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://virtus2-kz:local' :
        'virtus2-kz:local' }"

    input:
    tuple val(meta), path(fastq)

    output:
    tuple val(meta), path('*.kz.fq.gz'), emit: reads
    path 'versions.yml',                 emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix    = task.ext.prefix ?: "${fastq.baseName}"
    def threshold = params.kz_threshold ?: 0.1
    def decompress = fastq.name.endsWith('.gz') ? "gunzip -c ${fastq}" : "cat ${fastq}"
    """
    ${decompress} \\
        | kz \\
            --filter \\
            --threshold ${threshold} \\
        | gzip -c > ${prefix}.kz.fq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        komplexity: \$(kz --version 2>&1 | head -1 || echo 'unknown')
    END_VERSIONS
    """
    stub:
    def prefix = task.ext.prefix ?: "${fastq.baseName}"
    """
    touch ${prefix}.kz.fq.gz
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        komplexity: stub
    END_VERSIONS
    """

}
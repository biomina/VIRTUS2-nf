// Low-complexity filter using the komplexity (kz) tool.
// For PE reads two independent filter processes are called (once per read file).
// Command: kz --filter --threshold <t> < input.fq > output.fq
process KZ_FILTER {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://quay.io/andvon/komplexity:0.3.6' :
        'quay.io/andvon/komplexity:0.3.6' }"

    input:
    tuple val(meta), path(fastq)

    output:
    tuple val(meta), path('*.kz.fq.gz'),                                                                                                       emit: reads
    tuple val("${task.process}"), val('komplexity'), eval("kz --version 2>&1 | head -1 || echo 'unknown'"), emit: versions_komplexity, topic: versions

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
    """
    stub:
    def prefix = task.ext.prefix ?: "${fastq.baseName}"
    """
    touch ${prefix}.kz.fq.gz
    """

}
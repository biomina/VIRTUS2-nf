// Re-pair PE reads after independent per-read filtering.
// fastq_pair writes <input1>.paired.fq and <input2>.paired.fq.
process FASTQ_PAIR {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastq-pair:1.0--he1b5a44_1' :
        'quay.io/biocontainers/fastq-pair:1.0--he1b5a44_1' }"

    input:
    tuple val(meta), path(reads)   // [fq1, fq2]

    output:
    tuple val(meta), path('*.paired.fq.gz'),                                                                                              emit: reads
    tuple val("${task.process}"), val('fastq-pair'), eval("fastq_pair -v 2>&1 | head -1 || echo 'unknown'"), emit: versions_fastq_pair, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def r1 = reads[0]
    def r2 = reads[1]
    def r1u = r1.name.endsWith('.gz') ? r1.baseName : r1.name
    def r2u = r2.name.endsWith('.gz') ? r2.baseName : r2.name
    """
    ${r1.name.endsWith('.gz') ? "gunzip -c ${r1} > ${r1u}" : "ln -s ${r1} ${r1u}"}
    ${r2.name.endsWith('.gz') ? "gunzip -c ${r2} > ${r2u}" : "ln -s ${r2} ${r2u}"}
    fastq_pair ${r1u} ${r2u}
    gzip ${r1u}.paired.fq
    gzip ${r2u}.paired.fq
    """
    stub:
    """
    touch ${reads[0]}.paired.fq.gz
    touch ${reads[1]}.paired.fq.gz
    """

}
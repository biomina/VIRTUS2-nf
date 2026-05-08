// Convert unmapped BAM to FASTQ for downstream re-alignment.
// Handles PE (two output files) and SE (one output file) via meta.single_end.
process BEDTOOLS_BAMTOFASTQ {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bedtools:2.29.2--hc088bd4_0' :
        'quay.io/biocontainers/bedtools:2.29.2--hc088bd4_0' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path('*.fq.gz'),                                                                                            emit: reads
    tuple val("${task.process}"), val('bedtools'), eval("bedtools --version | sed 's/bedtools v//'"), emit: versions_bedtools, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (meta.single_end) {
        """
        bedtools bamtofastq \\
            -i ${bam} \\
            -fq /dev/stdout \\
            | gzip -c > ${prefix}.unmapped.fq.gz
        """
    } else {
        """
        bedtools bamtofastq \\
            -i ${bam} \\
            -fq /dev/stdout \\
            -fq2 ${prefix}_2.unmapped.fq.gz.tmp \\
            | gzip -c > ${prefix}_1.unmapped.fq.gz
        gzip -c ${prefix}_2.unmapped.fq.gz.tmp > ${prefix}_2.unmapped.fq.gz
        rm ${prefix}_2.unmapped.fq.gz.tmp
        """
    }
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (meta.single_end) {
        """
        echo | gzip > ${prefix}.unmapped.fq.gz
        """
    } else {
        """
        echo | gzip > ${prefix}_1.unmapped.fq.gz
        echo | gzip > ${prefix}_2.unmapped.fq.gz
        """
    }

}
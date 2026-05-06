process STAR_GENOMEGENERATE {
    tag "$fasta.name"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/star:2.7.11b--h43eeafb_0' :
        'quay.io/biocontainers/star:2.7.11b--h43eeafb_0' }"

    input:
    tuple val(meta), path(fasta)
    // gtf may be an empty list [] for virus index — handled below
    path gtf

    output:
    tuple val(meta), path('star'), emit: index
    path 'versions.yml',           emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args     = task.ext.args ?: ''
    def gtf_cmd  = gtf ? "--sjdbGTFfile ${gtf}" : ''
    """
    mkdir star
    STAR \\
        --runMode genomeGenerate \\
        --genomeDir star \\
        --genomeFastaFiles ${fasta} \\
        --runThreadN ${task.cpus} \\
        ${gtf_cmd} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        star: \$(STAR --version | sed -e "s/STAR_//g")
    END_VERSIONS
    """
    stub:
    """
    mkdir -p star
    touch star/Genome
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        star: stub
    END_VERSIONS
    """

}
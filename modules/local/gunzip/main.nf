process GUNZIP {
    tag "$archive"
    label 'process_single'

    conda 'conda-forge::pigz=2.8'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'ubuntu:20.04' }"

    input:
    path archive

    output:
    path "${archive.baseName}", emit: gunzip
    path 'versions.yml',        emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    gunzip -c ${archive} > ${archive.baseName}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gunzip: \$(gunzip --version 2>&1 | head -1)
    END_VERSIONS
    """

    stub:
    """
    touch ${archive.baseName}
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gunzip: stub
    END_VERSIONS
    """
}

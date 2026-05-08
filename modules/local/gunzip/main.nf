process GUNZIP {
    tag "$archive"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'ubuntu:20.04' }"

    input:
    path archive

    output:
    path "${archive.baseName}",                                                                                              emit: gunzip
    tuple val("${task.process}"), val('gunzip'), eval('gunzip --version 2>&1 | head -1'), emit: versions_gunzip, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    gunzip -c ${archive} > ${archive.baseName}
    """

    stub:
    """
    touch ${archive.baseName}
    """
}

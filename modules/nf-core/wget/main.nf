process WGET {
    tag "$url"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gnu-wget:1.18--h60da905_7' :
        'quay.io/biocontainers/gnu-wget:1.18--h60da905_7' }"

    input:
    val  url
    val  filename

    output:
    path "${filename}", emit: file
    path 'versions.yml', emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    wget \\
        -O ${filename} \\
        ${args} \\
        "${url}"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        wget: \$(wget --version | head -1 | sed 's/GNU Wget //' | sed 's/ .*//')
    END_VERSIONS
    """
    stub:
    """
    touch ${filename}
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        wget: stub
    END_VERSIONS
    """

}
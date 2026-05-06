// Generate per-sample virus detection summary (virus × rate_hit table).
// Calls mk_summary_virus_count.py from the pipeline bin/ or from the container image.
process MK_SUMMARY_VIRUS_COUNT {
    tag "$meta.id"
    label 'process_single'

    conda 'conda-forge::pandas=1.3.5'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://yyasumizu/mk_summary_virus_count:2.0' :
        'yyasumizu/mk_summary_virus_count:2.0' }"

    input:
    tuple val(meta), path(log_final)    // STAR human Log.final.out
    tuple val(meta2), path(coverage)    // samtools coverage output
    val   layout                        // 'PE' or 'SE'

    output:
    tuple val(meta), path('*.tsv'), emit: output
    path 'versions.yml',            emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    python /workdir/mk_summary_virus_count.py \\
        ${log_final} \\
        ${layout} \\
        ${coverage} \\
        ${prefix}.${params.filename_output}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //')
        pandas: \$(python -c "import pandas; print(pandas.__version__)")
    END_VERSIONS
    """
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.${params.filename_output}
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: stub
    END_VERSIONS
    """

}
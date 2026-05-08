// Generate per-sample virus detection summary (virus × rate_hit table).
// Calls mk_summary_virus_count.py from the pipeline bin/ or from the container image.
process MK_SUMMARY_VIRUS_COUNT {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://yyasumizu/mk_summary_virus_count:2.0' :
        'yyasumizu/mk_summary_virus_count:2.0' }"

    input:
    tuple val(meta), path(log_final)    // STAR human Log.final.out
    tuple val(meta2), path(coverage)    // samtools coverage output
    val   layout                        // 'PE' or 'SE'

    output:
    tuple val(meta), path('*.tsv'),                                                                                                       emit: output
    tuple val("${task.process}"), val('python'), eval('python --version 2>&1 | sed "s/Python //"'),              emit: versions_python, topic: versions
    tuple val("${task.process}"), val('pandas'), eval('python -c "import pandas; print(pandas.__version__)"'),  emit: versions_pandas, topic: versions

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
    """
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.${params.filename_output}
    """

}
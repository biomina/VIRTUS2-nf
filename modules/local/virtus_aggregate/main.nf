// Aggregate per-sample VIRTUS output TSVs, build rate/coverage matrices,
// run Mann-Whitney U + BH-FDR if two groups are present, and produce
// summary.csv + scattermap.pdf.
process VIRTUS_AGGREGATE {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://community.wave.seqera.io/library/matplotlib_numpy_pandas_python_pruned:e8acf970170a6bce' :
        'community.wave.seqera.io/library/matplotlib_numpy_pandas_python_pruned:e8acf970170a6bce' }"

    input:
    path tsvs          // collected list of per-sample *.tsv files
    path metadata      // samplesheet CSV (sample, fastq1, fastq2, group)

    output:
    path 'summary.csv',                                                                                                                   emit: summary
    path 'scattermap.pdf',                                                                                            optional: true,    emit: plot
    tuple val("${task.process}"), val('python'),  eval('python --version 2>&1 | sed "s/Python //"'),                  emit: versions_python,  topic: versions
    tuple val("${task.process}"), val('pandas'),  eval('python -c "import pandas; print(pandas.__version__)"'),       emit: versions_pandas,  topic: versions
    tuple val("${task.process}"), val('scipy'),   eval('python -c "import scipy; print(scipy.__version__)"'),         emit: versions_scipy,   topic: versions
    tuple val("${task.process}"), val('seaborn'), eval('python -c "import seaborn; print(seaborn.__version__)"'),     emit: versions_seaborn, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    aggregate_virtus.py \\
        --tsv_dir . \\
        --metadata ${metadata} \\
        --th_cov ${params.th_cov} \\
        --th_rate ${params.th_rate} \\
        --figsize ${params.figsize}
    """
    stub:
    """
    touch summary.csv
    touch scattermap.pdf
    """

}
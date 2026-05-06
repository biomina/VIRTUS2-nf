// Aggregate per-sample VIRTUS output TSVs, build rate/coverage matrices,
// run Mann-Whitney U + BH-FDR if two groups are present, and produce
// summary.csv + scattermap.pdf.
process VIRTUS_AGGREGATE {
    label 'process_single'

    conda 'conda-forge::pandas conda-forge::scipy conda-forge::seaborn conda-forge::matplotlib'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://virtus2-aggregate:local' :
        'virtus2-aggregate:local' }"

    input:
    path tsvs          // collected list of per-sample *.tsv files
    path metadata      // samplesheet CSV (sample, fastq1, fastq2, group)

    output:
    path 'summary.csv',   emit: summary
    path 'scattermap.pdf', emit: plot,    optional: true
    path 'versions.yml',   emit: versions

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

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //')
        pandas: \$(python -c "import pandas; print(pandas.__version__)")
        scipy:  \$(python -c "import scipy; print(scipy.__version__)")
        seaborn: \$(python -c "import seaborn; print(seaborn.__version__)")
    END_VERSIONS
    """
    stub:
    """
    touch summary.csv
    touch scattermap.pdf
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: stub
    END_VERSIONS
    """

}
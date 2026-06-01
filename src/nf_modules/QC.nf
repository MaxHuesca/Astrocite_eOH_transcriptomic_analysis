process fastQC {
    //name of the nextflow job 
    tag "${srr_id}_QCreps_${type}"
    //save options 
    publishDir "${params.outdir}/QC/${type}/FastQC/${srr_id}", mode: 'copy',overwrite: true

    input:
        tuple val(srr_id), path(srr_files),val(type)
    output: 
        tuple val(srr_id),path(srr_files), path("*_fastqc.zip"),path("*fastqc.html"),val(type),emit: fastq_out
    script:
    """ 
    mkdir -p "${params.outdir}/QC/${type}/FastQC/${srr_id}"

    fastqc -t ${params.threads} ${srr_files.join(' ')}
    """
}


process multiQC{
    //name of the nextflow job 
    tag "multiQC_${type}"
    //save options 
    publishDir "${params.outdir}/QC/${type}/multiQC/", mode: 'copy',overwrite: true

    input:
        tuple val(type), path(fastqc_reps)
    output: 
        path("*.html"), emit: multiqc_res
    script: 
    """
    mkdir -p ${params.outdir}/QC/${type}/multiQC/

    multiqc ${fastqc_reps.join(' ')}
    """
}



workflow report_QC {
    take:
        in_fastqs
    main:
        clean_fastqc = fastQC(in_fastqs).fastq_out
        //paths
        clean_fastqc
            .map { _id, _paths, _zipF , _html, _type-> tuple(_type, _zipF) }
            .groupTuple()
            .map { _type, _zipF ->
                tuple(_type, _zipF.flatten())
            }
            .set { all_fastqc_clean }

        multiQC(all_fastqc_clean)
    emit: 
        fastq_out = clean_fastqc
}
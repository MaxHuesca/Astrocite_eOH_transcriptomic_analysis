/*
This pipeline is for making the Quality Control reports of the fastq files in order to also make the 
cleaning file. 

============================================================================
Input
============================================================================
It needs to be a csv file with the following columns in that order without header: 

srrid,path_fastq,path_fastq_2 

- srr_id: ID from srr or a identifier of the sample (fot downloading it must be the srr_id)
- path_fastq : the path from the main fastq file 
- path_fastq_2 : the path of the second fastq file if they are paired end data

============================================================================
Arguments
============================================================================


*/ 

// general arguments 
params.outdir = params.outdir ?: "results/nf/"
params.outdir_QC = params.outdir_QC ?: params.outdir
params.metadata = params.metadata ?: "data/metadata.csv"
params.conda_env = params.conda_env ?: "/export/space3/users/ismadlsh/conda/bio_informatics" 
params.threads = params.threads ?: 2

//arguments for fastp trimming 
params.trimF = params.trimF ?: 10
params.fastp_env= params.fastp_env ?: "fastp" 
params.fastp_args= params.fastp_args ?: null
params.drop_dup= params.drop_dup ?: "no"


//alignment options
params.aligner= params.aligner ?: "both"
params.star_args= params.star_args ?: null 
params.hisat_args= params.hisat_args ?: null 
params.star_index= params.star_index ?: null
params.hisat_index= params.hisat_index ?: null
params.qual_align= params.qual_align ?: 10
params.fastq_compres= params.fastq_compres ?: "gz"

//flags for the general run 
params.onlydownload= params.onlydownload ?: false 
params.onlyclean= params.onlyclean ?: false 
params.onlyalign = params.onlyalign ?: false 

//arguments for feature counts
params.annotation_file = params.annotation_file ?: "/export/space3/users/ismadlsh/LCG/S4/transcriptomica/proyecto_final/data/reference/gencode.vM38.chr_patch_hapl_scaff.annotation.gtf"
params.paired_end = params.paired_end ?: true
params.feature_env = params.feature_env ?: "subread"

nextflow.enable.dsl=2

include { report_QC as raw_fastQC } from './nf_modules/QC'
include { report_QC as clean_fastQC } from './nf_modules/QC'

process Download_srr {
    //name of the nextflow job 
    tag "${srr_id}"
    errorStrategy 'retry'
    maxRetries 3
    cpus params.threads

    //save options 
    publishDir "${params.outdir}/${srr_id}", mode: 'copy',overwrite: true


    input:
        val(srr_id)
    output: 
        tuple val(srr_id), path("*.fastq.gz"),val("raw_data"), emit: dw_fastq
    script: 
    """
    conda run -p "${params.conda_env}" prefetch "${srr_id}" 
    
    conda run -p "${params.conda_env}" fasterq-dump "${srr_id}" \
    --split-files \
    --threads "${params.threads}" --force

    gzip *.fastq
    """
}


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
    multiqc ${fastqc_reps.join(' ')}
    """
}

process fastp {
    //name of the nextflow job 
    tag "${srr_id}_fastp"
    //save options 
    publishDir "${params.outdir}/clean_data/${srr_id}", mode: 'copy',overwrite: true
    input:
        tuple val(srr_id), path(srr_files), path(fastqc_res),val(type)
    output: 
        tuple val(srr_id), path("*_clean.fastq.gz*"),val("clean_data"), emit: fastq_clean
    script:
    """ 
    bash ${projectDir}/run_fastp.sh -t ${params.trimF} \
    -e ${params.fastp_env} -i ${srr_id} \
    -z ${fastqc_res} -d ${params.drop_dup} \
    ${params.fastp_args? "-a ${params.fastp_args}" : ""} \
    ${srr_files.join(' ')}
    """
} 

process align_star{
    //name of the nextflow job 
    tag "align_star_${srr_id}"
    //save options 
    publishDir "${params.outdir}/alignments/star", mode: 'copy',overwrite: true,
        saveAs: { filename ->
        if(filename.endsWith("Log.final.out"))
            "stats/${filename}"
        else
            filename
        }
    cpus params.threads

    input: 
        tuple val(srr_id), path(fastq_files)
    output:
        tuple val(srr_id), path("star_${srr_id}.bam"),path("*Log.final.out"), path("star_${srr_id}.bam.bai"), emit: aligned_star
    script: 
    """
    bash ${projectDir}/align_star.sh -d ${srr_id} \
    -i ${params.star_index} -t ${params.threads} \
    -q ${params.qual_align} -c ${params.fastq_compres} \
    ${params.star_args? "-a '${params.star_args}'" : ""} \
    ${fastq_files.join(' ')}
    """
}

process align_hisat{
    //name of the nextflow job 
    tag "align_hisat_${srr_id}"
    //save options 
    publishDir "${params.outdir}/alignments/hisat", mode: 'copy',overwrite: true,
        saveAs: { filename ->
        if(filename.endsWith("sum.txt"))
            "stats/${filename}"
        else
            filename
        }
    cpus params.threads

    input: 
        tuple val(srr_id), path(fastq_files)
    output:
        tuple val(srr_id), path("*.bam"), path("*sum.txt"), path("*.bai"), emit: aligned_hisat
    script: 
    """
    bash ${projectDir}/align_hisat.sh -d ${srr_id} \
    -i ${params.hisat_index} -t ${params.threads} \
    -q ${params.qual_align} \
    ${params.hisat_args ? "-a '${params.hisat_args}'" : ""} \
    ${fastq_files.join(' ')}
    """
}


process align_stats {
    //name of the nextflow job 
    tag "align_stats"
    //save options 
    publishDir "${params.outdir}/alignments/stats", mode: 'copy',overwrite: true

    input: 
        path(stats_reports)
        path(parse_script)
    output: 
        tuple path("alignment_stats.csv"), path("Multi_mapped_vs_no_aligned.png"), path("aligned_vs_time.png")
    script: 
    """
    conda run -p "${params.conda_env}" python ${parse_script} \
    -p ${stats_reports.join(',')}
    """
}

process makeC_matrixes {
    //name of the nextflow job 
    tag "Make_count_matrixes_${aligner}"
    //save options 
    publishDir "${params.outdir}/count_matrixes", mode: 'copy',overwrite: true
    input:
        tuple val(aligner), path(bams) 
    output: 
        path("${aligner}_countMatrix.txt")
    script: 
    """
    conda run -n ${params.feature_env} featureCounts \
        -a ${params.annotation_file} \
        -o "${aligner}_countMatrix.txt" \
        ${params.paired_end ? "-p" : ""} \
        -T ${params.threads} \
        -F GTF \
        ${bams.join(' ')}
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

workflow clean_seqs {
    take:
        fastq_ch
    main: 
        //report of the raw data 
        fastq_rep=raw_fastQC(fastq_ch.map{ _id, _paths -> tuple (_id , _paths, "raw_data")}).fastq_out
        fastq_rep 
            .map {_id, _paths, _zipF , _html, _type -> tuple(_id, _paths, _zipF.first() , _type)}
            .set {fastq_rep_clean}
        //make the cleaning step 
        clean_data=fastp(fastq_rep_clean).fastq_clean
        //report of the cleaned data
        clean_fastQC(clean_data)
    emit: 
        fastq_clean = clean_data
}

workflow align_seqs {
    take: 
        files_ch 
    main: 
        //firts we run the alignment 
        switch(params.aligner) {
            case "star": 
                log.info "Running star alignment"
                aligned=align_star(files_ch).aligned_star
                break
            case "hisat": 
                log.info "Running hisat alignment"
                aligned=align_hisat(files_ch).aligned_hisat
                break
            case "both": 
                log.info "Running star and hisat alignment"
                aligned=align_star(files_ch).aligned_star
                aligned_hi=align_hisat(files_ch).aligned_hisat 
                aligned = aligned.concat(aligned_hi)
                break
            default:
                error """
                Invalid aligner method: ${params.aligner}

                Supported methods:
                    - star
                    - hisat
                    - both
                """ 
        }
        //then we can obtain the stats files for the alignment performance 
        aligned
            .map {_id, _bam, _stats, _bai -> _stats}
            .collect()
            .set {stats_ch}
        //make the stats analysis 
        align_stats(stats_ch, file("${projectDir}/parse_align_stats.py"))
        //make the matrixes 
        aligned
            .map { _id, _bam, _stats, _bai ->

                def aligner = _bam.name.startsWith("star") ?
                    "star" :
                    "hisat"

                tuple(aligner, _bam)
            }
            .groupTuple()
            .set { bam_alignment } 
        makeC_matrixes(bam_alignment) 
    emit:
        aligned = aligned
}

workflow {
    meta_ch = channel.fromPath(params.metadata)
        .splitCsv(header: false, sep: ",")
        .map {row -> row[0]
        }
    if (params.onlydownload){
        //download the data 
        dw_pths=Download_srr(meta_ch).dw_fastq
        //QC reports of the downloaded data 
        report_QC(dw_pths)

    }else { 
        //check if the user is providing paired data or not 
        meta_ch = channel.fromPath(params.metadata)
        .splitCsv(header: false, sep: ",")
        .map {row ->
            def reads = row.size() > 2 && row[2] ? 
            [ file(row[1]), file(row[2]) ] :
            [ file(row[1]) ]
            tuple(row[0], reads)
        } 
        if (params.onlyclean){
            clean_seqs(meta_ch)
        }else if (params.onlyalign){
            align_seqs(meta_ch)
        } else{
            dw_pths=Download_srr(meta_ch).dw_fastq
            cleaned=clean_seqs(dw_pths).fastq_clean 
            cleaned
                .map{_id, _fastq, _type -> tuple(_id, _fastq)}
                .set(min_align)
            align_seqs(min_align)
        }
    }
} 

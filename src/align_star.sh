#!/usr/bin/env bash 
#Ensure robusteness
set -e # Only to ensure scrpt executions
set -u # To avoid undefined variables usage
set -o pipefail # To avoid failed runs 

#make the alignment of the sequences using satr
#Arguuments
#   d: the id for the files generated 
#   i: the path of the index used for hisat alignment 
#   a: list separated by a comma with the star arguments
#   t: number of threads  
#   q: quality min of the alignment
#   c: gz for compressed files 
#Positional:  
#   <fastq_1>: for the first read
#   <fastq_2>: for the second read 

while getopts "d:i:a:t:q:c:" opt; do
  case $opt in
    d) id_s="$OPTARG" ;;
    i) index_pth="$OPTARG" ;;
    a) add_args="$OPTARG" ;;
    t) threads="$OPTARG" ;;
    q) align_quality="$OPTARG" ;;
    c) compressed="$OPTARG" ;;
    \?) echo "Invalid option: -$OPTARG" >&2 ;;
  esac
done
shift $((OPTIND - 1))  

#positional arguments 
zip_1=$1 
[[ -n "${2:-}" ]] && zip_2=$2

#verify the obligatory arguments 
if [[ -z "${zip_1:-}" || -z "${index_pth}" ]]; then 
  echo "The option -i and at least one fastq postional file are necessary exiting..."
  exit 1
fi  

#if the id is not provided we use the defualt basename of the file 
[[ -z "${id_s:-}" ]] && base=$(basename "$zip_1")  && id_s="${base%%.*}"

#array for the arguments 
star_args=() 

[[ -z "${threads:-}" ]] && threads=4


#check if are paired data 
if [[ -n "${zip_2:-}" ]]; then
  prefix_name="star_PR_${id_s}_"
  star_args+=("--readFilesIn" "${zip_1}" "${zip_2}")
else
  prefix_name="star_UN_${id_s}_"
  star_args+=("--readFilesIn" "${zip_1}")
fi

star_args+=("--runMode" "alignReads" 
            "--genomeDir" "${index_pth}"
            "--outSAMtype" "BAM" "SortedByCoordinate"
            "--runThreadN" "${threads}"
            "--outFileNamePrefix" "${prefix_name}") 

out_bam="${prefix_name}Aligned.sortedByCoord.out.bam"

[[ "${compressed:-}" == "gz" ]] && star_args+=("--readFilesCommand" "zcat")

#aditional options
if [[ -n "${add_args:-}" ]]; then
  IFS="," read -ra args_array <<< "$add_args" 
  star_args+=("${args_array[@]}")
fi 

#samtools options 
[[ -z "${align_quality:-}" ]] && align_quality=10 

#run the alignment 
conda run -n star STAR \
    "${star_args[@]}"

samtools view -bq "${align_quality}" "${out_bam}" > "star_${id_s}.bam"

#index the bam file 
samtools index "star_${id_s}.bam"
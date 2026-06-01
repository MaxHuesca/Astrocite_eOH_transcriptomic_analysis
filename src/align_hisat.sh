#!/usr/bin/env bash 
#Ensure robusteness
set -e # Only to ensure scrpt executions
set -u # To avoid undefined variables usage
set -o pipefail # To avoid failed runs 

#make the alignment of the sequences using hisat2 
#Arguuments
#   d: the id for the files generated 
#   i: the path of the index used for hisat alignment 
#   a: list separated by a comma with the star arguments
#   t: number of threads  
#   q: quality min of the alignment 
#Positional:  
#   <fastq_1>: for the first read
#   <fastq_2>: for the second read 

while getopts "d:i:a:t:q:" opt; do
  case $opt in
    d) id_s="$OPTARG" ;;
    i) index_pth="$OPTARG" ;;
    a) add_args="$OPTARG" ;;
    t) threads="$OPTARG" ;;
    q) align_quality="$OPTARG" ;;
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
[[ -z "${id_s:-}" ]] && base=$(basename $zip_1)  && id_s="${base%%.*}"

#array for the arguments 
hisat_args=()

#fastq related arguments 
if [[ -n "${zip_2:-}" ]]; then 
  sum_file="hisat_PR_${id_s}_sum.txt"
  hisat_args+=("-1" "${zip_1}" "-2" "${zip_2}")
    
else 
  sum_file="hisat_UN_${id_s}_sum.txt"
  hisat_args+=("-U" "${zip_1}")
fi

[[ -z "${threads:-}" ]] && threads=4

#index file
hisat_args+=("-x" "${index_pth}" 
              "-t" "-p" "${threads}" 
              "--summary-file" "${sum_file}"
              "--new-summary" "--met" "1"
              "--met-file" "${sum_file%_*}_met.txt") 

#additional arguments 
if [[ -n "${add_args:-}" ]]; then
  IFS="," read -ra args_array <<< "$add_args" 
  hisat_args+=("${args_array[@]}")
fi 

#samtools options 
[[ -z "${align_quality:-}" ]] && align_quality=10

#run the alignment
/usr/bin/time -f "time_align: %e" -o "time_${id_s}.txt" \
hisat2 "${hisat_args[@]}" |\
    samtools view -bSq "${align_quality}" |\
    samtools sort -o "hisat_${id_s}.bam" 

#add the time used 
cat "time_${id_s}.txt" >> "${sum_file}"


#index the bam file 
samtools index "hisat_${id_s}.bam"
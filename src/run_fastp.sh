#!/usr/bin/env bash 
#Ensure robusteness
set -e # Only to ensure scrpt executions
set -u # To avoid undefined variables usage
set -o pipefail # To avoid failed runs

#Make the fastqc reports for fastq files 
#Arguments: 
#   t: number of bases to trim from the front
#   e: conda enviroment for runing fastp
#   z: path to fastqc zip file
#   a: list of additional arguments splited by a comma
#   i: the srr_id of the sample
#   d: duplicated and overrepresentad sequences
#Positional: 
#   <fastq_1>: for the first read
#   <fastq_2>: for the second read 
#The script generate one directory with all the fastqc report on zip and html format


while getopts "t:e:z:a:i:d:" opt; do
  case $opt in
    t) trim_fron="$OPTARG" ;;
    e) fastp_env="$OPTARG" ;;
    z) zip_pth="$OPTARG" ;;
    a) add_args="$OPTARG" ;;
    i) srr_id="$OPTARG" ;;
    d) dr_dup="$OPTARG" ;;
    \?) echo "Invalid option: -$OPTARG" >&2 ;;
  esac
done
shift $((OPTIND - 1))  

#positional arguments 
zip_1=$1 
[[ -n "${2:-}" ]] && zip_2=$2


#verify the obligatory arguments 
if [[ -z "${zip_1:-}" || -z "${fastp_env:-}" ]]; then 
  echo "The option -e and -u are necessary exiting... "
  exit 1
fi 

#obatain the srr_id 
[[ -z "${srr_id:-}" ]] && srr_id=$(basename $zip_1 fastq.gz) 


#unzip the directory 
unzip -q $zip_pth
base_zip=$(basename "$zip_pth" .zip)
sum="${base_zip}/summary.txt"

#array for the arguments 
fastp_args=()
[[ -z "${trim_fron}" ]] && trim_fron=10
[[ -n "${zip_1}" ]] && fastp_args+=("--in1" "${zip_1}" "-o" "${srr_id}_1_clean.fastq.gz")
[[ -n "${zip_2:-}" ]] && fastp_args+=("--in2" "${zip_2}" "-O" "${srr_id}_2_clean.fastq.gz")

fastp_args+=("-h" "${srr_id}_clean.html")

#check the base content stats 
if grep "Per base sequence content" "$sum" | grep -q "FAIL"; then
    fastp_args+=("--trim_front1" "${trim_fron}")
fi

if [[ "${r_dup:-}" == "yes" ]]; then 

  #review the Sequence Duplication Levels 
  if grep "Sequence Duplication Levels" "$sum" | grep -q "FAIL"; then
      fastp_args+=("--dedup")
  fi

  #review the over represetation sequences
  if grep "Overrepresented sequences" "$sum" | grep -q "FAIL"; then
      fastp_args+=("--overrepresentation_analysis")
  fi 

fi

#finally split the additional arguments 
if [[ -n "${add_args:-}" ]]; then
  IFS="," read -ra args_array <<< "$add_args" 
  fastp_args+=("${args_array[@]}")
fi 

conda run -n $fastp_env fastp "${fastp_args[@]}"
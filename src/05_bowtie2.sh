#!/bin/bash

# Function to display usage
usage() {
  echo "Usage: $0 -i input_dir -o output_dir -x index_file -m merge -l log_path -t n_threads"
  echo "  -i  Input directory containing trimmed fowards and reverse reads"
  echo "  -o  Output directory for Bowtie results"
  echo "  -x  Bowtie index file path base-prefix (eg. GHCh38_noalt_as)"
  echo "  -m  Is paired-end reads already merged (true or false, string)"
  echo "  -l  File path to log file output"
  echo "  -t  Number of threads per parallel instance"
  exit 1
}

# Parse command-line options
while getopts ":i:o:x:m:l:t:" opt; do
  case $opt in
    i) reads_dir="$OPTARG";;
    o) bowtie_dir="$OPTARG";;
    x) index_file="$OPTARG";;
    m) merge="$OPTARG";;
    l) log_path="$OPTARG";;
    t) threads="$OPTARG";;
    \?) echo "Invalid option: -$OPTARG" >&2; usage;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage;;
  esac
done

# Check if required options are provided
if [[ -z "$reads_dir" || -z "$bowtie_dir" || -z "$index_file" || -z "$log_path" || -z "$threads" || -z "$merge" ]]; then
  usage
fi

# Check if the merge option is valod
if [ "$merge" != 'true' ] && [ "$merge" != 'false' ]; then
    echo "Error: Read type must be either true or false (string)"
    exit 1
fi

# Export variables for use in the exported function
export reads_dir bowtie_dir index_file merge

# Create the trimmed directory if it doesn't exist
mkdir -p "$bowtie_dir"

# Create or clear the log file
mkdir -p $(dirname "$log_path") # Ensure the log directory exists
: > "$log_path"

# Bowtie alignment function
run_bowtie() {
  read1=$1
  read2=$(echo $read1 | sed "s/_1/_2/")
  base=$(basename $1)
  out=$(echo "${bowtie_dir}${base}" | sed "s/_trimmed_1.fastq.gz/_host_removed/")
  out_sam=$(echo "${bowtie_dir}${base}" | sed "s/_trimmed_1.fastq.gz/_mapped_and_unmapped.sam/")
  st=$(echo $read1 | sed "s/_1/_singleton/")
  out_sam_st=$(echo "${bowtie_dir}$(basename $st)" | sed "s/_trimmed_1.fastq.gz/singleton.sam/")
  # Forward and reverse
  /home/ctools/bowtie2-2.4.4/bowtie2 -p 10 -x $index_file \
        -1 $read1 -2 $read2 --very-sensitive-local --un-conc-gz $out > $out_sam

  # Singleton file, if paired-end reads are merged
  if [ "$merge" == 'true' ]; then
    /home/ctools/bowtie2-2.4.4/bowtie2 -p 10 -x $index_file \
        -U $st --very-sensitive-local --un-conc-gz $out > $out_sam_st
  fi
}

# Export run_bowtie to be used in parallel
export -f run_bowtie

# Loop parallelize bowtie across all reads in reads_dir
ls ${reads_dir}*_1.fastq.gz | \
  parallel -j $threads run_bowtie 2>&1 | tee -a $log_path

echo ${bowtie_dir}
echo $(ls ${bowtie_dir}*_host_removed.*)
# Rename host_removed files to .fasta.gz
host_removed_files=($(ls ${bowtie_dir}*_host_removed.*))
echo "$host_removed_files"
for file in "${host_removed_files[@]}"; do
  base=$(basename "$file")
  new_name=$(echo "$base" | sed 's/\(.*\)_host_removed\.\(.\)/\1_host_removed_\2.fastq.gz/')
  mv "$file" "$bowtie_dir$new_name"
done

# Sam to bam
sam_files=($(ls ${bowtie_dir}*.sam))
for sam_name in "${sam_files[@]}"
do
    bam_name=$(echo $sam_name | sed 's/.sam/.bam/')
    samtools view --threads 10 -bS $sam_name > $bam_name
    rm $sam_name
done
#!/usr/bin/env bash

# Default values
input_dir=""
output_dir=""
log_path=""

# Function to show usage
usage() {
    echo "Usage: $0 -i <input_dir> -o <output_dir> -l <log_path>"
    echo "  -i  Input directory containing FASTQ files"
    echo "  -o  Output directory for FastQC results"
    echo "  -l  Path for the log file"
    exit 1
}

# Parse command-line options
while getopts 'i:o:l:' flag; do
    case "${flag}" in
        i) input_dir=${OPTARG} ;;
        o) output_dir=${OPTARG} ;;
        l) log_path=${OPTARG} ;;
        *) usage ;;
    esac
done

# Check if all options are provided
if [ -z "$input_dir" ] || [ -z "$output_dir" ] || [ -z "$log_path" ]; then
    usage
fi

# Create the output and log directories if they don't exist
mkdir -p "$output_dir"
mkdir -p "$(dirname "$log_path")"

# Use parallel to process FastQC on files concurrently and log the output
ls "${input_dir}"/*.fastq.gz | parallel -j 10 fastqc -o "$output_dir" {} > "$log_path"
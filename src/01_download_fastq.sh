#!/usr/bin/env bash

# Default values
input_file=""
reads_dir=""
read_type=""
log_path=""
num_processes=10  # Default number of processes

# Function to show usage
usage() {
    echo "Usage: $0 -f <input_file> -d <reads_dir> -t <read_type> -l <log_path> -p <num_processes>"
    echo "  -f  File containing list of accession numbers"
    echo "  -d  Directory for downloaded reads"
    echo "  -t  Type of reads (single or paired)"
    echo "  -l  Path to save the log file"
    echo "  -p  Number of parallel processes (default: 10)"
    exit 1
}

# Parse command-line options
while getopts 'f:d:t:l:p:' flag; do
    case "${flag}" in
        f) input_file=${OPTARG} ;;
        d) reads_dir=${OPTARG} ;;
        t) read_type=${OPTARG} ;;
        l) log_path=${OPTARG} ;;
        p) num_processes=${OPTARG} ;;
        *) usage ;;
    esac
done

# Check if all options are provided
if [ -z "$input_file" ] || [ -z "$reads_dir" ] || [ -z "$read_type" ] || [ -z "$log_path" ]; then
    usage
fi

# Check if the read type is valid
if [ "$read_type" != "single" ] && [ "$read_type" != "paired" ]; then
    echo "Error: Read type must be either 'single' or 'paired'"
    exit 1
fi

# Export variables for use in the exported function
export reads_dir
export read_type

# Create the output directory if it doesn't exist
mkdir -p "$reads_dir"

# Function to process each line
process_line() {
    line="$1"
    if [[ -e "${reads_dir}${line}_1.fastq.gz" ]]; then
        echo "${reads_dir}${line}_1.fastq.gz exists"
    else
        echo "Processing line: $line"

        # Common fastq-dump options
        common_opts="--gzip --skip-technical --readids --read-filter pass --dumpbase --clip -O $reads_dir"

        # Check if the read type is paired and set the appropriate fastq-dump flags
        if [ "$read_type" == "paired" ]; then
            fastq_dump_options="$common_opts --split-files $line"
        else
            fastq_dump_options="$common_opts $line"
        fi

        # Download reads with fastq-dump
        echo $fastq_dump_options
        nice -n 19 fastq-dump $fastq_dump_options

    fi
}

# Export the function for parallel to use
export -f process_line

# Create or clear the log file
: > "$log_path"

# Use parallel to process lines concurrently and log the output
cat "$input_file" | parallel -j $num_processes process_line 2>&1 | tee -a "$log_path"

# Find all files with '_pass' in their names and rename them
find "$reads_dir" -type f -name "*_pass*" | while read file; do
    mv "$file" "$(echo $file | sed 's/_pass//')"
done
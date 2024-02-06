#!/bin/bash

# Default values
output_dir=""
log_path=""
input_dir=""
report_title=""

# Function to show usage
usage() {
    echo "Usage: $0 -o <output_dir> -l <log_path> -i <input_dir> -t <report_title>"
    echo "  -o  Output directory for MultiQC report"
    echo "  -l  Log file path for MultiQC output"
    echo "  -i  Input directory containing analysis results for MultiQC"
    echo "  -t  Title for the MultiQC report"
    exit 1
}

# Parse command-line options
while getopts 'o:l:i:t:' flag; do
    case "${flag}" in
        o) output_dir=${OPTARG} ;;
        l) log_path=${OPTARG} ;;
        i) input_dir=${OPTARG} ;;
        t) report_title=${OPTARG} ;;
        *) usage ;;
    esac
done

# Check if all options are provided
if [ -z "$output_dir" ] || [ -z "$log_path" ] || [ -z "$input_dir" ] || [ -z "$report_title" ]; then
    usage
fi

# Run MultiQC
/home/ctools/bin/multiqc -o "$output_dir" --title "$report_title" "${input_dir}"/* > "$log_path"
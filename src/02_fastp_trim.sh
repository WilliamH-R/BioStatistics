#!/usr/bin/env bash

# Default values
reads_dir=""
trimmed_dir=""
read_type=""
log_path=""
thread=10
minlength=10
merge=false

# Function to show usage
usage() {
    echo "Usage: $0 -r <reads_dir> -t <trimmed_dir> -T <read_type> -l <log_path> [-p <threads> -K <kmin> -R <ktrim> -Q <qtrim> -q <trimq> -m <minlength>]"
    echo "  -r  Directory containing raw FASTQ files"
    echo "  -t  Directory to store trimmed reads"
    echo "  -T  Type of reads (single or paired)"
    echo "  -l  Path to save the log file"
    echo "  -p  Number of threads (default 10)"
    echo "  -m  Merge paired-end reads (default false)"
    # Include other options in the usage message
    exit 1
}

# Parse command-line options
while getopts 'r:t:a:T:l:p:k:K:R:Q:q:m:o:z:' flag; do
    case "${flag}" in
        r) reads_dir=${OPTARG} ;;
        t) trimmed_dir=${OPTARG} ;;
        T) read_type=${OPTARG} ;;
        l) log_path=${OPTARG} ;;
        p) threads=${OPTARG} ;;
        m) merge=${OPTARG} ;;
        # Include other options here
        *) usage ;;
    esac
done

# Check if required options are provided
if [ -z "$reads_dir" ] || [ -z "$trimmed_dir" ] || [ -z "$read_type" ] || [ -z "$log_path" ] || [ -z "$merge" ]; then
    usage
fi

# Check if the read type is valid
if [ "$read_type" != "single" ] && [ "$read_type" != "paired" ]; then
    echo "Error: Read type must be either 'single' or 'paired'"
    exit 1
fi

# Check if the merge option is valod
if [ "$merge" != true ] && [ "$read_type" != false ]; then
    echo "Error: Read type must be either true or false (boolean)"
    exit 1
fi


# Export variables for use in the exported function
export reads_dir trimmed_dir read_type thread minlength merge

# Create the trimmed directory if it doesn't exist
mkdir -p "$trimmed_dir"

# Create or clear the log file
mkdir -p $(dirname "$log_path") # Ensure the log directory exists
: > "$log_path"

# Parallel command for trimming
trim_command() {
    base=$(basename $1)
    if [ "$read_type" == "paired" ]; then
        read2=$(echo $1 | sed "s/_1/_2/")
        trim1=$(echo $base | sed "s/.fastq.gz//")_trimmed_1.fastq.gz
        trim2=$(echo $base | sed "s/.fastq.gz//")_trimmed_2.fastq.gz
        st=$(echo $base | sed "s/.fastq.gz//")_trimmed_singleton.fastq.gz
        up=$(echo $base | sed "s/.fastq.gz//")_trimmed_unpaired.fastq.gz

        # Decide to merge or not
        if [ "$merge" == true ]; then
            /home/ctools/fastp/fastp --in1=$1 --in2=$read2 --out1="$trimmed_dir"$trim1 --out2="$trimmed_dir"$trim2 \
            -m --merged_out="$trimmed_dir"$st --unpaired1="$trimmed_dir"$up --unpaired2="$trimmed_dir"$up --thread $thread -l $minlength --cut_tail \
            --adapter_sequence=AATGATACGGCGACCACCGAGATCTACACGCT --adapter_sequence_r2=CAAGCAGAAGACGGCATACGAGAT
        else
            /home/ctools/fastp/fastp --in1=$1 --in2=$read2 --out1="$trimmed_dir"$trim1 --out2="$trimmed_dir"$trim2 \
            --thread $thread -l $minlength --cut_tail \
            --adapter_sequence=AATGATACGGCGACCACCGAGATCTACACGCT --adapter_sequence_r2=CAAGCAGAAGACGGCATACGAGAT
        fi
    else
        trim1=$(echo $base | sed "s/.fastq.gz//")_trimmed.fastq.gz
        /home/ctools/fastp/fastp in1=$1 out1="$trimmed_dir"$trim1 thread=$threads l=$minlength
    fi
}

export -f trim_command

# Run the trimming process and log the output
if [ "$read_type" == "paired" ]; then
    ls "$reads_dir"*_1.fastq.gz | \
    parallel -j $thread trim_command 2>&1 | tee -a "$log_path"

    # Rename files if run for paired reads
    paired_end_reads=($(ls ${trimmed_dir}*_1_*.fastq.gz))
    for file in "${paired_end_reads[@]}"; do
        mv "$file" "$(echo "$file" | sed 's/_1_/_/')"
    done
    
    # Merge unpaired with singleton file, if enabled
    if [ "$merge" == true ]; then
        unpaired=($(ls ${trimmed_dir}*_unpaired.fastq.gz))
        for file in "${unpaired[@]}"; do
            cat "$file" >> "$(echo "$file" | sed 's/unpaired/singleton/')"
            rm "$file"
        done
    fi
    
else
    ls "$reads_dir"*.fastq.gz | parallel -j $threads trim_command 2>&1 | tee -a "$log_path"
fi

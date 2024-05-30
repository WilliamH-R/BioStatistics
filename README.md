# BioStatistics Course

This repository is the outcome of a Special Course on BioStatistics at The Technical University of Denmark (DTU). The course was held in the spring of 2024. The course was a part of my MSc in Bioinformatics at DTU.

The learning objectives of the course were:

*The goal of the project is for the student to be able to acquire new knowledge on their own, specifically within the topics of staticstics and modeling in biology. This new knowledge must be applicable in the Tidyverse R framework Tidy Modeling with R. Furthermore, the student must gain experience in finding data sources. The new knowledge must be documented through the Quarto Bookdown format, through which knowledge of this framework is also gained.*

I was to select a biological topic of interest and apply the knowledge gained in the course to analyze data related to this topic. I chose to work with 16S data from the human gut microbiome to differentiate between patients with Multiple Sclerosis (MS) from healthy controls. The data was obtained from the study by [Cox et al. (2021)](https://onlinelibrary.wiley.com/doi/10.1002/ana.26084). The data were preprocessed via the pipeline described further below.

From the plethora of modeling techniques available, I was to pick a few that were relevant to the data and the research question. Those that were picked out I was to explain and exemplify, for then finally to apply them to the data through the tidy modeling framework in R. All of this were to be documented in a Quarto Bookdown document seen [here](https://williamh-r.github.io/BioStatistics/)

## Metagenomics Pipeline

The metagenomics pipeline was used to preprocess the 16S data. The data is availabla at Short Read Archive (SRA) under the accession number PRJNA721421. The pipeline was used to preprocess the data and to obtain the OTU table. All shell scripts used is to be found in the [GitHub Repository](https://github.com/WilliamH-R/BioStatistics) under `src/`. The pipeline was as follows:

1. **Download**: The raw reads were downloaded with `fastq-dump` using the script `src/01_download_fastq.sh`
  - Command run: `src/01_download_fastq.sh -f data/PRJNA721421_acc.txt -d data/_raw/ -t paired -l data/logs/download.log -p 10`

2. **Trimming**: The raw reads were trimmed with fastp using the script `src/02_fastp_trim.sh`
  - Command run: `src/02_fastp_trim.sh -r data/_raw/ -t data/trimmed_reads/ -T paired -m false -l data/logs/fastp.log`

3. **Quality Control 1**: The trimmed reads were quality controlled with FastQC using the script `src/03_fastqc.sh`
  - Command run: `src/03_fastqc.sh -i data/trimmed_reads/ -o data/fastqc/ -l data/logs/fastqc.log`

4. **Quality Control 2**: The quality of the trimmed reads summarised with MultiQC using the script `src/04_multiqc.sh`.
  - Command run: `src/04_multiqc.sh -o data/multiqc/ -l data/logs/multiqc.log -i data/fastqc/ -t fastqc_summary`

5. **Host Removal**: The trimmed reads were decontaminated with bowtie2 using the script `src/05_bowtie2.sh`
  - Command run: `src/05_bowtie2.sh -i data/trimmed_reads/ -o data/bowtie2/ \\`
                  `-x /home/databases/genomes/Homo_sapiens/GRCh38/bowtie2index/hg38 \\`
                  `-m false -l data/logs/bowtie2.log -t 10`

6. **Abundance and Taxonomy**: The trimmed reads were assembled and aligned with DADA2 using the script `src/06_dada2.R`
  - Command run: The R script was run interactively.

7. **Cleaning**: The Operational taxonomic units (OTUs) filtered using the script `src/07_clean_phyloseq.R`
  - Command run: The R script was run interactively.

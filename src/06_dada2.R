library('tidyverse')
library('dada2')
library('here')
library('phyloseq'); packageVersion("phyloseq")
library('Biostrings'); packageVersion("Biostrings")
#library('ggplot2'); packageVersion("ggplot2")
#theme_set(theme_bw())

# Set path to input trimmed files
path <- here("data/bowtie2/")

# Get filenames of forward and reverse reads
fnFs <- sort(list.files(path, pattern="_1.fastq.gz", full.names = TRUE))
fnRs <- gsub('_1', '_2', fnFs)

# Extract sample names, assuming filenames have format: SAMPLENAME_XXX.fastq
sample.names <- sapply(strsplit(basename(fnFs), "_"), `[`, 1)

# Output for filtering
filtFs <- file.path(here(paste0("data/dada2/", sample.names, "_1_filt.fastq.gz")))
filtRs <- file.path(here(paste0("data/dada2/", sample.names, "_2_filt.fastq.gz")))

#names(filtFs) <- sample.names
#names(filtRs) <- sample.names

#fnFs <- fnFs[1:2]
#fnRs <-  fnRs[1:2]
#filtFs <- filtFs[1:2]
#filtRs <- filtRs[1:2]

#print(fnFs)
#print(fnRs)
#print(filtFs)
#print(filtRs)


# Create empty files beforehand
create_empty_files <- function(file_list) {
  for (file in file_list) {
    file.create(file)
    #cat(sprintf("Empty file created: %s\n", file))
  }
}

create_empty_files(filtFs)
create_empty_files(filtRs)


### Filtering ambiguous N
fastqPairedFilter_loop <- function(Freads, Rreads, Freads_filt,Rreads_filt){
  for (i in 1:length(Freads)){
    start_time <- Sys.time()
    
    print(paste0(i, '/', length(Freads)))
    out <- fastqPairedFilter(fn=c(fnFs[[i]], fnRs[[i]]), 
                         fout=c(filtFs[[i]], filtRs[[i]]),
                         maxN=0, maxEE=c(2,2), truncQ=2, rm.phix=TRUE,
                         compress=TRUE, multithread=TRUE)
    
    print(out)
    end_time <- Sys.time()
    diff_time = end_time - start_time
    print(paste('time:', round(diff_time,2)))
  }
}

print("Filtering ambiguous 'N' from reads")
fastqPairedFilter_loop(fnFs, fnRs, filtFs, filtRs)


### Learn errors
print("Learning errors forward reads")
errF <- learnErrors(filtFs, multithread=TRUE, verbose = TRUE)

print("Learning errors reverse reads")
errR <- learnErrors(filtFs, multithread=TRUE, verbose = TRUE)


### Sample inference
print("Sampling inference")
dadaFs <- dada(filtFs, err=errF, multithread=TRUE)
dadaRs <- dada(filtRs, err=errR, multithread=TRUE)

### Merge paired reads
mergers <- mergePairs(dadaFs, filtFs, dadaRs, filtRs, verbose=TRUE)
# Inspect the merger data.frame from the first sample
#mergers

### Construct sequence table
print("Merging pair end reads")
seqtab <- makeSequenceTable(mergers)

### Inspect distribution of sequence lengths
#table(nchar(getSequences(seqtab)))

### Remove chimeras
print("Checking chimeras")
seqtab.nochim <- removeBimeraDenovo(seqtab, method="consensus", multithread=TRUE, verbose=TRUE)
#dim(seqtab.nochim)
paste0(round((1 - sum(seqtab.nochim)/sum(seqtab)) * 100,
            5),
      '% removed due to chimera')


### Track reads through the pipeline
print('Assigning taxonomy against silva_nr99_v138.1_train_set.fa.gz')

baseSRAs_seqtab <- gsub("_1_filt.fastq.gz", "", rownames(seqtab.nochim))
rownames(seqtab.nochim) <- baseSRAs_seqtab

taxa <- assignTaxonomy(seqtab.nochim, 
                       here("/home/databases/SILVA2/silva_nr99_v138.1_train_set.fa.gz"),
                       multithread=TRUE)

taxa <- addSpecies(taxa,
                   here("/home/databases/SILVA2/silva_species_assignment_v138.1.fa.gz"))


### Off to phyloseq
### Setup physeq data
meta <- read_csv(here("data/metadata.txt"))
meta <- meta |> filter(Run %in% baseSRAs_seqtab)

# Create sample_data object and set row/ sample_names
META = sample_data(meta)
rownames(META) <-meta$Run

# Create otu_table object
OTU <- otu_table(seqtab.nochim, taxa_are_rows = FALSE)

# Create tax_table object
TAXA <- tax_table(taxa)

sample_names(META) %in% sample_names(OTU)

ps <- phyloseq(OTU,
               TAXA,
               META)

ps <- prune_samples(sample_names(ps) != "Mock", ps) # Remove mock sample


### Renaming to ASV
dna <- Biostrings::DNAStringSet(taxa_names(ps))
names(dna) <- taxa_names(ps)
ps <- merge_phyloseq(ps, dna)
taxa_names(ps) <- paste0("ASV", seq(ntaxa(ps)))


# Saving phyloseq object
saveRDS(ps, here("data/dada2/dada2.phyloseq.rds"))
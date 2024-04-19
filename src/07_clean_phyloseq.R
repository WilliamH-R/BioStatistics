# Packages
library("phyloseq")
library("dplyr")
library("tidyr")
library("tibble")



# Load data object and select needed objects
physeq_tbl <- readRDS("data/dada2/dada2.phyloseq.rds") |>
  psmelt() |> 
  select(Sample, Abundance, Kingdom, Phylum,
         Class, Order, Family, Genus, Species)

# Amalgamate to genus level, too many unknown species
physeq_tbl_amal <- physeq_tbl |>
  group_by(Sample,
           Genus) |> 
  summarize(Abundance = sum(Abundance))

# Drop Genus present in less than 10% of samples
physeq_tbl_amal_filt <- physeq_tbl_amal |> 
  group_by(Genus) |> 
  add_count(name = "Count") |>
  mutate(Count_non_zero = sum(Abundance != 0),
         Frac_non_zero = Count_non_zero / Count) |>
  ungroup() |> 
  filter(Frac_non_zero > 0.1) |>
  select(Sample, Genus, Abundance)

# Pivot wider which creates count matrix
count_matrix <- physeq_tbl_amal_filt |> 
  pivot_wider(names_from = Genus,
              values_from = Abundance,
              values_fill = 0)

# clr transformation
count_matrix <- count_matrix |>
  tibble::column_to_rownames(var = "Sample") |>
  compositions::clr() |>
  tibble::as_tibble(rownames = "Sample")

# Create a small subset used for testing
count_matrix_test <- count_matrix |> 
  slice_head(n = 10) |> 
  select(Sample, Actinomyces,
         Adlercreutzia, Agathobacter, Akkermansia)

# Save data
saveRDS(object = count_matrix,
        file = "data/count_matrix/count_matrix.rds")
saveRDS(object = count_matrix_test,
        file = "data/count_matrix/count_matrix_test.rds")

# OTU, Sample, Abundance, chem_administration, ETHNICITY, geo_loc_name,
# Host_age, host_body_mass_index, Host_disease, host_phenotype, host_sex,
# Kingdom, Phylum, Class, Order, Family, Genus, Species
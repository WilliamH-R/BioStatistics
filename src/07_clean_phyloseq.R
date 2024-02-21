# Packages
library("magrittr")
library("phyloseq")
library("dplyr")
library("tidyr")



# Load data object and select needed objects
physeq_tbl <- readRDS("data/dada2/dada2.phyloseq.rds") %>%
  psmelt() %>% 
  select(Sample, Abundance, Kingdom, Phylum,
         Class, Order, Family, Genus, Species)

# Amalgamate to genus level, too many unknown species
physeq_tbl_amal <- physeq_tbl %>%
  group_by(Sample,
           Genus) %>% 
  summarize(Abundance = sum(Abundance))

# Pivot wider which creates count matrix
physeq_tbl_amal %>% 
  pivot_wider(names_from = Genus,
              values_from = Abundance,
              values_fill = 0)




# OTU, Sample, Abundance, chem_administration, ETHNICITY, geo_loc_name,
# Host_age, host_body_mass_index, Host_disease, host_phenotype, host_sex,
# Kingdom, Phylum, Class, Order, Family, Genus, Species
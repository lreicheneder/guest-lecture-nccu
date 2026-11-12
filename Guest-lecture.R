## The consequences of armed conflict for foreign aid ##
## Guest lecture, November 13, 2026 
## IMPIS, National Chengchi University
## Leonie Reicheneder (leonie.reicheneder@gu.se) ## 

install.packages("tidyverse")
library(tidyverse)

# 0. Introduction and data ----

# This R script provides the data and code for the guest lecture on
# foreign aid allocation in postconflict settings.
#
# The final dataset used for the analysis is called "df_final_pc".
# It contains ODA disbursements from individual donor countries
# to individual recipient countries between 2002 and 2024, including
# information on recipient conflict status, donor involvement in preceding
# conflicts, and relevant control variables.
#
# There are two ways to obtain this dataset:
#
# OPTION 1: Download the ready-made dataset from GitHub.
# This allows you to skip the data preparation and proceed directly to
# the descriptive statistics and regression analysis (Step 4 onwards).
#
# OPTION 2: Reproduce the data preparation yourself.
# Follow Steps 1-3 of this script to construct "df_final_pc".
# For this, you will need three additional datasets, which can be
# downloaded from the GitHub repository:
# - warstatus_rec.RData
# - gdp_pop_rec.RData
# - donor_confl_involve.RData
#
# All datasets are available at: https://github.com/lreicheneder/guest-lecture-nccu

## 0.1. Set working directory and download datasets from GitHub ----

# Create a local folder for data in your current working directory
# OBS: remember to set working directory with setwd("filepath") or under "Session"

dir.create("Guestlecture_Data", showWarnings = FALSE)

## 0.2.OPTION 1: Download ready-made analytical dataset ----

download.file(
  url = "https://raw.githubusercontent.com/lreicheneder/guest-lecture-nccu/main/Data/df_final_pc.RData",
  destfile = "Guestlecture_Data/df_final_pc.RData",
  mode = "wb"
)

load("Guestlecture_Data/df_final_pc.RData")

# 1. Prepare OECD CRS data ----
## 1.1. Options for retrieving OECD data ----
### 1.1.1. OPTION A: Download OECD aid data through the API ----
#
# See explanation of how to use API and R: https://www.oecd.org/en/data/insights/data-explainers/2024/09/api.html

# a. Open https://data-explorer.oecd.org/
# b. Select a dataset (e.g., Development > Official Development Assistance > CRS: Creditor Reporting System (flows).
# c. Apply filters for donors, recipients, years, etc.
# d. Click the "Developer API" icon above the data table.
# e. Copy the API URL for the selected data.

url <- "paste-your-url-here"

# download the data into R
oecd_dataset <- read.csv(url)

# inspect the data
summary(oecd_dataset)

### 1.1.2. OPTION B: Download aid data using the oecdoda package ----

install.packages("oecdoda")
library(oecdoda)

# Example: German and Swedish ODA to Indonesia between 2010 and 2023
# all sectors and channels, disbursements, constant prices
oda_dataset <- oda_get_crs(
  start_year = 2010,
  end_year = 2023,
  filters = list(
    donor = c("DEU", "SWE"),
    recipient = "IDN",
    flow_type = "D", # disbursements ("C" for commitments)
    measure = 100, # Official development assistance ()
    price_base = "Q" # constant prices
  )
)

# inspect the data
summary(oda_dataset)

## 1.2. Download full OECD CRS dataset ----
# Problem: The full OECD CRS dataset, covering all available years, donors, 
# recipients, sectors, and channels, is too large to retrieve through the API.
#
# Instead, we download the CRS dataset in Parquet format and save it to the working directory. 
#
# Parquet is a file format designed for efficient storage and processing of 
# large datasets. Unlike CSV files, which store data row by row, 
# Parquet stores data column by column.
# It also uses efficient compression, reducing file size.
#
# The OECD provides two Parquet versions:
# - Full Parquet: Contains classification codes and descriptive labels.
# - Reduced Parquet: Contains classification codes but omits
#   the corresponding descriptive labels. 
#
# Both versions contain the full CRS dataset across all available years.

# Dataset information:
# OECD CRS (flows)
# Version: v20261006
# Format: Reduced Parquet
# Source: OECD Data Explorer (https://data-explorer.oecd.org/)
# Accessed: 2026-11-06
# Path to file: OECD Data Explorer > Development > ODA > CRS > Related files

install.packages("arrow")
library(arrow)

crs_full <- arrow::open_dataset(file.choose())
# this will open a window from which you can select the Parquet file. 
#OBS: this is not yet loaded into R memory; it is stored as an Arrow dataset

# List variable names
crs_full$schema$names

# Inspect first 100 obs to get overview of the dataset
crs_sample <- crs_full %>%
  head(100) %>%
  collect()

# select relevant variables
crs_oda <- crs_full |> 
  filter(category == 10, # restrict to ODA only
         year > 2001,    # CRS reliable for disbursements only after 2001
         year <= 2024) |>  # reporting for 2025 not yet concluded
  select(de_donorcode, 
         donor_name, 
         de_recipientcode, 
         recipient_name, 
         year, 
         usd_disbursement_defl, # deflated, base year 2024, cf. https://www.oecd.org/en/data/insights/data-explainers/2024/10/resources-for-reporting-development-finance-statistics.html
         purpose_code, 
         bi_multi, # type of cooperation (e.g. bilateral, triangular, etc.)
         channel_code, # delivery channel (e.g. NGO, recipient government)
         finance_t, # type of financing instrument (e.g. loan, grant, etc.)
         crs_id) |> 
  collect() # loading into R memory

# check disbursements = 0
crs_oda_null <- crs_oda |>
  filter(
    usd_disbursement_defl == 0,
  )

# Explanations: OECD donors register existing aid activities and revisions with 
# CRS, even if no new disbursements are made that year.
# Since my interest is in actual allocation, not reporting, these can be removed.

crs_oda_base <- crs_oda |> 
  filter(usd_disbursement_defl > 0)

## 1.3. Clean OECD CRS ----
### 1.3.1. Check donor and recipient codes ----
# Unique donor-year combinations
crs_donor_year <- crs_oda_base |>
  distinct(
    de_donorcode,
    donor_name,
    year
  ) |>
  arrange(de_donorcode, year)

# Recode Czech Republic from CZE to CZR (official ISO3c code)

# Unique recipient-year combinations
crs_recipient_year <- crs_oda_base |>
  distinct(
    de_recipientcode,
    recipient_name,
    year
  ) |>
  arrange(de_recipientcode, year)

# Montenegro and Serbia appear appear as separate states for all years but
# they were officially "Serbia and Montenegro" until 2006. To simplify merging
# later on, recode country codes to "SCG" (code for Serbia and Montenegro) but 
# keep everything else intact for option to differentiate. 
# Recode Kosovo from XKV to XKX.

crs_oda_base_harmonized <- crs_oda_base |>
  mutate(
    # recode Czech Republic
    de_donorcode = case_when(
      de_donorcode == "CZE" ~ "CZR", 
      TRUE ~ de_donorcode
    ), 
    # Preserve original OECD recipient code
    recipientcode_original = de_recipientcode,
    
    # Harmonize recipient codes
    de_recipientcode = case_when(
      de_recipientcode == "XKV" ~ "XKX",
      year >= 2002 & year <= 2005 &
        de_recipientcode %in% c("SRB", "MNE") ~ "SCG",
      TRUE ~ de_recipientcode
    )
  )

# check that this worked
crs_oda_base_harmonized |>
  filter(
    recipient_name %in% c("Serbia", "Montenegro", "Kosovo") |
      de_recipientcode %in% c("SCG", "XKX")
  ) |>
  distinct(
    recipient_name,
    recipientcode_original,
    de_recipientcode,
    year
  ) |>
  arrange(year, recipient_name)

# 2. Donor-recipient-year dataset ----
# Goal: One row per donor-recipient-year combination

## 2.1. Restrict to bilateral aid flows between countries ----
# ODA donors include both individual countries (e.g. the USA and Germany)
# and multilateral agencies (e.g. the UN and EU). Similarly, recipients can
# be individual countries (e.g. Indonesia and the Philippines) or entire
# regions (e.g. Latin America). To examine the relationship between a donor's
# involvement in a conflict and its subsequent aid allocation to postconflict
# countries, we restrict the sample to bilateral aid flows between individual
# donor and recipient countries.

oda_bilateral <- crs_oda_base_harmonized |>
  rename(recipient_iso3c = de_recipientcode, # rename to make future interpretations easier
         donor_iso3c = de_donorcode) |> 
  filter(
    # include only donors with numeric ISO codes (= bilateral donors)
    grepl("^[A-Za-z]", donor_iso3c), 
    # exclude recipients with "_X" in their code (=regional recipients)
    !grepl("_X", recipient_iso3c))

## 2.2. Aggregate total aid disbursements ----
# Create one row per donor-recipient-year combination ("dyad-year"). A dyad is a 
# combination of two actors, in this case between a donor and a recipient. 

aid_dy <- oda_bilateral |>
  group_by( #creates one row per donor-recipient-year
    donor_iso3c,
    recipient_iso3c,
    year
  ) |>
  summarise(
    # Creates aid disbursements: sum up values for each donor-recipient-year
    total_disbursement = sum(usd_disbursement_defl, na.rm = TRUE),
    .groups = "drop"
  )

# 3. Create dataset for regression analysis ----
## 3.1. Explaining merging ----
# To do a regression, we need all variables (DVs, IVs, controls) in one dataset. 
# The donor-recipient-year dataset (aid_dy) already includes our dependent 
# variable (total aid disbursements). We now need to also add all other relevant 
# variables. 

# You can add variables from one dataset to another through a process called
# "merging". This means taking variables from an additional dataset and adding
# them to your original dataset.
#
# To merge two datasets, you need to identify the variables that the datasets
# have in common (= merge keys). These variables determine which observations
# in the two datasets correspond to each other. The information from the
# additional dataset is then added to the corresponding observations in your
# original dataset.

## 3.2. Merge recipient-level information ----
# First, we merge all recipient-level information into the dataset. In our case,
# this is the recipient's "war status" (whether a recipient country is in active 
# war or a post-civil war phase), the recipient's population and its GDP per 
# capita. 

### 3.2.1. Recipient war status ----
#
# Steps: 
#### (a) Download the relevant dataset from github ----
# It  is named "warstatus_rec.RData". 
# This dataset is based on version 26.1 of the UCDP/PRIO Armed Conflict Dataset 
# which includes all country-years in active war between 1946 and 2025. 

download.file(
  url = "https://raw.githubusercontent.com/lreicheneder/guest-lecture-nccu/main/Data/warstatus_rec.RData",
  destfile = "Guestlecture_Data/warstatus_rec.RData",
  mode = "wb"
)

# Load dataset
load("Guestlecture_Data/warstatus_rec.RData")

#### (b) Identify which variables the datasets have in common (merge keys) ----
# The easiest way to identify these is to have a look at both datasets. 
# The merge keys are the recipient's ISO3c code (variable: recipient_iso3c) and
# year (variable: year). 

#### (c) Carry out the merge ----
aid_dy_war <- aid_dy |> # new object for merged dataset -> your main dataset
  left_join(            # command for merging
    warstatus_rec, # dataset you want to merge into the original one
    by = c("recipient_iso3c", "year"),  # merge keys; if only one, just write by = year
    relationship = "many-to-one" 
  )

# The argument "relationship" specifies how observations in the two datasets
# are expected to correspond to each other based on the merge keys.
#
# - "one-to-one": Each observation in the first dataset matches exactly one
#   observation in the second dataset, and vice versa.
#
# - "many-to-one": Multiple observations in the first dataset can match the
#   same observation in the second dataset. For example, several donors can
#   provide aid to the same recipient in a given year, so multiple observations
#   in the aid dataset match one recipient-year observation in the conflict
#   dataset.
#
# Specifying the expected relationship helps detect unintended duplicates.
# R returns an error if the data do not satisfy the specified relationship.

# After merging, you will find all variables that the datasets do NOT have 
# in common added to the end of your dataset. The new dataset called "aid_dy_war"
# now oincludes all variables from the original dataset, plus two new variables
# at the end (post_civilwar10 and war). 

#### (d) Inspect NAs ----
# After merging two datasets, it is important to check for missing values (NAs).
#
# NAs often occur when an observation in the original dataset has no matching
# observation in the dataset being merged. For example, a recipient country
# may appear in the OECD aid data but not in the UCDP data for a
# particular year. This can happen because data are unavailable, country codes
# differ, or the two datasets cover different samples or periods.
#
# An NA therefore can, but does not necessarily have to indicate an error 
# with merging  However, it is important to inspect missing values to 
# understand why the observations could not be matched and whether any 
# corrections are necessary.

# Check missing values after the merge

aid_dy_war |>
  summarise(
    across(
      c(post_civilwar10, war),
      ~ sum(is.na(.x))
    )
  ) # This shows a substantial amount of NAs in both merged variables

# In this case, NAs after the merge are not errors. The dataset
# "warstatus_rec" is based on the UCDP/PRIO Armed Conflict Dataset and
# only includes country-years with a relevant conflict history. This means
# that it includes countries that either experienced active war between
# 2002 and 2024 or were in a post-civil-war period (within ten years
# after the end of a civil war).
#
# Countries without such a conflict history are therefore not included
# in "warstatus_rec".
#
# In contrast, the OECD aid dataset includes all donor-recipient
# combinations, regardless of the recipient's conflict history. As a result,
# some observations in the OECD dataset have no corresponding match in
# "warstatus_rec". 

# IN THIS CASE, NAs in the newly merged variables "post_civilwar10" and "war" 
# indicate that the recipient has no recorded conflict history and should 
# therefore be coded as 0.

aid_dy_war_nonas <- aid_dy_war |>
  mutate(
    across(
      c(post_civilwar10, war),
      ~ replace_na(.x, 0)
    )
  )

### 3.2.2. Recipient GDP per capita and population ----
#### (a) The dataset is called "gdp_pop_rec.RData" ----
# It is taken from the World Development Indicators (WDI) dataset from the World
# Bank. 

download.file(
  url = "https://raw.githubusercontent.com/lreicheneder/guest-lecture-nccu/main/Data/gdp_pop_rec.RData",
  destfile = "Guestlecture_Data/gdp_pop_rec.RData",
  mode = "wb"
)

# Load dataset
load("Guestlecture_Data/gdp_pop_rec.RData")

#### (b) Merge keys: recipient_iso3c, year ----

#### (c) Merge ----

aid_dy_rec <- aid_dy_war_nonas |> 
  left_join(
    gdp_pop_rec, 
    by = c("recipient_iso3c", "year"), 
    relationship = "many-to-one"
  )

#### (d) Check NAs ----
aid_dy_rec |>
  summarise(
    across(
      c(log_gdp_rec, log_pop_rec),
      ~ sum(is.na(.x))
    )
  ) 

# Again, we have NAs in the merged variables. This time, they result from NAs
# already in the original World Bank dataset which does not have data for every 
# single country year. Therefore, we do not recode NAs. These reflect genuine 
# missing information about a country's GDP per capita and population in a given 
# year. 

## 3.3. Merge donor-level information ----
# Now, we merge all donor-level information into the dataset. In our case, 
# this is the donor's involvement in a prior conflict and its total disbursed aid
# in a given year. 

### 3.3.1. Donor involvement in prior conflict (IV)----
#### (a) The relevant dataset is called "donor_confl_involve.RData" ----

# Download donor involvement data from GitHub

download.file(
  url = "https://raw.githubusercontent.com/lreicheneder/guest-lecture-nccu/main/Data/donor_confl_involve.RData",
  destfile = "Guestlecture_Data/donor_confl_involve.RData",
  mode = "wb"
)

# Load dataset
load("Guestlecture_Data/donor_confl_involve.RData")

#### (b) The merge keys are donor_iso3c, recipient_iso3c, and year. ----

#### (c) Merge ----

aid_dy_rec_don <- aid_dy_rec |> 
  left_join(
    donor_confl_involve, 
    by = c("donor_iso3c", "recipient_iso3c", "year")
  )

#### (d) Take care of NAs ----
aid_dy_rec_don_nonas <- aid_dy_rec_don |>
  mutate(
    across(
      c(donor_conflict_involved, years_involved_max),
      ~ replace_na(.x, 0)
    )
  )

#### 3.3.2. Total yearly aid disbursements by donor ----

# Calculate total annual aid disbursements per donor

donor_aid_total <- aid_dy |>
  group_by(donor_iso3c, year) |>
  summarise(
    donor_total_aid = sum(total_disbursement, na.rm = TRUE),
    .groups = "drop"
  )

# Merge total donor aid into main dataset

df_final <- aid_dy_rec_don_nonas |>
  left_join(
    donor_aid_total,
    by = c("donor_iso3c", "year"),
    relationship = "many-to-one"
  )

## 3.4. Create final dataset for analysis ----
# We restrict the dataset to all observations in which the recipient is in a post-
# conflict phase, as our sample are aid flows to postconflict recipient countries
# between 2002 and 2024. 

df_final_pc <- df_final |> 
  filter(post_civilwar10==1) # restrict to postconflict recipients only

# This is now our final dataset for analysis. It contains all ODA flows to 
# postconflict recipients between 2002 and 2024. 

save(df_final_pc, file = "df_final_pc.RData")

# 4. Descriptives ----
## 4.1. Overview of the sample ----

sample_overview <- df_final_pc |>
  summarise(
    observations = n(),
    donors = n_distinct(donor_iso3c),
    recipients = n_distinct(recipient_iso3c),
    dyads = n_distinct(donor_iso3c, recipient_iso3c),
    total_aid = sum(total_disbursement, na.rm = TRUE)
  )

sample_overview

## 4.2. Descriptives of the relevant variables ----
install.packages("stargazer")
library(stargazer)

# select only the explanatory variables (DV, IV and controls)
df <- df_final_pc |> 
  select(total_disbursement, 
         war, 
         gdp_rec, 
         pop_rec, 
         donor_conflict_involved, 
         donor_total_aid) |> 
  ungroup() |> 
  as.data.frame()

# create descriptives statistics
stargazer(df, 
          type = "html", # document type, can also be latex, etc. 
          digits = 2,
          title = "Descriptive Statistics",
          label = "tab:desc",
          out = "descriptives.html") # file name

## 4.3. Histogram of the dependent variable ----

install.packages("ggplot")
library(ggplot2)
install.packages("scales")
library(scales)

totaid_histo <- ggplot(df_final_pc, aes(x = total_disbursement)) +
  geom_histogram(
    bins = 50,
    fill = "steelblue",
    color = "white"
  ) +
  scale_x_log10( #using a logarithmic axis to better display the huge values
    labels = scales::label_number(big.mark = ",")
  ) +
  labs(
    title = "Distribution of aid disbursements",
    subtitle = "Logarithmic x-axis",
    x = "Total aid disbursements (million 2024 USD, log scale)",
    y = "Number of donor-recipient-year observations"
  ) +
  theme_minimal(base_size = 13)

ggsave(
  filename = "totaid_histo.jpg",
  plot = totaid_histo,
  width = 10,
  height = 6,
  dpi = 300
)

## 4.4. Bar chart of the independent variable ----

donorinvolve_bar <- ggplot(
  df_final_pc,
  aes(x = factor(donor_conflict_involved))
) +
  geom_bar(fill = "steelblue") +
  geom_text(
    stat = "count",
    aes(
      label = paste0(
        round(after_stat(count / sum(count) * 100), 1),
        "%"
      )
    ),
    vjust = -0.5,
    size = 4
  ) +
  scale_x_discrete(
    labels = c(
      "0" = "No involvement",
      "1" = "Donor involved"
    )
  ) +
  scale_y_continuous(
    expand = expansion(mult = c(0, 0.12))
  ) +
  labs(
    title = "Donor involvement in preceding conflicts",
    x = "Donor involvement",
    y = "Number of donor-recipient-year observations"
  ) +
  theme_minimal(base_size = 13)

ggsave(
  filename = "donorinvolve_bar.jpg",
  plot = donorinvolve_bar,
  width = 10,
  height = 6,
  dpi = 300
)

## 4.5. Dependent variable against independent variable ----
# aka a box plot of aid disbursement by donor involvement in preceding conflict

aid_involved <- ggplot(
  df_final_pc,
  aes(
    x = factor(donor_conflict_involved),
    y = total_disbursement
  )
) +
  geom_boxplot(
    fill = "steelblue",
    alpha = 0.8
  ) +
  scale_y_log10(
    labels = scales::label_number(big.mark = ",")
  ) +
  scale_x_discrete(
    labels = c(
      "0" = "No involvement",
      "1" = "Donor involved"
    )
  ) +
  labs(
    title = "Aid disbursements by donor involvement",
    x = "Donor involvement in preceding conflict",
    y = "Total aid disbursements (million 2024 USD, log scale)"
  ) +
  theme_minimal(base_size = 13)

ggsave(
  filename = "aid_involved.jpg",
  plot = aid_involved,
  width = 10,
  height = 6,
  dpi = 300
)

# 5. Regression ----
## 5.1. Prepare regression sample by logging total donor disbursements ----

df_reg <- df_final_pc |>
  mutate(
    log_donor_total_aid = log(donor_total_aid)
  )

## 6.2. Model 1: Bivariate regression ----

m1 <- lm(
  total_disbursement ~ donor_conflict_involved,
  data = df_reg
)

summary(m1)

## 6.2. Model 2: Multivariate regression ----
m2 <- lm(
    total_disbursement ~  
      donor_conflict_involved +
      log_gdp_rec +
      log_pop_rec +
      war +
      donor_total_aid,
    data = df_reg
  )

summary(m2)

## 6.3. Model 3: Multivariate regression with year-fixed effects ----
m3 <- lm(
  total_disbursement ~  
    donor_conflict_involved +
    log_gdp_rec +
    log_pop_rec +
    war +
    donor_total_aid + 
    factor(year) + 
    factor(donor_iso3c),
  data = df_reg
)

summary(m3)

## 6.4. Model summary output ----
install.packages("modelsummary")
library(modelsummary)
install.packages("flextable")
library(flextable)
install.packages("officer")
library(officer)

mainmodels <- list("1" = m1, "2" = m2, m3)

results <- modelsummary(
  mainmodels,
  stars = TRUE,
  intercept = TRUE, 
  coef_omit = "factor\\(year\\)|factor\\(donor_iso3c\\)", # omit fixed effects from table
  output = "flextable"
) |>
  autofit()

save_as_docx("Results" = results, path = "Results.docx")

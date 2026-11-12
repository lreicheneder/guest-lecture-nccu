# Guest lecture on foreign aid allocation in postconflict settings
This repository contains the R code and datasets for the guest lecture on foreign aid allocation in postconflict settings within the MA Program IMPIS at NCCU

The exercise examines whether donors that participated in a preceding conflict provide higher aid volumes to recipients in the postconflict period.

## 1. Getting started

There are two ways to follow the exercise:

### Option 1: Use the ready-made dataset

The dataset `df_final_pc.RData` contains bilateral Official Development Assistance (ODA) disbursements from individual donor countries to individual recipient countries between **2002 and 2024**, restricted to recipients in a postconflict setting.

It includes:
- Total aid disbursements at the donor-recipient-year level.
- Recipient conflict status.
- Donor involvement in the preceding conflict.
- Recipient GDP per capita and population.
- Total annual aid disbursements by donor.

To use this option:

1. Download the R script from the `R` folder.
2. Open it in RStudio.
3. Set your working directory to the folder where you saved the R script.
4. Run the introductory code to create the local `Guestlecture_Data` folder.
5. Follow **Option 1** in the R script to download and load `df_final_pc.RData` directly from GitHub.

You can then skip the data preparation in Steps 1–3 and proceed directly to the descriptive statistics and regression analysis.

### Option 2: Construct the dataset yourself

Alternatively, you can reproduce the data preparation by following Steps 1–3 of the R script.

For this, you will need the following datasets, which are downloaded directly from this repository:

- `warstatus_rec.RData`: Recipient conflict status, based on the UCDP/PRIO Armed Conflict Dataset.
- `gdp_pop_rec.RData`: Recipient GDP per capita and population, based on the World Bank's World Development Indicators.
- `donor_confl_involve.RData`: Donor involvement in the conflicts preceding recipients' postconflict periods, based on UCDP/PRIO data.

The R script contains the download instructions and explains how these datasets are merged with the OECD aid data.

Once you have completed Steps 1–3, you will have constructed the analytical dataset `df_final_pc` yourself.

## 2. Repository structure

The repository contains the following files:

**Data/**
- `df_final_pc.RData` – Ready-made analytical dataset.
- `warstatus_rec.RData` – Recipient conflict status.
- `gdp_pop_rec.RData` – Recipient GDP and population.
- `donor_confl_involve.RData` – Donor involvement in preceding conflicts.

**R/**
- `guest_lecture.R` – R script containing the data preparation, descriptive statistics and regression analysis.

## 3. Data sources

The datasets draw on the following sources:

- **OECD Creditor Reporting System (CRS):** Bilateral ODA disbursement data.
- **UCDP/PRIO Armed Conflict Dataset, version 26.1:** Information on armed conflicts and conflict participation.
- **World Bank World Development Indicators (WDI):** GDP per capita and population data.

The R script provides further information on dataset versions, definitions and data preparation.

## 4. Requirements

To follow the exercise, you need:

- R installed on your computer.
- RStudio (strongly recommended).

## 5. Repository link

All files are available here:

https://github.com/lreicheneder/guest-lecture-nccu

Enjoy the exercise!

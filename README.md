# DataRush - Group A
# Urban Transport Data Analysis

## Group Members

- Christoph van Jaarsveld — 50143956
- Luan du Plessis — 46251960
- Pieta Hattingh — 49019767
- Sune Muller — 45926808
- Zoe du Plessis — 46036482

## Project Description

This project uses MySQL to analyse urban transport data from Uber and Bolt in South Africa. It focuses on rider spending patterns, trip distances, tipping behaviour, payment methods, cancellations, and surge pricing.

## How to Run

Run the SQL scripts in **MySQL Workbench** in the following order:

1. `urban_transport_script.sql` — Creates the database and tables.
2. `LoadScript.sql` — Loads the data into the tables.
3. `queries_urban_transport.sql` — Runs the analysis queries.

**Important:** Before running `LoadScript.sql`, replace the existing file paths with the paths to your own CSV files. Use forward slashes (`/`) in the file paths.

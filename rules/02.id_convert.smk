#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import pandas as pd
from loguru import logger
from rich import inspect,print
# Load the samples CSV file into a DataFrame
samples_df = pd.read_csv(config["sample_csv"])
logger.info(f"Loaded samples from {config["sample_csv"]}")
# Convert the DataFrame to a dictionary for easy access
samples = samples_df.set_index("sample").to_dict(orient="index")
if config['print_sample']:
    print(samples)
logger.info(f"Analyzed {len(samples)} short-read samples from the CSV file.")
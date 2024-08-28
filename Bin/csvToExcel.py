"""
    Convert a csv file to xlsx format
"""
import os
import sys

import pandas as pd

# -------------------------------------
# check number of arguments
# ------------------------------------
if len(sys.argv) < 2:
    print("""\
This script read a csv file and save it in a Excel format.

Usage: theScript <csv file name> <Excel file name>
""")
    sys.exit(1)

FILE_VALID = True
df = None
file_to_read = os.path.normpath(sys.argv[1])

try:
    df = pd.read_csv(file_to_read)
except pd.errors.EmptyDataError:
    print('Empty csv file: ' + file_to_read)
    FILE_VALID = False
except pd.errors.ParserError:
    print('Error on parsing: ' + file_to_read)
    FILE_VALID = False

if FILE_VALID is False or df is None:
    print('ERROR! Impossible to process input file: ' + file_to_read)
    if FILE_VALID:
        FILE_VALID = False

if FILE_VALID:
    df.to_excel(sys.argv[2], index=False, engine='openpyxl')
else:
    # Create empty file
    with open(sys.argv[2], mode='w', encoding='UTF-8') as file:
        file.write("")

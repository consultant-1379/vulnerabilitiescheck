"""
    Convert a csv file to HTML format
"""
import os
import sys

import pandas as pd

# -------------------------------------
# check number of arguments
# ------------------------------------
if len(sys.argv) < 2:
    print("""\
This script save a csv file in HTML format.

Usage: theScript <csv file name> <html file name>
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
    df.to_html(sys.argv[2], index=False, na_rep='')
else:
    # Create empty file
    with open(sys.argv[2], mode='w', encoding='UTF-8') as file:
        file.write("")

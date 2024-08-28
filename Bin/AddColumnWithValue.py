"""
    Add a column with a fixed value
"""
import os
import sys
import pandas as pd

# -------------------------------------
# check number of arguments
# ------------------------------------
inputArgs = sys.argv
if len(sys.argv) != 4:
    print("""\
This script add, on a csv file, a column with a predefined value

Usage: theScript <file name> <column name> <column value>
""")
    sys.exit(1)

file_name = os.path.normpath(inputArgs[1])
try:
    input_df = pd.read_csv(file_name)
    if input_df is None:
        print('ERROR! Impossible to load input file: ' + file_name)
        sys.exit(0)
    input_df[inputArgs[2]] = inputArgs[3]
    input_df.to_csv(file_name, index=False)
except pd.errors.EmptyDataError:
    print('Empty csv file: ' + file_name)
    sys.exit(0)
except pd.errors.ParserError:
    print('Error on parsing: ' + file_name)
    sys.exit(0)

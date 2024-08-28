"""
    Merge VA report file 
"""
import os
import sys

import pandas as pd


def clean_package_path(package_path):
    """
    Clean package path field
    Args:
        package_path: the package path string
    """
    grype_package_path_header = '[Location<RealPath='
    grype_package_path_footer = '">]"'

    find_grype_package_path_header_position = package_path.find(
        grype_package_path_header)
    if find_grype_package_path_header_position >= 0:
        grype_package_path_header_len = len(grype_package_path_header)
        package_path = package_path[grype_package_path_header_len:]

    find_grype_package_path_footer_position = package_path.find(
        grype_package_path_footer)
    if find_grype_package_path_footer_position >= 0:
        package_path = package_path[:find_grype_package_path_footer_position]

    return package_path


# -------------------------------------
# check number of arguments
# ------------------------------------
if len(sys.argv) < 4:
    print("""\
This script merge at least 2 VA report csv file.

Usage: theScript <file to merge 1> <file to merge 2> ... <file to merge N> \\
<target file>
""")
    sys.exit(1)

target_file = os.path.normpath(sys.argv[len(sys.argv) - 1])
data_frames = []
for item in range(1, len(sys.argv) - 1):
    file_to_merge = os.path.normpath(sys.argv[item])
    VALID_MERGE_FILE = True
    merge_df = []

    try:
        merge_df = pd.read_csv(file_to_merge)
    except pd.errors.EmptyDataError:
        print('Empty csv file: ' + file_to_merge)
        VALID_MERGE_FILE = False
    except pd.errors.ParserError:
        print('Error on parsing:' + file_to_merge)
        VALID_MERGE_FILE = False

    if VALID_MERGE_FILE and merge_df is None:
        print('ERROR! Impossible to load input file: ' + file_to_merge)
        VALID_MERGE_FILE = False

    if VALID_MERGE_FILE:
        if len(data_frames) == 0:
            data_frames = pd.concat([merge_df], ignore_index=True)
        else:
            data_frames = pd.concat([data_frames, merge_df],
                                    ignore_index=True)

if len(data_frames) > 0:
    # Clean values on columns
    for row_index, row in data_frames.iterrows():
        data_frames.at[row_index, 'Severity'] = \
            data_frames.at[row_index, 'Severity'].capitalize()
        data_frames.at[row_index, 'Locations'] = clean_package_path(
            data_frames.at[row_index, 'Locations'])

    # Sort by 'Severity', 'Package Name' and 'VulnerabilityID'
    data_frames.sort_values(by=['Severity', 'Package Name', 'VulnerabilityID'],
                            inplace=True)

    # Fill NaN value with ""
    data_frames.fillna(value='', inplace=True)

    # Save file
    data_frames.to_csv(os.path.normpath(target_file), index=False)
else:
    # Save an empty file
    with open(target_file, mode='w', encoding='UTF-8') as file:
        file.close()

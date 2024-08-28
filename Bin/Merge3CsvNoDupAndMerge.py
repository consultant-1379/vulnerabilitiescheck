"""
    Merge 3 csv file and remove duplicates
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
        grype_package_path_footer)
    if find_grype_package_path_header_position >= 0:
        grype_package_path_header_len = len(grype_package_path_header)
        package_path = package_path[grype_package_path_header_len:]

    find_grype_package_path_footer_position = package_path.find(
        grype_package_path_footer)
    if find_grype_package_path_footer_position >= 0:
        package_path = package_path[:find_grype_package_path_footer_position]

    grype_package_path_header = '[Location<RealPath="'
    grype_package_path_footer = '" Layer="'

    find_grype_package_path_header_position = package_path.find(
        grype_package_path_footer)
    if find_grype_package_path_header_position >= 0:
        grype_package_path_header_len = len(grype_package_path_header)
        package_path = package_path[grype_package_path_header_len:]

    find_grype_package_path_footer_position = package_path.find(
        grype_package_path_footer)
    if find_grype_package_path_footer_position >= 0:
        package_path = package_path[:find_grype_package_path_footer_position]

    return package_path


# check number of arguments
# ------------------------------------
inputArgs = sys.argv
if len(sys.argv) != 5:
    print("""\
This script merge 3 csv files, and for every duplicates row, merge the values.

Usage: theScript <file to merge 1> <file to merge 2> <file to merge 3>\\
 <target file>
""")
    sys.exit(1)

file_1_to_merge = os.path.normpath(inputArgs[1])
file_2_to_merge = os.path.normpath(inputArgs[2])
file_3_to_merge = os.path.normpath(inputArgs[3])

merge_1_df = pd.read_csv(file_1_to_merge)
if merge_1_df is None:
    print("ERROR! Impossible to load file to merge:", inputArgs[1])
    sys.exit(2)

merge_2_df = pd.read_csv(file_2_to_merge)
if merge_2_df is None:
    print("ERROR! Impossible to load file to merge:", inputArgs[2])
    sys.exit(2)

merge_3_df = pd.read_csv(file_3_to_merge)
if merge_3_df is None:
    print("ERROR! Impossible to load file to merge:", inputArgs[3])
    sys.exit(2)

data_frames = [merge_1_df, merge_2_df, merge_3_df]
df_merged = pd.concat(data_frames, ignore_index=True)

# Clean values on columns
for row_index, row in df_merged.iterrows():
    df_merged.at[row_index, 'Severity'] = row['Severity'].capitalize()
    df_merged.at[row_index, 'Locations'] = clean_package_path(row['Locations'])

df_duplicates_to_remove = df_merged[df_merged.duplicated(
    ["Vulnerability ID", 'Package Name', 'Severity', 'Locations'])]
print("--- DUPLICATES TO REMOVE")
print(df_duplicates_to_remove)
print("------------------------")

# Iterate on every entry in df_duplicates_to_remove
for index, row_duplicate in df_duplicates_to_remove.iterrows():
    IS_FOUND_ON_GRYPE = IS_FOUND_ON_XRAY = IS_FOUND_ON_TRIVY = False
    VALUE = ""

    if not df_duplicates_to_remove.at[index, "Found on grype"] or pd.isnull(
            df_duplicates_to_remove.at[index, "Found on grype"]):
        IS_FOUND_ON_GRYPE = True
        VALUE = df_duplicates_to_remove.at[index, "Found on grype"]
    elif df_duplicates_to_remove.at[index, "Found on trivy"] or pd.isnull(
            df_duplicates_to_remove.at[index, "Found on trivy"]):
        IS_FOUND_ON_TRIVY = True
        VALUE = df_duplicates_to_remove.at[index, "Found on trivy"]
    elif df_duplicates_to_remove.at[index, "Found on XRay"] or pd.isnull(
            df_duplicates_to_remove.at[index, "Found on XRay"]):
        IS_FOUND_ON_XRAY = True
        VALUE = df_duplicates_to_remove.at[index, "Found on XRay"]

    found_on_merged = df_merged.loc[
        (df_merged["Vulnerability ID"] == df_duplicates_to_remove.at[
            index, "Vulnerability ID"])
        & (df_merged['Package Name'] == df_duplicates_to_remove.at[
            index, 'Package Name']) &
        (df_merged['Severity'] == df_duplicates_to_remove.at[index,
                                                             'Severity']) &
        (df_merged['Locations'] == df_duplicates_to_remove.at[index,
                                                              'Locations'])]

    if IS_FOUND_ON_GRYPE:
        df_merged.loc[found_on_merged.index, "Found on grype"] = VALUE
    elif IS_FOUND_ON_XRAY:
        df_merged.loc[found_on_merged.index, "Found on XRay"] = VALUE
    elif IS_FOUND_ON_TRIVY:
        df_merged.loc[found_on_merged.index, "Found on trivy"] = VALUE

    # Remove every entry present on df_duplicated from the df_merged dataframe
    df_merged = df_merged.drop([index])

# save the df_merged dataframe
df_merged.to_csv(os.path.normpath(inputArgs[4]), index=False)

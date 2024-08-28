"""
The script return how many vulnerabilities with the specified or higher
severity are present on the source file.
"""
import argparse
import os
import sys
from typing import Optional

import pandas as pd

severity_list = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']  # Ordered by severity


def validate_existing_file(file_name: str) -> str:
    """
    Check that the given file name is an existing file
    Args:
        file_name: the string containing the full name of a file

    Returns:
        the same file name if the file exist, otherwise it raises an exception
    """
    if os.path.exists(file_name):
        return file_name

    raise argparse.ArgumentTypeError(
            f"Enter a valid input file. '{file_name}' not found!")


def validate_severity(severity: str) -> str:
    """
    Check that the given severity is a valid value
    Args:
        severity: the string containing the severity

    Returns:
        the same severity in uppercase if it is a valid name, otherwise it
        raises an exception
    """
    if severity.upper() in severity_list:
        return severity.upper()

    raise argparse.ArgumentTypeError(
            f"Severity '{severity}' not match to one of the following defined "
            f"severity: {get_list_value(severity_list)}.")


def get_list_value(items_list: list, separator: str = ", ") -> str:
    """
    Return a string containing all the list value concatenated by the separator
    Args:
        items_list: list of values
        separator: separator between items

    Returns:
        a string containing all the list value concatenated by the separator
    """
    return separator.join(items_list)


def get_df_from_spreadsheet_file(path: str) -> Optional[pd.DataFrame]:
    """
    Load the content of a .csv/Excel file into a pandas dataframe
    Args:
        path: full path name of the input file

    Returns:
        a pandas dataframe if the input files was correctly read

        'None' if an error occurred on loading file
    """
    df = None
    if os.path.exists(path):
        if not os.stat(path).st_size == 0:
            try:
                if path.endswith('.csv'):
                    df = pd.read_csv(path)
                else:
                    df = pd.read_excel(path)
            except OSError as exc:
                print(f"{exc} on reading file: {path}")
        else:
            df = pd.DataFrame()

    return df


def items_with_higher_or_equal_severity(series: pd.Series,
                                        severity_list_values: list,
                                        severity_level: str) -> int:
    """
    Calculate the sum number of vulnerabilities equal or higher of the severity
    level
    Args:
        series: series of the severity value from datasource
        severity_list_values: list of severity values
        severity_level: the security level to find

    Returns:
        the number of vulnerability equal or higher of the severity level
    """
    pos = severity_list_values.index(severity_level, 0) + 1
    return series.isin(severity_list[:pos]).sum()


def count_higher_or_equal_severity_vulnerability(file_name: str,
                                                 column_name: str,
                                                 severity_level: str) -> int:
    """
    Count the vulnerabilities equal or higher of the security level parameter.
    Args:
        file_name: the file name
        column_name: the column name that contain the severity values
        severity_level: the security level to find

    Returns:
        the number vulnerability higher or equal of the security level
    """
    va_report_df = get_df_from_spreadsheet_file(os.path.normpath(file_name))
    if va_report_df is None:
        print(f"Error on loading input file: {file_name}.")
        sys.exit(1)

    if va_report_df.empty:
        return 0

    if column_name not in va_report_df.columns:
        print(f"Column name '{column_name}' not found on file '{file_name}'!")
        sys.exit(1)

    va_report_df[column_name] = va_report_df[column_name].apply(str.upper)

    return items_with_higher_or_equal_severity(va_report_df[column_name],
                                               severity_list, severity_level)


def main():
    """
    The script return how many vulnerabilities with the specified or higher
    severity are present on the source file.
    """
    if sys.version_info.major < 3 or pd.__version__ < "1.1.5":
        print("""\
    WARNING! Script running with python version minor of 3 or pandas version
    minor of 1.1.5, it is not guaranteed to work properly.
    """)

    parser = argparse.ArgumentParser(
        description="The script return how many vulnerabilities with the "
        "specified or higher severity are present.")
    parser.add_argument('-f',
                        '--file',
                        type=validate_existing_file,
                        required=True,
                        help="the full path of the VA summary report file")
    parser.add_argument('-c',
                        '--column',
                        type=str,
                        required=True,
                        default='',
                        help="the column name containing the severity info")
    parser.add_argument('-s',
                        '--severity',
                        type=validate_severity,
                        required=True,
                        default='',
                        help="the lower value of severity to check. "
                             "Accepted values: "
                             f"{get_list_value(severity_list)}.")

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()

    number_of_vulnerability = count_higher_or_equal_severity_vulnerability(
        args.file, args.column, args.severity.upper())

    print(f"{number_of_vulnerability}")


if __name__ == '__main__':
    main()

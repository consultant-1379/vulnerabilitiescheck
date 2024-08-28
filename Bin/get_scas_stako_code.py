"""
The script get the STAKO level info for the required GAV by the SCAS tool
"""
import argparse
import http.client
import json
import os
import re

import sys
from typing import Optional

import requests
from requests import RequestException

SCAS_URL = 'https://scas.internal.ericsson.com'
SCAS_OIDC_BASE_URL = SCAS_URL + '/auth/realms/SCA/protocol/openid-connect'
SCAS_OIDC_TOKEN_URL = SCAS_OIDC_BASE_URL + '/token'
SCAS_OIDC_USER_INFO_URL = SCAS_OIDC_BASE_URL + '/userinfo'

SCAS_SEARCH_API_URL = SCAS_URL + '/ordering/components/search?size=1'
SCAS_FILTER_ARTIFACT = '&filter=compName,fts,'
SCAS_FILTER_VERSION = '&filter=compVersion,NTXEQ,'

SCAS_ENVIRONMENT_VAR_NAME = "SCAS_OFFLINE_TOKEN"

STAKO_JSON_PARAMETER = "stakoCode"
STAKO_NA = "N/A"

GAV_SEPARATOR = ':'
CSV_SEPARATOR = ','
REGEX_GAV_VALIDATOR = "^([^" + GAV_SEPARATOR + "]*" + GAV_SEPARATOR \
                      + "){2}[^" + GAV_SEPARATOR + "]*$"


def validate_gav(gav_value: str,
                 raise_exception: bool = True) -> Optional[str]:
    """
    Validate the GAV value passed as argument
    Accepted values:
      - group:artifact:version
      - :artifact:version
    Args:
        gav_value: the GAV value
        raise_exception: optional raise an exception if the GAV validation
        fails, otherwise return None

    Returns:
        the GAV value
    """

    # Check artifact and version entry
    artifact_version_result = re.search(REGEX_GAV_VALIDATOR, gav_value.strip())
    if artifact_version_result is not None:
        return gav_value

    if not raise_exception:
        return None

    raise argparse.ArgumentTypeError(
        "GAV not correctly passed.\nAccepted values are:"
        "\n\tgroup:artifact:version"
        "\n\t:artifact:version")


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

    exc_message = f"Enter a valid input file. File: '{file_name}' not found!"
    raise argparse.ArgumentTypeError(exc_message)


def get_scas_offline_token_from_env(env_var_name: str) -> Optional[str]:
    """
    Get the SCAS offline token from the environment variable
    Args:
        env_var_name: name of environment variable to get value
    Returns:
        the SCAS offline token if it's set. None otherwise
    """
    return os.getenv(env_var_name)


def refresh_access_token(check_certificate: bool) -> str:
    """
    Get a new access token using the refresh token value
    Args:
        check_certificate: check the site certificate
    Returns:
        the new access token
    """

    scas_offline_token = \
        get_scas_offline_token_from_env(SCAS_ENVIRONMENT_VAR_NAME)
    if not scas_offline_token:
        print('Token is not set in environment variable '
              f'\'{SCAS_ENVIRONMENT_VAR_NAME}\'.')
        sys.exit(1)

    request_data = {
        'refresh_token': scas_offline_token,
        'client_id': 'scas-ext-client-direct',
        'grant_type': 'refresh_token'
    }
    request_headers = {'Accept': 'application/json'}

    try:
        login_response = requests.post(SCAS_OIDC_TOKEN_URL,
                                       data=request_data,
                                       headers=request_headers,
                                       timeout=30000,
                                       verify=check_certificate)
    except RequestException as exc:
        print(f"Error connecting to '{SCAS_OIDC_TOKEN_URL}': {exc}")
        sys.exit(1)

    if login_response.status_code == http.HTTPStatus.OK:
        return login_response.json()['access_token']

    print(f"Error \'{login_response.json()['error']}\' on retrieving "
          f"access token. {login_response.json()['error_description']}.")
    sys.exit(3)


def check_token_validation(access_token: str, check_certificate: bool) -> bool:
    """
    Check if token is valid
    Args:
        access_token: the access token
        check_certificate: check the site certificate

    Returns:
        True if the access token is valid, False otherwise.
    """

    request_header = {'Authorization': 'Bearer ' + access_token}
    try:
        response = requests.get(url=SCAS_OIDC_USER_INFO_URL,
                                headers=request_header,
                                timeout=3000,
                                verify=check_certificate)
    except RequestException as exc:
        print(f"Error connecting to '{SCAS_OIDC_USER_INFO_URL}': {exc}")
        sys.exit(2)

    return response.status_code == http.client.OK


def extract_stako_info(json_str: str) -> str:
    """
    Extract STAKO level from JSON response
    Args:
        json_str: the json response from the SCAS tool

    Returns:
        the STAKO level or N/A if not available
    """

    # Convert str to json to avoid type checker issue
    json_data = json.loads(json.dumps(json_str))
    if len(json_data['content']):
        stako_level = json_data['content'][0][STAKO_JSON_PARAMETER]
    else:
        stako_level = STAKO_NA

    return stako_level


def get_stako_info(access_token: str, gav: str,
                   check_certificate: bool) -> str:
    """
    Send a REST to the SCAS tool to retrieve the GAV STAKO level
    Args:
        access_token: the SCAS access token
        gav: the GAV value to retrieve from the SCAS tool
        check_certificate: check the site certificate

    Returns:
        the STAKO level
    """

    artifact = gav.split(GAV_SEPARATOR)[1].strip()
    version = gav.split(GAV_SEPARATOR)[2].strip()
    filter_artifact = SCAS_FILTER_ARTIFACT + artifact
    filter_version = SCAS_FILTER_VERSION + version

    url = str(SCAS_SEARCH_API_URL + filter_artifact + filter_version)
    request_header = {'Authorization': 'Bearer ' + access_token}
    try:
        response = requests.get(url,
                                headers=request_header,
                                timeout=3000,
                                verify=check_certificate)
    except RequestException as exc:
        print(f"Error connecting to '{url}': {exc}")
        sys.exit(2)

    if response.status_code == http.client.OK:
        stako_level = extract_stako_info(response.json())
    else:
        stako_level = STAKO_NA

    return stako_level


def retrieve_stako_from_gav(access_token: str, gav: str,
                            check_certificate: bool) -> str:
    """
    Retrieve the STAKO level from GAV
    Args:
        access_token: the SCAS site access token
        gav: the GAV value
        check_certificate: check the site certificate

    Returns:
        a string containing stako:group:artifact:version
    """
    stako_code_with_gav = (get_stako_info(access_token, gav, check_certificate)
                           + GAV_SEPARATOR + gav)

    return stako_code_with_gav.replace(GAV_SEPARATOR, CSV_SEPARATOR)


def retrieve_stako_from_gav_file(input_file: str, access_token: str,
                                 check_certificate: bool) -> str:
    """
    Retrieve the STAKO level from GAV values present in the input file
    Args:
        input_file: the file containing GAV values
        access_token: the SCAS site access token
        check_certificate: check the site certificate

    Returns:
        a string containing a list of 'stako:group:artifact:version'
    """

    summary_stako_gav_values = ''
    try:
        with open(input_file, 'r', encoding='UTF-8') as file:
            for line in file:
                # Removing CR from line
                clean_line = line.rstrip('\n')

                # Skip empty line
                if not clean_line:
                    continue

                # Verify the correct syntax of the GAV line
                gav_line = validate_gav(clean_line, False)

                if gav_line is None:
                    print(f"Error processing line: '{clean_line}'.\n "
                          "Reason: not a valid GAV (group:artifact:version) "
                          "value!")
                else:
                    if len(summary_stako_gav_values) > 0:
                        summary_stako_gav_values += '\n'

                    summary_stako_gav_values += \
                        retrieve_stako_from_gav(access_token, gav_line,
                                                check_certificate)
    except IOError as exc:
        print(f"Error on reading file: '{input_file}'. Reason: {exc}")
        sys.exit(2)

    return summary_stako_gav_values


def write_result_to_file(summary: str, filename: str):
    """
    Write STAKO level and GAV value to file
    Args:
        summary: the STAKO level and GAV value string to write
        filename: output file name
    """

    try:
        with open(filename, "w", encoding='UTF-8') as file:
            file.write(summary)
    except IOError as exc:
        print(f"Error on writing file: '{filename}'. Reason: {exc}")
        sys.exit(3)


def main():
    """
    The script return the STAKO level info for the required GAV.
    """

    parser = argparse.ArgumentParser(
        description=f'''
The script return the STAKO level for the required GAV.
It use the Access Token defined on the env variable named: '{SCAS_ENVIRONMENT_VAR_NAME}'

Select a 'GAV' (-g) or a input file (-f) to process.
''',
        formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('-g',
                        '--gav',
                        dest='gav',
                        type=validate_gav,
                        required=False,
                        help="the group:artifact:version (GAV) whose we need "
                        "to search for STAKO level. Accepted values are: "
                        "'group:artifact:version' or ':artifact:version'")
    parser.add_argument('-i',
                        '--input',
                        dest='input_file',
                        type=validate_existing_file,
                        required=False,
                        help="The file name that contains the list of "
                        "'group:artifact:version' (GAV) whose we need "
                        "to search to retrieve the STAKO level.")
    parser.add_argument('-o',
                        '--output',
                        dest='output_file',
                        required=False,
                        help="The output file name that will contains the"
                        "stako level for all the GAV requested in a form "
                        "as 'stako_level:group:artifact:version'.")
    parser.add_argument('-d',
                        '--disable',
                        dest='check_certificate',
                        required=False,
                        default=True,
                        action="store_false",
                        help="Disable site certificate verification.")

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()
    if args.gav is None and args.input_file is None:
        parser.print_help()
        sys.exit(1)

    scas_access_token = refresh_access_token(bool(args.check_certificate))
    is_token_valid = check_token_validation(scas_access_token,
                                            bool(args.check_certificate))
    if not is_token_valid:
        print("ERROR! Offline access token expired! Need to create a new "
              "offline access token.")
        sys.exit(1)

    if args.gav is not None:
        result = retrieve_stako_from_gav(scas_access_token, str(args.gav),
                                         bool(args.check_certificate))
    else:
        result = retrieve_stako_from_gav_file(str(args.input_file),
                                              scas_access_token,
                                              bool(args.check_certificate))

    if args.output_file is None:
        print(result)
    else:
        write_result_to_file(result, str(args.output_file))


if __name__ == '__main__':
    main()

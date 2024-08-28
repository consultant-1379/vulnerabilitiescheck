"""
The script return a SCAS offline access token.
"""
import argparse
import http.client

import sys

import requests
from requests import RequestException

SCAS_OIDC_TOKEN_URL = 'https://scas.internal.ericsson.com/auth/realms/SCA' \
                      '/protocol/openid-connect/token'


def get_offline_access_token(username: str, password: str,
                             check_certificate: bool) -> str:
    """
    Get the offline access token from the SCAS site
    Args:
        username: the login username
        password: the password
        check_certificate: check the site certificate

    Returns:
        the offline access token
    """

    data = {
        'grant_type': 'password',
        'client_id': 'scas-ext-client-direct',
        'scope': 'offline_access',
        'username': username,
        'password': password
    }
    headers = {'Accept': 'application/json'}
    try:
        response = requests.post(url=SCAS_OIDC_TOKEN_URL,
                                 data=data,
                                 headers=headers,
                                 timeout=3000,
                                 verify=check_certificate)
        if response.status_code != http.client.OK:
            print("Error getting the 'offline access token' from SCAS site: "
                  f"{SCAS_OIDC_TOKEN_URL}")
            print(f"Status Code: {response.status_code}")
            print(f"JSON Response: {response.json()}\n")
            sys.exit(2)
    except RequestException as exc:
        print(f"Error connecting to '{SCAS_OIDC_TOKEN_URL}': {exc}")
        sys.exit(2)

    return response.json()['refresh_token']


def main():
    """
    The script return a SCAS offline access token.
    """

    parser = argparse.ArgumentParser(
        description="The script return a SCAS offline access token")
    parser.add_argument('-u',
                        '--username',
                        dest='username',
                        required=True,
                        help="The username")
    parser.add_argument('-p',
                        '--password',
                        dest='password',
                        required=True,
                        help="The password")
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

    access_token = get_offline_access_token(str(args.username),
                                            str(args.password),
                                            bool(args.check_certificate))
    print(f'Offline access token:\n{access_token}')

    account_url = (
        SCAS_OIDC_TOKEN_URL.replace('/protocol/openid-connect/token',
                                    '/account/#/applications'))
    print(f'\nTo revoke it, please use the following link:\n{account_url}\n')


if __name__ == '__main__':
    main()

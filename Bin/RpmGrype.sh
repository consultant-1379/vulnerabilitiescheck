#!/bin/bash

RPM2CPIO_COMMAND=rpm2cpio
CPIO_COMMAND=cpio
GRYPE_COMMAND=grype
GRYPE_CSV_TEMPLATE=~/workspace/Configurations/grype_csv_template.templ
RPM_EXTRACTION_FOLDER=./RPM_EXTRACTION_FOLDER

if [[ $(command -v "${RPM2CPIO_COMMAND}" | wc -l) -lt 1 ]]; then
    echo "ERROR! Need '${RPM2CPIO_COMMAND}' to execute the script."
    exit 1
fi

if [[ $(command -v "${CPIO_COMMAND}" | wc -l) -lt 1 ]]; then
    echo "ERROR! Need '${CPIO_COMMAND}' to execute the script."
    exit 1
fi

if [[ $(command -v "${GRYPE_COMMAND}" | wc -l) -lt 1 ]]; then
    echo "ERROR! Need '${GRYPE_COMMAND}' to execute the script."
    exit 1
fi

usage()
{
cat << EOF
Usage: $(basename "$0") <rpm>
The script run a 'grype' scan on the RPM.

Parameters:
    rpm: rpm file

Example: $(basename "$0") ERICfake.rpm

EOF
}

#Check parameters
if [ $# -lt 1 ]; then
    echo "Error. No arguments provided!"
    echo
    usage
    exit 1
fi

FULL_RPM_PATH=${1}
PACKAGE_NAME=$(basename "${FULL_RPM_PATH}")
GRYPE_JSON_REPORT_FILE_NAME=${PACKAGE_NAME}.json.grype

# Extract the content from RPM
${RPM2CPIO_COMMAND} "${FULL_RPM_PATH}" | ${CPIO_COMMAND} -D ${RPM_EXTRACTION_FOLDER} -id &>/dev/null

echo
echo "----------- Generate csv vulnerability report of rpm package: ${PACKAGE_NAME} -----------"
${GRYPE_COMMAND} -o template -t ${GRYPE_CSV_TEMPLATE} dir:${RPM_EXTRACTION_FOLDER} > "${GRYPE_JSON_REPORT_FILE_NAME}".csv
echo

# Fix Jenkins environment issues
chown -R jenkins:jenkins ./RPM_EXTRACTION_FOLDER/
chmod -R 777 ./RPM_EXTRACTION_FOLDER/
# -----------------------------

# Remove the extracted content
rm -r -f ${RPM_EXTRACTION_FOLDER}

echo "Generated report file:"
ls -1 "${GRYPE_JSON_REPORT_FILE_NAME}".csv
echo

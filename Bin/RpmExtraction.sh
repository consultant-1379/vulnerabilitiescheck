#!/bin/bash

RPM2CPIO_COMMAND=rpm2cpio
CPIO_COMMAND=cpio

if [[ $(command -v "${RPM2CPIO_COMMAND}" | wc -l) -lt 1 ]]; then
    echo "ERROR! Need '${RPM2CPIO_COMMAND}' to execute the script."
    exit 1
fi

if [[ $(command -v "${CPIO_COMMAND}" | wc -l) -lt 1 ]]; then
    echo "ERROR! Need '${CPIO_COMMAND}' to execute the script."
    exit 1
fi


usage()
{
cat << EOF

Usage: $(basename "$0") <options>
The script extract the contents of a .rpm package file on a specified folder.

OPTIONS:
    -h    Show this message

    -r    rpm file name
    -p    extraction path

Example: $(basename "$0") -r /tmp/ERICfake.rpm -p ./RPM_EXTRACTION

EOF
}

while getopts "h?r:p:" OPTION
do
    case $OPTION in
        h)
            usage
            exit 0
            ;;
        r)
            RPM_NAME=$OPTARG
            ;;
        p)
            EXTRACTION_PATH=$OPTARG
            ;;
        ?)
            usage
            exit 0
            ;;
    esac
done

# Check the parameters value
if [[ -z $RPM_NAME || -z $EXTRACTION_PATH ]]; then
    echo "Error! No parameters provided."
    usage
    exit 1
fi

RPM_EXTRACTION_FOLDER=${EXTRACTION_PATH}/$(basename "${RPM_NAME}")
rm -r -f "${RPM_EXTRACTION_FOLDER}"
mkdir -p "${RPM_EXTRACTION_FOLDER}"

# Extract the content from RPM
#${RPM2CPIO_COMMAND} "${RPM_NAME}" | ${CPIO_COMMAND} -D "${RPM_EXTRACTION_FOLDER}" -id &>/dev/null
${RPM2CPIO_COMMAND} "${RPM_NAME}" | ${CPIO_COMMAND} -D "${RPM_EXTRACTION_FOLDER}" -id

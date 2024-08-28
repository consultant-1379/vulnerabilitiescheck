#!/bin/bash

usage()
{
cat << EOF
Usage: $(basename "$0") options
The script retrieve, for all the project dependencies, the STAKO classification
from the Ericsson SCAS tools.

OPTIONS:
    -h    Show this message
    -g    Path of 'get_scas_stako_code.py' script (optional)
    -p    Process dependency with scope 'provided'
    -t    Process dependency with scope 'test'

Example:
$(basename "$0") -p $HOME/Bin/get_scas_stako_code.py -t -p

EOF
}

PYTHON_COMMAND="python3"
if [ "$(command -v ${PYTHON_COMMAND} | wc -l)" -lt 1 ]; then
    echo "ERROR! Need '${PYTHON_COMMAND}' to execute the script."
    exit 1
fi

ERICSSON_ARTIFACTS_TO_REMOVE="com.ericsson"

FILE_NAME="Project_3PP_Dependencies"

HEADER_STAKO_REPORT="STAKO Classification,Group,Artifact,Version"

GET_SCAS_STAKO_CODE_SCRIPT_PATH="get_scas_stako_code.py"

OUTPUT_DEPENDENCY_RAW_LIST=$(pwd)/${FILE_NAME}_Report_raw.txt
OUTPUT_DEPENDENCY_LIST=$(pwd)/${FILE_NAME}_Report.csv
OUTPUT_STAKO_REPORT=$(pwd)/${FILE_NAME}_STAKO_Report.csv

PROCESS_SCOPE_PROVIDED="provided"
PROCESS_SCOPE_TEST="test"

while getopts "hptg:" OPTION
do
    case $OPTION in
        h)
            usage
            exit 0
            ;;
        p)
            PROCESS_SCOPE_PROVIDED=""
            ;;
        t)
            PROCESS_SCOPE_TEST=""
            ;;
        g)
            GET_SCAS_STAKO_CODE_SCRIPT_PATH=$OPTARG
            ;;
        ?)
            usage
            exit 0
            ;;
    esac
done

# Check if 'GET_SCAS_STAKO_CODE_SCRIPT_PATH' exist
if [ ! -f "${GET_SCAS_STAKO_CODE_SCRIPT_PATH}" ]; then
  echo "Error! '${GET_SCAS_STAKO_CODE_SCRIPT_PATH}' script not found."
  exit 1
fi


extractDependencyInfo()
{
    # Check the presence of 4 ':' in the line, if not print an error and skip the line.
    line=${1}

    res="${line//[^:]}"
    if [ "${#res}" -lt 4 ]; then
        return
    fi

    IFS=':' read -r -a array <<< "${line}"
    GroupId="${array[0]}"
    ArtifactId="${array[1]}"
    Version="${array[3]}"
    Scope="${array[4]}"
    unset IFS

    if [ -z "${GroupId}" ] || [ -z "${ArtifactId}" ] || [ -z "${Version}" ] || [ -z "${Scope}" ]; then
        return
    fi

    if [ "${Scope}" = "${PROCESS_SCOPE_TEST}" ]; then
        return;
    fi

    if [ "${Scope}" = "${PROCESS_SCOPE_PROVIDED}" ]; then
        return;
    fi

    echo "${GroupId}:${ArtifactId}:${Version}"
}


processingDependenciesFile()
{
    while read -r dependency; do
        extractDependencyInfo "${dependency}"
    done < "${1}"
}


echo -n "Extraction of project 3PP dependencies in progress. Please wait ... "
mvn -q dependency:list -D appendOutput=true -D excludeTransitive=true -D skip=true -D excludeGroupIds="${ERICSSON_ARTIFACTS_TO_REMOVE}" -D outputFile="${OUTPUT_DEPENDENCY_RAW_LIST}"
return_code=$?
if [ "${return_code}" -ne 0 ] ; then
  echo -e "\nError during operation. Abort!"
  exit 1
fi
echo "Done!"


echo -n "Processing project 3PP dependencies declaration. Please wait ... "
processingDependenciesFile "${OUTPUT_DEPENDENCY_RAW_LIST}" | sort -u > "${OUTPUT_DEPENDENCY_LIST}"
echo "Done!"


echo -n "Querying on SCAS database in progress. Please wait ... "
echo "${HEADER_STAKO_REPORT}" > "${OUTPUT_STAKO_REPORT}"
exec "${PYTHON_COMMAND}" "${GET_SCAS_STAKO_CODE_SCRIPT_PATH}" -i "${OUTPUT_DEPENDENCY_LIST}" -d 2>/dev/null | sort -ur >> "${OUTPUT_STAKO_REPORT}"
return_code=$?
if [ "${return_code}" -ne 0 ] ; then
  echo -e "\nError during operation. Abort!"
  exit 1
fi
echo "Done!"


# Remove temporary file
rm -r -f "${OUTPUT_DEPENDENCY_RAW_LIST}" "${OUTPUT_DEPENDENCY_LIST}"


echo
echo "Generated report file: ${OUTPUT_STAKO_REPORT}"
echo

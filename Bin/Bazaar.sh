#!/bin/bash

usage()
{
cat << EOF
Usage: `basename $0` options
The script retrieve, for all the project dependency, the FOSS information from the Ericsson Bazaar tools.

OPTIONS:
    -h    Show this message
    -t    Unskip dependency with scope test
    -c    Convert '-' to '_' on 'ArtifactId' for Bazaar search

EOF
}

RETRIEVE_COMMAND="curl"
if [ `command -v ${RETRIEVE_COMMAND} | wc -l` -lt 1 ]; then
    echo "ERROR! Need '${RETRIEVE_COMMAND}' to execute the script."
    exit 1
fi

JSON_PROCESSING_COMMAND="jq"
if [ `command -v ${JSON_PROCESSING_COMMAND} | wc -l` -lt 1 ]; then
    echo "ERROR! Need '${JSON_PROCESSING_COMMAND}' to execute the script."
    exit 1
fi

SKIP_SCOPE=test
while getopts "hrtc" OPTION
do
    case $OPTION in
        h)
            usage
            exit 0
            ;;
        t)
            SKIP_SCOPE=""
            ;;
        c)
            CONVERT_TO_UNDERSCORE=
            ;;
        ?)
            usage
            exit 0
            ;;
    esac
done

# --- USER CONFIGURATION ---
USER_NAME=enmadm100
TOKEN=U2FsdGVkX1+odlrwSlnijSzn/wxddceNBMOq85VRZ2A=
# --------------------------

BAZAAR_API_URL=http://papi.internal.ericsson.com

BAZAAR_PREFIX_NAME=`pwd`/BazaarDependency

BAZAAR_TEMP_FILE_1=${BAZAAR_PREFIX_NAME}-artifact-version.txt
BAZAAR_TEMP_FILE_2=${BAZAAR_PREFIX_NAME}-prim.txt
BAZAAR_TEMP_FILE_3=${BAZAAR_PREFIX_NAME}-package-info.txt

OUTPUT_DEPENDENCY_LIST=${BAZAAR_PREFIX_NAME}-list-raw.txt
OUTPUT_FULL_DEPENDENCY=${BAZAAR_PREFIX_NAME}-full-list.txt
OUTPUT_RESTRICTED_DEPENDENCY=${BAZAAR_PREFIX_NAME}-restricted-list.txt

OUTPUT_BAZAAR_REPORT=${BAZAAR_PREFIX_NAME}Report
OUTPUT_BAZAAR_TXT_REPORT=${OUTPUT_BAZAAR_REPORT}.txt
OUTPUT_BAZAAR_CSV_REPORT=${OUTPUT_BAZAAR_REPORT}.csv
OUTPUT_BAZAAR_CSV_TEMP_FILE=${OUTPUT_BAZAAR_REPORT}.temp

STRINGS_TO_REMOVE="\| none\|The following files have been resolved:\|^$\|"
ERICSSON_ARTIFACTS_TO_REMOVE="\|com.ericsson.\|"

HEADER_BAZAAR_CSV_REPORT="STAKO classification,Group,Artifact,Version"

extractDependencyInfo()
{
    # Check the presence of 4 ':' in the line, if not print an error and skip the line.
    line=${1}

    res="${line//[^:]}"
    if [ "${#res}" -lt 4 ]; then
        echo
        echo "--------------------------------------"
        echo "Error! Not recognized package: ${line}"
        echo "--------------------------------------"
        echo
        return
    fi

    depInfo=(${line//:/ })

    GroupId=${depInfo[0]}
    ArtifactId=${depInfo[1]}
    Version=${depInfo[3]}
    Scope=${depInfo[4]}

    echo
    echo "GroupId: ${GroupId}"
    echo "ArtifactId: ${ArtifactId}"
    if [ ${CONVERT_TO_UNDERSCORE+x} ]; then
      original_ArtifactId=${ArtifactId}
      ArtifactId=${ArtifactId//[-]/_}
      if [ "${ArtifactId}" != "${original_ArtifactId}" ]; then
        echo "Converted ArtifactId: ${ArtifactId}"
      fi
    fi

    echo ""
    echo "Version: ${Version}"
#    echo "Scope: ${Scope}"

    # Manage SKIP_SCOPE
    if [ "${Scope}" = "${SKIP_SCOPE}" ]; then
        echo
        echo "--------------------------------------"
        echo "Skip due to scope '${Scope}' definition"
        echo "--------------------------------------"
        echo
        return;
    fi
    # --------------------------------

    ${RETRIEVE_COMMAND} -s -o ${BAZAAR_TEMP_FILE_1} -k --noproxy '*' ${BAZAAR_API_URL}'?query=\{"username":"'${USER_NAME}'","token":"'${TOKEN}'","facility":"COMPONENT_QUERY","name":"'${ArtifactId}'","version":"'${Version}'"\}'

    ${JSON_PROCESSING_COMMAND} '{PRIM: .prim}' ${BAZAAR_TEMP_FILE_1} | grep "\"PRIM\": " > ${BAZAAR_TEMP_FILE_2}
    while read primCodeList; do
        IFS=':' read -ra primCodeField <<< $primCodeList
        primCode=`echo ${primCodeField[1]} | sed 's/ //'`

        decrypted_token=$(echo ${TOKEN} | openssl aes-256-cbc -pbkdf2 -d -a -pass pass:$0)

        FULL_URL=${BAZAAR_API_URL}?query=\\{\""username\"":\""${USER_NAME}\"",\""token\"":\""${decrypted_token}\"",\""facility\"":\""COMPONENT_QUERY\"",\""prim\"":${primCode}\\}

        ${RETRIEVE_COMMAND} -s -o ${BAZAAR_TEMP_FILE_3} -k --noproxy '*' ${FULL_URL}
        ${JSON_PROCESSING_COMMAND} '{NAME: .name, VERSION: .version, PRIM: .prim, STAKO: .stako}' ${BAZAAR_TEMP_FILE_3}
        StakoClassification=`${RETRIEVE_COMMAND} -s -k --noproxy '*' ${FULL_URL} | ${JSON_PROCESSING_COMMAND} '.stako' | tr -d '"null"' | tr -d '"'`
        if [[ ! ${StakoClassification} ]]; then
            StakoClassification="NA"
        fi
        echo "${StakoClassification},${GroupId},${ArtifactId},${Version}" >> ${OUTPUT_BAZAAR_CSV_TEMP_FILE}
    done < ${BAZAAR_TEMP_FILE_2}
    echo "-------------------------------------------------------------------"
    echo
}

processingDependenciesFile()
{
    while read dependency; do
        extractDependencyInfo $dependency
    done < ${OUTPUT_RESTRICTED_DEPENDENCY}
}

echo -n "Dependency extraction in progress. Please wait ... "
mvn -q dependency:list -DexcludeTransitive=true -DappendOutput=true -DoutputFile=${OUTPUT_DEPENDENCY_LIST}
echo "Done!"

echo "Querying Bazaar database. Please wait ..."

# Removing string defined on ${STRING_TO_REMOVE} and sort the output
grep -v "'${STRINGS_TO_REMOVE}'" ${OUTPUT_DEPENDENCY_LIST} | sort -u > ${OUTPUT_FULL_DEPENDENCY}
# Removing Ericsson artifacts
grep -v "'${ERICSSON_ARTIFACTS_TO_REMOVE}'" ${OUTPUT_FULL_DEPENDENCY} > ${OUTPUT_RESTRICTED_DEPENDENCY}

# Processing dependencies file
echo ${HEADER_BAZAAR_CSV_REPORT} > ${OUTPUT_BAZAAR_CSV_REPORT}
rm -rf ${OUTPUT_BAZAAR_CSV_TEMP_FILE}
touch ${OUTPUT_BAZAAR_CSV_TEMP_FILE}
processingDependenciesFile > ${OUTPUT_BAZAAR_TXT_REPORT}

# Create result file in CSV format
cat ${OUTPUT_BAZAAR_CSV_TEMP_FILE} | sort -ur >> ${OUTPUT_BAZAAR_CSV_REPORT}

# Show result
#cat ${OUTPUT_BAZAAR_REPORT}

echo
echo "Result file in text format available at: ${OUTPUT_BAZAAR_TXT_REPORT}"
echo "Result file in CSV format available at: ${OUTPUT_BAZAAR_CSV_REPORT}"
echo

# Remove temporary and unuseful files
rm -r -f ${OUTPUT_DEPENDENCY_LIST} ${OUTPUT_FULL_DEPENDENCY} ${OUTPUT_RESTRICTED_DEPENDENCY} ${BAZAAR_TEMP_FILE_1} ${BAZAAR_TEMP_FILE_2} ${BAZAAR_TEMP_FILE_3} ${OUTPUT_BAZAAR_CSV_TEMP_FILE}

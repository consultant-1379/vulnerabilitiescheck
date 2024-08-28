#!/bin/bash

usage()
{
cat << EOF
Usage: `basename $0` options
The script retrieve the latest version of a groupId:artifactId component on Nexus

Example: $0 -f -c org.apache.poi:poi

OPTIONS:
    -h    Show this message
    -c    Component with syntax 'groupId:artifactId'
    -f    Full ouput 'groupId:artifactId:version' [optional]

EOF
}

MISSING_COMMANDS=false
RETRIEVE_COMMAND="curl"
XML_PROCESSING_COMMAND="xmllint"

if [ `command -v ${RETRIEVE_COMMAND} | wc -l` -lt 1 ]; then
    echo "ERROR! Need '${RETRIEVE_COMMAND}' to execute the script."
    MISSING_COMMANDS=true
fi

if [ `command -v ${XML_PROCESSING_COMMAND} | wc -l` -lt 1 ]; then
    echo "ERROR! Need '${XML_PROCESSING_COMMAND}' to execute the script."
    MISSING_COMMANDS=true
fi

if [ ${MISSING_COMMANDS} = true ]; then
    exit 1
fi

SHOW_FULL_INFO=false
while getopts "hc:f" OPTION
do
    case $OPTION in
        h)
            usage
            exit 0
            ;;
        c)
            COMPONENT=$OPTARG
            ;;
        f)
            SHOW_FULL_INFO=true
            ;;
        ?)
            usage
            exit 0
            ;;
    esac
done

# Check number of parameters
if [ -z ${COMPONENT+x} ]; then
    echo "ERROR!! No component provided!"
    echo
    usage
    exit 1
fi

arrIN=(${COMPONENT//:/ })
GROUP_ID=${arrIN[0]}
ARTIFACT_ID=${arrIN[1]}
# Check length of GROUP_ID and ARTIFACT_ID
if [ ${#GROUP_ID} -eq 0 ]; then
    echo "ERROR! Wrong parameter!"
    echo
    usage
    exit 1
fi

if [ ${#ARTIFACT_ID} -eq 0 ]; then
    echo "ERROR! Wrong parameter!"
    echo
    usage
    exit 1
fi

NEXUS_URL="https://arm1s11-eiffel004.eiffel.gic.ericsson.se:8443/nexus"
NEXUS_SEARCH_URL="${NEXUS_URL}/service/local/lucene/search?g=${GROUP_ID}&a=${ARTIFACT_ID}&collapseresults=true"

# Execute command to search in Nexus the G:A
curlOutput=`${RETRIEVE_COMMAND} -s "${NEXUS_SEARCH_URL}"`

# Processing the response and retreive the latest release of the G:A
ARTIFACT_LATEST_RELEASE=`echo "$curlOutput" | ${XML_PROCESSING_COMMAND} --xpath "string(//latestRelease)" /dev/stdin`

if [ "${SHOW_FULL_INFO}" = true ]; then
    echo "${GROUP_ID}:${ARTIFACT_ID}:${ARTIFACT_LATEST_RELEASE}"
 else
    echo "${ARTIFACT_LATEST_RELEASE}"
fi

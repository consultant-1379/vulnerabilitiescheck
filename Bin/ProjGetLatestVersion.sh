#!/bin/bash

usage()
{
cat << EOF
Usage: `basename $0` options
The script retrieve, for all the project dependencies, the latest version available on Nexus

OPTIONS:
    -h    Show this message
    -t    Show dependencies with scope test
    -s    Skip report if the latest version is used

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
SKIP_LATEST_VERSION=false
while getopts "hrts" OPTION
do
    case $OPTION in
        h)
            usage
            exit 0
            ;;
        t)
            SKIP_SCOPE=""
            ;;
        s)
            SKIP_LATEST_VERSION=true
            ;;

        ?)
            usage
            exit 0
            ;;
    esac
done

OUTPUT_DEPENDENCY_LIST=`pwd`/proj-dep-list-raw.txt
OUTPUT_FULL_DEPENDENCY=`pwd`/proj-dep-full-list.txt
OUTPUT_RESTRICTED_DEPENDENCY=`pwd`/proj-dep-restricted-list.txt

OUTPUT_LATEST_VERSION_REPORT=`pwd`/proj-dep-report.txt

STRINGS_TO_REMOVE="\| none\|The following files have been resolved:\|^$\|"
SNAPSHOT_ARTIFACTS_TO_REMOVE="\|-SNAPSHOT\|"

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

    if [ "${Scope}" = "${SKIP_SCOPE}" ]; then
        return;
    fi
    # --------------------------------

    LATEST_VERSION=`../Bin/GA_LatestVersion.sh -c ${GroupId}:${ArtifactId}`
    if [ ${SKIP_LATEST_VERSION} = true ]; then
        if [ "${LATEST_VERSION}" = "${Version}" ]; then
            return
        fi
    fi

    echo "${GroupId}:${ArtifactId}:${Version} ----> ${LATEST_VERSION}"
}

processingDependenciesFile()
{
    echo "+========================================================+"
    echo "| Group:Artifact:Version ----> E/// Nexus latest version |"
    echo "+========================================================+"
    echo
    while read dependency; do
        extractDependencyInfo $dependency
    done < ${OUTPUT_RESTRICTED_DEPENDENCY}
}

echo -n "Dependency extraction in progress. Please wait ... "
mvn -q dependency:list -DexcludeTransitive=true -DappendOutput=true -DoutputFile=${OUTPUT_DEPENDENCY_LIST}
echo "Done!"

# Removing string defined on ${STRING_TO_REMOVE} and sort the output
grep -v "'${STRINGS_TO_REMOVE}'" ${OUTPUT_DEPENDENCY_LIST} | sort -u > ${OUTPUT_FULL_DEPENDENCY}
# Removing SNAPSHOT artifacts
grep -v "'${SNAPSHOT_ARTIFACTS_TO_REMOVE}'" ${OUTPUT_FULL_DEPENDENCY} > ${OUTPUT_RESTRICTED_DEPENDENCY}

echo -n "Searching latest version of GroupId:ArtifactId items on Nexus ... "
processingDependenciesFile > ${OUTPUT_LATEST_VERSION_REPORT}
echo "Done!"

echo
echo "Result file in text format available at: ${OUTPUT_LATEST_VERSION_REPORT}"
echo

# Remove unused files
rm -r -f ${OUTPUT_DEPENDENCY_LIST} ${OUTPUT_FULL_DEPENDENCY} ${OUTPUT_RESTRICTED_DEPENDENCY}

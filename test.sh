#!/bin/bash
#SPDX-License-Identifier: GPL-3.0-only
# Copyright 2020 Johannes Eigner <jo-hannes@dev-urandom.de>

# This script will run various tests

# global return value. Will be set to 1 if any test fails.
retval=0

# checks the return value and if the output contains the defined string
# checkReturnValueAndString <command> <expectedReturnValue> <expectedString> <lineNumber>
function checkReturnValueAndString
{
    if [[ $# -ne 4 ]]
    then
        echo "Wrong number of parameters for function: ${FUNCNAME[0]}"
        echo "  Expected: '4'"
        echo "  but got : '$#'"
        return 1
    fi
    local ret
    local str
    str=$(${1})
    ret=$?
    if [[ ${ret} -ne ${2} ]]
    then
        echo "ERROR: Wrong return code at ${0}:${4}."
        echo "  Expected: '${2}'"
        echo "  but got : '${ret}'"
        retval=1
    fi

    if ! grep -q "${3}" <<< "${str}";
    then
        echo "ERROR: Wrong string returned at ${0}:${4}."
        echo "  Expected: '${3}'"
        echo "  but got : '${str}'"
        retval=1
    fi
}

# check if file contains an SPDX identifier
# spdx-check <file>
function spdx-check
{
    # we want this license in all files
    local targedLicense="GPL-2.0-only"
    # search at first two lines. Normally the SPDX should be a comment at the
    # first line. But on shell scripts the first line is the shebang.
    local spdx
    spdx=$(head -n2 "${1}" | grep "SPDX-License-Identifier:")
    if [[ -z ${spdx} ]]
    then
        echo "ERROR: No SPDX-License-Identifier within first two lines in file: ${1}"
        retval=1
    else
        # check license type
        if [[ ! ${spdx} == *"${targedLicense}"* ]]; then
            echo "WARNING: Wrong license found in file: ${1}"
            echo "  Expected: '${targedLicense}'"
            echo "  but got : '$(echo "${spdx}" | sed -n -e 's/^.*SPDX-License-Identifier: //p')'"
            retval=1
        fi
    fi
}

# main
function main
{
    # get search path based on script location
    searchPath="$(dirname "${0}")"

    echo "######################"
    echo "# static code checks #"
    echo "######################"

    echo "# SPDX check #"
    find "${searchPath}" -type f ! -path "${searchPath}/.git/*" \
      ! -name "LICENSE" ! -name "README.md" | while read -r line; do
         spdx-check "${line}"
     done

    echo "# shellcheck #"
    find "${searchPath}" -name "*.sh" | while read -r line; do
        shellcheck "${line}"
    done

    exit ${retval}
}

main "$@"

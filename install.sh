#!/bin/bash
#SPDX-License-Identifier: GPL-2.0-only
# Copyright 2020 Johannes Eigner <jo-hannes@dev-urandom.de>

# Instal macstat on your system

# print help text
function help
{
    cat <<HelpText
Usage: $(basename "${0}") [path]

Instal macstat on your system

path: specify path where macstat will be installed. If no path is given
      /usr/local/bin/ will be used.
HelpText
}

# main
function main
{
    # check number of commands
    if [[ $# -gt 1 ]]; then
        echo "Error: Wrong number of arguments"
        echo ""
        help
        exit 1
    fi

    # set destination path if given
    if [[ $# -eq 1 ]]; then
        readonly destPath="${1}"
    else
        readonly destPath="/usr/local/bin/"
    fi

    # check if destination path exists
    if [[ ! -d "${destPath}" ]]; then
        echo "Error: Target directory '${destPath}' does not exist"
        echo "  You may need to create it first with:"
        echo "  mkdir -p ${destPath}"
        exit 1
    fi

    # install it
    install -g admin -m 0755 macstat.sh "${destPath}/macstat"

    exit 0
}

main "$@"

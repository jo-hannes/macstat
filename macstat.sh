#!/bin/bash
#SPDX-License-Identifier: GPL-2.0-only
# Copyright 2020 Johannes Eigner <jo-hannes@dev-urandom.de>

# Display important system statistics of macOS

# print help text
function help
{
    cat <<HelpText
Usage: $(basename "${0}") [-bch]

Display important system statistics of macOS
    -b  Display bars
    -c  Coloured output
    -h  Display help
HelpText
}

# configuration
# currently we need to specify the device for measuring hdd usage
readonly cfgMacHddUsageDev="/dev/disk1s1"

# colors
readonly COL_WARN='\033[1;33m'  # Warnings in yellow
readonly COL_ERR='\033[0;31m'   # Errors in red
readonly COL_NC='\033[0m'       # No Color

# measuremnt configuration
cfgDescription=("CPU" "RAM" "HDD space" "HDD inode" "Batt"  "Batt Keyboard" "Batt Mouse" "TM Backup Age")
   cfgFunction=(cpu   ram   hddUsage    hddInode    battery battKeyboard    battMouse    tmBackupAge)
       cfgWarn=(80    70    75          20          20      20              20            86400)
      cfgError=(90    80    85          30          10      10              10           172800)


function cpu
{
    # cpu percentage
    # Note: CPU usage is scaled per thread. So a CPU with n threads will report
    # up to n * 100% on full usage.
    local numThreads
    numThreads=$(sysctl -n hw.ncpu)
    local cpuTotal
    cpuTotal=$(ps -A -o %cpu | awk '{s+=$1} END {print s}' | tr ',' '.')
    echo "${cpuTotal}/${numThreads}" | bc
}

function ram
{
    # ram percentage
    # vm_stat or memory_pressure?
    local ramFreePercent
    ramFreePercent=$(memory_pressure | grep "System-wide memory free percentage" | cut -d: -f2 | tr -d %)
    echo $(( 100 - ramFreePercent ))
}

function hddUsage
{
    df | grep ${cfgMacHddUsageDev} | awk '{print $5}' | tr -d %
}

function hddInode
{
    df | grep ${cfgMacHddUsageDev} | awk '{print $8}' | tr -d %
}

function battery
{
    # main battery
    # pmset -g batt | grep "InternalBattery" | awk '{print %3}'
    # Return empty value for no battery. As I have no MacBook I can not test
    # this functionality.
    echo ""
}

function battMouse
{
    ioreg -c AppleDeviceManagementHIDEventService -r -l | grep -i mouse -A 20 | grep BatteryPercent | cut -d= -f2 | cut -d' ' -f2
}

function battKeyboard
{
    ioreg -c AppleDeviceManagementHIDEventService -r -l | grep -i keyboard -A 20 | grep BatteryPercent | cut -d= -f2 | cut -d' ' -f2
}

function tmBackupAge
{
    local lastTmBackupDate
    lastTmBackupDate=$(defaults read "/Library/Preferences/com.apple.TimeMachine.plist" Destinations | sed -n '/SnapshotDates/,$p' | grep -v 'StableLocalSnapshotDate' | grep -e '[0-9]' | awk -F '"' '{print $2}' | sort | tail -n1)
    # convert to unix time for calculation
    lastTmBackupDate=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "${lastTmBackupDate}" +"%s")
    local currentDate
    currentDate=$(date +"%s")
    echo "$((currentDate - lastTmBackupDate))"
}

# do all measurements
function measure
{
    for idx in ${!cfgFunction[*]}
    do
        value[$idx]=$(${cfgFunction[idx]})
    done
}

# Printing functions
# TODO calculate from cfgDescription
descLen=13

# Print usage bar
# printBar <value>
function printBar
{
    local val
    local fillLen
    local freeLen
    val="$1"
    fillLen="$(( barLen * val / 100 ))"
    freeLen="$(( barLen - fillLen ))"
    printf " ["
    if [[ $fillLen -gt 0 ]]; then
        printf "%0.s#" $(seq 1 $fillLen)
    fi
    printf "%0.s " $(seq 1 $freeLen)
    printf "]"
}

# Print measured percentage value
# printPercent <description> <value>
function printPercent
{
    if [[ -n $2 ]]; then
        printf "%-${descLen}s: $3%3d%%" "$1" "$2"
        if [[ ${bars} -eq 1 ]]; then
            printBar "$2"
        fi
        if [[ -n "$3" ]]; then
            echo -ne "${COL_NC}"
        fi
        printf "\n"
    fi
}

# Print measured time span value
# printPercent <description> <time span in seconds>
function printTimeSpan
{
    if [[ -n $2 ]]; then
        local span
        local days
        local hours
        local mins
        span=$2
        days="$(( span / 60 / 60 / 24 ))"
        hours="$(( ( span / 60 /60 ) % 24 ))"
        mins="$(( ( span / 60 ) % 60 ))"
        printf "%-${descLen}s: $3" "$1"
        if [[ ${days} -gt 0 ]]; then
            echo -n "${days}d"
        fi
        if [[ ${hours} -gt 0 || ${days} -gt 0 ]]; then
            printf "%02dh" "${hours}"
        fi
        printf "%02dm" "${mins}"
        if [[ -n "$3" ]]; then
            echo -ne "${COL_NC}"
        fi
        printf "\n"
    fi
}

function print
{
    for idx in ${!cfgFunction[*]}
    do
        txtCol=""
        if [[ ${color} -eq 1 ]]; then
            # check for warnings/error
            if [[ "${cfgError[$idx]}" -ge "${cfgWarn[$idx]}" ]]; then
                # higher values are problematic
                if [[ "${value[$idx]}" -ge "${cfgError[$idx]}" ]]; then
                    txtCol="${COL_ERR}"
                elif [[ "${value[$idx]}" -ge "${cfgWarn[$idx]}" ]]; then
                    txtCol="${COL_WARN}"
                fi
            else
                # lower values are problematic
                if [[ "${value[$idx]}" -le "${cfgError[$idx]}" ]]; then
                    txtCol="${COL_ERR}"
                elif [[ "${value[$idx]}" -le "${cfgWarn[$idx]}" ]]; then
                    txtCol="${COL_WARN}"
                fi
            fi
        fi

        # print it
        if [[ "${value[$idx]}" -gt 100 ]]; then
            printTimeSpan "${cfgDescription[idx]}" "${value[$idx]}" "${txtCol}"
        else
            printPercent "${cfgDescription[idx]}" "${value[$idx]}" "${txtCol}"
        fi
    done
}

# main
function main
{
    # parse options
    bars=0
    color=0
    while getopts bch opt; do
        case $opt in
        b)
            bars=1
            local colLen
            colLen=$(tput cols)
            barLen=$(( colLen - descLen - 9 ))
            ;;
        c)
            color=1
            ;;
        h)
            help
            exit 0
            ;;
        *)
            echo "Invalid argument"
            help
            exit 1
            ;;
        esac
    done

    measure
    print

    exit 0
}

main "$@"


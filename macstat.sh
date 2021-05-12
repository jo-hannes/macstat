#!/bin/bash
#SPDX-License-Identifier: GPL-2.0-only
# Copyright 2020 Johannes Eigner <jo-hannes@dev-urandom.de>

# Display important system statistics of macOS

# print help text
function help
{
    cat <<HelpText
Usage: $(basename "${0}")

Display important system statistics of macOS
HelpText
}

# do all measurements
function measure
{
    # cpu percentage
    # Note: CPU usage is scaled per thread. So a CPU with n threads will report
    # up to n * 100% on full usage.
    local numThreads
    numThreads=$(sysctl -n hw.ncpu)
    local cpuTotal
    cpuTotal=$(ps -A -o %cpu | awk '{s+=$1} END {print s}' | tr ',' '.')
    cpuPercent=$(echo "${cpuTotal}/${numThreads}" | bc)

    # ram percentage
    # vm_stat or memory_pressure?
    local ramFreePercent
    ramFreePercent=$(memory_pressure | grep "System-wide memory free percentage" | cut -d: -f2 | tr -d %)
    ramPercent="$(( 100 - ramFreePercent ))"

    # hdd usage
    # currently we need to specify the device to measure
    local macHddUsageDev="/dev/disk1s1"
    local diskinfo
    diskinfo=$(df | grep ${macHddUsageDev})
    hddSpaceUsagePercent=$(echo "${diskinfo}" | awk '{print $5}' | tr -d %)
    hddInodeUsagePercent=$(echo "${diskinfo}" | awk '{print $8}' | tr -d %)

    # main battery
    # pmset -g batt | grep "InternalBattery" | awk '{print %3}'
    # Return empty value for no battery. As I have no MacBook I can not test
    # this functionality.
    batteryPercent=""

    batteryMousePercent=$(ioreg -c AppleDeviceManagementHIDEventService -r -l | grep -i mouse -A 20 | grep BatteryPercent | cut -d= -f2 | cut -d' ' -f2)

    batteryKeyboardPercent=$(ioreg -c AppleDeviceManagementHIDEventService -r -l | grep -i keyboard -A 20 | grep BatteryPercent | cut -d= -f2 | cut -d' ' -f2)

    local lastTmBackupDate
    lastTmBackupDate=$(defaults read "/Library/Preferences/com.apple.TimeMachine.plist" Destinations | sed -n '/SnapshotDates/,$p' | grep -v 'StableLocalSnapshotDate' | grep -e '[0-9]' | awk -F '"' '{print $2}' | sort | tail -n1)
    # convert to unix time for calculation
    lastTmBackupDate=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "${lastTmBackupDate}" +"%s")
    local currentDate
    currentDate=$(date +"%s")
    tmBackupAgeSeconds="$((currentDate - lastTmBackupDate))"
}

# main
function main
{
    measure

    # echo "TODO: HW information. I know what mac I have!"
    echo "CPU          : ${cpuPercent}%"
    echo "RAM          : ${ramPercent}%"
    echo "HDD space    : ${hddSpaceUsagePercent}%"
    echo "HDD inode    : ${hddInodeUsagePercent}%"
    # echo "Batt         : ${batteryPercent}"
    echo "Batt Keyboard: ${batteryKeyboardPercent}%"
    echo "Batt Mouse   : ${batteryMousePercent}%"
    echo "TM Backup Age: $((tmBackupAgeSeconds / 60 / 60))h$(( ( tmBackupAgeSeconds / 60 ) % 60 ))m"
    exit 0
}

main "$@"


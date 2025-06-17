#!/usr/bin/env bash

GrubConfigFile="/etc/default/grub.d/50-cloudimg-settings.cfg"

# Log the given message at the given level. All logs are written to stderr with a timestamp.
log() {
    local -r level="$1"
    local -r message="$2"
    local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local -r script_name="$(basename "$0")"
    >&2 echo -e "${timestamp} [${level}] [$script_name] ${message}"
}

# Log the given message at INFO level. All logs are written to stderr with a timestamp.
log_info() {
    local -r message="$1"
    log "INFO" "$message"
}

# Log the given message at WARN level. All logs are written to stderr with a timestamp.
log_warn() {
    local -r message="$1"
    log "WARN" "$message"
}

# Log the given message at ERROR level. All logs are written to stderr with a timestamp.
log_error() {
    local -r message="$1"
    log "ERROR" "$message"
}

# Check error when a command was ran. If failed log message
check_error() {
    if [ $? -ne 0 ]
    then
        log_error "${1}"
    fi
}

# Replace a line of text that matches the given regular expression in a file with the given replacement.
# Only works for single-line replacements. Note that this method uses sudo!
file_replace_text() {
    local -r original_text_regex="$1"
    local -r replacement_text="$2"
    local -r file="$3"
    local args=()
    args+=("-i")
    args+=("s|$original_text_regex|$replacement_text|")
    args+=("$file")
    sudo sed "${args[@]}" > /dev/null
}

# Replace a line of text that matches the given regular expression in a file with the given replacement.
# Only works for single-line replacements. Note that this method uses sudo!
file_replaceAppend_text() {
    local -r original_text_regex="$1"
    local -r replacement_text="$2"
    local -r file="$3"
    if grep -q "${original_text_regex}" "${file}" 2>/dev/null; then
        file_replace_text "${original_text_regex}" "${replacement_text}" "${file}"
    else
        file_append_text "${replacement_text}" "${file}"
    fi
}

# Append the given text to the given file. The reason this method exists, as opposed to using bash's built-in append
# operator, is that this method uses sudo, which doesn't work natively with the built-in operator.
file_append_text() {
    local -r text="$1"
    local -r file="$2"

    echo -e "$text" | sudo tee -a "$file" > /dev/null
}

EnableHugePages() {
    # Determine the core topology we can use for our DPDK threads.
    #   LcoreStart: index of first core to reserve
    #   LcoreLast : index of last core to reserve
    #   LcoreCount: how many cores are reserved

    declare -g LcoreStart=8
    declare -g LcoreLast=15

    local -r __nr_hugepages=$(cat /proc/sys/vm/nr_hugepages)
    log_info "Setting up hugepage support: current nr_hugepages=$__nr_hugepages"
    local __bootcmd="default_hugepagesz=1G hugepagesz=1G hugepages=6"
    # local __bootcmd="${__bootcmd} nohz_full=$LcoreStart-$LcoreLast rcu_nocbs=$LcoreStart-$LcoreLast rcu_nocb_poll isolcpus=$LcoreStart-$LcoreLast"
    if [[ $CloudTarget == "ALIBABA" ]]; then
        local __bootcmd="${__bootcmd} intel_iommu=on"
    fi
    # GRUB_CMDLINE_LINUX_DEFAULT is always added to GRUB_CMDLINE_LINUX for normal boots.
    # It is NOT used during recovery boots.
    local -r __cmdline="GRUB_CMDLINE_LINUX_DEFAULT="
    local -r __replacement_text="$__cmdline\"$__bootcmd\""
    file_replaceAppend_text "^${__cmdline}.*$" "$__replacement_text" "${GrubConfigFile}"
    sudo update-grub
}

EnableHugePages

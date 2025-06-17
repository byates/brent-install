#!/usr/bin/env bash
set -euo pipefail

GrubConfigFile="/etc/default/grub.d/50-cloudimg-settings.cfg"
VERBOSE=1

# Parse arguments
for arg in "$@"; do
  case "$arg" in
  --verbose)
    VERBOSE=1
    ;;
  esac
done

# Log the given message at the given level. All logs are written to stderr with a timestamp.
log() {
  local -r level="$1"
  local -r message="$2"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local script_name
  script_name="$(basename "$0")"
  >&2 echo -e "${timestamp} [${level}] [$script_name] ${message}"
}

log_info() { log "INFO" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }
log_debug() {
  if [[ $VERBOSE -eq 1 ]]; then
    log "DEBUG" "$1"
  fi
}

check_error() {
  if [ $? -ne 0 ]; then
    log_error "$1"
  fi
}

file_replace_text() {
  local -r original_text_regex="$1"
  local -r replacement_text="$2"
  local -r file="$3"
  log_debug "Replacing in $file: $original_text_regex → $replacement_text"
  sudo sed -i -- "s|$original_text_regex|$replacement_text|" "$file" >/dev/null
}

file_replaceAppend_text() {
  local -r original_text_regex="$1"
  local -r replacement_text="$2"
  local -r file="$3"
  if grep -q "$original_text_regex" "$file" 2>/dev/null; then
    log_debug "Match found for regex in $file: $original_text_regex"
    file_replace_text "$original_text_regex" "$replacement_text" "$file"
  else
    log_debug "No match found for regex in $file. Appending instead."
    file_append_text "$replacement_text" "$file"
  fi
}

file_append_text() {
  local -r text="$1"
  local -r file="$2"
  log_debug "Appending to $file: $text"
  echo -e "$text" | sudo tee -a "$file" >/dev/null
}

enable_hugepages() {
  local lcore_start=8
  local lcore_last=15

  local nr_hugepages
  read -r nr_hugepages </proc/sys/vm/nr_hugepages
  log_info "Setting up hugepage support: current nr_hugepages=$nr_hugepages"

  local bootcmd="default_hugepagesz=1G hugepagesz=1G hugepages=6"
  log_debug "Initial bootcmd: $bootcmd"

  if [[ "${CloudTarget:-}" == "ALIBABA" ]]; then
    bootcmd+=" intel_iommu=on"
    log_debug "CloudTarget is ALIBABA; updated bootcmd: $bootcmd"
  fi

  local cmdline="GRUB_CMDLINE_LINUX_DEFAULT="
  local replacement_text="${cmdline}\"${bootcmd}\""
  log_debug "Replacing GRUB line with: $replacement_text"

  file_replaceAppend_text "^${cmdline}.*$" "$replacement_text" "$GrubConfigFile"

  log_debug "Running update-grub"
  if ! sudo update-grub; then
    log_error "Failed to update GRUB configuration"
    exit 1
  fi
}

# Automatically run if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  enable_hugepages
fi

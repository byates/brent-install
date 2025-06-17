#!/bin/bash
set -e

# Disallow running as root
if [[ "$(id -u)" == 0 ]]; then
  echo -e "\033[1;31mERROR: Do not run this script as root. Use a normal user.\033[0m"
  exit 1
fi

# Fancy colors
CYAN='\033[1;36m'
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

INSTALL_DIR="/usr/share/brent-install/scripts"
SCRIPTS=("$INSTALL_DIR"/install-*)

# Check if any matching scripts exist
if [[ ! -d "$INSTALL_DIR" || ! -e "${SCRIPTS[0]}" ]]; then
  echo -e "${RED}No install scripts found in $INSTALL_DIR${NC}"
  exit 1
fi

# Display menu
echo -e "${CYAN}Available Install Scripts:${NC}"
i=1
for script in "${SCRIPTS[@]}"; do
  script_name=$(basename "$script")
  echo -e "  ${YELLOW}$i)${NC} $script_name"
  ((i++))
done

# Add Quit option
echo -e "  ${YELLOW}$i)${NC} Quit"

# Prompt for user choice
echo
echo -en "${GREEN}Choose a script to run [1-$i]: ${NC}"
read choice

# Validate and run
if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "$i" ]]; then
  if [[ "$choice" -eq "$i" ]]; then
    echo -e "${CYAN}Goodbye!${NC}"
    exit 0
  fi
  selected_script="${SCRIPTS[$((choice - 1))]}"
  echo -e "${CYAN}Running: $selected_script${NC}"
  bash "$selected_script"
else
  echo -e "${RED}Invalid choice. Exiting.${NC}"
  exit 1
fi

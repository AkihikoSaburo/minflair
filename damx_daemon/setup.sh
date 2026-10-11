#!/bin/bash

# DAMX Direct Installer Script (Daemon & Driver Only)
# This script directly installs Linuwu-Sense drivers and DAMX-Daemon for Acer laptops on Linux

# Constants
SCRIPT_VERSION="1.2.0"
INSTALL_DIR="/opt/damx"
SYSTEMD_DIR="/etc/systemd/system"
DAEMON_SERVICE_NAME="damx-daemon.service"

# Legacy paths for cleanup (uppercase naming convention)
LEGACY_INSTALL_DIR="/opt/DAMX"
LEGACY_DAEMON_SERVICE_NAME="DAMX-Daemon.service"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to pause script execution
pause() {
  echo -e "${BLUE}Press any key to continue...${NC}"
  read -n 1 -s -r
}

# Function to check and elevate privileges
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}This script requires root privileges.${NC}"

    if command -v sudo &> /dev/null; then
      echo -e "${BLUE}Attempting to run with sudo...${NC}"
      exec sudo "$0" "$@"
      exit $?
    else
      echo -e "${RED}Error: sudo not found. Please run this script as root.${NC}"
      exit 1
    fi
  fi
}

print_banner() {
  clear
  echo -e "${BLUE}==========================================${NC}"
  echo -e "${BLUE}    DAMX Direct Installer v${SCRIPT_VERSION}      ${NC}"
  echo -e "${BLUE}    Acer Laptop WMI Controls for Linux  ${NC}"
  echo -e "${BLUE}==========================================${NC}"
  echo ""
}

# Function to detect and clean up legacy installations
cleanup_legacy_installation() {
  echo -e "${YELLOW}Checking for legacy installations...${NC}"
  local cleanup_performed=false

  if [ -f "${SYSTEMD_DIR}/${LEGACY_DAEMON_SERVICE_NAME}" ]; then
    echo -e "${BLUE}Found legacy service file: ${LEGACY_DAEMON_SERVICE_NAME}${NC}"
    if systemctl is-active --quiet ${LEGACY_DAEMON_SERVICE_NAME} 2>/dev/null; then
      systemctl stop ${LEGACY_DAEMON_SERVICE_NAME}
    fi
    if systemctl is-enabled --quiet ${LEGACY_DAEMON_SERVICE_NAME} 2>/dev/null; then
      systemctl disable ${LEGACY_DAEMON_SERVICE_NAME}
    fi
    rm -f "${SYSTEMD_DIR}/${LEGACY_DAEMON_SERVICE_NAME}"
    cleanup_performed=true
  fi

  if [ -d "${LEGACY_INSTALL_DIR}" ]; then
    rm -rf "${LEGACY_INSTALL_DIR}"
    cleanup_performed=true
  fi

  local legacy_artifacts=(
    "/usr/local/bin/DAMX-Daemon"
    "/usr/local/bin/DAMX"
    "/usr/share/applications/damx.desktop"
    "/usr/share/applications/DAMX.desktop"
    "/usr/share/icons/hicolor/256x256/apps/damx.png"
    "/usr/share/icons/hicolor/256x256/apps/DAMX.png"
  )

  for artifact in "${legacy_artifacts[@]}"; do
    if [ -f "$artifact" ] || [ -d "$artifact" ]; then
      rm -rf "$artifact"
      cleanup_performed=true
    fi
  done

  if [ "$cleanup_performed" = true ]; then
    systemctl daemon-reload
    echo -e "${GREEN}Legacy installation cleanup completed.${NC}"
  else
    echo -e "${GREEN}No legacy installations found.${NC}"
  fi
}

cleanup_nitro_service() {
  echo -e "${YELLOW}Cleaning up Nitro Key Detection Service...${NC}"
  NITRO_SERVICE_NAME="nitro-key-detection.service"
  
  if systemctl is-active --quiet ${NITRO_SERVICE_NAME} 2>/dev/null; then
    systemctl stop ${NITRO_SERVICE_NAME}
  fi
  if systemctl is-enabled --quiet ${NITRO_SERVICE_NAME} 2>/dev/null; then
    systemctl disable ${NITRO_SERVICE_NAME}
  fi
  if [ -f "${SYSTEMD_DIR}/${NITRO_SERVICE_NAME}" ]; then
    rm -f "${SYSTEMD_DIR}/${NITRO_SERVICE_NAME}"
  fi
  if [ -f "/usr/local/bin/nitro-key-detection.sh" ]; then
    rm -f "/usr/local/bin/nitro-key-detection.sh"
  fi
  if [ -f "/etc/damx/nitro_key.conf" ]; then
    rm -f "/etc/damx/nitro_key.conf"
  fi
  echo -e "${GREEN}Nitro Key Detection Service cleaned up.${NC}"
}

comprehensive_cleanup() {
  echo -e "${YELLOW}Performing cleanup of previous installations...${NC}"
  if systemctl is-active --quiet ${DAEMON_SERVICE_NAME} 2>/dev/null; then
    systemctl stop ${DAEMON_SERVICE_NAME}
  fi
  if systemctl is-enabled --quiet ${DAEMON_SERVICE_NAME} 2>/dev/null; then
    systemctl disable ${DAEMON_SERVICE_NAME}
  fi
  if [ -f "${SYSTEMD_DIR}/${DAEMON_SERVICE_NAME}" ]; then
    rm -f "${SYSTEMD_DIR}/${DAEMON_SERVICE_NAME}"
  fi

  cleanup_nitro_service
  cleanup_legacy_installation
  rm -rf ${INSTALL_DIR}

  if [ -d "Linuwu-Sense" ]; then
    cd Linuwu-Sense
    if [ -f "Makefile" ]; then
      make uninstall 2>/dev/null || true
    fi
    cd ..
  fi

  rm -rf /etc/damx
  systemctl daemon-reload
}

# Detect the compiler used to build the running kernel.
is_llvm_kernel() {
  local kernel_release
  local kernel_build
  local config_file

  kernel_release=$(uname -r)
  kernel_build="/lib/modules/${kernel_release}/build"

  for config_file in "/boot/config-${kernel_release}" "${kernel_build}/.config"; do
    if [ -r "$config_file" ] && grep -q '^CONFIG_CC_IS_CLANG=y' "$config_file"; then
      return 0
    fi
  done

  if command -v zgrep &> /dev/null && [ -r /proc/config.gz ] && zgrep -q '^CONFIG_CC_IS_CLANG=y' /proc/config.gz; then
    return 0
  fi

  if grep -qsiE 'clang|llvm' /proc/version 2>/dev/null; then
    return 0
  fi

  if [ -r "${kernel_build}/include/generated/compile.h" ] && grep -qsiE 'clang|llvm' "${kernel_build}/include/generated/compile.h"; then
    return 0
  fi

  if [ -r /etc/os-release ] && grep -qi 'cachyos' /etc/os-release; then
    return 0
  fi

  return 1
}

install_build_deps() {
  if command -v pacman &> /dev/null; then
    pacman -S --needed --noconfirm base-devel
    if is_llvm_kernel; then
      pacman -S --needed --noconfirm clang llvm lld
    fi
  elif command -v apt-get &> /dev/null; then
    apt-get update && apt-get install -y build-essential
  elif command -v dnf &> /dev/null; then
    dnf install -y gcc make kernel-devel
  elif command -v zypper &> /dev/null; then
    zypper install -y gcc make kernel-devel
  fi
}

install_drivers() {
  local build_args=()
  echo -e "${YELLOW}Installing Linuwu-Sense drivers...${NC}"

  if [ ! -d "Linuwu-Sense" ]; then
    echo -e "${RED}Error: Linuwu-Sense directory not found!${NC}"
    exit 1
  fi

  cd Linuwu-Sense

  if ! command -v make &> /dev/null; then
    echo -e "${YELLOW}Installing build tools...${NC}"
    install_build_deps || { cd ..; exit 1; }
  fi

  if is_llvm_kernel; then
    echo -e "${YELLOW}Detected LLVM-compiled kernel, using Clang...${NC}"
    if ! command -v clang &> /dev/null; then
      install_build_deps || { cd ..; exit 1; }
    fi
    build_args=(LLVM=1 CC=clang)
  fi

  if ! make clean "${build_args[@]}" || ! make "${build_args[@]}"; then
    echo -e "${RED}Error: Failed to build Linuwu-Sense drivers${NC}"
    cd ..
    exit 1
  fi

  if ! make install "${build_args[@]}"; then
    echo -e "${RED}Error: Failed to install Linuwu-Sense drivers${NC}"
    cd ..
    exit 1
  fi

  echo -e "${GREEN}Linuwu-Sense drivers installed successfully!${NC}"
  cd ..
}

install_daemon() {
  echo -e "${YELLOW}Installing DAMX-Daemon...${NC}"

  if [ ! -d "DAMX-Daemon" ]; then
    echo -e "${RED}Error: DAMX-Daemon directory not found!${NC}"
    exit 1
  fi

  mkdir -p ${INSTALL_DIR}/daemon
  cp -f DAMX-Daemon/DAMX-Daemon ${INSTALL_DIR}/daemon/
  chmod +x ${INSTALL_DIR}/daemon/DAMX-Daemon

  cat > ${SYSTEMD_DIR}/${DAEMON_SERVICE_NAME} << EOL
[Unit]
Description=DAMX Daemon for Acer laptops
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/daemon/DAMX-Daemon
Restart=on-failure
RestartSec=5
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL

  systemctl daemon-reload
  systemctl enable ${DAEMON_SERVICE_NAME}
  systemctl start ${DAEMON_SERVICE_NAME}

  if systemctl is-active --quiet ${DAEMON_SERVICE_NAME}; then
    echo -e "${GREEN}DAMX-Daemon installed and service started successfully!${NC}"
  else
    echo -e "${RED}Warning: DAMX-Daemon service may not have started correctly. Check with 'systemctl status ${DAEMON_SERVICE_NAME}'${NC}"
  fi
}

configure_nitro_button() {
  echo -e "${YELLOW}Configuring Nitro/PredatorSense Button Hardware Code...${NC}"

  echo -e "${YELLOW}Do you want to setup your Nitro/PredatorSense Key? (y/N) - Waiting 10 seconds...${NC}"
  read -t 10 -n 1 -r response
  
  if [[ $? -ne 0 ]] || [[ -z "$response" ]]; then
    echo -e "\n${BLUE}No response detected. Skipping Nitro button setup.${NC}"
    response="N"
  fi

  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Skipping button configuration.${NC}"
    return 0
  fi

  if ! command -v evtest &> /dev/null; then
    echo -e "${BLUE}Installing evtest for hardware detection...${NC}"
    if command -v apt-get &> /dev/null; then
      apt-get update && apt-get install -y evtest
    elif command -v dnf &> /dev/null; then
      dnf install -y evtest
    elif command -v pacman &> /dev/null; then
      pacman -S --noconfirm --needed evtest
    fi
  fi

  DEVICE=$(grep -A 5 -B 5 "AT Translated Set 2 keyboard" /proc/bus/input/devices | grep -m 1 "event" | sed 's/.*event\([0-9]\+\).*/\/dev\/input\/event\1/')
  mkdir -p /etc/damx

  if [ -z "$DEVICE" ]; then
    echo -e "${RED}Error: Keyboard hardware not found! Using default Nitro code (425).${NC}"
    echo "NITRO_KEY=425" > /etc/damx/nitro_key.conf
    return 1
  fi

  echo -e "${GREEN}Keyboard detected at: $DEVICE${NC}"
  echo -e "${YELLOW}>>> PLEASE PRESS YOUR NITRO / PREDATORSENSE BUTTON NOW (Waiting 30 seconds)... <<<${NC}"

  CAPTURED_CODE=$(timeout 30 evtest "$DEVICE" | grep -m 1 "type 1 (EV_KEY).*value 1" | sed -n 's/.*code \([0-9]*\).*/\1/p')

  if [ -n "$CAPTURED_CODE" ]; then
    echo -e "${GREEN}Success! Button code captured: ${CAPTURED_CODE}${NC}"
    echo "NITRO_KEY=$CAPTURED_CODE" > /etc/damx/nitro_key.conf
  else
    echo -e "${RED}Timeout or no key detected. Falling back to default code (425).${NC}"
    echo "NITRO_KEY=425" > /etc/damx/nitro_key.conf
  fi
  
  install_nitro_service
}

detect_desktop_user() {
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ] && id -u "$SUDO_USER" >/dev/null 2>&1; then
    echo "$SUDO_USER"
    return 0
  fi
  if command -v loginctl >/dev/null 2>&1; then
    local session_user
    session_user=$(loginctl list-sessions --no-legend 2>/dev/null | awk '$3 != "root" && $3 != "gdm" { print $3; exit }')
    if [ -n "$session_user" ] && id -u "$session_user" >/dev/null 2>&1; then
      echo "$session_user"
      return 0
    fi
  fi
  awk -F: '$3 >= 1000 && $3 < 60000 && $1 != "nobody" { print $1; exit }' /etc/passwd
}

install_nitro_service() {
  echo -e "${YELLOW}Installing Nitro Key Detection Service...${NC}"
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  NITRO_SCRIPT="$SCRIPT_DIR/nitro-key-detection.sh"
  TARGET_USER=$(detect_desktop_user)

  if [ -z "$TARGET_USER" ] || ! id -u "$TARGET_USER" >/dev/null 2>&1; then
    echo -e "${RED}Error: Could not determine desktop user for Nitro key launcher.${NC}"
    return 1
  fi

  if [ ! -f "$NITRO_SCRIPT" ]; then
    echo -e "${RED}Error: NitroKeyDetection.sh not found in $SCRIPT_DIR${NC}"
    return 1
  fi
  
  chmod +x "$NITRO_SCRIPT"
  cp "$NITRO_SCRIPT" /usr/local/bin/
  chmod +x "/usr/local/bin/nitro-key-detection.sh"
  
  cat > /etc/systemd/system/nitro-key-detection.service << EOF
[Unit]
Description=Nitro/PredatorSense Key Detection Service
After=multi-user.target
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/nitro-key-detection.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
User=root
Environment=DAMX_TARGET_USER=${TARGET_USER}

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable nitro-key-detection.service
  systemctl start nitro-key-detection.service
  
  if systemctl is-active --quiet nitro-key-detection.service; then
    echo -e "${GREEN}✓ Nitro Key Detection Service installed and running!${NC}"
  else
    echo -e "${RED}✗ Service installation failed.${NC}"
  fi
}

# --- MAIN EXECUTION FLOW ---
check_root "$@"
print_banner

echo -e "${BLUE}Starting DAMX Driver & Daemon installation...${NC}"
comprehensive_cleanup

mkdir -p ${INSTALL_DIR}
install_drivers
install_daemon
configure_nitro_button

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  Installation Completed Successfully!    ${NC}"
echo -e "${GREEN}==========================================${NC}"
systemctl status ${DAEMON_SERVICE_NAME} --no-pager -l
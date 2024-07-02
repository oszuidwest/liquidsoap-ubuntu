#!/usr/bin/env bash

# Set-up the functions library
FUNCTIONS_LIB_PATH="/tmp/functions.sh"
FUNCTIONS_LIB_URL="https://raw.githubusercontent.com/oszuidwest/bash-functions/main/common-functions.sh"

# Set-up Liquidsoap
LIQUIDSOAP_VERSION="2.2.5"
LIQUIDSOAP_PACKAGE_BASE_URL="https://github.com/savonet/liquidsoap/releases/download/v$LIQUIDSOAP_VERSION"
LIQUIDSOAP_CONFIG_URL="https://raw.githubusercontent.com/oszuidwest/zwfm-liquidsoap/main/radio.liq"
LIQUIDSOAP_SERVICE_URL="https://raw.githubusercontent.com/oszuidwest/zwfm-liquidsoap/main/liquidsoap.service"
AUDIO_FALLBACK_URL="https://upload.wikimedia.org/wikipedia/commons/6/66/Aaron_Dunn_-_Sonata_No_1_-_Movement_2.ogg"

# Set-up StereoTool
STEREOTOOL_VERSION="1021"
STEREOTOOL_BASE_URL="https://download.thimeo.com"

# General options
SUPPORTED_OS=("bookworm" "jammy" "noble")
TIMEZONE="Europe/Amsterdam"
DIRECTORIES=("/etc/liquidsoap" "/var/audio")

# Remove old functions library and download the latest version
rm -f "$FUNCTIONS_LIB_PATH"
if ! curl -sLo  "$FUNCTIONS_LIB_PATH" "$FUNCTIONS_LIB_URL"; then
  echo -e "*** Failed to download functions library. Please check your network connection! ***"
  exit 1
fi

# Source the functions file
# shellcheck source=/tmp/functions.sh
source "$FUNCTIONS_LIB_PATH"

# Basic environment configuration
set_colors
check_user_privileges privileged
is_this_linux
is_this_os_64bit
set_timezone "$TIMEZONE"

# Detect and validate the operating system
os_id=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
os_version=$(lsb_release -cs)
os_arch=$(dpkg --print-architecture)

if [[ ! " ${SUPPORTED_OS[*]} " =~ ${os_version} ]]; then
  printf "This script does not support '%s' OS version. Exiting.\n" "$os_version"
  exit 1
fi

# Start with a clean terminal
clear

# Banner
cat << "EOF"
 ______     _     ___          __       _     ______ __  __ 
|___  /    (_)   | \ \        / /      | |   |  ____|  \/  |
   / /_   _ _  __| |\ \  /\  / /__  ___| |_  | |__  | \  / |
  / /| | | | |/ _` | \ \/  \/ / _ \/ __| __| |  __| | |\/| |
 / /_| |_| | | (_| |  \  /\  /  __/\__ \ |_  | |    | |  | |
/_____\__,_|_|\__,_|   \/  \/ \___||___/\__| |_|    |_|  |_|
EOF

# Greeting
echo -e "${GREEN}⎎ Liquidsoap and StereoTool setup${NC}\n\n"
ask_user "USE_ST" "n" "Do you want to use StereoTool for sound processing? (y/n)" "y/n"
ask_user "DO_UPDATES" "y" "Do you want to perform all OS updates? (y/n)" "y/n"

# OS-specific configurations for Debian Bookworm
if [ "$os_version" == "bookworm" ]; then
  install_packages silent software-properties-common
  apt-add-repository -y non-free
fi

# Update OS
if [ "$DO_UPDATES" == "y" ]; then
  update_os silent
fi

# Liquidsoap installation
install_packages silent fdkaac libfdkaac-ocaml libfdkaac-ocaml-dynlink
echo -e "${BLUE}►► Installing Liquidsoap...${NC}"
package_url="${LIQUIDSOAP_PACKAGE_BASE_URL}/liquidsoap_${LIQUIDSOAP_VERSION}-${os_id}-${os_version}-1_${os_arch}.deb"
liquidsoap_package="/tmp/liquidsoap_${LIQUIDSOAP_VERSION}.deb"
curl -sLo  "$liquidsoap_package" "$package_url"
apt -qq -y install "$liquidsoap_package" --fix-broken

# Directory setup
echo -e "${BLUE}►► Creating directories...${NC}"
for dir in "${DIRECTORIES[@]}"; do
  mkdir -p "$dir" && chown liquidsoap:liquidsoap "$dir" && chmod g+s "$dir"
done

# Download configuration and sample files
echo -e "${BLUE}►► Downloading files...${NC}"
curl -sLo  /var/audio/fallback.ogg "$AUDIO_FALLBACK_URL"
curl -sLo  /etc/liquidsoap/radio.liq "$LIQUIDSOAP_CONFIG_URL"

# StereoTool setup
if [ "$USE_ST" == "y" ]; then
  install_packages silent unzip
  echo -e "${BLUE}►► Installing StereoTool...${NC}"
  mkdir -p /opt/stereotool
  curl -sLo  /tmp/st.zip "${STEREOTOOL_BASE_URL}/Stereo_Tool_Generic_plugin_${STEREOTOOL_VERSION}.zip"
  unzip -o /tmp/st.zip -d /tmp/
  extracted_dir=$(find /tmp/* -maxdepth 0 -type d -print0 | xargs -0 ls -td | head -n 1)
  
  if [ "$os_arch" == "amd64" ]; then
    cp "${extracted_dir}/lib/Linux/IntelAMD/64/libStereoToolX11_intel64.so" /opt/stereotool/st_plugin.so
    curl -sLo  /opt/stereotool/st_standalone "${STEREOTOOL_BASE_URL}/stereo_tool_cmd_64_${STEREOTOOL_VERSION}"
  elif [ "$os_arch" == "arm64" ]; then
    cp "${extracted_dir}/lib/Linux/ARM/64/libStereoTool_arm64.so" /opt/stereotool/st_plugin.so
    curl -sLo  /opt/stereotool/st_standalone "${STEREOTOOL_BASE_URL}/stereo_tool_pi2_64_${STEREOTOOL_VERSION}"
  fi
  chmod +x /opt/stereotool/st_standalone

  # Generate and patch StereoTool config file
  /opt/stereotool/st_standalone -X /etc/liquidsoap/st.ini
  sed -i 's/^\(Whitelist=\).*$/\1\/0/' /etc/liquidsoap/st.ini
else
  # If StereoTool is not used, remove its configuration from the liquidsoap script
  sed -i '/# StereoTool implementation/,/output.dummy(radioproc)/d' /etc/liquidsoap/radio.liq
fi

# Liquidsoap service installation
echo -e "${BLUE}►► Setting up Liquidsoap service${NC}"
rm -f /etc/systemd/system/liquidsoap.service
curl -sLo  /etc/systemd/system/liquidsoap.service "$LIQUIDSOAP_SERVICE_URL"
systemctl daemon-reload
if ! systemctl is-enabled liquidsoap.service; then
  systemctl enable liquidsoap.service
fi

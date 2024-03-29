#!/usr/bin/env bash

# Initialize the environment
clear
rm -f /tmp/functions.sh
if ! curl -s -o /tmp/functions.sh https://raw.githubusercontent.com/oszuidwest/bash-functions/main/common-functions.sh; then
  echo "*** Failed to download functions library. Please check your network connection! ***"
  exit 1
fi

source /tmp/functions.sh

# Configure environment
set_colors
are_we_root
is_this_linux
is_this_os_64bit
set_timezone Europe/Amsterdam

# Detect OS details
OS_ID=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
OS_VERSION=$(lsb_release -cs)
OS_ARCH=$(dpkg --print-architecture)

# Validate OS version
SUPPORTED_OS=("bookworm" "jammy")
if [[ ! " ${SUPPORTED_OS[*]} " =~ ${OS_VERSION} ]]; then
  printf "This script does not support '%s' OS version. Exiting.\n" "$OS_VERSION"
  exit 1
fi

# OS-specific configurations
if [ "$OS_VERSION" == "bookworm" ]; then
  install_packages silent software-properties-common
  apt-add-repository -y non-free
fi

# Set package URLs
BASE_URL="https://github.com/savonet/liquidsoap/releases/download/v2.2.4/liquidsoap_2.2.4"
PACKAGE_URL="${BASE_URL}-${OS_ID}-${OS_VERSION}-2_${OS_ARCH}.deb"

# User input for script execution
ask_user "DO_UPDATES" "y" "Do you want to perform all OS updates? (y/n)" "y/n"
ask_user "USE_ST" "n" "Do you want to use StereoTool for sound processing? (y/n)" "y/n"

# Perform OS updates if desired by user
if [ "$DO_UPDATES" == "y" ]; then
  update_os silent
fi

# Install necessary packages
install_packages silent fdkaac libfdkaac-ocaml libfdkaac-ocaml-dynlink
wget "$PACKAGE_URL" -O /tmp/liq_2.2.4.deb
apt -qq -y install /tmp/liq_2.2.4.deb --fix-broken

# Create directories and configure them
dirs=(/etc/liquidsoap /var/audio)
for dir in "${dirs[@]}"; do
  mkdir -p "$dir" && \
  chown liquidsoap:liquidsoap "$dir" && \
  chmod g+s "$dir"
done

# Download and install StereoTool if desired by user
if [ "$USE_ST" == "y" ]; then
  install_packages silent unzip
  mkdir -p /opt/stereotool
  wget https://download.thimeo.com/Stereo_Tool_Generic_plugin.zip -O /tmp/st.zip
  unzip -o /tmp/st.zip -d /tmp/
  EXTRACTED_DIR=$(find /tmp/* -maxdepth 0 -type d -print0 | xargs -0 ls -td | head -n 1)
  
  if [ "$OS_ARCH" == "amd64" ]; then
    cp "${EXTRACTED_DIR}/lib/Linux/IntelAMD/64/libStereoToolX11_intel64.so" /opt/stereotool/st_plugin.so
    wget https://download.thimeo.com/stereo_tool_cmd_64_1021 -O /opt/stereotool/st_standalone
  elif [ "$OS_ARCH" == "arm64" ]; then
    cp "${EXTRACTED_DIR}/lib/Linux/ARM/64/libStereoTool_arm64.so" /opt/stereotool/st_plugin.so
    wget https://download.thimeo.com/stereo_tool_pi2_64_1021 -O /opt/stereotool/st_standalone
  fi
  chmod +x /opt/stereotool/st_standalone
fi

# Generate and patch StereoTool config file
if [ "$USE_ST" == "y" ]; then
  /opt/stereotool/st_standalone -X /etc/liquidsoap/st.ini
  sed -i 's/^\(Whitelist=\).*$/\1\/0/' /etc/liquidsoap/st.ini
fi

# Fetch fallback sample and configuration files
wget https://upload.wikimedia.org/wikipedia/commons/6/66/Aaron_Dunn_-_Sonata_No_1_-_Movement_2.ogg -O /var/audio/fallback.ogg
wget https://raw.githubusercontent.com/oszuidwest/liquidsoap-ubuntu/main/radio.liq -O /etc/liquidsoap/radio.liq

# Comment out the StereoTool implementation if not enabled
if [ "$USE_ST" == "y" ]; then
  sed -i '/# StereoTool implementation/,/output.dummy(radioproc)/ s/^#//' "/etc/liquidsoap/radio.liq"
fi

# Install and set up service
rm -f /etc/systemd/system/liquidsoap.service
wget https://raw.githubusercontent.com/oszuidwest/liquidsoap-ubuntu/main/liquidsoap.service -O /etc/systemd/system/liquidsoap.service
systemctl daemon-reload
if ! systemctl is-enabled liquidsoap.service; then
  systemctl enable liquidsoap.service
fi

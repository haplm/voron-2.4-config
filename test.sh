#!/bin/bash

###### Configuration variables - please edit #########
KLIPPER_PATH=/home/pi/klipper
PICO_CONF=.config.pico
SPIDER_CONF=.config.spider
PICOTOOL_BIN_PATH=/home/pi/repos/picotool/build/picotool

###### Configuration end - DO NOT EDIT BELOW #########

#colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

function checkSudo() {
   if [ "$EUID" -ne 0 ]
      then echo -e "${RED}This script needs to be run with sudo to work properly, terminating...${ENDCOLOR}"
      exit 1
   fi
}

function pause(){
   read -p "$*"
}

function checkPicotool() {
   #check if picotool is installed, if it's correct binary, so you don't accidentaly reboot your machine
   if [ -f "$PICOTOOL_BIN_PATH" ]; then
   if ! objdump -s "$PICOTOOL_BIN_PATH" | grep -q picotool; then
      echo -e "${RED}Invalid path or picotool binary, install it from https://github.com/raspberrypi/picotool, exiting...${ENDCOLOR}"
      exit 1
   else
      echo -e "${GREEN}Picotool found, continuing...${ENDCOLOR}"
   fi
   else
      echo -e "${RED}Picotool not found, exiting...${ENDCOLOR}"
      exit 1
   fi  
}

function findPico() {
   #find pico
   if pico=$(find /dev/serial/by-id/ -name "*rp2040*" 2>/dev/null); then
      echo -e "${GREEN}Pico path: $pico ${ENDCOLOR}"
   elif pico_bootsel=$(udevadm info /dev/pico 2>/dev/null); then
      pico=$(echo "$pico_bootsel" | grep ACM)
      echo -e "${RED}Pico found in BOOTSEL mode, rebooting pico...${ENDCOLOR}"
      $PICOTOOL_BIN_PATH reboot
      sleep 5
      exec bash "$0"
   else
      echo -e "${RED}Pico not found, re-plug needed, exiting...${ENDCOLOR}"
      kill -INT $$
   fi
}

function check_udev_rule() {
   if [ ! -s /etc/udev/rules.d/99-pico.rules ]; then
      cat << EOF > /etc/udev/rules.d/99-pico.rules
      SUBSYSTEM=="tty", ATTRS{product}=="rp2040",SYMLINK+="pico"
EOF
      udevadm control --reload
      echo -e "${GREEN}udev rule for pico added and reloaded, continuing...${ENDCOLOR}"
   fi
}

function checkKlipper() {
    if [ ! -d  $KLIPPER_PATH ]; then
        echo -e "${RED}Klipper directory ${KLIPPER_PATH} doesn't exists, exiting${ENDCOLOR}"
        exit 1
    elif [ ! -f  $KLIPPER_PATH/$PICO_CONF ]; then
        echo -e "${RED}Pico config $KLIPPER_PATH/$PICO_CONF doesn't exists, exiting${ENDCOLOR}"
        exit 1
    elif [ ! -f $KLIPPER_PATH/$SPIDER_CONF ]; then
        echo -e "${RED}Spider config $KLIPPER_PATH/$SPIDER_CONF doesn't exists, exiting${ENDCOLOR}"
        exit 1
    else
        echo -e "${GREEN}All Klipper configs are present, Klipper directory valid${ENDCOLOR}"
    fi
}

pause "Press ENTER to start the update"

checkSudo
checkKlipper
checkPicotool
findPico
check_udev_rule
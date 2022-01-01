#!/bin/bash
#colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"
if [ "$EUID" -ne 0 ]
  then echo -e "${RED}Run script with sudo, exiting...${ENDCOLOR}"
  kill -INT $$
fi

cleanup () { (umount /mnt/pico; rm -rf /mnt/pico; rm /dev/pico; unset pico; unset fs; kill -INT $$) &>/dev/null; }

KLIPPER_PATH=#<path_to_klipper_folder>
PICOTOOL_BIN_PATH=#<path_to_picotool_binary>

#check if picotool is installed, if it's correct binary, so you don't accidentaly reboot your machine
if [ -f "$PICOTOOL_BIN_PATH" ]; then
  if ! objdump -s "$PICOTOOL_BIN_PATH" | grep -q picotool; then
    echo -e "${RED}Invalid path or picotool binary, install it from https://github.com/raspberrypi/picotool, exiting...${ENDCOLOR}"
    kill -INT $$
  else
    echo -e "${GREEN}Picotool found, continuing...${ENDCOLOR}"
  fi
else
  echo -e "${RED}Picotool not found, exiting...${ENDCOLOR}"
  kill -INT $$
fi  

#find pico
if pico=$(find /dev/serial/by-id/ -name "*rp2040*" 2>/dev/null); then
  echo -e "${GREEN}Pico found: $pico, continuing...${ENDCOLOR}"
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

#create udev rule for pico and reload udevadm
if [ ! -s /etc/udev/rules.d/99-pico.rules ]; then
  cat << EOF > /etc/udev/rules.d/99-pico.rules
SUBSYSTEM=="tty", ATTRS{product}=="rp2040",SYMLINK+="pico"
EOF
  udevadm control --reload
  echo -e "${GREEN}udev rule for pico added and reloaded, continuing...${ENDCOLOR}"
fi

#build pico fw
cd "$KLIPPER_PATH" || { echo -e "${RED} $KLIPPER_PATH does not exist, exiting...${ENDCOLOR}"; kill -INT $$; }
if ! grep -q "rp2040" "$(readlink -f "$KLIPPER_PATH")"/fw.pico; then
  echo -e "${GREEN}creating fw.pico config${ENDCOLOR}"
  cat << EOF > "$KLIPPER_PATH"/fw.pico
CONFIG_MACH_RP2040=y
CONFIG_BOARD_DIRECTORY="rp2040"
CONFIG_MCU="rp2040"
CONFIG_CLOCK_FREQ=12000000
CONFIG_USBSERIAL=y
CONFIG_FLASH_START=0x10000000
CONFIG_FLASH_SIZE=0x200000
CONFIG_RAM_START=0x20000000
CONFIG_RAM_SIZE=0x42000
CONFIG_STACK_SIZE=512
CONFIG_RP2040_SELECT=y
CONFIG_RP2040_USB=y
CONFIG_USB_VENDOR_ID=0x1d50
CONFIG_USB_DEVICE_ID=0x614e
CONFIG_USB_SERIAL_NUMBER_CHIPID=y
CONFIG_USB_SERIAL_NUMBER="12345"
CONFIG_HAVE_GPIO=y
CONFIG_HAVE_GPIO_ADC=y
CONFIG_HAVE_GPIO_SPI=y
CONFIG_HAVE_GPIO_HARD_PWM=y
CONFIG_HAVE_GPIO_BITBANGING=y
CONFIG_HAVE_STRICT_TIMING=y
CONFIG_HAVE_CHIPID=y
CONFIG_HAVE_STEPPER_BOTH_EDGE=y
CONFIG_INLINE_STEPPER_HACK=y
EOF
else 
  echo -e "${YELLOW}fw.pico already exists, skipping...${ENDCOLOR}"
fi
make -j"$(($(nproc)+1))" KCONFIG_CONFIG=fw.pico &>/dev/null

#mount pico fs
if ! stty -F "$pico" 1200; then
  echo -e "${RED}error with BOOTSEL, exiting...${ENDCOLOR}"; cleanup
fi
func_fs () { fs=$(readlink -f /dev/pico);export fs;}
echo -e "${YELLOW}waiting for fs...${ENDCOLOR}"
rgx="/dev/sd[a-zA-Z]1"
while ! [[ "$fs" =~ $rgx ]]; do func_fs; sleep 0.5; done
mount "$fs" -t vfat -o x-mount.mkdir /mnt/pico
if cp "$KLIPPER_PATH"/out/klipper.uf2 /mnt/pico; then
  echo -e "${GREEN}FW copied to pico, waiting for pico to reboot...${ENDCOLOR}"
  umount /mnt/pico
  while [ ! -e "$pico" ]; do sleep 0.1; done
  echo -e "${GREEN}Pico booted: $pico, exiting...${ENDCOLOR}"
else
  echo -e "${RED}there was an issue copying fw to pico, exiting...${ENDCOLOR}"
  cleanup
fi
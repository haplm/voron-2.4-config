#!/bin/bash
function pause(){
   read -p "$*"
}

pause "Press ENTER to start the update"

cd ../klipper

#Stop Klipper
echo "*** Stopping Klipper ***"
sudo service klipper stop

# Update Spider
echo "*** Updating Spider ***"
cp .config.spider .config
make clean
make
make flash FLASH_DEVICE=/dev/serial/by-id/usb-Klipper_stm32f446xx_4B0032000250563046353420-if00
pause 'Spider updated, press ENTER to continue with Pico'

#Update Pico
echo "*** Updating Pico ***"
cp .config.pico .config
make clean
make

echo "*** Putting Pico into BOOTSEL mode ***"
sudo stty -F /dev/serial/by-id/usb-Klipper_rp2040_E6609CB2D3243128-if00 1200
sleep 2

echo "*** Copying firmware ***"
sudo mount -t vfat /dev/sda1 /mnt/usb
sudo cp ./out/klipper.uf2 /mnt/usb/
sudo umount /mnt/usb

echo "*** Starting Klipper again ***"
sudo service klipper start

echo "*** Update Complete ***"
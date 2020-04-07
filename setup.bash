#!/bin/bash

# ---------------- Settings ----------------

# the URL where the minecraft server jar can be downloaded
URL=''

# where the server should be installed
SERVER_DIRECTORY='/srv/minecraft'

# ---------------- Setup ----------------

# update and install the required packages
sudo apt install screen openjdk-11-jre-headless || exit

# add a user for the minecraft server
sudo adduser --system --home "$SERVER_DIRECTORY" --group minecraft || exit

# download the minecraft server jar
sudo -u minecraft wget -O "$SERVER_DIRECTORY"/server.jar $URL || exit

# install the helper script
sudo cp minecraft.bash "$SERVER_DIRECTORY" || exit
sudo chown minecraft:minecraft "$SERVER_DIRECTORY"/minecraft.bash
sudo chmod +x "$SERVER_DIRECTORY"/minecraft.bash

# install the startup service
sudo cp minecraft.service /etc/systemd/system/minecraft.service
sudo systemctl daemon-reload
sudo systemctl enable minecraft.service;

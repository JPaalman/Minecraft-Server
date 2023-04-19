#!/bin/bash

# usage: [path_to_script]/minecraft.bash [functions_to_run]

# example: /srv/minecraft/minecraft.bash backup start console
# explanation: stop the server, make a backup, then start the server again and open the console

# example: /srv/minecraft/minecraft.bash "say Hello everyone!"
# explanation: send the message "Hello everyone!" to the server chat

# -------------------------------- settings --------------------------------

# amount of backups to keep before removing old ones
# set to 0 to keep all backups
BACKUP_AMOUNT=14

# where to store the backups
BACKUP_DIRECTORY="backup"

# JVM arguments to use when starting the server
JVM_ARGUMENTS="-Xms4G -Xmx4G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true"

# log all screen content to $WORLD_NAME.log
LOGGING=true

# kick messages
BACKUP_MESSAGE="The server is restarting to make a backup, and will be back online in a few minutes"
STOP_MESSAGE="The server is shutting down for maintenance"

# has to be the same as level-name in server.properties
WORLD_NAME="matigcraft"

# -------------------------------- functions --------------------------------

# check if the server is running
function status {
  screen -ls | grep -q -w "$WORLD_NAME" &&
    echo $WORLD_NAME is running && return 0 ||
    echo $WORLD_NAME is not running && return 1
}

# restore converted vanilla worlds to Bukkit, Spigot, Paper and similar server format
function convert_bukkit {
  [ -d "$WORLD_NAME"/"$WORLD_NAME"_nether ] && {
    mv "$WORLD_NAME"/"$WORLD_NAME"_nether ./
    mv "$WORLD_NAME"/DIM-1 "$WORLD_NAME"_nether
  }
  [ -d "$WORLD_NAME"/"$WORLD_NAME"_the_end ] && {
    mv "$WORLD_NAME"/"$WORLD_NAME"_the_end ./
    mv "$WORLD_NAME"/DIM1 "$WORLD_NAME"_the_end
  }
}

# convert Bukkit, Spigot, Paper and similar server worlds back to vanilla format
function convert_vanilla {
  [ -d "$WORLD_NAME"_nether ] && {
    mv "$WORLD_NAME"_nether/DIM-1 "$WORLD_NAME"
    mv "$WORLD_NAME"_nether "$WORLD_NAME"
  }
  [ -d "$WORLD_NAME"_the_end ] && {
    mv "$WORLD_NAME"_the_end/DIM1 "$WORLD_NAME"
    mv "$WORLD_NAME"_the_end "$WORLD_NAME"
  }
}

# if not running, start the server in the background
function start {
  status >/dev/null || {
    convert_bukkit
    $LOGGING && {
      printf "\n\n" >>"$WORLD_NAME".log && date >>"$WORLD_NAME".log
      screen -L -Logfile "$WORLD_NAME".log -DmS "$WORLD_NAME" java $JVM_ARGUMENTS -jar server.jar nogui &
      return
    }
    screen -DmS "$WORLD_NAME" java $JVM_ARGUMENTS -jar "$SERVER_NAME" nogui &
  }
}

# open the server console (CTRL + A, D to close)
function console {
  screen -d -r "$WORLD_NAME"
}

# if running, send a chat message to the server
# call with message
function say {
   status >/dev/null && screen -S "$WORLD_NAME" -X stuff "say $@"
}

# if running, stop the server and wait
# call with kick message, defaults to STOP_MESSAGE
function stop {
  status >/dev/null && {
    screen -S "$WORLD_NAME" -X stuff "kick @a ${1:-$STOP_MESSAGE}\n""stop\n"
    while status >/dev/null; do sleep 1; done
  }
}

# make a backup of the world
# call with kick message, defaults to BACKUP_MESSAGE
function backup {
  stop "${1:-$BACKUP_KICK_MESSAGE}"
  convert_vanilla
  mkdir -p "$BACKUP_DIRECTORY"
  zip -9 -r "$BACKUP_DIRECTORY"/"$WORLD_NAME"_"$(date +%Y_%m_%d_%H%M)".zip "$WORLD_NAME"
  
  # if $BACKUP_AMOUNT is larger than 0, attempt to clean old backups
  (("$BACKUP_AMOUNT" > 0)) || {
    find "$BACKUP_DIRECTORY"/"$WORLD_NAME"_*.zip |
    sort -r |
    cut -d $'\n' -f $((BACKUP_AMOUNT + 1))- |
    xargs rm
  }
}

# -------------------------------- main --------------------------------

# make sure to run as user 'minecraft'
[ "$USER" == minecraft ] || {
  sudo -u minecraft "$0" "$@"
  exit
}

# make sure to run from script directory
cd "$(dirname "$0")" || exit

# run all parameters as functions
for ARG in "$@"; do
  $ARG
done

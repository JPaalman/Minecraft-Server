#!/bin/bash

# usage: [path_to_script]/minecraft.bash [functions_to_run]
# example: /srv/minecraft/minecraft.bash "backup 10" start
# explanation: stop the server and make a backup in 10 minutes, then start the server again

# -------------------------------- settings --------------------------------

# enable if you are using Bukkit, Spigot or Paper
ALTERNATIVE_SERVER=true

# clean old backups after making a backup
AUTO_CLEAN=true

# amount of backups to keep when cleaning
BACKUP_AMOUNT=14

# where to store the backups
BACKUP_DIRECTORY="backup"

# JVM arguments to use when starting the server
JVM_ARGUMENTS="-Xms4G -Xmx4G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true"

# log all screen content to $WORLD_NAME.log
LOGGING=true

# messages
RESTART_KICK_MESSAGE="The server is restarting and making a backup, and will be back online in a few minutes"
RESTART_WARNING_MESSAGE="The server will restart to make a backup in X minute(s)"
STOP_KICK_MESSAGE="The server is shutting down for maintenance"
STOP_WARNING_MESSAGE="The server will shut down for maintenance in X minute(s)"

# has to be the same as level-name in server.properties
WORLD_NAME="matigcraft"

# -------------------------------- functions --------------------------------

# check if the server is running
function status {
  screen -ls | grep -q -w "$WORLD_NAME" \
  && echo $WORLD_NAME is running && return 0 \
  || echo $WORLD_NAME is not running && return 1
}

# if not running, start the server in the background
function start {
  status > /dev/null || {
    $LOGGING && {
      printf "\n\n" >> "$WORLD_NAME".log && date >> "$WORLD_NAME".log
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

# if running, stop the server and wait
# call with number to set as warning delay
# call with additional text to use as warning message, defaults to STOP_WARNING_MESSAGE
# call with additional text to use as kick message, defaults to STOP_KICK_MESSAGE
function stop {
  status > /dev/null && {
    [ -z "$1" ] || {
      T="${2:-$STOP_WARNING_MESSAGE}"
      screen -S "$WORLD_NAME" -X stuff "say ${T//X/$1}\n"
      sleep $(($1 * 60))
    }
    screen -S "$WORLD_NAME" -X stuff "kick @a ${3:-$STOP_KICK_MESSAGE}\n""stop\n"
    while status > /dev/null; do sleep 1; done
  }
}

# stop the server, then start the server
# call with number to set as warning delay
# call with additional text to use as warning message, defaults to RESTART_WARNING_MESSAGE
# call with additional text to use as kick message, defaults to RESTART_KICK_MESSAGE
function restart {
  stop "$1" "${2:-$RESTART_WARNING_MESSAGE}" "${3:-$RESTART_KICK_MESSAGE}"
  start
}

# make a backup of the world
# call with number to set as warning delay
# call with additional text to use as warning message, defaults to RESTART_WARNING_MESSAGE
# call with additional text to use as kick message, defaults to RESTART_KICK_MESSAGE
function backup {
  stop "$1" "${2:-$RESTART_WARNING_MESSAGE}" "${3:-$RESTART_KICK_MESSAGE}"
  $ALTERNATIVE_SERVER && convert
  mkdir -p "$BACKUP_DIRECTORY"
  zip -9 -r "$BACKUP_DIRECTORY"/"$WORLD_NAME"_"$(date +%Y_%m_%d_%H%M)".zip "$WORLD_NAME"
  $AUTO_CLEAN && clean
}

# convert Bukkit, Spigot and Paper worlds back to vanilla format
function convert {
  mv "$WORLD_NAME"_nether/DIM-1 "$WORLD_NAME"/DIM-1
  mv "$WORLD_NAME"_the_end/DIM1 "$WORLD_NAME"/DIM1
  rm -rf "$WORLD_NAME"_nether
  rm -rf "$WORLD_NAME"_the_end
}

# clean old backups
function clean {
  find "$BACKUP_DIRECTORY"/"$WORLD_NAME"*.zip |
  sort -r |
  cut -d $'\n' -f $((BACKUP_AMOUNT + 1))- |
  xargs rm
}

# update the server.jar
# call with URL to new server.jar
function update {
  stop
  rm server.jar
  wget -O server.jar $1
}

# -------------------------------- main --------------------------------

# make sure to run as user 'minecraft'
[ "$USER" == minecraft ] || { sudo -u minecraft "$0" "$@"; exit; }

# make sure to run from script directory
cd "$(dirname "$0")" || exit

# run all parameters as functions
for ARG in "$@"; do
  $ARG
done

#!/bin/bash

# ---------------- Settings ----------------

# Paths (relative to script directory)
WORLDNAME='matigcraft'  # should be the same as level-name in server.properties
BACKUP_DIRECTORY='backup'

# Messages
STOP_MESSAGE='The server is shutting down for maintenance'
BACKUP_MESSAGE='The server is making a backup, and will be back online shortly'

# Log all screen content to $WORLDNAME.log
LOGGING=true

# How many backups to keep when cleaning
BACKUP_AMOUNT=28

# Clean automatically after a backup
AUTOCLEAN=true

# Which JVM arguments to use when starting the server
JVM_ARGUMENTS='-Xms6G -Xmx6G -XX:+UnlockExperimentalVMOptions -XX:+UseZGC'

# ---------------- Functions ----------------

# Start the server inside a screen session
function start() {
  $LOGGING && date >> "$WORLDNAME".log
  screen $($LOGGING && echo -L -Logfile "$WORLDNAME".log) -DmS "$WORLDNAME" java $JVM_ARGUMENTS -jar server.jar nogui &
}

# Check if the server is running
function status() {
  screen -ls | grep -q -w "$WORLDNAME" \
  && echo $WORLDNAME is running && return 0 \
  || echo $WORLDNAME is not running && return 1
}

# Open the server console
function console() {
  screen -d -r "$WORLDNAME"
}

# Stop the server
function stop() {
  status > /dev/null && {
    screen -S "$WORLDNAME" -X stuff "kick @a ${1:-$STOP_MESSAGE}\n""stop\n"
    while status > /dev/null; do sleep 1; done
    $LOGGING && printf "\n\n" >> "$WORLDNAME".log
  }
}

# Make a backup of the world
function backup() {
  mkdir -p "$BACKUP_DIRECTORY"
  status && stop "$BACKUP_MESSAGE"
  local DATE=$(date +%Y_%m_%d_%H%M)
  zip -9 -r "$BACKUP_DIRECTORY"/"$WORLDNAME"_"$DATE".zip "$WORLDNAME"
  $AUTOCLEAN && clean
}

# Clean old backups
function clean() {
  find "$BACKUP_DIRECTORY"/"$WORLDNAME"* |
  sort -r |
  cut -d $'\n' -f $((BACKUP_AMOUNT + 1))- |
  xargs rm
}

# ---------------- Main ----------------

# make sure to run as user 'minecraft'
[ "$USER" == minecraft ] || { sudo -u minecraft "$0" "$@"; exit; }

# make sure to run from script directory
cd "$(dirname "$0")" || exit

# run all parameters as functions
for ARG in "$@"; do
  $ARG
done

#!/bin/bash

# usage: [path_to_script]/minecraft.bash [functions_to_run]
# example: /srv/minecraft/minecraft.bash start console

# ---------------- settings ----------------

# paths (relative to script directory)
WORLDNAME="matigcraft" # should be the same as level-name in server.properties
BACKUP_DIRECTORY="backup"

# messages
STOP_KICK_MESSAGE="The server is shutting down for maintenance"
BACKUP_KICK_MESSAGE="The server is making a backup, and will be back online in a few minutes"
BACKUP_WARNING_MESSAGE="The server will go offline to make a backup in X minute(s)"

# JVM arguments to use when starting the server
JVM_ARGUMENTS="-Xms4G -Xmx4G -XX:+UnlockExperimentalVMOptions -XX:+UseZGC"

# amount of backups to keep when cleaning
BACKUP_AMOUNT=14

# clean automatically after a backup
AUTOCLEAN=true

# log all screen content to $WORLDNAME.log
LOGGING=true

# ---------------- functions ----------------

# check if the server is running
function status {
  screen -ls | grep -q -w "$WORLDNAME" \
  && echo $WORLDNAME is running && return 0 \
  || echo $WORLDNAME is not running && return 1
}

# if not running, start the server in the background
function start {
  status > /dev/null || {
    $LOGGING && printf "\n\n" >> "$WORLDNAME".log && date >> "$WORLDNAME".log
    screen $($LOGGING && echo -L -Logfile "$WORLDNAME".log) -DmS "$WORLDNAME" java $JVM_ARGUMENTS -jar server.jar nogui &
  }
}

# if running, stop the server and wait
# call with text argument to display text as kick message
function stop {
  status > /dev/null && {
    screen -S "$WORLDNAME" -X stuff "kick @a ${1:-$STOP_KICK_MESSAGE}\n""stop\n"
    while status > /dev/null; do sleep 1; done
  }
}

# open the server console (CTRL + A, D to close)
function console {
  screen -d -r "$WORLDNAME"
}

# make a backup of the world
# call with number argument to display warning message and wait for number in minutes
function backup {
  mkdir -p "$BACKUP_DIRECTORY"
  [ -z "$1" ] || screen -S "$WORLDNAME" -X stuff "${BACKUP_WARNING_MESSAGE//X/$1}" && sleep $(($1 * 60))
  stop "$BACKUP_KICK_MESSAGE"
  zip -9 -r "$BACKUP_DIRECTORY"/"$WORLDNAME"_"$(date +%Y_%m_%d_%H%M)".zip "$WORLDNAME"
  $AUTOCLEAN && clean
}

# clean old backups
function clean {
  find "$BACKUP_DIRECTORY"/"$WORLDNAME"* |
  sort -r |
  cut -d $'\n' -f $((BACKUP_AMOUNT + 1))- |
  xargs rm
}

# ---------------- main ----------------

# make sure to run as user 'minecraft'
[ "$USER" == minecraft ] || { sudo -u minecraft "$0" "$@"; exit; }

# make sure to run from script directory
cd "$(dirname "$0")" || exit

# run all parameters as functions
for ARG in "$@"; do
  $ARG
done

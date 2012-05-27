#!/bin/bash

if [ -z $1 ]; then
  read -p "Where are you wanting to connect? " s
else
  s=$1
fi

if [ -z $(echo $s | grep -P "^(([A-Za-z0-9]+\.)+[A-Za-z]+|([0-9]{1,3}\.){3}[0-9]{1,3})(:[0-9]+)?$") ]; then
  echo "Are you sure this is a valid server name/IP ($s)?"
  exit
elif [ -z $(echo $s | grep -P "(:[0-9]+)$") ]; then
  server=$s
  port=6667
else
  server=$(echo $s | cut -d: -f1)
  port=$(echo $s | cut -d: -f2)
fi
unset s

if [ -z $2 ]; then
  nick=bashbot
else
  nick=$2
fi

#set up file descriptor
f=/tmp/irc.$(date +%s)
exec 3>$f

#remove file descriptor
exec 3>&-
rm -f $f

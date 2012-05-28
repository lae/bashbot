#!/bin/bash

#check for our primary dependency lol
which nc 2>&1>/dev/null
if [ $? -eq 1 ]; then
  echo "Could not locate netcat."
  exit 1
fi

if [ -z $1 ]; then
  read -p "Where are you wanting to connect? " s
else
  s=$1
fi

if [ -z $(echo $s | grep -P "^(([A-Za-z0-9]+\.)+[A-Za-z]+|([0-9]{1,3}\.){3}[0-9]{1,3})(:[0-9]+)?$") ]; then
  echo "Are you sure this is a valid server name/IP ($s)?"
  exit 1
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

startup() {
  #set up file descriptor
  f=/tmp/irc.$(date +%s)
  exec 3>$f
  echo -e "NICK $nick\nUSER $nick $nick $server :bashbot by musee" >&3
  #set up capture from irc
  log=/tmp/irc-reply.$(date +%s)
  exec 4>$log
  #open connection to irc
  tail -f $f | nc $server $port >&4 &
  nc_pid=$!
  parselog &
}

quit() {
  echo -e "\nQuitting..."
  kill -6 $nc_pid 2>&1>/dev/null
  #remove file descriptors
  exec 4>&-
  rm -f $log
  exec 3>&-
  rm -f $f
  exit $?
}

parselog() {
  tail -f $log |
  while read l
  do
    echo "$l" | grep ^: 2>&1>/dev/null
    if [ $? -eq 0 ]; then
      echo "$l" | grep -P "^:$server [0-9]{3} " 2>&1>/dev/null
      if [ $? -eq 0 ]; then
        r="${l##:$server }"
        rc=${r%% $nick*}
        r="`echo "$r" | sed "s/$nick //"`"
        rp="${r#[0-9]* }"
        case $rc in
        *)
          m="-?- $r"
        ;;
        esac
      else
        m="$l"
      fi
    else
      m="$l"
    fi
    echo "$m"
  done
}

# trap interrupt
trap quit SIGINT

startup

while read
do
  echo $REPLY >&3
done

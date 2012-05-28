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
  echo "while true; do sleep 120; echo 'PONG :bash your face!' >&3; done" | bash &
  channels=
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
        00[1-5])
          m="# ${rp##*:}"
        ;;
        2[56][0-9])
          m="# `echo $rp | sed "s/://g"`"
        ;;
        353)
          m="users in $(echo $rp | awk '{print $2}'): ${rp##*:}"
        ;;
        366)
        ;;
        37[256])
          m="# ${rp##*:}"
        ;;
        *)
          m="-?- $r"
        ;;
        esac
      else
        t=$(echo $l | awk '{print $2}')
        c=$(echo $l | awk '{print $3}')
        case $t in
        "PRIVMSG")
          u="$(echo $l | cut -d! -f1 | cut -d: -f2)"
          pm="$(echo $l | cut -d: -f3)"
          if [ "${c###*}" == "" ]; then
            m="($c) <$u> $pm"
            if [ "${pm##.*}" == "" ]; then
              echo "${pm##.}" "$u" "$c"
              botcmd "${pm##.}" "$u" "$c" &
            elif [ "${pm##$nick*}" == "" ]; then
              echo "$(echo ${pm##$nick} | awk '{print $2}')" "$u" "$c" &
            fi
          else
            m="~> $u: $pm"
          fi
        ;;
        *)
          m="\$ $l"
        esac
      fi
    else
      m="$l"
    fi
    if [ ! "$m" = "" ]; then echo "$m"; unset m;fi
  done
}

readcmd() {
  if [ "${1%%/*}" == "" ]; then
    cmd=$(echo "${1#/}" | awk '{print $1}')
    params="${1#/$cmd }"
    case $cmd in
    "join")
      c="$params"
      echo $channels | grep $c 2>&1>/dev/null
      if [ $? -eq 1 ]; then
        echo "JOIN $c" >&3
        channels="${channels}$c\n"
        curchan="$c"
      fi
    ;;
    selchan)
      $c="$params"
      echo $channels | grep $c 2>&1>/dev/null
      if [ $? -eq 0 ]; then
        curchan=$c
      else
        echo "Silly bot, you're not in $c."
      fi
    ;;
    bash)
      $params | while read
      do
        echo "PRIVMSG $curchan :$REPLY" >&3
      done
    ;;
    *)
      echo "Invalid command - $1"
    esac
  else
    if [ ! $curchan ]; then
      echo "Join a channel first."
    else
      echo "PRIVMSG $curchan :$1" >&3
    fi
  fi
}

botcmd() {
  cmd="$(echo $1 | awk '{print $1}')"
  params="${1##$cmd }"
  u="$2"
  c="$3"
  echo $cmd $params $u $c
  case $cmd in
  "hi")
    m="hi $u! "
  ;;
  "fag")
    toilet --gay -f mono9 "$params" | while read;do echo "PRIVMSG $c :$REPLY" >&3;done
  ;;
  *)
    m='wat'
  ;;
  esac
  if [ $(echo "$m" | wc -l) -ge 1 ]; then
    echo $m | while read
    do
      echo "PRIVMSG $c :$REPLY" >&3
    done
  else
    echo "PRIVMSG $c :$m" >&3
  fi
  return 0
}

# trap interrupt
trap quit SIGINT

startup

while read
do
  readcmd "$REPLY"
done
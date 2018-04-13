#!/bin/bash

# Logfile
logFile=~/checkIp.log
rm -f $logFile

# Host list definition
HOSTNAME_LIST="@server@"

DNS_SERVER_LIST="1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4"

#Configuration
NO_IP_USER="@noip_user@"
NO_IP_PASSWD="@noip_pwd@"
NO_IP_DOMAIN="@noip_domain@"
NO_IP_UPDADD="http://dynupdate.no-ip.com/nic/update?hostname=@HOSTNAME@&myip=@IP@"
NO_IP_USERAGENT="No-IP_Updater_$HOSTNAME/1.0_$NO_IP_USER"
NO_IP_REQUIRED_INTERVAL=30 # days

MAILTO="@mailto@"

IP_HISTORY=50
IP_HISTORY_FILE=~/.IPAddress

DATE_FORMAT=%Y/%m/%dT%H:%M:%S

CHECK_IP_URL="checkip.dyndns.org        \
              bot.whatismyipaddress.com \
              myglobalip.com            \
              www.tracemyip.org         \
              ifconfig.me"

#Log message function
logmsg() {

  echo "$(date +%Y/%m/%d-%H:%M:%S) - $@"

  if [ -n "$logFile" ]; then
    echo "$(date +%Y/%m/%d-%H:%M:%S) - $@" >> $logFile
  fi

}

# Getting current IP address
logmsg "Getting current IP Address: "
while [ "${currentIPAddress}" == "" ]; do

  for check_IP_url in $CHECK_IP_URL; do

    checkIP=$(curl -s -A \"${NO_IP_USERAGENT}\" ${check_IP_url} | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')
    logmsg "   $check_IP_url: $checkIP"

    if [ "$checkIP" != "" ]; then
      if [ "$checkIP" == "$currentIPAddress" ]; then
        break
      else
        currentIPAddress=$checkIP
      fi
    fi
  done
done

logmsg "Current IP Address: $currentIPAddress"

# Getting previous IP address
previousIPAddress=$(tail -n 1 $IP_HISTORY_FILE | awk '{print $NF}')

# Getting previous IP address
logmsg "Getting previous IP Address: "
for hostname in $HOSTNAME_LIST; do
  for dnsserver in $DNS_SERVER_LIST; do
    checkIP=$(nslookup -timeout=1 $hostname.$NO_IP_DOMAIN $dnsserver | grep Name: -A 2 | grep Address: | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')
    logmsg "   $dnsserver: $checkIP"

    if [ "$checkIP" != "" ]; then
      if [ "$checkIP" == "$previousIPAddress" ]; then
        break
      else
        previousIPAddress=$checkIP
      fi
    fi
  done
done

logmsg "Previous IP Address: $previousIPAddress"


# Checking time
currentTime=$(date +'%s')
if [ -f $IP_HISTORY_FILE ]; then

  # Loading last update date
  lastUpdTime=$(date -d $(tail -n 1 ${IP_HISTORY_FILE} | awk '{print $1}') +'%s')
  lastUpdTimeDiff=$((($currentTime - $lastUpdTime)/86400))

  # Checking last update time difference
  if [ "$lastUpdTimeDiff" -ge "$NO_IP_REQUIRED_INTERVAL" ]; then
    logmsg "Maximum required update interval exceed. Forcing IP update..."
    forceUpd=true
  else
    forceUpd=false
  fi

else
  logmsg "Last update IP file ($IP_HISTORY_FILE) not found. Forcing IP update..."
  forceUpd=true
fi

# Checking with previous IP address
if [ "$currentIPAddress" != "$previousIPAddress" ] || [ "$forceUpd" == true ]; then

  for currentHost in $HOSTNAME_LIST; do 

    # Store IP address and assuring max history records
    echo "$(date +${DATE_FORMAT}) $lastUpdTimeDiff $currentHost $currentIPAddress" >> $IP_HISTORY_FILE
    tail -n $IP_HISTORY $IP_HISTORY_FILE >/tmp/ipTmpHistory; mv /tmp/ipTmpHistory $IP_HISTORY_FILE

    # Update no-ip.org
    updateAddress=${NO_IP_UPDADD/@HOSTNAME@/${currentHost}.${NO_IP_DOMAIN}}
    updateAddress=${updateAddress/@IP@/$currentIPAddress}

#    updCmd="wget -d -O - -o $LOG_FILE --user-agent=\"$NO_IP_USERAGENT\" --http-user=$NO_IP_USER --http-password=$NO_IP_PASSWD $updateAddress"
    updCmd="curl -ks -u ${NO_IP_USER}:${NO_IP_PASSWD} -A \"${NO_IP_USERAGENT}\" $updateAddress"

    logmsg "Updating IP Address to DDNS Service... "
#   logmsg $updCmd
    updStatus=$($updCmd)

    strStatus=$(echo $updStatus | awk '{ print $1 }')
    case $strStatus in
      "good")
          logLine="(good) DNS hostname(s) successfully updated to ${currentIPAddress}."
          ;;
      "nochg")
          logLine="(nochg) IP address is current: ${currentIPAddress}; no update performed."
          ;;
      "nochglocal")
          logLine="(nochglocal) IP address is current: $currentIPAddress; no update performed."
          ;;
      "nohost")
          logLine="(nohost) Hostname supplied does not exist under specified account. Revise config file."
          ;;
      "badauth")
          logLine="(badauth) Invalid username password combination."
          ;;
      "badagent")
          logLine="(badagent) Client disabled - No-IP is no longer allowing requests from this update script."
          ;;
      "!donator")
          logLine="(!donator) An update request was sent including a feature that is not available."
          ;;
      "abuse")
          logLine="(abuse) Username is blocked due to abuse."
          ;;
      "911")
          logLine="(911) A fatal error on our side such as a database outage. Retry the update in no sooner than 30 minutes."
          ;;
      *)
          logLine="(error) Could not understand the response from No-IP. The DNS update server may be down. $updStatus"
          ;;
    esac

    logmsg $logLine

    mail -s "$currentHost: New IP address detected $currentIPAddress" -a "From: $currentHost" $MAILTO < $logFile

  done

else

  logmsg "No IP change detected: $currentIPAddress"

fi




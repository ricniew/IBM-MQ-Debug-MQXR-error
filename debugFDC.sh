#!/bin/bash
# R Niewolik IBM Expertise Connect Team EMEA
# Execution:
#    ./scritname {-q qmgr_name, -h MQ Home, -e FDC error dir, -p MQXR port} 

#
function usage()
{
 echo "Syntax is:"
 echo "   ./scriptname {-q qmgr_name, -h MQ Home, -e FDC error dir, -p MQXR port}"
 echo "Example:"
 echo "   ./scriptname -q MYQMGR -h /opt/mqm -e /var/mqm/errors -p 1883"
 return 0 
}

function trap_ctrlc ()
{
  echo 
  echo "WARNING: - trap_ctrlc - CTRL-C caught...performing clean up"
  cleanup 
  echo "INFO: - trap_ctrlc - Procedure aborted by user"
  exit 2
}

function cleanup()
{
  echo 
  echo "INFO: - cleanup - Stop MQXR chl trace: 'controlMQXRChannel.sh -qmgr=$QMGR_NAME -port=$QMGR_MQXR_PORT -mode=stoptrace'"
  controlMQXRChannel.sh -qmgr=$QMGR_NAME -port=$QMGR_MQXR_PORT -mode=stoptrace
  
  con=1
  while [ $con -eq 1 ]
  do 
    echo "INFO: - cleanup - Do you want to delete the tcpdump output file if it was created already (y/n; 'n' is default)?  -> "
    read ans
    if [ "$ans" == "y" ] ; then 
        if [ -f $OUT ] ; then
            echo "INFO: - cleanup - Delete tcpdump output file '$OUT'"
            rm -f $OUT
        fi
        con=0
    elif  [[ $ans == "n"  ||  -z "$ans" ]]; then
        echo "INFO: - cleanup - Tcpdump output file NOT deleted"
        con=0
    else
        echo "ERROR: Bad input. Only 'y' or 'n' allowed"
    fi
  done

  return 0
} 

function check_param ()
{
  if [ "$QMGR_NAME" == "" ] ; then
      echo "ERROR: - check_param - Option '-q' not set ('$QMGR_NAME')" 
      usage; exit 1
  elif [ "$FDCDIR" == "" ] ; then
      echo "ERROR: - check_param - Option '-e' not set" 
      usage; exit 1
  elif [ "$MQHOME" == "" ] ; then
      echo "ERROR: - check_param - Option '-h' not set" 
      usage; exit 1
  elif [ "$QMGR_MQXR_PORT" == "" ] ; then
      echo "ERROR: - check_param - Option '-p' not set" 
      usage; exit 1
  fi
  #echo "ps -ef | grep -v grep | grep -i \"$QMGR_NAME\" > /dev/null" 
  ps -ef | grep -v "grep" | grep -v "$0" | grep -i $QMGR_NAME > /dev/null
  if [ $? -ne 0 ] ; then
      echo "ERROR: - check_param - QMGR '$QMGR_NAME' not running'" ; exit 1
  fi 
  if [ ! -f $FDCDIR/AMQERR01.LOG ]; then   
      echo "ERROR: - check_param - Error log folder '$FDCDIR' does not exists'" ; exit 1
  elif  [ ! -d $MQHOME ] ; then
      echo "ERROR: - check_param - MQ HOME  '$MQHOME' does not exists'" ; exit 1
  elif ! [[ "$QMGR_MQXR_PORT" =~ ^[0-9]+$ ]] ; then
      echo "ERROR: - check_param - '$QMGR_MQXR_PORT' is not a number" ; exit 1
  fi
  netstat -an | grep ":$QMGR_MQXR_PORT" | grep LISTEN > /dev/null
  if [ $? -ne 0 ] ; then
      echo "ERROR: - check_param - Port '$QMGR_MQXR_PORT' is not in LISTEN status'" ; exit 1
  fi 

}

# ----
# MAIN
# ----
while getopts "q:h:p:e:" OPTS
do
  case $OPTS in
    q) QMGR_NAME=${OPTARG} ;;
    p) QMGR_MQXR_PORT=${OPTARG} ;;
    h) MQHOME=${OPTARG} ;;
    e) FDCDIR=${OPTARG} ;;
    *) echo "ERROR - main - You have used a not valid switch"; usage ; exit ;;
  esac
done

trap "trap_ctrlc" 2

check_param
ERROR_TO_CAPTURE="AMQXR1003E"

echo "INFO: - main - QMGR_NAME=$QMGR_NAME"
echo "INFO: - main - QMGR_MQXR_PORT=$QMGR_MQXR_PORT"
echo "INFO: - main - FDC log dir : $FDCDIR" 
echo "INFO: - main - MQHOME : $MQHOME" 
PATH=$PATH:$MQHOME/mqxr/bin
export PATH

# getting local ip port where QMGR_MQXR_PORT is used
#echo "---- netstat -an| grep \":$QMGR_MQXR_PORT\" | grep  ESTABLISHED| awk '{print \$4}'| sort -u| cut -d':' -f1"
IP=`netstat -an| grep ":$QMGR_MQXR_PORT" | grep -v ESTABLISHED| awk '{print $4}'| sort -u| cut -d':' -f1`
# creating tcpdump output filename
OUT=$FDCDIR/tcpdump_$(hostname)_$(date +"%Y_%m_%d_%I_%M_%p").pcap

echo "INFO: - main - IP port used to connect : $IP" 
echo "INFO: - main - TCPDUMP output: $OUT" 
sleep 3

echo "INFO: - main - Remove existing FDC files"
rm -fR $FDCDIR/*.FDC
if [ $? -ne 0 ] ; then 
    echo "ERROR: - main - Failed to delete old *.FDC files (rm -fR $FDCDIR/*.FDC)"
    exit 1
fi

echo "INFO: - main - Start tcpdump trace: 'tcpdump -i any -s 0 -w $OUT dst $IP and port $QMGR_MQXR_PORT' " 
tcpdump -i any -s 0 -w $OUT dst $IP and port $QMGR_MQXR_PORT &
sleep 2
jobs |grep "Running" > /dev/null
if [ $? -ne 0 ]  ; then 
    echo "ERROR: - main - Command tcpdump failed"
    exit 1
fi
sleep 2

echo "INFO: - main - Start MQXR chl trace: 'controlMQXRChannel.sh -qmgr=$QMGR_NAME -port=$QMGR_MQXR_PORT -mode=starttrace'"
controlMQXRChannel.sh -qmgr=$QMGR_NAME -port=$QMGR_MQXR_PORT -mode=starttrace 
if [ $? -ne 0 ] ; then 
    echo "ERROR: - main - Script controlMQXRChannel.sh failed (starttrace)"
    exit 1
fi
echo "INFO: - main - Waiting for error \"$ERROR_TO_CAPTURE\" to be raised"
i=1
while [ $i -eq 1 ]
do                                   
     sleep 2  
     echo -n .
     if grep "$ERROR_TO_CAPTURE" $FDCDIR/*.FDC 2> /dev/null
     then  
         i=0
         echo "INFO: - main - \"$ERROR_TO_CAPTURE\" error was captured"
         sleep 5                               
         echo "INFO: - cleanup - Stop MQXR chl trace: 'controlMQXRChannel.sh -qmgr=$QMGR_NAME -port=$QMGR_MQXR_PORT -mode=stoptrace'"
         controlMQXRChannel.sh -qmgr=$QMGR_NAME -port=$QMGR_MQXR_PORT -mode=stoptrace | tee /tmp/controlMQXRChannel.sh.out
         if [ $? -ne 0 ] ; then 
             echo "ERROR: - main - Script controlMQXRChannel.sh failed (stoptrace)"
             exit 1
         fi
         echo "INFO: - main - stop tcpdump trace"
         PID=$(/usr/bin/ps -ef | grep tcpdump | grep $$ | grep -v grep | grep -v ".sh" | awk '{print $2}')
         kill -9 $PID
     fi                                   
done 
echo "INFO: - main - TCPDUMP output files is= $OUT'"
echo "INFO: - main - end"
exit 0

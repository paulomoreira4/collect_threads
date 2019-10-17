#!/bin/bash

# Change log
# v1.0  * initial version

#Configurable variables -- script usually does a decent job at figuring these out
WL_ADMIN_SERVER_NAME="AdminServer"
WL_MANAGED_SERVER_NAME=""
PROCESS_USER=""
LOGDAYS=30
LOGS_FOLDER_ADMIN_SERVER=""

VERSION="1.0"

# prepare for execution

if [ ! -f /etc/sysconfig/outsystems ]; then
	echo "OutSystems Platform is not installed on this server. Cancelling."
	exit
fi

if [ $(whoami) != "root" ]; then
	echo "This script must be executed as root."
	exit
fi

source /etc/sysconfig/outsystems
CP='cp -p'
DIR=$(mktemp -d)
chmod 777 $DIR
touch $DIR/errors.log
chmod 777 $DIR/errors.log

LOGS_FOLDER=""

JAVA_BIN=$(dirname "$(readlink /proc/$PROCESS_PID/exe)")
if [ -f $JAVA_BIN/../../bin/java ]; then
	JAVA_BIN="$JAVA_BIN/../../bin/"
fi

echo "OutSystems Services Thread Collector v$VERSION" >> $DIR/toolinfo
echo >> $DIR/toolinfo
echo "OutSystems platform Directory: $OUTSYSTEMS_HOME" >> $DIR/toolinfo

if [ -h /opt -o -h /opt/outsystems -o -h /opt/outsystems/platform -o -h /opt/outsystems/platform/share ]; then
	echo >> $DIR/toolinfo
	echo "WARNING: OutSystems is installed on a symlink." >> $DIR/toolinfo
	echo "  From version 9.1 this may make it impossible to publish modules with web references." >> $DIR/toolinfo
	echo >> $DIR/toolinfo
fi

echo "Java Directory: $JAVA_BIN"  >> $DIR/toolinfo
echo "$APPSERVER_NAME user: $PROCESS_USER" >> $DIR/toolinfo
echo "$APPSERVER_NAME pid: $PROCESS_PID" >> $DIR/toolinfo
echo "$APPSERVER_NAME logs folder: $LOGS_FOLDER" >> $DIR/toolinfo
cat $DIR/toolinfo
echo

echo "Gathering OutSystems Services info ..."
for SERVICE_INFO in $(su outsystems -c "$JAVA_HOME/bin/jps -l" | grep outsystems.hubedition | tr ' ' '|')
do
	eval $(echo "$SERVICE_INFO" | gawk -F "|" '{print "SERVICE_PID="$1";SERVICE_PROCESS_NAME="$2}')
	if [ -f $JAVA_HOME/bin/jrcmd ]; then
		su outsystems - -s /bin/bash -c "$JAVA_HOME/bin/jrcmd $SERVICE_PID print_threads > $DIR/threads_"$SERVICE_PROCESS_NAME".log 2>> $DIR/errors.log"
	else
		su outsystems - -s /bin/bash -c "$JAVA_HOME/bin/jstack $SERVICE_PID > $DIR/threads_"$SERVICE_PROCESS_NAME".log 2>> $DIR/errors.log"
	fi
	pmap -d $SERVICE_PID > $DIR/pmap_$SERVICE_PROCESS_NAME
done
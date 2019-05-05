#!/bin/bash

function killpid {
	pid=$1
	sudo kill $pid >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "Failed killing pid $pid"
	else
		while true; do
			sleep 1
			sudo kill -n 0 $pid >/dev/null 2>&1
			if [ $? -ne 0 ]; then
				break
			fi
			echo "Waiting pid $pid exit"
		done
	fi
}

export PATH=/usr/local/bin:/usr/bin:/bin
BOOTTIME=$(date +%Y%m%d%H%M%S)
export BOOTTIME

echo "bleAoA is starting($BOOTTIME)..."

MYDIR=$(realpath $(dirname $0))
echo "My directory is $MYDIR"
cd $MYDIR
echo "Changed to directory $MYDIR"

./service_bleAoA.py >/dev/null 2>&1 &
./service_BLEcomms.py >/dev/null 2>&1 &

sleep 1
PID_bleAoA=`ps aux|grep python|grep 'service_bleAoA.py'|grep -v grep|awk '{print $2}'`
echo "Service ble AoA started($PID_bleAoA)"
PID_BLEcomms=`ps aux|grep python|grep 'service_BLEcomms.py'|grep -v grep|awk '{print $2}'`
echo "Service ble comms started($PID_BLEcomms)"

# Cleanup after foreground process exited

kill $PID_bleAoA
echo "bleAoA stopped."
kill $PID_BLEcomms
echo "ble comms stopped."

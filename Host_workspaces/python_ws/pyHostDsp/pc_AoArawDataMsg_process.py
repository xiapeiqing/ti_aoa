#!/usr/bin/env python
PcBinaryLog = False # format 7c1024hc is wrong
wait4SignalProcessingDoneTimeoutSec = 2000
import CONSTaoa
import logging
#DEBUG
#INFO
#WARNING
#ERROR
#CRITICAL
loglevel = logging.INFO
logdatefmt = "%Y-%m-%d %H:%M:%S"
logfmt = "%(asctime)s %(filename)s:%(lineno)d %(levelname)s %(message)s"
logging.basicConfig(format=logfmt, level=loglevel, datefmt=logdatefmt)

import os,sys
from datetime import datetime
import time
import threading
from collections import deque
try:
    from Queue import Queue
except:
    from queue import Queue
import sys
import getopt
import bluetooth
import subprocess
import pexpect as ep
import re
import bluetoothutils
import mqttutils
import transportLayer
import ctypes
import struct
if 2 == sys.version_info.major:
    pythonVer = 2
else:
    pythonVer = 3

MQTT_HOST = mqttutils.MQTT_HOST_IP
MQTT_PORT = mqttutils.MQTT_PORT_NUMBER
MQTT_NAME = "PC_AOA_PROC"

btRcvStr = b""
# max duration in sec before we output anything we have in Rx buffer
# even before the line end "\n" is received
MAXDURATION2SHOW_RXBUF_S = 20
LastRcvDatDumpTimeS = time.time()
index = 0

def stateTransition(newState):
    global mState, mStateEntryEvt, m_entryTimeS
    mStateEntryEvt = True
    old_mState = mState
    mState = newState
    logging.info('state:{}=>{}'.format(old_mState,mState))
    m_entryTimeS = time.time()
    
mState = CONSTaoa.State_PCuninitialized
mStateEntryEvt = True
def handle_mqtt_continuously():
    global collectionii, COLLECTIONCNT, btRcvStr, LastRcvDatDumpTimeS, currBLDCctrlcmd, index, m_entryTimeS, mState, m_entryTimeS, mStateEntryEvt
    stateTransition(CONSTaoa.State_PCwait4matlabCmd)
    global mqueue
    BLDCctrlCmd = 0
    while True:
        if mState == CONSTaoa.State_PCsendBLDCrotate_startCMD:
            if mStateEntryEvt:
                mStateEntryEvt = False      
            mqproxy.publish(mqttutils.TOPIC_PcCmd,'{}'.format(BLDCctrlCmd))
            stateTransition(CONSTaoa.State_PCwait4MqttDoneEvt)
        elif mState == CONSTaoa.State_PCwait4MqttDoneEvt:
            if mStateEntryEvt:
                mStateEntryEvt = False      
            if PcBinaryLog:
                binFilename = './datapkt_{:07d}.bin'.format(index)
                hbinaryFile = open(binFilename, 'w+b')
            while not mqueue.empty():
                # source (1)
                _client, _userdata, msg = mqueue.get()
                if msg.topic == mqttutils.TOPIC_EmbdRAW and msg is not None:
                    # mosquitto_pub -d -t "/m2cambot/MEAS/BleAoARawDatPub" -m "DONE" -h 192.168.31.211
                    if len(msg.payload) > 100: # I don't why Last will is always received first
                        logging.info('TOPIC_EmbdRAW')
                        if PcBinaryLog:
                            logging.info('receive data:{}'.format(msg.payload))
                            print(len(msg.payload))  # 1032
                            values = struct.unpack('<7c1024hc', msg.payload)
                            # write to file and call matlab to process
                            hbinaryFile.write(values)
                elif msg.topic == mqttutils.TOPIC_RPiStatus:
                    # OK to send next turn cmd
                    strdata = msg.payload.decode("utf-8").strip()
                    logging.info("mqtt rcvd msg:{}".format(strdata))
                    if strdata.startswith(CONSTaoa.RPiStatus_LUTdatasetRdy):
                        subprocess.run('../../utilities/shellUtilityUbuntu/cp_RPi_DataFile')
                        file = open("{}{}".format(CONSTaoa.realtimeLogFolder,CONSTaoa.pcPython2matlabLUTrawdataRdy),"w")
                        file.write("completed") 
                        file.close()
                    elif strdata.startswith(CONSTaoa.RPiStatus_pktCollected):
                        if PcBinaryLog:
                            hbinaryFile.close()
                            os.rename(binFilename, "../../datalog/PCmqttData.bin")
                        index += 1
                        logging.info('TOPIC_S2H_EVT')
                        file = open("{}{}".format(CONSTaoa.realtimeLogFolder,CONSTaoa.pcPython2matlabStatusRptFile),"w")
                        file.write("completed") 
                        file.close()
                        subprocess.run('./cp_RPi_governorModeData') # block process, no need for time.sleep(2)
                        stateTransition(CONSTaoa.State_PCwait4matlabCmd)
                time.sleep(0.01)
        elif mState == CONSTaoa.State_PCwait4matlabCmd:
            # source (2)
            strfilepath = '{}{}'.format(CONSTaoa.realtimeLogFolder,CONSTaoa.matlab2pcPythonCmdFile)
            if testFileExist(strfilepath):
                with open(strfilepath,'r') as f:
                    output = f.read()
                BLDCctrlCmd = int(output)
                os.remove(strfilepath)
                stateTransition(CONSTaoa.State_PCsendBLDCrotate_startCMD)
            if time.time() - m_entryTimeS > wait4SignalProcessingDoneTimeoutSec:
                logging.info('timeout when waiting for matlab command')
                stateTransition(CONSTaoa.State_PCsendBLDCrotate_startCMD)
            
            #if time.time() - m_entryTimeS > wait4SignalProcessingDoneTimeoutSec:
            #    stateTransition(CONSTaoa.State_PCsendBLDCrotate_startCMD)
        else:
            logging.error('unhandled state')
            break
        time.sleep(0.01)

def testFileExist(strfilepath):
    exists = os.path.isfile(strfilepath)
    return exists
try:
    opts, args = getopt.getopt(sys.argv[1:], "h:p:l:r", ["host=", "port=", "log=", "reset"])
except getopt.GetoptError as e:
    logging.error("Error: {}".format(str(e)))
    sys.exit(-1)
for opt, optval in opts:
    if opt in ["-h", "--host"]:
        MQTT_HOST = optval
    elif opt in ["-p", "--port"]:
        MQTT_PORT = int(optval)
    elif opt in ["-l", "--log"]:
        COLLECTIONCNT = int(optval)
    else:
        assert False, "Option {} not known".format(opt)

logging.info('Program start')
mqueue = Queue()
mqproxy = mqttutils.MQTTClientProxy(MQTT_HOST, MQTT_PORT, MQTT_NAME, mqueue)
mqproxy.connect()
mqproxy.runAsThread()
#mqproxy.subscribe(mqttutils.TOPIC_EmbdRAW)
mqproxy.subscribe(mqttutils.TOPIC_RPiStatus)
time.sleep(1)
filetobedeleted = "{}{}".format(CONSTaoa.realtimeLogFolder,CONSTaoa.pcPython2matlabStatusRptFile)
if os.path.exists(filetobedeleted):
    os.remove(filetobedeleted)
try:
    handle_mqtt_continuously()
except BaseException as e:
    mqproxy.quit()
    raise
mqproxy.quit()
logging.info("Good bye.")

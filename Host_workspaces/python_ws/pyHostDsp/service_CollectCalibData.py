#!/usr/bin/env python
#
# Ref. https://github.com/karulis/pybluez
# Ref. https://people.csail.mit.edu/albert/bluez-intro/x232.html
# run in RPi py3, send cmd via HC05 and collect AoA meas at each angular position.
# theoretically such ctrl could be done using laptop with BLE hardware, and automatically scp the result produced in RPi to laptop
# I want direct replacement of save to file module to AoA estimation module, that's why run it in RPi

# ./AoArcvSPI -l100 -m2

import serial
try:
    from Queue import Queue
except:
    from queue import Queue
TakePhoto = True # True/False take one photo at each angular position for data collection
if TakePhoto:
    from picamera import PiCamera
    import cv2

import CONSTaoa
import logging
# Configure logging
loglevel = logging.INFO
logdatefmt = "%Y-%m-%d %H:%M:%S"
logfmt = "%(asctime)s %(filename)s:%(lineno)d %(levelname)s %(message)s"
logging.basicConfig(format=logfmt, level=loglevel, datefmt=logdatefmt)

import os,sys
from datetime import datetime
import time
import threading
from collections import deque
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

if 2 == sys.version_info.major:
    pythonVer = 2
else:
    pythonVer = 3

def log_serialPort(serial_port,logfile):
    rv = b""
    while True:
        ch = serial_port.read()
        rv += ch
        if ch==b'' or ch ==b'\n':
            logfile.write(rv)
            return

def discover_devices(target):
    logging.info("Searching nearby devices...")
    nearby_devices = bluetooth.discover_devices(duration=4, lookup_names=True,
                                                flush_cache=True)
    logging.info("Found {} device(s)".format(len(nearby_devices)))
    target_devices = {}
    for bdaddr, bdname in nearby_devices:
        # logging.info("Bluetooth {} ({})".format(bdaddr, bdname))
        # bdname = bluetooth.lookup_name( bdaddr )
        if bdname.startswith(target):
            target_devices[bdaddr] = bdname
    return target_devices


def discover_devices_btctl(bc, target):
    devices = bc.getDevices()
    cands = {}
    for bdaddr, bdname in devices.items():
        if bdname.startswith(target):
            cands[bdaddr] = bdname
    return cands


def pair_devices_btctl(bc, cands):
    return bc.pairDevices(cands)

def discover_services(bdaddr):
    services = bluetooth.find_service(address=bdaddr)
    if len(services) > 0:
        print("Found %d services on %s" % (len(services), bdaddr))
        print("")
    else:
        print("No services found on %s" % (bdaddr,))
    for svc in services:
        print("Service Name: %s"    % svc["name"])
        print("    Host:        %s" % svc["host"])
        print("    Description: %s" % svc["description"])
        print("    Provided By: %s" % svc["provider"])
        print("    Protocol:    %s" % svc["protocol"])
        print("    channel/PSM: %s" % svc["port"])
        print("    svc classes: %s "% svc["service-classes"])
        print("    profiles:    %s "% svc["profiles"])
        print("    service id:  %s "% svc["service-id"])
        print("")
    return services

def send_ctrl_cmd(sock,BLDCctrlcmd):
    i32BLDCctrlcmd = bytearray(5)
    i32BLDCctrlcmd[0]=3 #applicable modes defined in Host_workspaces/utilities/arduinoBLDCgimbal/arduinoBLDCgimbal.ino
    # little endian
    i32BLDCctrlcmd[1]=(BLDCctrlcmd>>0)&0xFF
    i32BLDCctrlcmd[2]=(BLDCctrlcmd>>8)&0xFF
    i32BLDCctrlcmd[3]=(BLDCctrlcmd>>16)&0xFF
    i32BLDCctrlcmd[4]=(BLDCctrlcmd>>24)&0xFF
    ctrlStr = bytes(tl.construct(bytes(i32BLDCctrlcmd)))
    sock.send(ctrlStr)
    logging.debug("Send val:{} {}Bytes CtrlMsg:{}".format(BLDCctrlcmd,len(ctrlStr),ctrlStr))

def stateTransition(newState):
    global mState, mStateEntryEvt, m_entryTimeS
    mStateEntryEvt = True
    old_mState = mState
    mState = newState
    logging.info('state:{}=>{}'.format(old_mState,mState))
    m_entryTimeS = time.time()
    
def handle_socket_continuously(sock):
    global collectionii0, COLLECTIONCNT, btRcvStr, LastRcvDatDumpTimeS, currBLDCctrlcmd, etMode, mState, hackSkipBLE
    if not hackSkipBLE:
        sock.settimeout(BD_TIMEOUT)
    if etMode == CONSTaoa.HardCodeTurnSeq or etMode == CONSTaoa.collectLUT_then_CmdFromPC1:
        stateTransition(CONSTaoa.State_init)
    elif etMode == CONSTaoa.bldcCtrlCmdFromPC:
        stateTransition(CONSTaoa.State_wait4mqttMsg)
    else:
        print('gwtrherthghetryhj')
        sys.exit()
    GovernerBLDCctrlcmd = 0
    
    mStateEntryEvt = True
    global mqueue
    while True:
        if LogSerialData:
            log_serialPort(serialPort,logfp)
        if mState == CONSTaoa.State_init:
            if mStateEntryEvt:
                mStateEntryEvt = False
            if time.time() - m_entryTimeS > PauseInitS:
                stateTransition(CONSTaoa.State_SendBLDCctrlCmd)
                if etMode == CONSTaoa.HardCodeTurnSeq or etMode == CONSTaoa.collectLUT_then_CmdFromPC1:
                    logging.info('going to {}deg'.format(PosCtrlHwCmd[collectionii0]/ctrlSigCyclesPerRotation))
                elif etMode == CONSTaoa.collectLUT_then_CmdFromPC2 or etMode == CONSTaoa.bldcCtrlCmdFromPC:
                    logging.info('going to {}deg'.format(GovernerBLDCctrlcmd/ctrlSigCyclesPerRotation))
                else:
                    print("fgshgsdhgbshfvbls")
                    sys.exit()
            else:
                time.sleep(0.01)
        elif mState == CONSTaoa.State_SendBLDCctrlCmd:
            if etMode == CONSTaoa.HardCodeTurnSeq or etMode == CONSTaoa.collectLUT_then_CmdFromPC1:
                bldcSequenceCtrlcmd = PosCtrlHwCmd[collectionii0]
            elif etMode == CONSTaoa.bldcCtrlCmdFromPC or etMode == CONSTaoa.collectLUT_then_CmdFromPC2:
                bldcSequenceCtrlcmd = GovernerBLDCctrlcmd
            else:
                print('rteiugw4hjskdjfnbgfh')
                sys.exit()
            if mStateEntryEvt:
                mStateEntryEvt = False
            #if 3 == pythonVer:
            #    i32BLDCctrlcmd = ctypes.c_int32(bldcSequenceCtrlcmd)
            #else:
            if abs(currBLDCctrlcmd - bldcSequenceCtrlcmd) < BLDCctrlCmdMaxStep:
                currBLDCctrlcmd = bldcSequenceCtrlcmd
            else:
                if bldcSequenceCtrlcmd > currBLDCctrlcmd:
                    currBLDCctrlcmd += BLDCctrlCmdMaxStep
                else:
                    currBLDCctrlcmd -= BLDCctrlCmdMaxStep
            if not hackSkipBLE:    
                send_ctrl_cmd(sock,currBLDCctrlcmd) 
            stateTransition(CONSTaoa.State_TestdesiredPos)
        elif mState == CONSTaoa.State_TestdesiredPos:
            if mStateEntryEvt:
                mStateEntryEvt = False
                
            if time.time() - m_entryTimeS > PauseSendBLDCctrlCmd:
                if etMode == CONSTaoa.HardCodeTurnSeq or etMode == CONSTaoa.collectLUT_then_CmdFromPC1:
                    ctrl_target = bldcSequenceCtrlcmd
                else:
                    ctrl_target = GovernerBLDCctrlcmd
                    
                if currBLDCctrlcmd == ctrl_target:
                    logging.info('reached {}deg'.format(ctrl_target/ctrlSigCyclesPerRotation))
                    if etMode == CONSTaoa.HardCodeTurnSeq or etMode == CONSTaoa.collectLUT_then_CmdFromPC1:
                        datfilename = "Log_{:0>3d}_{:0>5d}_{:0>2d}".format(collectionii0,bldcSequenceCtrlcmd/ctrlSigCyclesPerRotation,collectionii0%COLLECTION_EACH_LOCATION)
                    else:
                        datfilename = "LogGovernerMode"
                    if etMode == CONSTaoa.HardCodeTurnSeq and collectionii0 == len(PosCtrlHwCmd) - 1:
                        break

                    stateTransition(CONSTaoa.State_wait4mqttMsg)
                    if TakePhoto:
                        jpgfilename = "{}/{}.jpg".format(PhotoJpgStorageFolder,datfilename)
                        camera.capture(jpgfilename)
                        
                    mqproxy.publish(mqttutils.TOPIC_RPiCmd,datfilename)
                else:
                    stateTransition(CONSTaoa.State_SendBLDCctrlCmd)
            else:
                time.sleep(0.01)
                                
        elif mState == CONSTaoa.State_wait4mqttMsg:
            if mStateEntryEvt:
                mStateEntryEvt = False        
            if wait2rcvMqttMsgBeforeProceed:
                while not mqueue.empty():
                    if LogSerialData:
                        log_serialPort(serialPort,logfp)
                    _client, _userdata, msg = mqueue.get()
                    if msg.topic == mqttutils.TOPIC_EmbdEvt:
                        strdata = msg.payload.decode("utf-8").strip()
                        logging.debug("mqtt rcvd msg:{}".format(strdata))
                        if strdata.startswith("DONE"):
                            if etMode == CONSTaoa.HardCodeTurnSeq or etMode == CONSTaoa.collectLUT_then_CmdFromPC1:
                                pass
                            elif etMode == CONSTaoa.bldcCtrlCmdFromPC or etMode == CONSTaoa.collectLUT_then_CmdFromPC2:
                                mqproxy.publish(mqttutils.TOPIC_RPiStatus,CONSTaoa.RPiStatus_pktCollected)
                            else:
                                logging.error("jmfyerfDFV")
                                sys.exit()
                            
                            if etMode == CONSTaoa.HardCodeTurnSeq or etMode == CONSTaoa.collectLUT_then_CmdFromPC1:
                                stateTransition(CONSTaoa.State_init)
                                if collectionii0 == COLLECTIONCNT - 2:
                                    #if etMode == CONSTaoa.HardCodeTurnSeq or etMode == CONSTaoa.:
                                    #    break
                                    if etMode == CONSTaoa.collectLUT_then_CmdFromPC1:
                                        mqproxy.publish(mqttutils.TOPIC_RPiStatus,CONSTaoa.RPiStatus_LUTdatasetRdy)
                                        logging.info("LUT data preparation done")
                                        etMode = CONSTaoa.collectLUT_then_CmdFromPC2
                                        currBLDCctrlcmd = 0
                            elif etMode == CONSTaoa.bldcCtrlCmdFromPC or etMode == CONSTaoa.collectLUT_then_CmdFromPC2:
                                pass
                            else:
                                logging.error("tryhncmhl")
                                sys.exit()
                            collectionii0 = collectionii0 + 1
                    elif msg.topic == mqttutils.TOPIC_PcCmd:
                        if etMode == CONSTaoa.bldcCtrlCmdFromPC or etMode == CONSTaoa.collectLUT_then_CmdFromPC2:
                            GovernerBLDCctrlcmd = int(msg.payload.decode("utf-8").strip())
                            stateTransition(CONSTaoa.State_init)
                        elif etMode == CONSTaoa.HardCodeTurnSeq or CONSTaoa.collectLUT_then_CmdFromPC1:
                            pass
                        else:
                            logging.error("asdgsrhgsdhdtryjetyjhns")
                            sys.exit()
                                        
                time.sleep(0.01)
            else:
                if time.time() - m_entryTimeS > unconditionalWaitSec:
                    collectionii0 = collectionii0 + 1
                    stateTransition(CONSTaoa.State_init)
                    mStateEntryEvt = True
                else:
                    time.sleep(0.01)
        else:
            logging.error('unhandled state')
            break
        if etMode == CONSTaoa.HardCodeTurnSeq:
            if collectionii0 == COLLECTIONCNT:
                break
        thisBtRcvStr = b""
        if not hackSkipBLE:
            try:
                thisBtRcvStr = sock.recv(BD_BUFFER_SIZE)
                # print(type(btRcvStr)) reports <type 'str'>
            except Exception as e:
                pass # normal timeout also produces exception
                #logging.error("BT sock rcv err:{}".format(e))
            if thisBtRcvStr: # End of file
                btRcvStr += thisBtRcvStr
            nowS = time.time()
            if btRcvStr:
                if len(btRcvStr) > BD_BUFFER_SIZE or nowS - LastRcvDatDumpTimeS > MAXDURATION2SHOW_RXBUF_S:
                    logging.debug("BT sock rcv sth :{}".format(btRcvStr))
                    btRcvStr = b""
                    LastRcvDatDumpTimeS = nowS
                else:
                    if "\n" in btRcvStr:
                        lines = btRcvStr.split("\n")
                        btRcvStr = lines[-1]
                        lines = lines[0:-1]
                        logging.debug("BT sock rcv list of sentence(s):{}".format(lines))
                        LastRcvDatDumpTimeS = nowS


def main_loop():
    global collectionii0, COLLECTIONCNT
    quit = False
    bc = None
    while not quit:
        mydevices = discover_devices(BD_NAME_PREFIX)
        if len(mydevices) == 0:
            logging.info("No cambot bt found")
            time.sleep(5)
            continue
        logging.info("Found my cambot: {}".format(mydevices))
        bc = bluetoothutils.BluetoothControl()
        if not bc.open():
            time.sleep(5)
            continue
        logging.info("Bluetoothctl opened")
        cands = {}
        ntries = 0
        while ntries < 5:
            time.sleep(1) # Wait for bluetoothctl ready
            itsdevices = discover_devices_btctl(bc, BD_NAME_PREFIX)
            if len(itsdevices)==0:
                ntries += 1
                time.sleep(2)
                continue
            logging.info("Found its cambot: {}".format(itsdevices))
            for k, v in itsdevices.items():
                if k in mydevices:
                    cands[k] = v
            if len(cands) > 0:
                break
        if len(cands)==0:
            bc.close()
            logging.info("No cambot pairable")
            time.sleep(5)
            continue
        cands = pair_devices_btctl(bc, cands)
        bc.close()
        btsock = None
        for bdaddr, bdname in cands.items(): # Try connecting one by one until success
            """
            First try already paired devices. If none of them is connectable, then
            try paring and connecting newly found devices. If all of them failed,
            start discover_devices() again. See pair_devices() for better understand.
            """
            try:
                btsock = bluetooth.BluetoothSocket (bluetooth.RFCOMM)
                btsock.connect((bdaddr,BD_PORT))
                logging.info("Connected to {} {}".format(bdaddr, bdname))
                break
            except Exception as e:
                logging.info("Failed connecting to {} {}: {}".format(bdaddr, bdname, e))
                btsock.close()
                btsock = None
        if btsock is not None:
            send_ctrl_cmd(btsock,0)
            time.sleep(0.5)
            if sendBLDCresetCmd_and_exit:
                break
            LastRcvDatDumpTimeS = time.time()
            handle_socket_continuously(btsock)
            btsock.close()
        if collectionii0 >= COLLECTIONCNT-1:
            break
        time.sleep(2)

# /////////////////////////////////////////////////////////////////////////////
bModeSet = False
# HardCodeTurnSeq
# bldcCtrlCmdFromPC
etMode = '' # True/False: choose to run hard coded BLDC rotation sequence or take rotation angle command from MQTT msg
try:
    opts, args = getopt.getopt(sys.argv[1:], "h:p:l:r:m", ["host=", "port=", "log=", "reset", "mode"])
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
    elif opt in ["-r", "--reset"]:
        sendBLDCresetCmd_and_exit = True
    elif opt in ["-m", "--mode"]:
        bModeSet = True
        etMode = str(optval)
    else:
        assert False, "Option {} not known".format(opt)

if False:
    print('hacked to force collectLUT_then_CmdFromPC1')
    etMode = CONSTaoa.collectLUT_then_CmdFromPC1
else:
    if not bModeSet:
        print('choose from (H)HardCodeTurnSeq/(B)bldcCtrlCmdFromPC/(R)collectLUT_then_CmdFromPC')
        if 3 == pythonVer:
            stringinput = str(input())
        else:
            stringinput = raw_input()
        if stringinput == 'H' or stringinput == 'h' or stringinput == 'HardCodeTurnSeq':
            etMode = CONSTaoa.HardCodeTurnSeq
        elif stringinput == 'B' or stringinput == 'b' or stringinput == 'bldcCtrlCmdFromPC':
            etMode = CONSTaoa.bldcCtrlCmdFromPC
        elif stringinput == 'R' or stringinput == 'r' or stringinput == 'collectLUT_then_CmdFromPC':
            etMode = CONSTaoa.collectLUT_then_CmdFromPC1
        else:
            sys.exit()
####################################################
# begining of user cfg
####################################################
if etMode == CONSTaoa.HardCodeTurnSeq:
    StepDeg = 10
    beginDeg = 0
    EndDeg = 180
    BLDCctrlCmdMaxStep = 20 # 
    COLLECTION_EACH_LOCATION = 1 # at each angular location, we may want to collect multiple dataset, in case some files are corrupted.
    repeatedDataCollect = 20 # the same data collection pattern within a cycle can be collected for multiple times
elif etMode == CONSTaoa.collectLUT_then_CmdFromPC1:
    StepDeg = 10
    beginDeg = 0
    EndDeg = 180
    BLDCctrlCmdMaxStep = 20 # 
    COLLECTION_EACH_LOCATION = 1 # at each angular location, we may want to collect multiple dataset, in case some files are corrupted.
    repeatedDataCollect = 20 # the same data collection pattern within a cycle can be collected for multiple times
elif etMode == CONSTaoa.bldcCtrlCmdFromPC:
    BLDCctrlCmdMaxStep = 20 # 
else:
    print('asdfgwsrthdntydr')
    sys.exit()
hackSkipBLE = False
ctrlSigCyclesPerRotation = 14 # determined by PMDC HW configuration
wait2rcvMqttMsgBeforeProceed = True # True/False set to False if we only want to test BLDC control without running CPP AoArcvSPI, which publishes DONE msg
LogSerialData = False  # CC2640 onchip AoA estimate is reported in serial port
sendBLDCresetCmd_and_exit = False # one shot action to reset BLDC condition
PauseInitS = 0.2
PauseSendBLDCctrlCmd = 0.1 # a desired rotation contains many small steps, a time gap between each new movement 
PhotoJpgStorageFolder = '/home/pi/code/remote_dbg/AoArcvSPI' # I prefer the same folder as dat file
####################################################
# end of user cfg
####################################################

if not wait2rcvMqttMsgBeforeProceed:
    unconditionalWaitSec = 0   

if LogSerialData:
    port = '/dev/ttyACM0'
    serialPort = serial.Serial(port, baudrate=115200, timeout=0.02)
    LOG_FILE = "aoa_data.txt"
else:
    LOG_FILE = None

if etMode == CONSTaoa.HardCodeTurnSeq or etMode == CONSTaoa.collectLUT_then_CmdFromPC1:
    PosCtrlHwCmd=[]
    for ii in range(0,repeatedDataCollect):
        for degVal in range(360*ii+beginDeg,360*ii+EndDeg+1,StepDeg):
            PosCtrlHwCmd.append(degVal*ctrlSigCyclesPerRotation)
    PosCtrlHwCmd.append((ii+1)*360*ctrlSigCyclesPerRotation) # no data collection at this last position, it is for base alignment purpose only 
    print(PosCtrlHwCmd)
    logging.info("total {} steps".format(len(PosCtrlHwCmd)))
    # total desired collection, 1 rotation needs 14 cycle of sine ctrl.
    COLLECTIONCNT = len(PosCtrlHwCmd)
    assert(COLLECTIONCNT < 1e5)
elif etMode == CONSTaoa.bldcCtrlCmdFromPC:
    # do nothing
    pass
else:
    print('asdfgwsrthdntydr')
    sys.exit()
    
camdim = (640, 480)

currBLDCctrlcmd = 0

collectionii0 = 0
BD_NAME_PREFIX = "cambot-"
BD_PINCODE = "1977"
BD_PORT = 1
BD_TIMEOUT = 0.01 # In seconds
BD_BUFFER_SIZE = 128


MQTT_HOST = mqttutils.MQTT_HOST_IP
MQTT_PORT = mqttutils.MQTT_PORT_NUMBER
MQTT_NAME = "BTService"

btRcvStr = b""
# max duration in sec before we output anything we have in Rx buffer
# even before the line end "\n" is received
MAXDURATION2SHOW_RXBUF_S = 20
LastRcvDatDumpTimeS = time.time()

mqueue = Queue()
mqproxy = mqttutils.MQTTClientProxy(MQTT_HOST, MQTT_PORT, MQTT_NAME, mqueue)
mqproxy.connect()
mqproxy.runAsThread()
mqproxy.subscribe(mqttutils.TOPIC_EmbdEvt)
mqproxy.subscribe(mqttutils.TOPIC_PcCmd)
tl = transportLayer.TL()
logfp = None
if TakePhoto:
    camera = PiCamera()
    camera.start_preview()

if LOG_FILE is not None:
    logfp = open(LOG_FILE, "w")
    logging.info("Opened log file {}".format(LOG_FILE))
mState = CONSTaoa.State_uninitialized
try:
    if hackSkipBLE:
        handle_socket_continuously("")
    else:
        main_loop()
except BaseException as e:
    mqproxy.quit()
    raise
mqproxy.quit()
if TakePhoto:
    camera.stop_preview()

if LOG_FILE is not None:
    logfp.close()

logging.info("Good bye.")

#!/usr/bin/env python
import serial
import transportLayer
import ctypes
import sys
import time
import binascii
import logging
import math
loglevel = logging.DEBUG
logdatefmt = "%Y-%m-%d %H:%M:%S"
logfmt = "%(asctime)s %(filename)s:%(lineno)d %(levelname)s %(message)s"
logging.basicConfig(format=logfmt, level=loglevel, datefmt=logdatefmt)

#applicable modes defined in Host_workspaces/utilities/arduinoBLDCgimbal/arduinoBLDCgimbal.ino
OpModes = {
    "NonStopConstRPM" : 0,
    "NonStopSpeedSineTurn" : 1,
    "StartStopMotorCfgTest" : 2,
    "SerialCtrl" : 3
}

OpMode = "SerialCtrl"
StepSize = 30
port = "/dev/ttyUSB0"


def readlineCR(serialPort):
    rv = b""
    while True:
        ch = serialPort.read()
        rv += ch
        if ch==b'\n' or ch==b'':
            return rv


if 2 == sys.version_info.major:
    m_pythonVer = 2
else:
    m_pythonVer = 3
serialPort = serial.Serial(port, baudrate=115200, timeout=0.02)
time.sleep(1.5) # 1.5sec is needed for the arduino reset to complete (standard arduino serial open/close trigger CPU reset)
tl = transportLayer.TL()
stepPerSpeed = 10
BLDCctrlcmd = 0
BLDCctrlCmdStep = 30
lastSentTimeS = time.time()
loopii = 0
sent = False
while True:
    NowS = time.time()
    if NowS - lastSentTimeS > 0.01:
    #if NowS - lastSentTimeS > 0.1*math.sin(math.pi*(loopii%stepPerSpeed)/stepPerSpeed):
        userdata = bytearray(5)
        
        userdata[0] = OpModes[OpMode]
        if OpMode == "NonStopConstRPM" or OpMode == "NonStopSpeedSineTurn" or OpMode == "StartStopMotorCfgTest":
            if sent:
                pass
            else:
                userdata[1]=(StepSize>>0)&0xFF
                userdata[2]=(StepSize>>8)&0xFF
                userdata[3]=(StepSize>>16)&0xFF
                userdata[4]=(StepSize>>24)&0xFF
                ctrlStr = bytes(tl.construct(bytes(userdata)))
                logging.info("You sent {} byte(s), cmd{}, Hex:{}".format(len(ctrlStr),StepSize,binascii.hexlify(ctrlStr)))
                x = serialPort.write(ctrlStr)
                sent = True
        elif OpMode == "SerialCtrl":
            userdata[1]=(BLDCctrlcmd>>0)&0xFF
            userdata[2]=(BLDCctrlcmd>>8)&0xFF
            userdata[3]=(BLDCctrlcmd>>16)&0xFF
            userdata[4]=(BLDCctrlcmd>>24)&0xFF
            ctrlStr = bytes(tl.construct(bytes(userdata)))
            logging.info("You sent {} byte(s), cmd{}, Hex:{}".format(len(ctrlStr),BLDCctrlcmd,binascii.hexlify(ctrlStr)))
            x = serialPort.write(ctrlStr)
            BLDCctrlcmd = BLDCctrlcmd+BLDCctrlCmdStep
        else:
            print("unsupported OpMode")
            break
        lastSentTimeS = NowS
        loopii = loopii + 1
    rcv = readlineCR(serialPort)
    if len(rcv) > 0:
        print("You rcv:", rcv)
serialPort.close()

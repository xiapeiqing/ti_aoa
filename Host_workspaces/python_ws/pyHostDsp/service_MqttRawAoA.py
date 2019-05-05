#!/usr/bin/env python
# subscribe to raw BleAoA data publish by CPP SPI interfeace program
# run algorithm and publish AoA angle estimate

# ./AoArcvSPI -l10 -m2

import logging
import time
import sys
import getopt
import atexit
import struct
import CWphsEst

try:
    from Queue import Queue
except:
    from queue import Queue
import mqttutils

# Global definitions
MQTT_HOST = mqttutils.MQTT_HOST_IP
MQTT_PORT = mqttutils.MQTT_PORT_NUMBER
MQTT_NAME = "BleAoAresult"


def cleanup():
    def _wrapped():
        print("cleanup done.")
    return _wrapped


atexit.register(cleanup())
# Configure logging
loglevel = logging.DEBUG
logdatefmt = "%Y-%m-%d %H:%M:%S"
logfmt = "%(asctime)s %(filename)s:%(lineno)d %(levelname)s %(message)s"
logging.basicConfig(format=logfmt, level=loglevel, datefmt=logdatefmt)


try:
    opts, args = getopt.getopt(sys.argv[1:], "h:p:", ["host=", "port="])
except getopt.GetoptError as e:
    logging.error("Error: {}".format(str(e)))
    sys.exit(-1)
for opt, optval in opts:
    if opt in ["-h", "--host"]:
        MQTT_HOST = optval
    elif opt in ["-p", "--port"]:
        MQTT_PORT = int(optval)
    else:
        assert False, "Option {} not known".format(opt)

mqueue = Queue()
mqproxy = mqttutils.MQTTClientProxy(MQTT_HOST, MQTT_PORT, MQTT_NAME, mqueue)
mqproxy.connect()
mqproxy.subscribe(mqttutils.MQTT_MEAS_BleAoARawDatRpt)
mqproxy.runAsThread()
r, g, b, ms = 0, 0, 0, 0
STATE_NEW, STATE_ON, STATE_OFF = 0, 1, 2
state = STATE_NEW
state_time = time.time()
try:
    while True:
        msg = None
        now = time.time()
        delta = int((now - state_time)*1000.0)
        while not mqueue.empty():
            _client, _userdata, msg = mqueue.get()
        if msg is not None:
            values = struct.unpack('<7c1024hc', msg.payload) # len(values) = 1032
            IQ0index = 7
            i16sampleEachWavelength = 16*2 # 16 samples/wavelength, 2: IQ
            blkWavelength = [10,10,12]
            threeResults = [0,0,0]
            for ii in range(len(blkWavelength)):
                extractB = IQ0index+i16sampleEachWavelength*sum(blkWavelength[0:ii])
                extractE = IQ0index+i16sampleEachWavelength*sum(blkWavelength[0:ii+1])
                threeResults[ii] = CWphsEst.phs_est_adaptive_filter(values[extractB:extractE]) # type(values)=><class 'tuple'>
                #print(res)
            print("%2.1f %2.1f"
                  %(threeResults[1]-threeResults[0],threeResults[2]-threeResults[0]))

        time.sleep(0.01)
except BaseException:
    mqproxy.quit()
    raise

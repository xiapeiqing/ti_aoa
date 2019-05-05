#!/usr/bin/env python
import logging
try:
    from Queue import Queue
except:
    from queue import Queue
import sys
import getopt
import mqttutils
import struct
import os, mmap
import time

SlowDownCoeff = 1
AoA_PktCC2640Tx = 2056
AoA_PktOverheadLen = 4
AoA_PktLen = (AoA_PktCC2640Tx+AoA_PktOverheadLen)
MQTT_HOST = mqttutils.MQTT_HOST_IP
MQTT_PORT = mqttutils.MQTT_PORT_NUMBER
MQTT_NAME = "BleAoAraw"
LOG_FILE = None

# Configure logging
loglevel = logging.DEBUG
logdatefmt = "%Y-%m-%d %H:%M:%S"
logfmt = "%(asctime)s %(filename)s:%(lineno)d %(levelname)s %(message)s"
logging.basicConfig(format=logfmt, level=loglevel, datefmt=logdatefmt)

field_names = ('timestamp_ms', 'payloadBytes')

class Sbet(object):
    def __init__(self, filename, use_mmap=True):

        sbet_file = open(filename)

        if use_mmap:
            sbet_size = os.path.getsize(filename)
            self.data = mmap.mmap(sbet_file.fileno(), sbet_size, access=mmap.ACCESS_READ)
        else:
            self.data = sbet_file.read()

        # Make sure the file is sane
        assert(len(self.data)%AoA_PktLen == 0)

        self.num_datagrams = len(self.data) / AoA_PktLen

    def decode(self, offset=0):
        'Return a dictionary for an SBet datagram starting at offset'
        subset = self.data[ offset : offset+ AoA_PktLen ]
        # https://docs.python.org/2/library/struct.html
        values = struct.unpack('i2056s', subset) # len(values)=>2
        sbet_values = dict(zip (field_names, values))
        return sbet_values

    def get_offset(self, datagram_index):
        return datagram_index * AoA_PktLen

    def get_datagram(self, datagram_index):
        offset = self.get_offset(datagram_index)
        values = self.decode(offset)
        return values

    def __iter__(self):
        return SbetIterator(self)

class SbetIterator(object):
    'Independent iterator class for Sbet files'
    def __init__(self,sbet):
        self.sbet = sbet
        self.iter_position = 0

    def __iter__(self):
        return self

    def __next__(self):
        if self.iter_position >= self.sbet.num_datagrams:
            raise StopIteration

        values = self.sbet.get_datagram(self.iter_position)
        self.iter_position += 1
        return values

# /////////////////////////////////////////////////////////////////////////////

try:
    opts, args = getopt.getopt(sys.argv[1:], "h:p:l:s:", ["host=", "port=", "log=", "slowdown="])
except getopt.GetoptError as e:
    logging.error("Error: {}".format(str(e)))
    sys.exit(-1)
for opt, optval in opts:
    if opt in ["-h", "--host"]:
        MQTT_HOST = optval
    elif opt in ["-p", "--port"]:
        MQTT_PORT = int(optval)
    elif opt in ["-l", "--log"]:
        LOG_FILE = optval
    elif opt in ["-s", "--slowdown"]:
        SlowDownCoeff = int(optval)
    else:
        assert False, "Option {} not known".format(opt)

mqueue = Queue()
mqproxy = mqttutils.MQTTClientProxy(MQTT_HOST, MQTT_PORT, MQTT_NAME, mqueue)
mqproxy.connect()
mqproxy.runAsThread()
sbet = Sbet('./Log.dat')
Time0 = time.time()
for index, dictionaryData in enumerate( Sbet('./Log.dat') ):
    now = time.time()
    while now - Time0 < dictionaryData['timestamp_ms']/(1000/SlowDownCoeff):
        time.sleep(0.01) # seconds
        now = time.time()
    print("current ms: {}".format(dictionaryData['timestamp_ms']))
    mqproxy.publish(mqttutils.MQTT_MEAS_BleAoARawDatRpt, dictionaryData['payloadBytes'])

mqproxy.quit()
logging.info("Good bye.")


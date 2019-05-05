# https://github.com/eclipse/paho.mqtt.python
#

import paho.mqtt.client as mqtt
import threading
import logging
import time

#     Embedded(Embd): binary C++ program reading AoA raw meas via SPI data
#     RRPi(RaspberryPi): python program running in RaspberryPi, controlling BLDC gimbal rotation angle
#     Ubuntu PC(Pc): python porgram running in PC, interacting with matlab using shared file, interacting with other system parts using mqtt
# must match definition in blecpp
TOPIC_RPiCmd = "/m2cambot/CMD/cmdRPiCmd"
TOPIC_RPiStatus = "/m2cambot/CMD/statusRPiPub"
TOPIC_EmbdRAW = "/m2cambot/MEAS/BleAoARawDatPub"
TOPIC_EmbdEvt = "/m2cambot/MEAS/BleAoALogEvtPub"
TOPIC_PcCmd = "/m2cambot/CMD/G2HcmdBLDCrotation" 


# Topics to be used in future
MQTT_STATUS_BLEAOAresult_TOPIC = "/m2cambot/MEAS/BLE_AoA_result" # published by AoA service for AoA result in deg, subscribed by gimbal control module



MQTT_HOST_IP = "192.168.31.211"
MQTT_PORT_NUMBER = 1883
class MQTTClientProxy(object):
    def __init__(self, host="127.0.0.1", port=1883, name="MQTTClientProxy", mqueue=None):
        self._host = host
        self._port = port
        self._name = name
        self._client = None
        self._mqueue = mqueue # Queue to put received message
        self._thread = None
        self._run = True
    
    def quit(self):
        self._run = False
        self._client.disconnect()

    def on_message(self, client, userdata, msg):
        if self._mqueue is not None:
            #payload = msg.payload.decode("utf-8")
            self._mqueue.put((client, userdata, msg))
    
    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            logging.info("Connected to MQTT server {}:{}".format(self._host, self._port))
        elif rc == 1:
            logging.warn("Connection refused - unacceptable protocol version")
        elif rc == 2:
            logging.warn("Connection refused - identifier rejected")
        elif rc == 3:
            logging.warn("Connection refused - server unavailable")
        elif rc == 4:
            logging.warn("Connection refused - bad user name or password")
        elif rc == 5:
            logging.warn("Connection refused - not authorised")
        else:
            logging.warn("Connection failed - result code %d" % (rc))
    
    def on_disconnect(self, client, userdata, rc):
        logging.info("MQTT disconnected")
    
    def connect(self):
        assert self._client is None
        logging.info("Trying to connect to local broker")
        self._client = mqtt.Client(self._name, clean_session=True, userdata=None, 
                                   protocol=mqtt.MQTTv311, transport="tcp")
        self._client.on_connect = self.on_connect
        self._client.on_message = self.on_message
        self._client.on_disconnect = self.on_disconnect
        self._client.username_pw_set("", "")
        connected = False
        while not connected:
            try:
                self._client.connect(self._host, self._port, 60)
                connected = True
            except:
                time.sleep(2)
    
    def subscribe(self, topic, qos=0):
        self._client.subscribe(topic, qos)
    
    def publish(self, topic, payload, qos=0, retain=False):
        return self._client.publish(topic, payload, qos, retain)
    
    def loop_forever(self):
        self._client.loop_forever() # Auto connect if disconnected
    
    def loop_while(self):
        while self._run:
            self._client.loop()

    def loop(self, timeout=0.1):
        self._client.loop(timeout)
        
    def runAsThread(self, forever=True):
        assert self._thread is None
        target = self.loop_forever if forever else self.loop_while
        self._thread = threading.Thread(target=target, 
                                        name="MQTTClientProxy", args=())
        self._thread.start()
    

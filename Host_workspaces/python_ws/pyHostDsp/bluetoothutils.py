# support only python2, crash in python3
# derived from m2cambot/m2cambot/utils_onemark/bluetoothutils.py
import pexpect as ep
import re
import logging
import subprocess
import time


BTEP_TIMEOUT = 4
BTEP_ES = "\\[bluetooth\\].*# "
BTEP_REPL = "\x1b\\[((\\d+;?\\d*m)|(K))"
BTEP_SRCH = "^Device ([0-9a-fA-F:]+) (.+)"
BTEP_PSWD = "1977"


class BluetoothControl(object):
    def __init__(self):
        self._btc = None
    
    def open(self):
        assert self._btc is None
        # Remove old processes
        subprocess.call("kill -9 `pidof bluetoothctl` >/dev/null 2>&1", shell=True)
        time.sleep(1)
        status = subprocess.call("pidof bluetoothctl >/dev/null 2>&1", shell=True)
        if status == 0:
            logging.warn("Old bluetoothctl still living")
            return False
        self._btc = ep.spawn("bluetoothctl")
        time.sleep(1)
        status = subprocess.call("pidof bluetoothctl >/dev/null 2>&1", shell=True)
        if status != 0:
           logging.warn("Failed starting bluetoothctl")
           return False
        logging.info("Opened bluetoothctl")
        _expected, lines = self.runCmd("agent on")
        logging.info(str(lines))
        _expected, lines = self.runCmd("default-agent")
        logging.info(str(lines))
        _expected, lines = self.runCmd("scan on")
        logging.info(str(lines))
        return True
    
    def close(self):
        if self._btc is not None:
            _expected, lines = self.runCmd("scan off")
            #logging.info(str(lines))
            self.runCmd("quit", ep.exceptions.EOF)
            self._btc = None

    def runCmd(self, cmd, es=BTEP_ES, timeout=BTEP_TIMEOUT):
        getlines = lambda x: [v.strip() for v in re.sub(BTEP_REPL, "", x).split("\r")]
        self._btc.sendline(cmd)
        lines = []
        expected = -1
        try:
            expected = self._btc.expect(es, timeout=timeout)
        except ep.exceptions.TIMEOUT:
            logging.info("Error expect cmd {} '{}'".format(cmd, es))
            return (None, None)
        lines += getlines(str(self._btc.before)+str(self._btc.after))
        while True: # Drain repeated expected lines
            try:
                if not isinstance(es, str):
                    break
                expected = self._btc.expect(es, timeout=0.2)
                lines += getlines(str(self._btc.before)+str(self._btc.after))
            except ep.exceptions.TIMEOUT:
                break
        return (expected, lines)
    
    def parseDevices(self, lines):
        devices = {}
        for line in lines:
            m = re.search(BTEP_SRCH, line)
            if m:
                addr, name = m.group(1), m.group(2)
                devices[addr] = name
        return devices
    
    def filterLines(self, lines, kw):
        result = []
        for line in lines:
            if line.find(kw)>=0:
                result.append(line)
        return result
    
    def pairDevice(self, bdaddr):
        BTEP_ES_PAIR = ["Enter PIN code:", "Confirm passkey", "AlreadyExists", 
                        "ConnectionAttemptFailed", "not available"]
        BTEP_ES_PAIR_RESULT = ["Pairing successful", "AuthenticationFailed"]
        expected, lines = self.runCmd("pair {}".format(bdaddr), es=BTEP_ES_PAIR, timeout=20)
        if lines is None:
            return False
        logging.info("Pairing expceted: {} {}".format(expected, lines))
        if expected==0:
            expected, lines = self.runCmd(BTEP_PSWD, es=BTEP_ES_PAIR_RESULT, timeout=10)
        elif expected==1:
            expected, lines = self.runCmd("yes", es=BTEP_ES_PAIR_RESULT, timeout=10)
        elif expected==2:
            expected = 0
        else:
            expected = -1
        if expected==0:
            logging.info("Pairing sucessfully: {}".format(lines))
            return True
        else:
            logging.info("Failed pairing: {}".format(lines))
            return False
    
    def commonDevices(self, a, b):
        # a & b
        return {k:v for k,v in a.items() if k in b}
    
    def diffDevices(self, a, b):
        # a - b
        return {k:v for k,v in a.items() if k not in b}
    
    def getDevices(self):
        expected, lines = self.runCmd("devices")
        return self.parseDevices(lines)
    
    def pairDevices(self, cands):
        paired = self.parseDevices(self.runCmd("paired-devices")[1])
        result = {k:v for k,v in paired.items() if k in cands}
        todo = self.diffDevices(cands, paired)
        for bdaddr,bdname in todo.items():
            if self.pairDevice(bdaddr):
                logging.info("Newly paired device {} {}".format(bdaddr, bdname))
                result[bdaddr] = bdname
        return result

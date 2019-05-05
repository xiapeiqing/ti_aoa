import crcmod
import ctypes
import sys

class TL(object):
    def __init__(self, ParserState="ProtocolPreamble", PreambleIndex=0, ByteExpected=0, ByteFilled=0, PROTOCOL_PREAMBLE = "M2Rb"):
        self.ParserState = ParserState # ProtocolPreamble,PayloadByteCnt,ProtocolBody,ProtocolChksum
        self.PreambleIndex = PreambleIndex
        self.ByteExpected = ByteExpected
        self.ByteFilled = ByteFilled
        self.PROTOCOL_PREAMBLE = PROTOCOL_PREAMBLE
        self.m_pOneMsgBuf = ""
        self.m_CRCmodule = crcmod.mkCrcFun(0x131, 0, False, 0)
        if 2 == sys.version_info.major:
            self.m_pythonVer = 2
        else:
            self.m_pythonVer = 3

    def on_byte(self, client, newByte):
        # receiver end, to be implemented
        pass

    def construct(self, userdata):
        # userdata is of type bytearray
        str = bytearray(7+len(userdata))
        str[0:4] = b'M2Rb'
        userdatLen = len(userdata)
        if 2 == self.m_pythonVer:
            u16len = bytearray(2)
            u16len[0]=(userdatLen>>0)&0xFF
            u16len[1]=(userdatLen>>8)&0xFF
        else:
            u16len = ctypes.c_uint16(userdatLen)
        str[4:6] = bytes(u16len)
        str[6:6+len(userdata)] = userdata
        str[6+len(userdata)] = self.m_CRCmodule(bytes(str[4:-1]))
        return str

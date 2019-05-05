import crcmod
crc = crcmod.mkCrcFun(0x131, 0, False, 0)
print(hex(crc(bytes(bytearray([0x31, 0x32, 0x33, 0x34])))))
print(hex(crc(b"1234")))

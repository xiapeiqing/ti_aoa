#ifndef TRANSPORTLAYER_H_
#define TRANSPORTLAYER_H_

#ifdef __cplusplus
extern "C" {
#endif

// configurable section
#define PROTOCOL_PREAMBLE "M2Rb"
#define MAX_PAYLOAD_BYTES 50
// end of configurable section

typedef enum {
  SVTELEMPARSER_ERROR, // message unparsable by this parser
  SVTELEMPARSER_PAYLOADLENVIOLATION, // payload length > buffer length of MAX_PAYLOAD_BYTES
  SVTELEMPARSER_INCOMPLETE, // parser needs more data to complete the message
  SVTELEMPARSER_COMPLETE // parser has received a complete message and finished processing
} VarLenProtocolParserResult;
typedef enum
{
    ProtocolPreamble,
    PayloadByteCnt16bit,
    ProtocolBody,
    ProtocolChksum
} ProtocolParserState;
typedef struct {
    ProtocolParserState ParserState;
    uint16_t ByteExpected;
    uint16_t ByteFilled;
    uint8_t _computedCRC;
} __attribute__ ((packed)) ParserStatus;

#define PROTOCOL_PREAMBLE_BYTES (sizeof(PROTOCOL_PREAMBLE)-1) // C string definition contains a \0 in the end
extern ParserStatus m_sParserStatus;
extern uint8_t m_pOneMsgBuf[MAX_PAYLOAD_BYTES];
VarLenProtocolParserResult onProtocolByte(uint8_t c);

#ifdef __cplusplus
} // extern "C"
#endif
#endif

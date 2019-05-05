// PC ubuntu cross compilation error in link step: libpaho-mqttpp3.so: undefined reference to `std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >::basic_string()@GLIBCXX_3.4.21'
/*
 ============================================================================
 Name        : ReadSPI.c
 Author      : peiqing
 Version     :
 Copyright   : Your copyright notice
 Description : this program is built based on paho.mqtt.cpp/src/samples:
	async_publish.cpp
	async_subscribe.cpp
 ============================================================================
g++ AoArcvSPI.cpp -std=c++0x -lpaho-mqttpp3 -lwiringPi -lpthread -oAoArcvSPI
 */
typedef enum OperationModes{
	RdAoARawMeas_consolDisplayOnly,             // read SPI and print statistics, no Harddisk write operation, no MQTT publish
	LogAoARawMeas_NoMqttPublish,                // read SPI and print statistics,    Harddisk write operation, no MQTT publish
	LogAndMqttPublish_AoARawMeas_CompleteEvt,   // read SPI and print statistics,    Harddisk write operation,    MQTT publish TOPIC1: full content of data packet, TOPIC2: event of data collection completion
	NUM_OPERATIONMODES
} OperationModes;
OperationModes etOperationMode = LogAndMqttPublish_AoARawMeas_CompleteEvt;

#define RSSI_PRINT_DECIMATION 10 // reduce the print rate of RSSI dBm
const int	N_RETRY_ATTEMPTS = 5;
#define bufSPIpacketLEN (2057) // bytes, value of bufSPIpacketLEN
#define SNR_BYTE0 7

#define MAX_SPI_TRANS_BYTES 1000
// set 1e6, oscilloscope observes 2uS clk cycle
// set 2e6, oscilloscope observes 1uS clk cycle
#define SPI_CLK_RATE_HZ 4000000
#define SPI_MODE 1//2
#define DELAY_TAU1_uS 3500 // 3000 timing violation
// gcc SPIreader.cpp -o test -lwiringPi
// ./test -l10 /dev/spidev0.0
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string.h>
#include <dirent.h> // opendir
#include <csignal>
#include <iostream>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <chrono>
#include <linux/types.h>
#include <linux/spi/spidev.h>
#include <time.h>
#include <errno.h>
#include <wiringPi.h>
#include <iostream>
#include <atomic>
using namespace std;
// match consts in mqttutils.py
const string TOPIC_S2H_RAW       { "/m2cambot/MEAS/BleAoARawDatPub" };
const string TOPIC_S2H_EVT       { "/m2cambot/MEAS/BleAoALogEvtPub" };
const string TOPIC_RPiCmd_PUB    { "/m2cambot/CMD/cmdRPiCmd" };
const char* LWT_PAYLOAD = "Last will and testament.";

static int verbose = 0;

// myDoc\math\CRC\CRC8table.pdf
// x8+ x5+ x4
static const uint8_t __tl_crc_table[] =
{
    0x00,0x31,0x62,0x53,0xC4,0xF5,0xA6,0x97,0xB9,0x88,0xDB,0xEA,0x7D,0x4C,0x1F,0x2E,
    0x43,0x72,0x21,0x10,0x87,0xB6,0xE5,0xD4,0xFA,0xCB,0x98,0xA9,0x3E,0x0F,0x5C,0x6D,
    0x86,0xB7,0xE4,0xD5,0x42,0x73,0x20,0x11,0x3F,0x0E,0x5D,0x6C,0xFB,0xCA,0x99,0xA8,
    0xC5,0xF4,0xA7,0x96,0x01,0x30,0x63,0x52,0x7C,0x4D,0x1E,0x2F,0xB8,0x89,0xDA,0xEB,
    0x3D,0x0C,0x5F,0x6E,0xF9,0xC8,0x9B,0xAA,0x84,0xB5,0xE6,0xD7,0x40,0x71,0x22,0x13,
    0x7E,0x4F,0x1C,0x2D,0xBA,0x8B,0xD8,0xE9,0xC7,0xF6,0xA5,0x94,0x03,0x32,0x61,0x50,
    0xBB,0x8A,0xD9,0xE8,0x7F,0x4E,0x1D,0x2C,0x02,0x33,0x60,0x51,0xC6,0xF7,0xA4,0x95,
    0xF8,0xC9,0x9A,0xAB,0x3C,0x0D,0x5E,0x6F,0x41,0x70,0x23,0x12,0x85,0xB4,0xE7,0xD6,
    0x7A,0x4B,0x18,0x29,0xBE,0x8F,0xDC,0xED,0xC3,0xF2,0xA1,0x90,0x07,0x36,0x65,0x54,
    0x39,0x08,0x5B,0x6A,0xFD,0xCC,0x9F,0xAE,0x80,0xB1,0xE2,0xD3,0x44,0x75,0x26,0x17,
    0xFC,0xCD,0x9E,0xAF,0x38,0x09,0x5A,0x6B,0x45,0x74,0x27,0x16,0x81,0xB0,0xE3,0xD2,
    0xBF,0x8E,0xDD,0xEC,0x7B,0x4A,0x19,0x28,0x06,0x37,0x64,0x55,0xC2,0xF3,0xA0,0x91,
    0x47,0x76,0x25,0x14,0x83,0xB2,0xE1,0xD0,0xFE,0xCF,0x9C,0xAD,0x3A,0x0B,0x58,0x69,
    0x04,0x35,0x66,0x57,0xC0,0xF1,0xA2,0x93,0xBD,0x8C,0xDF,0xEE,0x79,0x48,0x1B,0x2A,
    0xC1,0xF0,0xA3,0x92,0x05,0x34,0x67,0x56,0x78,0x49,0x1A,0x2B,0xBC,0x8D,0xDE,0xEF,
    0x82,0xB3,0xE0,0xD1,0x46,0x77,0x24,0x15,0x3B,0x0A,0x59,0x68,0xFF,0xCE,0x9D,0xAC};
//template<typename T>
//void UNUSED(T &&) {}

#include <cstdlib>
#include <string>
#include <thread>	// For sleep
#include <atomic>
#include <mutex>
#include <chrono>
#include <cstring>
#include "mqtt/async_client.h"

// https://theboostcpplibraries.com/boost.interprocess-synchronization
#include <boost/interprocess/sync/named_mutex.hpp>
using namespace boost::interprocess;
named_mutex named_mtx{open_or_create, "mtx"};

const std::string DFLT_SERVER_ADDRESS	{ "tcp://192.168.31.211:1883" };
const std::string DFLT_CLIENT_ID		{ "AoArawDataCppCollector" };

const int  QOS = 1;

std::string LogFilename;
atomic<bool> bReqDataCollection;
/////////////////////////////////////////////////////////////////////////////

// Callbacks for the success or failures of requested actions.
// This could be used to initiate further action, but here we just log the
// results to the console.

class action_listener : public virtual mqtt::iaction_listener
{
	std::string name_;

	void on_failure(const mqtt::token& tok) override {
		std::cout << name_ << " failure";
		if (tok.get_message_id() != 0)
			std::cout << " for token: [" << tok.get_message_id() << "]" << std::endl;
		std::cout << std::endl;
	}

	void on_success(const mqtt::token& tok) override {
		std::cout << name_ << " success";
		if (tok.get_message_id() != 0)
			std::cout << " for token: [" << tok.get_message_id() << "]" << std::endl;
		auto top = tok.get_topics();
		if (top && !top->empty())
			std::cout << "\ttoken topic: '" << (*top)[0] << "', ..." << std::endl;
		std::cout << std::endl;
	}

public:
	action_listener(const std::string& name) : name_(name) {}
};

/////////////////////////////////////////////////////////////////////////////

/**
 * Local callback & listener class for use with the client connection.
 * This is primarily intended to receive messages, but it will also monitor
 * the connection to the broker. If the connection is lost, it will attempt
 * to restore the connection and re-subscribe to the topic.
 */
class usr_callback : public virtual mqtt::callback,
					public virtual mqtt::iaction_listener

{
	// Counter for the number of connection retries
	int nretry_;
	// The MQTT client
	mqtt::async_client& cli_;
	// Options to use if we need to reconnect
	mqtt::connect_options& connOpts_;
	// An action listener to display the result of actions.
	action_listener subListener_;

	// This deomonstrates manually reconnecting to the broker by calling
	// connect() again. This is a possibility for an application that keeps
	// a copy of it's original connect_options, or if the app wants to
	// reconnect with different options.
	// Another way this can be done manually, if using the same options, is
	// to just call the async_client::reconnect() method.
	void reconnect() {
		std::this_thread::sleep_for(std::chrono::milliseconds(2500));
		try {
			cli_.connect(connOpts_, nullptr, *this);
		}
		catch (const mqtt::exception& exc) {
			std::cerr << "Error: " << exc.what() << std::endl;
			exit(1);
		}
	}

	// Re-connection failure
	void on_failure(const mqtt::token& tok) override {
		std::cout << "Connection failed" << std::endl;
		if (++nretry_ > N_RETRY_ATTEMPTS)
			exit(1);
		reconnect();
	}

	// Re-connection success
	void on_success(const mqtt::token& tok) override {
		std::cout << "\nConnection success" << std::endl;
		std::cout << "\nSubscribing to topic '" << TOPIC_RPiCmd_PUB << "'\n"
			<< "\tfor client " << DFLT_CLIENT_ID
			<< " using QoS" << QOS << "\n"
			<< "\nPress Q<Enter> to quit\n" << std::endl;

		cli_.subscribe(TOPIC_RPiCmd_PUB, QOS, nullptr, subListener_);
	}

	// Callback for when the connection is lost.
	// This will initiate the attempt to manually reconnect.
	void connection_lost(const std::string& cause) override {
		std::cout << "\nConnection lost" << std::endl;
		if (!cause.empty())
			std::cout << "\tcause: " << cause << std::endl;

		std::cout << "Reconnecting..." << std::endl;
		nretry_ = 0;
		reconnect();
	}

	// Callback for when a message arrives.
	void message_arrived(mqtt::const_message_ptr msg) override {
		std::cout << "Message arrived" << std::endl;
		std::cout << "\ttopic: '" << msg->get_topic() << "'" << std::endl;
		std::cout << "\tpayload: '" << msg->to_string() << "'\n" << std::endl;
		named_mtx.lock();
		if (etOperationMode == LogAndMqttPublish_AoARawMeas_CompleteEvt)
			LogFilename = msg->to_string();
		bReqDataCollection = true;
		named_mtx.unlock();
	}

	void delivery_complete(mqtt::delivery_token_ptr token) override {}

public:
	usr_callback(mqtt::async_client& cli, mqtt::connect_options& connOpts)
				: nretry_(0), cli_(cli), connOpts_(connOpts), subListener_("Subscription") {}
};



static bool reqquit;

static void sigfunc(int signo)
{
	//UNUSED(signo);
	reqquit = true;
}

// Use GPIO Pin 17, which is Pin 0 for wiringPi library

#define SPI_SLAVE_DATA_RDY_FALLEDGE_PIN 0
#define SPI_MASTER_READY_PIN 1
#define SPI_MASTER_FRMSYNC_PIN 2
// http://wiringpi.com/pins/special-pin-functions/
// Pins 0 through 6: BCM_GPIO 17, 18,  21, 22, 23, 24, 25

// the event counter
static volatile bool slaveDataRdy;

bool need2print()
{
    if (verbose > 0)
        return true;
    else
        return false;
}
// -------------------------------------------------------------------------
// slaveDataRdyInterrupt:  called every time an event occurs
static void slaveDataRdyInterrupt(void) {
    if (need2print()){
        cout << "falling edge interrupt detected.\n";
    }
    slaveDataRdy = true;
}

int received_bytes;
static FILE *BinaryData_fd = 0;
FILE *file_fd_err;
static std::chrono::time_point<std::chrono::steady_clock> lastEventTime_ms;
template<typename TimeT = std::chrono::milliseconds>

static void packet_to_disk(unsigned char *buf, int len, __u32 timestamp)
{
    auto currentTime = std::chrono::steady_clock::now();
    auto duration = chrono::duration_cast< TimeT>(currentTime - lastEventTime_ms);
    int duration_ms = duration.count();
    fwrite(&duration_ms, 1, sizeof(int), BinaryData_fd);
    fwrite(buf, 1, len, BinaryData_fd);
}

static int8_t getRSSIdBm(unsigned char *buf)
{
	int8_t i8RSSI =  (int8_t)buf[SNR_BYTE0];
	return i8RSSI;
}

static bool parse_packet(unsigned char *buf)
{
    uint8_t crc_state = 0;
    for (int byteii = 4; byteii < bufSPIpacketLEN-1; byteii++)
    {
        crc_state = __tl_crc_table[crc_state ^ buf[byteii]];
    }
    if (crc_state == buf[bufSPIpacketLEN-1])
    {
    	return false;
    }
    else
    {
    	//packet_to_disk(buf, bufSPIpacketLEN, 0); // debug code
    	if (need2print()){
        	cout << endl << "crc error, local computed:" << +crc_state
			    << " rcvd:" << +buf[bufSPIpacketLEN-1] << " dat:" << +buf[bufSPIpacketLEN-2]
			    << " preamble:" << +buf[0] << +buf[1] << +buf[2] << +buf[3] << endl;
		}
    	return true;
    }
}

static void SPItransaction(int dev_fd, int byteNum, uint8_t* u8pRxBuf, uint8_t* u8pTxBuf)
{
	struct spi_ioc_transfer	xfer[1];
	memset(&xfer[0], 0, sizeof(xfer[0]));

	xfer[0].rx_buf = (unsigned long)u8pRxBuf;
	xfer[0].len = byteNum;
	xfer[0].tx_buf = (unsigned long)u8pTxBuf;
	xfer[0].len = byteNum;

    if (need2print()){
	    cout << "SPI transfer of " << byteNum << " bytes begins:";
	}
	int status = ioctl(dev_fd, SPI_IOC_MESSAGE(1), xfer);
	if (need2print()){
	    cout << "Completed\n";
	}
	if (status < 0) {
		perror("read");
		return;
	}
}

/*
static void SpiTxRx(int dev_fd, int txByteNum, uint8_t* u8pTxBuf, int rxByteNum, uint8_t* u8pRxBuf )
{
	struct spi_ioc_transfer	xfer[2];
	memset(&xfer[0], 0, 2*sizeof(spi_ioc_transfer));

	xfer[0].tx_buf = (unsigned long)u8pTxBuf;
	xfer[0].len = txByteNum;
	xfer[1].rx_buf = (unsigned long)u8pRxBuf;
	xfer[1].len = rxByteNum;

	//fprintf(stdout, "SPI transfer of %d bytes begins,",byteNum);
	int status = ioctl(dev_fd, SPI_IOC_MESSAGE(2), xfer);
	fprintf(stdout, "Completed\n");
	if (status < 0) {
		perror("read");
		return;
	}
}
*/

static void dumpstat(const char *SPIportName, int SPIfd)
{
	__u8	mode, lsb, bits;
	__u32	speed;

	if (ioctl(SPIfd, SPI_IOC_RD_MODE, &mode) < 0) {
		perror("SPI rd_mode");
		return;
	}
	if (ioctl(SPIfd, SPI_IOC_RD_LSB_FIRST, &lsb) < 0) {
		perror("SPI rd_lsb_fist");
		return;
	}
	if (ioctl(SPIfd, SPI_IOC_RD_BITS_PER_WORD, &bits) < 0) {
		perror("SPI bits_per_word");
		return;
	}
	if (ioctl(SPIfd, SPI_IOC_RD_MAX_SPEED_HZ, &speed) < 0) {
		perror("SPI max_speed_hz");
		return;
	}

	printf("%s: spi mode %d, %d bits %sper word, %d Hz max\n",
		SPIportName, mode, bits, lsb ? "(lsb first) " : "(msb first)", speed);
}

bool needMQTT()
{
	// global variable etOperationMode
    if (etOperationMode == LogAndMqttPublish_AoARawMeas_CompleteEvt)
    {
    	return true;
    }
    else if (etOperationMode == RdAoARawMeas_consolDisplayOnly || etOperationMode == LogAoARawMeas_NoMqttPublish)
    {
    	return false;
    }
    else
    {
    	cerr << "unknown operation mode" << endl;
    	exit(1);
    }

}

int main(int argc, char **argv)
{
	LogFilename = "Log";
	reqquit = false;
	slaveDataRdy = false;
	bReqDataCollection = false;
	signal(SIGINT, sigfunc); // Press Ctrl+C or use command kill to make program quit
	signal(SIGTERM, sigfunc);
	int		c;
	int		logcount = 0;
	int		SPIfd;
	int     AoApktCnt;
	const char	*SPIportName;

	while ((c = getopt(argc, argv, "m:l:v:h:?")) != EOF)
	{
		switch (c)
		{
		case 'm':
			etOperationMode = (OperationModes)atoi(optarg);
			if (etOperationMode >= NUM_OPERATIONMODES)
				goto usage;
			continue;
		case 'l':
			logcount = atoi(optarg);
			if (logcount < 0)
				goto usage;
			continue;
		case 'v':
			verbose++;
			continue;
		case 'h':
		case '?':
		default:
usage:
		cout << "./AoArcvSPI [-h] [-m N] [-lN] [-v]" << endl;
		cout << "hardcoded /dev/spidev0.0" << endl;
		cout << "-h: help" << endl;
		cout << "-m: operation modes" << endl;
		cout << "\t\t 0: dbg use, rd AoA Raw Meas, console print, nothing else" << endl;
		cout << "\t\t 1: Log AoA Raw Meas, No Mqtt Publish" << endl;
		cout << "\t\t 2: Log & Mqtt Publish over unique TOPICs 1)AoA Raw Meas 2)Log Completion Evt(DONE)" << endl;
		cout << "-v: verbose debug msg output" << endl;
		cout << "example usage:" << endl;
		cout << "\t\tcontinously read AoA Raw Meas and do nothing else. exit by ctrl-C: ./AoArcvSPI -m0" << endl;
		cout << "\t\tlog 100 5uS blk and exit: ./AoArcvSPI -m1 -l100" << endl;
		cout << "\t\tAfter rcving MQTT startLog cmd, log 100 5uS blk, then publish raw data and DONE event: ./AoArcvSPI -m2 -l100" << endl;
		return 1;
		}
	}
    lastEventTime_ms = chrono::steady_clock::now();
	string	address  = DFLT_SERVER_ADDRESS,
			clientID = DFLT_CLIENT_ID;

	cout << "Initializing for server '" << address << "'..." << endl;

	mqtt::connect_options connOpts;
	connOpts.set_keep_alive_interval(20);
	connOpts.set_clean_session(true);

	mqtt::async_client client(address, clientID);

	usr_callback cb(client, connOpts);
	client.set_callback(cb);

	mqtt::connect_options conopts;
	
    mqtt::message willmsg_RAW(TOPIC_S2H_RAW, LWT_PAYLOAD, 1, true);
	mqtt::will_options will_RAW(willmsg_RAW);
	conopts.set_will(will_RAW);
	mqtt::message willmsg_EVT(TOPIC_S2H_EVT, LWT_PAYLOAD, 1, true);
	mqtt::will_options will_EVT(willmsg_EVT);
	conopts.set_will(will_EVT);

	cout << "  ...OK" << endl;

	cout << "\nConnecting..." << endl;
	//mqtt::token_ptr conntok = client.connect(conopts);
	mqtt::token_ptr conntok;
	try {
		std::cout << "Connecting to the MQTT server..." << std::flush;
		conntok = client.connect(connOpts, nullptr, cb);
	}
	catch (const mqtt::exception&) {
		std::cerr << "\nERROR: Unable to connect to MQTT server: '"
			<< address << "'" << std::endl;
		return 1;
	}
	cout << "Waiting for the connection..." << endl;
	conntok->wait();
	cout << "  ...OK" << endl;

	// sets up the wiringPi library
	if (wiringPiSetup () < 0){
		fprintf (stderr, "Unable to setup wiringPi: %s\n", strerror (errno));
		return 1;
	}
	pinMode (SPI_SLAVE_DATA_RDY_FALLEDGE_PIN, INPUT);
	pullUpDnControl (SPI_SLAVE_DATA_RDY_FALLEDGE_PIN, PUD_DOWN);
	pinMode (SPI_MASTER_READY_PIN, OUTPUT);
	digitalWrite (SPI_MASTER_READY_PIN,LOW);cout << "MASTER_READY_PIN 0" << endl;

	// set Pin 17/0 generate an interrupt on high-to-low transitions
	// and attach slaveDataRdyInterrupt() to the interrupt
	if ( wiringPiISR (SPI_SLAVE_DATA_RDY_FALLEDGE_PIN, INT_EDGE_FALLING, &slaveDataRdyInterrupt) < 0 ){
		fprintf (stderr, "Unable to setup ISR: %s\n", strerror (errno));
		return 1;
	}

	cout << "Starting the RaspberryPi SPI server\n";

	// use cmd line input of /dev/spidev0.0
	/*
	if ((optind + 1) != argc)
		goto usage;
	SPIportName = argv[optind];
	*/
	SPIportName = "/dev/spidev0.0";

	SPIfd = open(SPIportName, O_RDWR);
	if (SPIfd < 0)
	{
		perror("open");
		return 1;
	}

	__u32 speed = SPI_CLK_RATE_HZ;
	if (ioctl(SPIfd, SPI_IOC_WR_MAX_SPEED_HZ, &speed) < 0)
	{
		perror("cannot set SPI wr max_speed_hz");
		return 0;
	}
	//----- SET SPI MODE -----
	//SPI_MODE_0 (0,0) 	CPOL=0 (Clock Idle low level), CPHA=0 (SDO transmit/change edge active to idle)
	//SPI_MODE_1 (0,1) 	CPOL=0 (Clock Idle low level), CPHA=1 (SDO transmit/change edge idle to active)
	//SPI_MODE_2 (1,0) 	CPOL=1 (Clock Idle high level), CPHA=0 (SDO transmit/change edge active to idle)
	//SPI_MODE_3 (1,1) 	CPOL=1 (Clock Idle high level), CPHA=1 (SDO transmit/change edge idle to active)
	__u8 mode = SPI_MODE;
	if (ioctl(SPIfd, SPI_IOC_WR_MODE, &mode) < 0)
	{
		perror("cannot set SPI wr_mode");
		return 0;
	}
	dumpstat(SPIportName, SPIfd);

	while(1)
	{
		if (digitalRead(SPI_SLAVE_DATA_RDY_FALLEDGE_PIN) == 0)
		{
			const int bytediscarded = 10;
			uint8_t RxBuf[bytediscarded], TxBuf[bytediscarded];
			SPItransaction(SPIfd, bytediscarded, RxBuf, TxBuf);
			
			cout << bytediscarded << " byte garbage data discard,SLAVE_DATA_RDY_PIN=0" << endl;
			if (reqquit)
				break;
		}
		else
		{
			cout << "SLAVE_DATA_RDY_PIN=1" << endl;
			break;
		}
	}
	int successPktCnt = 0;
	bool bWait4startSignal;
	switch(etOperationMode)
	{
		case RdAoARawMeas_consolDisplayOnly:
		case LogAoARawMeas_NoMqttPublish:
			bWait4startSignal = false;
			break;
		case LogAndMqttPublish_AoARawMeas_CompleteEvt:
			bWait4startSignal = true;
			break;
		default:
			cerr << "setsrhdrthertuth";
			exit(0);
	}
	if (logcount >=0 && !reqquit)
	{
		received_bytes = 0;
		char filename[255];
		AoApktCnt = 0;
		digitalWrite (SPI_MASTER_READY_PIN,HIGH);cout << "MASTER_READY_PIN 1" << endl;
		usleep(1000);
		uint8_t PktRxBuf[bufSPIpacketLEN];
		uint8_t SPItxBuf[MAX_SPI_TRANS_BYTES];
		const auto TIMEOUT = std::chrono::seconds(10);
		int sumRSSI = 0; // not precise, RSSI is in dBm, not linear
		int sumRSSIcnt = 0;
		while(true)
		{
			if (bWait4startSignal)
			{
				if (reqquit)
					break;
				if (bReqDataCollection) // set to true in MQTT sub callback
				{
					bReqDataCollection = false;
					bWait4startSignal = false;
				}
				else
					continue;
			}
            if (LogFilename.length()!=0)
            {
			    if (BinaryData_fd == 0)
			    {
				    sprintf(filename,"./%s.dat",LogFilename.c_str());
				    BinaryData_fd = fopen(filename, "w");
			    }
            }
			//if (digitalRead(SPI_SLAVE_DATA_RDY_FALLEDGE_PIN) == 0 || slaveDataRdy)
			if (slaveDataRdy)
			{
				slaveDataRdy = false;

				uint8_t RdCnt = bufSPIpacketLEN/MAX_SPI_TRANS_BYTES;
				if (RdCnt*MAX_SPI_TRANS_BYTES < bufSPIpacketLEN)
					RdCnt ++;

				for (uint8_t RDii = 0; RDii < RdCnt; RDii++)
				{
					// very important delay. RPi CPU runs much faster than cc2640 ARM
					// without delay, SPI master reading in RPi starts before ARM is ready to transfer data
					usleep(DELAY_TAU1_uS);

					// grab_log_packet(SPIfd, BinaryData_fd);
					int SPItransferByteCnt;
					if (RDii < RdCnt-1)
						SPItransferByteCnt = MAX_SPI_TRANS_BYTES;
					else
						SPItransferByteCnt = bufSPIpacketLEN - RDii*MAX_SPI_TRANS_BYTES;
				    if (need2print()){
				    	cout << "(" << +AoApktCnt << "-" << +RDii << ") ";
			    	}
					SPItransaction(SPIfd, SPItransferByteCnt, &(PktRxBuf[RDii*MAX_SPI_TRANS_BYTES]), SPItxBuf);
					digitalWrite (SPI_MASTER_READY_PIN,LOW);//cout << "MASTER_READY_PIN 0ghy" << endl;
					if (RDii == RdCnt-1)
					{
						if (!parse_packet(PktRxBuf))
						{
						    
						    int8_t i8RSSI = getRSSIdBm(PktRxBuf);
							sumRSSI += i8RSSI;
							sumRSSIcnt ++;
							if (AoApktCnt % RSSI_PRINT_DECIMATION == 0)
							    cout <<"RSSI: " << +i8RSSI << endl;

						    if (need2print()){
    							cout << "----------------------" << +PktRxBuf[7] << endl;
    						}
							successPktCnt++;
							switch(etOperationMode)
							{
								case RdAoARawMeas_consolDisplayOnly:
									break;
								case LogAndMqttPublish_AoARawMeas_CompleteEvt:
								case LogAoARawMeas_NoMqttPublish:
                                    if (LogFilename.length()!=0)
									    packet_to_disk(PktRxBuf, bufSPIpacketLEN, 0);
									break;
								default:
									cerr << "ujgeruyty";
									exit(0);
							}

							mqtt::delivery_token_ptr pubtok;
							switch(etOperationMode)
							{
								case LogAndMqttPublish_AoARawMeas_CompleteEvt:
								    if (need2print()){
    									cout << "\nSending next message..." << endl;
									}
									pubtok = client.publish(TOPIC_S2H_RAW, PktRxBuf, bufSPIpacketLEN, QOS, false);
									if (need2print()){
									    cout << "  ...with token: " << pubtok->get_message_id() << endl;
									    cout << "  ...for message with " << pubtok->get_message()->get_payload().size()
										    << " bytes" << endl;
								    }
									pubtok->wait_for(TIMEOUT);
									if (need2print()){
    									cout << "  ...OK" << endl;
									}
									break;
								case RdAoARawMeas_consolDisplayOnly:
								case LogAoARawMeas_NoMqttPublish:
									break;
								default:
									cerr << "setsrhdrthertuth";
									exit(0);
							}
						}
						memset(PktRxBuf, 0, sizeof(PktRxBuf));
						memset(SPItxBuf, 0, sizeof(SPItxBuf));
						AoApktCnt++;
						digitalWrite (SPI_MASTER_READY_PIN,HIGH);
						if (need2print()){
    						cout << "all done. MASTER_READY_PIN 1" << endl;
    			        }
					}
				}
			}
			else
				usleep(10000);

			if (reqquit)
				break;

			if (logcount > 0 && AoApktCnt >= logcount)
			{
                if (LogFilename.length()!=0)
				    fclose(BinaryData_fd);
				BinaryData_fd = 0;
                AoApktCnt = 0;
                bWait4startSignal = true;
                switch(etOperationMode)
                {
                    case LogAoARawMeas_NoMqttPublish:
                    case RdAoARawMeas_consolDisplayOnly:
                        break;
                    case LogAndMqttPublish_AoARawMeas_CompleteEvt:
                    {
					    mqtt::delivery_token_ptr pubtok;
					    pubtok = client.publish(TOPIC_S2H_EVT, "DONE", 4, QOS, false);
					    if (need2print()){
					        cout << "  ...with token: " << pubtok->get_message_id() << endl;
					        cout << "  ...for message with " << pubtok->get_message()->get_payload().size()
						        << " bytes" << endl;
				        }
					    pubtok->wait_for(TIMEOUT);
					    cout << "avg RSSI over this period is: " << sumRSSI/sumRSSIcnt << endl;
                        break;
                    }
                    default:
                        cerr << "UYI BKGYJER54";
                        exit(2);
                }
			}
		}
	}

	if (reqquit)
	{
		cout << "Manual quit requested, bye." << endl;
	}
	cout << "successPktCnt:" << successPktCnt << " out of " << AoApktCnt << endl;
	close(SPIfd);
	digitalWrite (SPI_MASTER_READY_PIN,LOW); cout << "exit. MASTER_READY_PIN 0" << endl;
	digitalWrite (SPI_SLAVE_DATA_RDY_FALLEDGE_PIN,HIGH);

	// Double check that there are no pending tokens
	auto toks = client.get_pending_delivery_tokens();
	if (!toks.empty())
		cout << "Error: There are pending delivery tokens!" << endl;
	// Disconnect
	cout << "\nDisconnecting..." << endl;
	conntok = client.disconnect();
	conntok->wait();
	cout << "  ...OK" << endl;
	return 0;
}


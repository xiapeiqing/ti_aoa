#include "PinChangeInt.h"
#include "transportLayer.h"
//////////////
#define MOTOR_CHOICE 2
#define pwrOnCtrlVal 0
typedef enum opMode{
	NonStopConstRPM = 0,
	NonStopSpeedSineTurn,
	StartStopMotorCfgTest,
	SerialCtrl, // unittest: 1080 (py352) environment: Host_workspaces/utilities/arduinoBLDCgimbalPyCtrl/serialControl.py
                // used by: Host_workspaces/pyHostDsp/service_BLEcomms.py
	OpModeCnt
} OpMode;
#define default_etOpMode SerialCtrl
int increment = 3;
OpMode etOpMode = default_etOpMode;

#define PWM_A_MOTOR1 3    // ATMEGA328p DIGITAL_3, IC_PIN1
#define PWM_B_MOTOR1 5    // ATMEGA328p DIGITAL_5, IC_PIN9
#define PWM_C_MOTOR1 6    // ATMEGA328p DIGITAL_6, IC_PIN10
//
#define PWM_A_MOTOR2 9    // ATMEGA328p DIGITAL_9, IC_PIN13
#define PWM_B_MOTOR2 10   // ATMEGA328p DIGITAL_10, IC_PIN14
#define PWM_C_MOTOR2 11   // ATMEGA328p DIGITAL_11, IC_PIN15
//////////////
#define CTRL_PWR 100
int CurrCtrlVal = 0; // currently applied ctrl setting value for BLDC anglular control

#define sineArraySize 360
#if false //true
// pure sine wave
// jumpy rotation
const int pwmSin[sineArraySize] = {127,129,131,134,136,138,140,143,145,147,149,151,154,156,158,160,162,164,166,169,171,173,175,177,179,181,183,185,187,189,191,193,195,196,198,200,202,204,205,207,209,211,212,214,216,217,219,220,222,223,225,226,227,229,230,231,233,234,235,236,237,239,240,241,242,243,243,244,245,246,247,248,248,249,250,250,251,251,252,252,253,253,253,254,254,254,254,254,254,254,255,254,254,254,254,254,254,254,253,253,253,252,252,251,251,250,250,249,248,248,247,246,245,244,243,243,242,241,240,239,237,236,235,234,233,231,230,229,227,226,225,223,222,220,219,217,216,214,212,211,209,207,205,204,202,200,198,196,195,193,191,189,187,185,183,181,179,177,175,173,171,169,166,164,162,160,158,156,154,151,149,147,145,143,140,138,136,134,131,129,127,125,123,120,118,116,114,111,109,107,105,103,100,98,96,94,92,90,88,85,83,81,79,77,75,73,71,69,67,65,63,61,59,58,56,54,52,50,49,47,45,43,42,40,38,37,35,34,32,31,29,28,27,25,24,23,21,20,19,18,17,15,14,13,12,11,11,10,9,8,7,6,6,5,4,4,3,3,2,2,1,1,1,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,0,1,1,1,2,2,3,3,4,4,5,6,6,7,8,9,10,11,11,12,13,14,15,17,18,19,20,21,23,24,25,27,28,29,31,32,34,35,37,38,40,42,43,45,47,49,50,52,54,56,58,59,61,63,65,67,69,71,73,75,77,79,81,83,85,88,90,92,94,96,98,100,103,105,107,109,111,114,116,118,120,123,125};
#else
// Space-Vector PWMs (SVPWM)
// rotation still has unexpected jump
const int pwmSin[sineArraySize] = {128, 132, 136, 140, 143, 147, 151, 155, 159, 162, 166,
          170, 174, 178, 181, 185, 189, 192, 196, 200, 203, 207,
          211, 214, 218, 221, 225, 228, 232, 235, 238, 239, 240,
          241, 242, 243, 244, 245, 246, 247, 248, 248, 249, 250,
          250, 251, 252, 252, 253, 253, 253, 254, 254, 254, 255,
          255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
          255, 254, 254, 254, 253, 253, 253, 252, 252, 251, 250,
          250, 249, 248, 248, 247, 246, 245, 244, 243, 242, 241,
          240, 239, 238, 239, 240, 241, 242, 243, 244, 245, 246,
          247, 248, 248, 249, 250, 250, 251, 252, 252, 253, 253,
          253, 254, 254, 254, 255, 255, 255, 255, 255, 255, 255,
          255, 255, 255, 255, 255, 255, 254, 254, 254, 253, 253,
          253, 252, 252, 251, 250, 250, 249, 248, 248, 247, 246,
          245, 244, 243, 242, 241, 240, 239, 238, 235, 232, 228,
          225, 221, 218, 214, 211, 207, 203, 200, 196, 192, 189,
          185, 181, 178, 174, 170, 166, 162, 159, 155, 151, 147,
          143, 140, 136, 132, 128, 124, 120, 116, 113, 109, 105,
          101, 97, 94, 90, 86, 82, 78, 75, 71, 67, 64, 60, 56, 53,
          49, 45, 42, 38, 35, 31, 28, 24, 21, 18, 17, 16, 15,
          14, 13, 12, 11, 10, 9, 8, 8, 7, 6, 6, 5, 4, 4, 3, 3, 3,
          2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2,
          3, 3, 3, 4, 4, 5, 6, 6, 7, 8, 8, 9, 10, 11, 12, 13, 14,
          15, 16, 17, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 8,
          7, 6, 6, 5, 4, 4, 3, 3, 3, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 5, 6, 6, 7, 8,
          8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 21, 24, 28, 31,
          35, 38, 42, 45, 49, 53, 56, 60, 64, 67, 71, 75, 78, 82,
          86, 90, 94, 97, 101, 105, 109, 113, 116, 120, 124};
#endif

int phaseShift = sineArraySize / 3; 
int currentStepA = 0;
int currentStepB = currentStepA + phaseShift;
int currentStepC = currentStepB + phaseShift;

uint32_t loopindex = 0;
void setMotorPosition(int motor, int position, int power);
void initBGC();

void setup() {
    Serial.begin(115200);
    initBGC();
    setMotorPosition(MOTOR_CHOICE, pwrOnCtrlVal, CTRL_PWR);
}

uint32_t lastTime_uS = 0;
#define delayPerLoopMs 500
int StepsPerSinePi;
void loop() 
{
	static uint16_t loopii = 0;
	if (etOpMode == NonStopConstRPM)
	{
		if (loopii % 100 == 0) Serial.println("NonStopConstRPM");
		CurrCtrlVal += increment;
		Serial.println(CurrCtrlVal);
		setMotorPosition(MOTOR_CHOICE, CurrCtrlVal, CTRL_PWR);
		delay(delayPerLoopMs);
	}
	else if(etOpMode == NonStopSpeedSineTurn)
	{
		if (loopii % 100 == 0) Serial.println("NonStopSpeedSineTurn");
		StepsPerSinePi = 100;
		CurrCtrlVal += increment*sin(PI*(float)(loopii%StepsPerSinePi)/StepsPerSinePi);
		Serial.println(CurrCtrlVal);
		setMotorPosition(MOTOR_CHOICE, CurrCtrlVal, CTRL_PWR);
		delay(delayPerLoopMs);
	}
	else if(etOpMode == StartStopMotorCfgTest)
	{
		if (loopii % 100 == 0) Serial.println("StartStopMotorCfgTest");
		CurrCtrlVal += increment;
		Serial.println(CurrCtrlVal);
		setMotorPosition(MOTOR_CHOICE, CurrCtrlVal, CTRL_PWR);
		delay(delayPerLoopMs);
		if (CurrCtrlVal >= 360)
		{
			delay(2000);
			CurrCtrlVal = 0;
		}
	}
	else if(etOpMode == SerialCtrl)
	{
		while (Serial.available() > 0) {
			uint8_t serialRdByte = Serial.read();
			VarLenProtocolParserResult res = onProtocolByte(serialRdByte);
			switch (res)
			{
				case SVTELEMPARSER_ERROR:
				{
					Serial.println("NACK");
				}
				break;
				case SVTELEMPARSER_PAYLOADLENVIOLATION:
				{
					Serial.println("bad PAYLOAD len");
				}
				break;
				case SVTELEMPARSER_INCOMPLETE:
				{
					// do nothing
				}
				break;
				case SVTELEMPARSER_COMPLETE:
				{
					#define ElectricalPhase 90
					int32_t rcvd_cmd;
					if (m_pOneMsgBuf[0] < OpModeCnt)
						etOpMode = (OpMode)m_pOneMsgBuf[0];
					else
						etOpMode = default_etOpMode;
					memcpy(&rcvd_cmd, &(m_pOneMsgBuf[1]), 4);
					switch (etOpMode)
					{
					case NonStopConstRPM:
						increment = (int)rcvd_cmd;
						break;
					case NonStopSpeedSineTurn:
						increment = (int)rcvd_cmd;
						break;
					case StartStopMotorCfgTest:
						if (360%increment != 0)
							Serial.print("S2H.StartStopMotorCfgTest needs integer multiple of cmd == 360");
						else
						{
							increment = (int)rcvd_cmd;
						}
						break;
					case SerialCtrl:
						CurrCtrlVal = (int)rcvd_cmd;
						setMotorPosition(MOTOR_CHOICE, CurrCtrlVal, CTRL_PWR);
						break;
					default:
						Serial.print("S2H.unknownMode!");
						break;
					}
					Serial.println(CurrCtrlVal);
				}
				break;
			}
		}
	}
	else
	{
		Serial.println("asdrfgafg");
	}
	loopii++;
}

void setMotorPosition(int motor, int position, int power) {
    if (position >= 0)
    {
        position = position%360;
    }
    else
    {
        position = -position;
        position %= 360;
        position = 360 - position;
    }

    int pin1, pin2, pin3;
    int pwm_a, pwm_b, pwm_c;

    power = constrain(power, 0, 255); // if only it were that easy

    if (motor == 1) {
        pin1 = PWM_A_MOTOR1;
        pin2 = PWM_B_MOTOR1;
        pin3 = PWM_C_MOTOR1;
    }
    if (motor == 2) {
        pin1 = PWM_A_MOTOR2;
        pin2 = PWM_B_MOTOR2;
        pin3 = PWM_C_MOTOR2;
    }

    // get number from the sin table, change amplitude from max
    pwm_a = (pwmSin[(position + currentStepA) % 360]) * (power / 255.0);
    pwm_b = (pwmSin[(position + currentStepB) % 360]) * (power / 255.0);
    pwm_c = (pwmSin[(position + currentStepC) % 360]) * (power / 255.0);

    analogWrite(pin1, pwm_a);
    analogWrite(pin2, pwm_b);
    analogWrite(pin3, pwm_c);
}

void initBGC() {
    // sets the speed of PWM signals. 
    // micros() uses Timer0, if modified, micros() return value won't be in uS.
    // The Arduino uses Timer 0 internally for the millis() and delay() functions http://www.righto.com/2009/07/secrets-of-arduino-pwm.html
    // https://playground.arduino.cc/Main/TimerPWMCheatsheet
    TCCR0B = (TCCR0B & 0b11111000) | 0x02; // pins 6 and 5
    TCCR1B = (TCCR1B & 0b11111000) | 0x01;   // pins 9 and 10
    TCCR2B = (TCCR2B & 0b11111000) | 0x01;   // pins 11 and 3

    pinMode(PWM_A_MOTOR1, OUTPUT); 
    pinMode(PWM_B_MOTOR1, OUTPUT); 
    pinMode(PWM_C_MOTOR1, OUTPUT); 

    pinMode(PWM_A_MOTOR2, OUTPUT); 
    pinMode(PWM_B_MOTOR2, OUTPUT); 
    pinMode(PWM_C_MOTOR2, OUTPUT); 
}

/*
10, Hex:4d32526204000a00000076
20, Hex:4d3252620400140000005b
30, Hex:4d32526204001e00000040
40, Hex:4d32526204002800000001
50, Hex:4d32526204003200000022
60, Hex:4d32526204003c00000037
70, Hex:4d32526204004600000084
80, Hex:4d325262040050000000b5
90, Hex:4d32526204005a000000ae
100, Hex:4d325262040064000000f3
110, Hex:4d32526204006e000000e8
120, Hex:4d325262040078000000d9
130, Hex:4d3252620400820000009b
140, Hex:4d32526204008c0000008e
150, Hex:4d325262040096000000ad
160, Hex:4d3252620400a0000000ec
170, Hex:4d3252620400aa000000f7
180, Hex:4d3252620400b4000000da
190, Hex:4d3252620400be000000c1
200, Hex:4d3252620400c800000060
210, Hex:4d3252620400d200000043
220, Hex:4d3252620400dc00000056
230, Hex:4d3252620400e600000005
240, Hex:4d3252620400f000000034
250, Hex:4d3252620400fa0000002f
260, Hex:4d32526204000401000025
270, Hex:4d32526204000e0100003e
280, Hex:4d3252620400180100000f
*/

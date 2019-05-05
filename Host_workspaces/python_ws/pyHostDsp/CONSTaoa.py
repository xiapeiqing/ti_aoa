# etMode
HardCodeTurnSeq = 'HardCodeTurnSeq'
bldcCtrlCmdFromPC = 'bldcCtrlCmdFromPC'
collectLUT_then_CmdFromPC1 = 'collectLUT_then_CmdFromPC1'
collectLUT_then_CmdFromPC2 = 'collectLUT_then_CmdFromPC2'

#mState
State_uninitialized = "State_uninitialized"
State_init = "State_init"
State_SendBLDCctrlCmd = "State_SendBLDCctrlCmd"
State_TestdesiredPos = "State_TestdesiredPos"
State_wait4mqttMsg = "State_wait4mqttMsg"

State_PCuninitialized = "State_PCuninitialized"
State_PCsendBLDCrotate_startCMD = "State_PCsendBLDCrotate_startCMD"
State_PCwait4MqttDoneEvt = "State_PCwait4MqttDoneEvt"
State_PCwait4matlabCmd = "State_PCwait4matlabCmd"

RPiStatus_pktCollected = "RPiStatus_pktCollected"
RPiStatus_LUTdatasetRdy = "RPiStatus_LUTdatasetRdy"

realtimeLogFolder = '../../datalog/'
analysisResultFolder = './analysisResultFolder/'
matlab2pcPythonCmdFile = 'rotate_and_EmbdAoAmeas.txt'
pcPython2matlabStatusRptFile = 'AoArawDataCollectionStatus.txt'
pcPython2matlabLUTrawdataRdy = "pcPython2matlabLUTrawdataRdy.txt"


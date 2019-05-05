#!/bin/bash
#sshpass -p "M2Robots" scp ./runservice.sh pi@192.168.31.211:/home/pi/code/pyHostDsp/ 
sshpass -p "M2Robots" scp ./*.py pi@192.168.31.211:/home/pi/code/pyHostDsp/ 
#sshpass -p "M2Robots" scp ../utilities/shellUtilityRPi/blecpp pi@192.168.31.211:/home/pi/ 
#sshpass -p "M2Robots" scp ../utilities/shellUtilityRPi/blepython pi@192.168.31.211:/home/pi/ 
#sshpass -p "M2Robots" scp ../utilities/shellUtilityRPi/clearlog pi@192.168.31.211:/home/pi/ 

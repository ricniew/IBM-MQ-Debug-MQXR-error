# IBM-MQ-Debug-MQXR-error

Author: Richard Niewolik

Contact: niewolik@de.ibm.com

Revision: 1.0

#

[1 General](#1-general) <BR>
[2 Usage](#2-usage) <BR>
[3 Sample run](#3-sample-run)


1 General
=========

This script helps to start an MQXR trace, a tcpdump trace and catch an specific FDC error.
By default it looks for the AMQXR1003E error. If you need to catch another FDC error, the line 150 needs to be modified:
        
    104: ERROR_TO_CAPTURE="AMQXR1003E"

2 Usage
=======

Execution:

    ./debugFDC.sh -q MYQM -h /opt/mqm -e /var/mqm/errors -p 1883

  
  -q  = Queue manager name <BR>
  -h  = ITBM MQ home folder <BR>
  -e  = Error log directory (where FDC fiels are generated) <BR>
  -p  = MQXR Ports used
  

3 Sample run
=============
```
[root@MQ911 errors]# ./test.sh -q MYQM -h /opt/mqm -e /var/mqm/errors -p 1883
INFO: - main - QMGR_NAME=MYQM
INFO: - main - QMGR_MQXR_PORT=1883
INFO: - main - FDC log dir : /var/mqm/errors
INFO: - main - MQHOME : /opt/mqm
INFO: - main - IP port used to connect : 0.0.0.0
INFO: - main - TCPDUMP output: /var/mqm/errors/tcpdump_MQ911.fyre.ibm.com_2022_11_30_08_58_AM.pcap
INFO: - main - Remove existing FDC files
INFO: - main - Start tcpdump trace: 'tcpdump -i any -s 0 -w /var/mqm/errors/tcpdump_MQ911.fyre.ibm.com_2022_11_30_08_58_AM.pcap dst 0.0.0.0 and port 1883'
tcpdump: listening on any, link-type LINUX_SLL (Linux cooked), capture size 262144 bytes
INFO: - main - Start MQXR chl trace: 'controlMQXRChannel.sh -qmgr=MYQM -port=1883 -mode=starttrace'
Warning: This program's arguments and output may change in future releases.
Command completed successfully
INFO: - main - Waiting for error AMQXR1003E to be raised
....................................................................................................................................................AMQXR1003E:an invalid message
INFO: - main - AMQXR1003E error was captured
INFO: - cleanup - Stop MQXR chl trace: 'controlMQXRChannel.sh -qmgr=MYQM -port=1883 -mode=stoptrace'
Warning: This program's arguments and output may change in future releases.
Command completed successfully
INFO: - main - stop tcpdump trace
INFO: - main - TCPDUMP output files is= /var/mqm/errors/tcpdump_MQ911.fyre.ibm.com_2022_11_30_08_58_AM.pcap'
INFO: - main - end
[root@MQ911 errors]#
```

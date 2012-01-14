#!/bin/bash

# chkconfig: 2345 91 1
# description:  Make this host a MySQL Master.

# Comments to support LSB init script conventions
### BEGIN INIT INFO
# Provides: mysql-start-master
# Required-Start: $local_fs $network $remote_fs mysql.server
# Should-Start: ypbind nscd ldap ntpd xntpd
# Required-Stop: $local_fs $network $remote_fs
# Default-Start:  2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Make this host a MySQL Master.
# Description: njordao@co.sapo.pt
### END INIT INFO

echo ""
echo "This Script will start MySQL Master and create the WRITE IP $IPWRITE"
echo "njordao@co.sapo.pt"
echo ""

if [ "$1" == "stop" ] ; then
	echo -e "\nSTOP does nothing!"
	echo "Please stop MYSQL and unconfigure the WRITER ip manually if needed"
	echo "QUIT!!"
	exit
fi

#Get Options
. /etc/mysql-variables.conf
if [ $? -ne 0 ] ; then
        echo "Probelm geting options."
        echo "This software was poorely installed."
        echo "QUIT!"
        exit;
fi

THISHOSTIP=`$IFCONFIG $INTERFACE | $GREP "inet addr:" | $AWK '{ print $2  }' | $AWK -F : '{ print $2}'`
if [ -z "$THISHOSTIP" ] ; then
	echo "Error! Bad interface!"
	echo "Quiting..."
	exit 1
fi
echo "This host has the ip $THISHOSTIP"

#############
#TEST NETWORK
#############

#TESTE GW
echo -e "\n-> Testing the network"
RESULT=`$PING -qn -c $PINGCOUNT $IPGW | grep received | awk '{ print $4  }'`
#echo $RESULT
if [ $RESULT -ne $PINGCOUNT ] ; then
    echo "ERROR! NETWORK DOWN!!! - $RESULT of $PINGCOUNT"
    echo "QUIT!"
    exit
fi
echo "GW pings OK!"

#TESTE IPWRITE
echo -e "\n-> Testing to see if the write ip is UP. It should NOT be UP"
RESULT=`$PING -qn -c $PINGCOUNT $IPWRITE | grep received | awk '{ print $4  }'`
#echo $RESULT
if [ $RESULT -gt 0 ] ; then
    echo "ERROR! NETWORK MYSQL IP WRITER UP!"
    echo "Please shutdown MySQL Master Manually and unconfigure writer IP."
    echo "QUIT!"
    exit
fi
echo "IPWRITER NOT UP! OK!"

echo -e "\n-> Checking if this host can/should be MASTER..."

# CHECK IF MYSQL IS UP
HOSTNAME_MYSQL=`$MYSQLCLIENT -h $THISHOSTIP $MYSQL_AUTH -e "SHOW VARIABLES like 'hostname' \G" | egrep "Value:" | $AWK '{ print $2  }'`
if [ -z "$HOSTNAME_MYSQL" ] ; then
    echo "$THISHOSTIP is unnavailable"
    echo "Please start MYSQL service"
    echo "QUIT!"
    exit
fi
# Ver se tudo bate certo
HOSTNAME=`uname -n`
if [ $HOSTNAME_MYSQL != $HOSTNAME ] ; then
    echo "Algo de estranho se passa..."
    echo "$HOSTNAME_MYSQL diferente de $HOSTNAME"
    echo "QUIT!"
    exit
fi

RESULT=`$MYSQLCLIENT -h $THISHOSTIP $MYSQL_AUTH -e "SHOW SLAVE STATUS \G" | egrep "Exec_Master_Log_Pos|\ Master_Log_File:" | $AWK '{ print $2 }'`
if [ -z "$RESULT" ] ; then
        echo "Ok! I'm not a slave!"
        RESULT=`$MYSQLCLIENT -h $THISHOSTIP $MYSQL_AUTH -e "SHOW MASTER STATUS \G" | egrep "Position:|File:" | $AWK '{ print $2  }'`
        if [ -z "$RESULT" ] ; then
            echo "But I'm not a Master... Something is wrong. Don't know what! I am afraid..."
            echo "QUIT!"
            exit
        fi
        echo "$HOSTNAME: I WILL BE A MASTER!!! MHUAHAHAHAHAH!"
else
	echo "I'm a SLAVE. Must BE SLAVE. Will Allways BE SLAVE!"
	echo "QUIT!!!"
	exit
fi

echo -e "\n-> Checking if the slaves know that I'm a MASTER..."

for i in $IPREADS; do

    # CHECK IF MYSQL IS UP
    HOSTNAME_TMP=`$MYSQLCLIENT -h $i $MYSQL_AUTH -e "SHOW VARIABLES like 'hostname' \G" | egrep "Value:" | $AWK '{ print $2  }'`
    if [ -z "$HOSTNAME_TMP" ] ; then
            echo "$i is unnavailable"
            continue;
    fi
    if [ $HOSTNAME_TMP == $HOSTNAME ] ; then
        #It's me, move along.
        continue
    fi
    
    echo "$i - $HOSTNAME_TMP"

    RESULT=`$MYSQLCLIENT -h $i $MYSQL_AUTH -e "SHOW SLAVE STATUS \G" | egrep "Master_Host:" | $AWK '{ print $2 }'`
    if [ -z "$RESULT" ] ; then
            echo "This guy doesn't know he is a slave..."
            echo "Shut him down or I won't work"
            echo "QUIT!"
            exit
    fi
    echo "$HOSTNAME_TMP: My Master is $RESULT"
    if [ $RESULT != $THISHOSTIP ] ; then
        echo "$HOSTNAME: What? I'm NOT MASTER? You should check this but will continue..."
    else
        echo "$HOSTNAME: MHUAHAHAHAHAH"
    fi
    
    RESULT=`$MYSQLCLIENT -h $i $MYSQL_AUTH -e "SHOW VARIABLES like 'read_only' \G" | egrep "Value:" | $AWK '{ print $2  }'`
    if [ "$RESULT" == "OFF" ] ; then
            echo "This guy is not READ_ONLY..."
            echo "Shut him down or I won't work"
            echo "QUIT!"
            exit
    fi

    
done
    
echo -e "\n-> A levantar o Master $HOSTNAME"
echo "By the power of... I WILL BE A MASTER!!!"
echo "Turning off read-only. Note: Must have acess through socket as root!"
$MYSQLCLIENT -e "$SQL_READONLYOFF"
if [ $? -ne 0 ] ; then
        echo "Error Configuring READONLY"
        echo "Snif. I cant be MASTER!"
        echo "QUIT!"
        exit;
fi

#TESTE IPWRITE
echo -e "\n-> Testing AGAIN to see if the write ip is UP. It should NOT be UP"
RESULT=`$PING -qn -c $PINGCOUNT $IPWRITE | grep received | awk '{ print $4  }'`
#echo $RESULT
if [ $RESULT -gt 0 ] ; then
    echo "ERROR! NETWORK MYSQL IP WRITER UP!"
    echo "Please shutdown MySQL Master Manually and unconfigure writer IP."
    echo "QUIT!"
    exit
fi
echo "IPWRITER NOT UP! COOL MAN, COOL!"
echo "Let's make it up!"

echo -e "\n-> configure Writer IP"
`$IFCONFIG $INTERFACE add $IPWRITE netmask $NETMASK`
if [ $? -ne 0 ] ; then
        echo "Error Configuring Virtual IP"
        echo "Snif. I cant be MASTER!"
        echo "QUIT!"
        exit;
fi

# CHECK IF MYSQL IS UP
HOSTNAME_MYSQL=`$MYSQLCLIENT -h $IPWRITE $MYSQL_AUTH -e "SHOW VARIABLES like 'hostname' \G" | egrep "Value:" | $AWK '{ print $2  }'`
if [ $? != 0 ] ; then
    echo "$IPWRITE is unnavailable"
    echo "Please check if MySQL is listening"
fi

echo "!!DONE!!"
echo "!!I AM MASTER!!"



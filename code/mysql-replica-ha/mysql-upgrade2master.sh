#!/bin/bash

#Get Options
. /etc/mysql-variables.conf
if [ $? -ne 0 ] ; then
        echo "Probelm geting options."
        echo "This software was poorely installed."
        echo "QUIT!"
        exit;
fi

max ()
if [ "$1" -gt "$2" ] ; then
	RETURN_VALUE=$1;
else
	RETURN_VALUE=$2;
fi

echo -e "\nThis script will try to upgrade a MYSQL SLAVE to MASTER"

THISHOSTIP=`$IFCONFIG $INTERFACE | $GREP "inet addr:" | $AWK '{ print $2  }' | $AWK -F : '{ print $2}'`
echo "This host has the ip $THISHOSTIP"

#############
#TEST NETWORK
#############

#TESTE GW
echo -e "\n -> Testing the network"
RESULT=`$PING -qn -c $PINGCOUNT $IPGW | grep received | awk '{ print $4  }'`
#echo $RESULT
if [ $RESULT -ne $PINGCOUNT ] ; then
	echo "ERROR! NETWORK DOWN!!! - $RESULT of $PINGCOUNT"
	exit
fi
echo "GW pings OK!"

#TESTE IPWRITE
echo -e "\n -> Testing to see if the write ip is UP. It should NOT be UP"
RESULT=`$PING -qn -c $PINGCOUNT $IPWRITE | grep received | awk '{ print $4  }'`
#echo $RESULT
if [ $RESULT -gt 0 ] ; then
	echo "ERROR! NETWORK MYSQL IP WRITER UP!"
	echo "Please shutdown MySQL Master Manually and unconfigure writer IP."
	exit
fi
echo "IPWRITER NOT UP! OK!"

################
#MYSQL SYNC INFO
################

DIFF_WARN=-1
DIFF_FATAL=-1
LOGFILE=""
MAXLOGPOS="-1"
SLAVELIST=""
FUTUREMASTERPOS="-1"

echo -e "\n -> Checking the SLAVES status and retrieve information."

for i in $IPREADS; do
	echo "* Analysing $i"
	# CHECK IF MYSQL IS UP
	HOSTNAME_TMP=`$MYSQLCLIENT -h $i $MYSQL_AUTH -e "system uname -n"`
	if [ $? -ne 0 ] ; then
		echo "$i is unnavailable"
		continue;
	fi
	echo "$i - $HOSTNAME_TMP"

	# GET MASTER INFO. LOG FILE AND LOG POS
	RESULT=`$MYSQLCLIENT -h $i $MYSQL_AUTH -e "SHOW SLAVE STATUS \G" | egrep "Exec_Master_Log_Pos|\ Master_Log_File:" | $AWK '{ print $2 }'`
	if [ -z "$RESULT" ] ; then
		echo "Possible MASTER or one of the slaves is NOT CONFIGURED CORRECTELY"
		echo "Please shutdown this MySQL or make it a slave if it is not a master"
		echo "Quiting!!!"
		exit
	fi
	LOGFILETEMP=`echo $RESULT | $AWK '{ print $1 }'`
	LOGPOSTEMP=`echo $RESULT | $AWK '{ print $2 }'`
	
	# MAYBE WE SHOULD DISCARD THIS SLAVE... TODO
	if [ ! -n "$LOGPOSTEMP" ] ; then
		LOGPOSTEMP=0
	fi
	
	# CHECK IF SLAVE IS SYNC
	echo "   $LOGFILETEMP, $LOGPOSTEMP"
	if [ "$LOGFILETEMP" != "$LOGFILE" ] ; then
		DIFF_FATAL=$((DIFF_FATAL+=1))
		LOGFILE=$LOGFILETEMP
	fi
	if [ "$LOGPOSTEMP" -ne "$MAXLOGPOS" ] ; then
		 DIFF_WARN=$((DIFF_WARN+=1))
	fi
	max $LOGPOSTEMP $MAXLOGPOS
	MAXLOGPOS=$RETURN_VALUE
	
	#MAXLOGPOS should be the position of the most updated slave
	#Gather info to make this host master
	if [ $i == $THISHOSTIP ] ; then
		FUTUREMASTERPOS=$LOGPOSTEMP
	else
		SLAVELIST="$SLAVELIST $i"
	fi

done

if [ $DIFF_FATAL -ne 0 ] ; then 
	echo "FATAL ERROR!"
	echo "Some SLAVE are MISCONFIGURED or badly unsync. Please shut it down and resync it after new MASTER is elected"
	echo "Quiting!"
	exit
fi

let LOGPOSDIFF=${MAXLOGPOS}-${FUTUREMASTERPOS}

if [ $LOGPOSDIFF -ne 0 ] ; then
	echo "ERROR! This SLAVE is NOT the most updated SLAVE!!!!"
	echo "QUIT!!!"
	exit
fi

if [ $DIFF_WARN -ne 0 ] ; then
	echo "WARNING! SLAVES have diferent LOG positions"
	echo "You should restore the SLAVES from a backup of the new MASTER"
	echo "You may want to choose the SLAVE with the highest position to minimize data lost"
	echo "Future MASTER has a delay of $LOGPOSDIFF bytes"
	echo "Do you really want to continue with this slave?(yes|no)"
	read ASK
	if [ $ASK == "no" -o $ASK == "No" -o $ASK == "NO" -o $ASK == "n" -o $ASK == "N" ] ; then
		echo "QUIT!!!"
		exit
	fi
fi

# TURN THIS SLAVE A MASTER
echo -e "\n -> Turnig this SLAVE a MASTER!"

#echo "Turning off read-only. Must have acess through socket as root!"
#$MYSQLCLIENT -e "$SQL_READONLY"
#if [ $? -ne 0 ] ; then
#        echo "Error Running MySQL Query..."
#        echo "QUIT!"
#        exit;
#fi

echo "RESET MASTER"
$MYSQLCLIENT -e "STOP SLAVE;"
if [ $? -ne 0 ] ; then
        echo "Error Running MySQL Query..."
        echo "QUIT!"
        exit;
fi

$MYSQLCLIENT -e "RESET MASTER;"
if [ $? -ne 0 ] ; then
        echo "Error Running MySQL Query..."
        echo "QUIT!"
        exit;
fi

$MYSQLCLIENT -e "CHANGE MASTER TO MASTER_HOST='';"
if [ $? -ne 0 ] ; then
        echo "Error Running MySQL Query..."
        echo "QUIT!"
        exit;
fi

RESULT=`$MYSQLCLIENT -h $THISHOSTIP $MYSQL_AUTH -e "SHOW MASTER STATUS \G" | egrep "Position:|File:" | $AWK '{ print $2  }'`
if [ -z "$RESULT" ] ; then
	echo "Error Getting Master Status. There may have been a problem configuring this host as MASTER"
	exit
fi
MASTERLOGFILE=`echo $RESULT | $AWK '{ print $1 }'`
MASTERLOGPOS=`echo $RESULT | $AWK '{ print $2 }'`
echo "New MASTER with file $MASTERLOGFILE, pos $MASTERLOGPOS"

echo -e "\n -> Configuring SLAVES"
if [ $DIFF_WARN -ne 0 ] ; then
	echo "The master is configured but there are slaves that are NOT SYNCHRONIZED."
	echo "If you continue, some or all slaves will loose data."
	echo "You should synchronize with mysqldump"
	echo "Do you really wanto to do this?"
fi
echo "Do you want to configure slaves $SLAVELIST?(yes|no)"
read ASK
if [ $ASK == "yes" ] ; then
	echo -e "\n -> Configuring slaves..."
	for s in $SLAVELIST; do
		echo $s
		$MYSQLCLIENT -h $s $MYSQL_AUTH -e "STOP SLAVE;"
		if [ $? -ne 0 ] ; then
		        echo "Error Running MySQL Query..."
		        echo "QUIT!"
		        exit;
		fi

		$MYSQLCLIENT -h $s $MYSQL_AUTH -e "CHANGE MASTER TO MASTER_HOST='$THISHOSTIP', MASTER_LOG_FILE='$MASTERLOGFILE', MASTER_LOG_POS=$MASTERLOGPOS, MASTER_PORT=3306, MASTER_USER='replicator', MASTER_PASSWORD='xeroxsapo';"
                if [ $? -ne 0 ] ; then
                        echo "Error Running MySQL Query..."
                        echo "QUIT!"
                        exit;
                fi

		$MYSQLCLIENT -h $s $MYSQL_AUTH -e "START SLAVE"
                if [ $? -ne 0 ] ; then
                        echo "Error Running MySQL Query..."
                        echo "QUIT!"
                        exit;
                fi

		sleep 1
		$MYSQLCLIENT -h $s $MYSQL_AUTH -e "SHOW SLAVE STATUS \G" | $EGREP "Slave_IO_Running:|Slave_SQL_Running:|Seconds_Behind_Master:"
	done
else
	echo "must choose 'yes' quiting..."
	echo "MASTER is configured. SLAVES ARE NOT!"
	echo "Manually you can run:"
	echo "STOP SLAVE;"
	echo "CHANGE MASTER TO MASTER_HOST='$THISHOSTIP', MASTER_LOG_FILE='$MASTERLOGFILE', MASTER_LOG_POS=$MASTERLOGPOS, MASTER_PORT=3306, MASTER_USER='replicator', MASTER_PASSWORD='xeroxsapo';"
	echo "START SLAVE"
	echo "QUIT!!!"
fi

echo -e "\n -> Configuration Done"
echo "Please start mysql as master using the script /etc/init.d/mysql-start-master"

#!/bin/bash

#Get Options
. /etc/mysql-variables.conf
if [ $? -ne 0 ] ; then
        echo "Probelm geting options."
        echo "This software was poorely installed."
        echo "QUIT!"
        exit;
fi

echo
echo "This script will try to Sync, using mysqldump, this host with master as configured in mysql-variables.conf"
echo "Needs the host package, the dns registry must be of the form 'uname -n'.domain"
echo -e "\n -> Applying iptables..."

$IPTABLES -A INPUT -p tcp --dport 3306 -j REJECT --reject-with tcp-reset
if [ $? -ne 0 ] ; then
        echo "Error applying iptables..."
        echo "QUIT!"
        exit;
fi

echo -e "\n -> Starting Database..."
/etc/init.d/mysql.server start
if [ $? -ne 0 ] ; then
        echo "Error starting Database..."
        echo "QUIT!"
        exit;
fi

echo -e "\n -> Checking if this slave is stoped"
# CHECK IF MYSQL IS UP
HOSTNAME_MYSQL=`$MYSQLCLIENT -e "SHOW VARIABLES like 'hostname' \G" | egrep "Value:" | $AWK '{ print $2  }'`
if [ -z "$HOSTNAME_MYSQL" ] ; then
    echo "$i is unnavailable"
    echo "Please start MYSQL service"
    echo "QUIT!"
    exit
fi

$MYSQLCLIENT -e "SHOW SLAVE STATUS \G" | $EGREP "Slave_IO_Running:|Slave_SQL_Running:|Seconds_Behind_Master:"

SLAVE_IO=`$MYSQLCLIENT -e "SHOW SLAVE STATUS \G" | $EGREP "Slave_IO_Running:" | $AWK '{ print $2}'`
SLAVE_SQL=`$MYSQLCLIENT -e "SHOW SLAVE STATUS \G" | $EGREP "Slave_SQL_Running:" | $AWK '{ print $2}'`

if [ "$SLAVE_IO" == "Yes" -a "$SLAVE_SQL" == "Yes" ] ; then
   $IPTABLES -F
   echo "Client in sync. Please make SLAVE STOP if you really wanto to do this!"
   echo "QUIT!"
   exit
fi

echo -e "\n -> Determining MASTER IP. Assuming domain .$DOMAIN"

HOSTNAME_MYSQL_WRITER=`$MYSQLCLIENT -h $IPWRITE $MYSQL_AUTH -e "SHOW VARIABLES like 'hostname' \G" | egrep "Value:" | $AWK '{ print $2  }'`
if [ -z "$HOSTNAME_MYSQL_WRITER" ] ; then
    echo "$IPWRITE is unnavailable"
    echo "MASTER IS DOWN! MASTER IS DOWN!"
    echo "Please start MYSQL service"
    echo "QUIT!"
    exit
fi
BACKEND_MASTER_IP=`$HOSTBIN $HOSTNAME_MYSQL_WRITER.$DOMAIN | $AWK '{ print $3}'`
if [ -z "$BACKEND_MASTER_IP" ] ; then
    echo "Please install the host package"
    echo "apt-get install host"
    echo "QUIT!"
    exit
fi
echo "Master Backend IP is $BACKEND_MASTER_IP"

echo -e "\n -> Checking if hostnames match..."

HOSTNAME_MASTER_MYSQL=`$MYSQLCLIENT -h $BACKEND_MASTER_IP $MYSQL_AUTH -e "SHOW VARIABLES like 'hostname' \G" | egrep "Value:" | $AWK '{ print $2  }'`
if [ -z "$HOSTNAME_MASTER_MYSQL" ] ; then
    echo "$BACKEND_MASTER_IP is unnavailable"
    echo "Please start MYSQL service"
    echo "QUIT!"
    exit
fi

# Ver se tudo bate certo
HOSTNAME=`uname -n`
if [ "$HOSTNAME" = "$HOSTNAME_MYSQL_WRITER" -o "$HOSTNAME" = "$HOSTNAME_MASTER_MYSQL" ] ; then
    echo "Algo de estranho se passa..."
    echo "Is this host the MASTER? MASTER can't be a SLAVE..."
    echo "$HOSTNAME != $HOSTNAME_MYSQL =  $HOSTNAME_MASTER_MYSQL"
    echo "QUIT!"
    exit
fi
echo "$HOSTNAME != $HOSTNAME_MYSQL_WRITER = $HOSTNAME_MASTER_MYSQL -> OK!!"

if [ $HOSTNAME_MYSQL_WRITER != $HOSTNAME_MASTER_MYSQL ] ; then
    echo "Algo de estranho se passa..."
    echo "$HOSTNAME_MYSQL diferente de $HOSTNAME_MASTER_MYSQL"
    echo "QUIT!"
    exit
fi

echo -e "\n -> Configuring Database Replication..."
$MYSQLCLIENT -e "CHANGE MASTER TO MASTER_HOST='$BACKEND_MASTER_IP', MASTER_PORT=3306, MASTER_USER='$REPUSER', MASTER_PASSWORD='$REPPASS';"
if [ $? -ne 0 ] ; then
        echo "Error Configuring Database Replication..."
        echo "QUIT!"
        exit;
fi
echo "OK!"

echo -e "\n -> Replicating... This can take a long time."
$MYSQLDUMP -h $BACKEND_MASTER_IP $MYSQL_AUTH --all-databases --flush-logs --single-transaction --master-data=1 | $MYSQLCLIENT
if [ $? -ne 0 ] ; then
        echo "Error in Replication..."
        echo "QUIT!"
        exit;
fi

sleep 1
$MYSQLCLIENT -e "START SLAVE"
if [ $? -ne 0 ] ; then
        echo "Error starting slave client.."
        echo "QUIT!"
        exit;
fi

sleep 1
$MYSQLCLIENT -e "SHOW SLAVE STATUS\G"

echo -e "\n -> Flushing ALL iptables entries! All iptables configurations will be deleted!!!"

$IPTABLES -F
if [ $? -ne 0 ] ; then
        echo "Error cleaning iptables.."
	echo "Please flush it manually."
        echo "QUIT!"
        exit;
fi


echo "Done!!!!"
exit 0

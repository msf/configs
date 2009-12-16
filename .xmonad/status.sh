#!/bin/zsh
#
# xmonad statusline, (c) 2007 by Robert Manea
#
 
# Configuration
DATE_FORMAT='%A, %d.%m.%Y %H:%M:%S'
TIME_ZONES=(Portugal/Lisbon)
WEATHER_FORECASTER=/path/to/dzenWeather.pl
DZEN_ICONPATH=
#MAILDIR=
 
# Main loop interval in seconds
INTERVAL=1
 
# function calling intervals in seconds
DATEIVAL=1
GTIMEIVAL=60
MAILIVAL=60
CPUTEMPIVAL=1
WEATHERIVAL=1800
 
# Functions
fdate() {
    date +$DATE_FORMAT
}
 
fgtime() {
    local i
 
    for i in $TIME_ZONES
        { print -n "${i:t}:" $(TZ=$i date +'%H:%M')' ' }
}
 
fcputemp() {
	if [ -f /proc/acpi/thermal_zone/THRM/temperature ]; then
		print -n ${(@)$(</proc/acpi/thermal_zone/THRM/temperature)[2,3]}
	fi
}
 
# don't use this
fmail() {
#    local -A counts; local i
# 
#	if [ -d "${HOME}/Mail" ]; then
#	    for i in "${MAILDIR:-${HOME}/Mail}"/**/new/*
#    	    { (( counts[${i:h:h:t}]++ )) }
#	    for i in ${(k)counts}
#    	    { print -n $i: $counts[$i]' ' }
#	fi
}
 
fweather() {
	if [ -x $WEATHER_FORECASTER ]; then
		$WEATHER_FORECASTER
	fi
}
 
fcpugraf() {
	dzen2-gcpubar -fg grey50  -bg '#37383a' -fg '11ffaa' -w 100 -h 8 -c 2 -i 0.5 |tail -n1
}

fmemgraf() {

AWKS='/MemTotal/   {mtotal=$2};
/MemFree/    {mfree=$2};
/Active/     {mactive=$2};
/^Cached/     {mcached=$2};
/SwapTotal/  {swtotal=$2};
/SwapFree/   {swfree=$2};
END {
    print mtotal-mfree " " mtotal;
    print mactive " " mtotal;
    print mcached " " mtotal;
    print swtotal-swfree " " swtotal; }'

print -n '^tw()Mem:
Active:
Cached:
Swap  : ' | paste -d '' - <(awk "$AWKS" /proc/meminfo | dzen2-gdbar -fg '#aecf96' -bg '#37383a' -w 50 -h 8)|tr  '\n' '      '
}
 
# Main
 
# initialize data
DATECOUNTER=$DATEIVAL;MAILCOUNTER=$MAILIVAL;GTIMECOUNTER=$GTIMEIVAL;CPUTEMPCOUNTER=$CPUTEMPIVAL;WEATHERCOUNTER=$WEATHERIVAL
 
while true; do
   if [ $DATECOUNTER -ge $DATEIVAL ]; then
     PDATE=$(fdate)
     DATECOUNTER=0
   fi
 
   if [ $MAILCOUNTER -ge $MAILIVAL ]; then
     TMAIL=$(fmail)
       if [ $TMAIL ]; then
         PMAIL="^fg(khaki)^i(${DZENICONPATH}/mail.xpm)^p(3)${TMAIL}"
       else
         PMAIL="^fg(grey60)^i(${DZENICONPATH}/envelope.xbm)"
       fi
     MAILCOUNTER=0
   fi
 
   if [ $GTIMECOUNTER -ge $GTIMEIVAL ]; then
     PGTIME=$(fgtime)
     GTIMECOUNTER=0
   fi
 
   if [ $CPUTEMPCOUNTER -ge $CPUTEMPIVAL ]; then
     PCPUTEMP=$(fcputemp)
     CPUTEMPCOUNTER=0
   fi
 
   if [ $WEATHERCOUNTER -ge $WEATHERIVAL ]; then
     PWEATHER=$(fweather)
     WEATHERCOUNTER=0
   fi

   MEMGRAF=$(fmemgraf)
   CPUGRAF=$(fcpugraf)
   VOLUME=`~/.xmonad/volume-bar.sh`

 
   # Arrange and print the status line
   print " $MEMGRAF $CPUGRAF $VOLUME $PWEATHER $PCPUTEMP $PGTIME $PMAIL ^fg(white)${PDATE}^fg()"
 
   DATECOUNTER=$((DATECOUNTER+1))
   MAILCOUNTER=$((MAILCOUNTER+1))
   GTIMECOUNTER=$((GTIMECOUNTER+1))
   CPUTEMPCOUNTER=$((CPUTEMPCOUNTER+1))
   WEATHERCOUNTER=$((WEATHERCOUNTER+1))
 
   sleep $INTERVAL
done

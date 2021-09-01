#!/bin/bash

# Modification : sshd_config
cat /etc/ssh/sshd_config | grep LogLevel | grep VERBOSE
if [ $? != "0" ]; then
	echo "LogLevel isn't on VERBOSE"
	# Set him on VERBOSE...
	line=$(cat /etc/ssh/sshd_config | grep LogLevel)
	if [ "$line" != "" ]; then
		echo "Line modification"
		sed -i.bak "s/$line/LogLevel VERBOSE/" /etc/ssh/sshd_config
	else
		echo "Append line"
		echo "LogLevel VERBOSE" >> /etc/ssh/sshd_config
	fi
fi

# Création de /etc/ipban/config if don't exist
cat /etc/ipban/config > /dev/null && echo "File exist"
if [ $? != "0" ]; then
	echo "Configuration File doesn't exist (/etc/ipban/config)"
	mkdir -p /etc/ipban
	echo "######################\n# Coding by BiMathAx #\n######################\n\n#yes|no code run code not run\nRunning=yes\n\n#In second before unban\nBantime=20\n\n#Try before ban\nTry=3" > /etc/ipban/config
	echo "File created"
fi

# Récupération setting (/etc/ipban/config)
Running=$(cat /etc/ipban/config | grep "Running=" | cut -c9-)
echo Running : $Running
Bantime=$(cat /etc/ipban/config | grep "Bantime=" | cut -c9-)
echo Bantime : $Bantime
Try=$(cat /etc/ipban/config | grep "Try=" | cut -c5-)
echo Try : $Try

# Fonction (ban, unban)
ban ()
{
	# ban 192.168.0.1
	IP=$1 
	iptables -I INPUT -s "$IP" -j DROP 
}
unban () 
{
	# unban 192.168.0.1
	IP=$1
	iptables -D INPUT -s "$IP" -j DROP
}
get_log ()
{
	com=""
	# get_log day month Try Bantime
	cat /var/log/auth.log | grep "$1" | grep "$2" | grep "Connection closed by authenticating" | cut -d" " -f12 > /etc/ipban/logfail
	cat /var/log/auth.log | grep "$1" | grep "$2" | grep "Failed publickey" | cut -d" " -f11 >> /etc/ipban/logfail
	cat /var/log/auth.log | grep "$1" | grep "$2" | grep "authentication failure" | grep "sshd" | cut -d" " -f14 | cut -d"=" -f2 >> /etc/ipban/logfail
	unset tabip
	declare -A tabip
	while read line; do 
		#echo $line ----------
		get=${tabip[$line]}
		#echo Get : "$get"
		if [ "$get" = "" ]; then
			#echo vide
			tabip+=([$line]=1)
		else
			#echo plein
			tabip+=([$line]=$((1+$get )))
		fi
		#echo ${tabip[192.168.1.27]}
       	done < /etc/ipban/logfail
	#for i in $(seq 1 ${#tabip[@]}); do
	for ip in ${!tabip[@]}; do
		nb=${tabip[$ip]}
		com+="L'ip $ip a échoué $nb ; "
		if [ "$3" -lt "$nb" ]; then
			com+="|BAN $ip|"
			ban $ip
			echo "$ip $(( $(date "+%s") + $4))" >> /etc/ipban/banner
			# Supp log
			grep -no "$ip" /var/log/auth.log | sort | uniq | cut -d":" -f1 > /etc/ipban/ligne
			
			expression=""
			while read line; do	
				expression+="$line"
				line+="p"
				sed -n "$line" /var/log/auth.log >> /var/log/auth_ipban.log
				expression+="d;"
			done < /etc/ipban/ligne		
			
			echo $expression
			sed -i.bak "$expression" /var/log/auth.log

			#echo $(date "+%s")		
		fi
	done
	echo $com > /etc/ipban/returnshell
}
banner ()
{
	com=$(cat /etc/ipban/returnshell)
	tour=1
	while read line; do
		ip=$(echo $line | cut -d" " -f1)
		timestamp=$(echo $line | cut -d" " -f2)
		com+="BanTime $ip and $timestamp | "
		if [ "$timestamp" -lt "$(date "+%s")" ]; then
			com+="Unban\n"
			l="$tour"
			l+="d"
			echo $l
			sed -i.bak "$l" /etc/ipban/banner #On supprime la ligne de ban sed '3d' file pour la ligne3
			tour=$(($tour - 1))
			unban $ip		
	      	fi
		tour=$(($tour + 1))		
	done < /etc/ipban/banner
	echo -ne "$com \r"
	echo $com > /etc/ipban/returnshell
}
eraser ()
{
	eraser=""
	for i in $(seq 1 $(wc -m "$1" | cut -d" " -f1)); do
		eraser+=" "
	done
	echo -ne "$eraser \r"
}


# Code

day=$(date "+%d")
month=$(date "+%b")	
echo Nous sommes le $day $month	

while [ $Running = "yes" ]; do
	get_log $day $month $Try $Bantime
	banner
	sleep 5
	eraser "/etc/ipban/returnshell"
done
echo "Code END"

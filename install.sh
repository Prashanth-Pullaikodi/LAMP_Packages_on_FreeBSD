#################################################################################################################
###################
#Purpose: Script to compile and install LAMP packages on FreeBSD
#Author: Prashanth Pullaikodi
#Date: 11.08.2017
#Version : V.01
#Pre-Reqs - Make sure Bash shell is installed and the script has given sudo access to run it.
###################
#! /usr/local/bin/bash
export PATH=$BASE_DIR/bin:$PATH

echo -e  "\n "
echo -e "-- Starting script.....\n"
SRC_DIR=/usr/src
BASE_DIR=/usr/local
APACHE_DIR=$BASE_DIR/apache2
PHP_DIR=$BASE_DIR/php
URL=$(which curl)


#OutPut File
OutPut="/var/log/output.txt"
OutPut1="/var/log/output-compiler.txt"

#Empty Log file.
truncate -s 0 $OutPut1
truncate -s 0 $OutPut

#Error Handling Function
#0-stdin ,1-stdout,2-stderr
#Error Message dirrected to output.txt and stdout to file output1.txt
exec 2>> $OutPut 2>1& >> ${OutPut1}

log()
        {
                echo "[${USER}][`date`] - ${*}" >> ${OutPut}
        }

#Test Internet connectivity..

if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
  echo -e "-- Internet Connection Working fine..\n "
else
  echo -e "-- Internet Connection NOT  Working .Please check connectvity.Please check connectivity  ..\n "
fi

if [ ! -d "$APACHE_DIR" ]; then
     mkdir -p "$BASE_DIR/apache2/" 

 else
    echo -e "-- $APACHE_DIR already exists \n" 
    log  "$APACHE_DIR already exists !!" 
 fi


if [[ ! -d $PHP_DIR ]]; then
        mkdir -p "$BASE_DIR/php5/"  
else
       echo -e  "-- $PHP_DIR already exists ..\n" 
       log "$PHP_DIR already exists .!!" 
fi


#echo -e "-- Updating FreeBSD  Ports ....This takes a while ..Please wait...\n"
#portsnap update 1>>$OutPut1 2>&1
#portsnap fetch 1>>$OutPut1 2>&1
#portsnap extract 1>>$OutPut1 2>&1

#Installing prerequisite packges  
#Check if package already installed
pkg1=" curl wget libxml2 cmake"
for pkg in $pkg1
	do

 		pkg info $pkg 1>>$OutPut1 2>&1  && {
        		echo -e "-- Prerequisite $pkg already  installed...\n"
    		} || {

        		cd `whereis -sq $pkg`
        		make -DBATCH install clean 1>>$OutPut1 2>&1
        			if [[ $? -eq 0 ]];then
                			echo -e "-- Prerequisite  $pkg Installed successfully..\n"
                			log echo " prerequisite $pkg Installed successfully"
        			else
                			echo  -e "-- Prerequisite $pkg Installation fialed.. \n"
                			log echo  "$pkg Installation failed"
				fi
    }
done

echo -e "\n"

#Capture Current Public IP to allow port 80 and 22
IP_PUB=`curl  -s ifconfig.co`
echo  -e "-- My  Public IP is $IP_PUB .. \n "
log "My  Public IP is $myIP \n "


download="http://archive.apache.org/dist/httpd/httpd-2.2.6.tar.gz http://ba1.php.net/get/php-5.5.34.tar.gz/from/this/mirror https://downloads.mysql.com/archives/get/file/mysql-5.5.8.tar.gz"
for url in $download
        do
                #Parsing url's
                apache=$(echo $url| awk -F "/" '{print $NF}'|awk -F . '{print $1}')
                apa_fname=$(echo $url | awk -F "/" '{print $NF}'|awk -F "." '{print $1"."$2"."$3}')
                php=$(echo $url | cut -d'/' -f5|awk -F "." '{print $1}')
                php_fname=$(echo $url | cut -d'/' -f5 | awk -F "." '{print $1"."$2"."$3}')
                mysql=$(echo $url| cut -d'/' -f7|awk -F "." '{print $1}')
                mysql_fname=$(echo $url| cut -d'/' -f7| awk -F "." '{print $1"."$2"."$3}')

                wget --spider -q --no-check-certificate $url  && {
                        if [[ $apache == httpd-2 ]];then
				echo -e "\n"
                                echo -e "-- Downloading $apache...\n"
                                wget --no-check-certificate -q -nc -P $SRC_DIR $url 
                                echo -e "-- Extracting $apache.. \n"
                                tar zxvf $SRC_DIR/$apache*.*.tar.gz -C $SRC_DIR &>>$OutPut
                                cd $SRC_DIR/$apa_fname
                                echo -e "-- Compiling and installing $apa_fname in $APACHE_DIR ..\n"
                                ./configure  --prefix=$APACHE_DIR --enable-shared="All" --enable-so --with-expat=builtin 1>>$OutPut1 2>&1
                                make install  1>>$OutPut1 2>&1 
                        #Modify apache configuration.
                                echo -e "-- Modifying Apache configuration..\n "
                                cp -p $APACHE_DIR/htdocs/index.html $APACHE_DIR/htdocs/phpinfo.php
                                echo "<?php" >$APACHE_DIR/htdocs/phpinfo.php
                                echo "phpinfo();" >>$APACHE_DIR/htdocs/phpinfo.php
                                echo "?>" >> $APACHE_DIR/htdocs/phpinfo.php
                                sed -e "s/DirectoryIndex index.html/DirectoryIndex index.php index.html/" $APACHE_DIR/conf/httpd.conf > $APACHE_DIR/conf/tmp.conf
                                awk '/TypesConfig conf\/\mime.types/{print "AddType application/x-httpd-php .php" "\n" "AddType application/x-httpd-php-source .phps"}1' $APACHE_DIR/conf/tmp.conf  > $APACHE_DIR/conf/httpd.conf
                        #Restarting apache
                                echo -e "-- Starting httpd ... \n"
				/usr/local/apache2/bin/apachectl start
                                echo -e "\n"

                       elif [[ $php == php-5 ]];then
                                echo -e "-- Downloading $php..\n"
                                wget --no-check-certificate -q -nc -O $SRC_DIR/php-5.5.34.tar.gz $url
                                echo -e "-- Extracting $php.. \n"
                                tar zxvf $SRC_DIR/$php.*.*.tar.gz -C $SRC_DIR &>>$OutPut
                                echo -e "-- Compiling and Installing $php in $PHP_DIR  .. Please wait this takes time \n"
                                cd $SRC_DIR/$php_fname
                                ./configure --prefix=$PHP_DIR --enable-libxml --with-libxml-dir=/usr/local/lib/ 1>>$OutPut1 2>&1
                                make install 1>>$OutPut1 2>&1
                                cp $SRC_DIR/$php_fname/php.ini-production /usr/local/etc/php.ini
                                echo  -e "\n"
                        elif [[ $mysql == mysql-5 ]];then
                                echo -e "-- Downloading mysqld..\n"
                                wget --no-check-certificate -q -nc -P $SRC_DIR $url
                                echo -e "-- Extracting $mysql.. \n"
                                tar zxvf $SRC_DIR/$mysql.*.*.tar.gz -C $SRC_DIR &>>$OutPut
                                cd $SRC_DIR/$mysql_fname
                                echo -e "-- Creating Mysql User \n"
                                pw groupadd  mysql 1>>$OutPut1 2>&1 
                                pw useradd mysql -s /usr/local/bin/bash  -g mysql -m -d /usr/local/mysql/data 1>>$OutPut1 2>&1
                                #pw useradd mysql -g wheel -s /usr/local/bin/bash -G wheel -m -d /usr/local/mysql/data 1>>$OutPut1 2>&1
                                echo -e "-- Compiling and instaling $mysql_fname  in /usr/local/mysql ..Please wait this takes a while ..\n"
                                cmake . 1>>$OutPut1 2>&1
                                echo " " 1>>$OutPut1 2>&1
                                make 1>>$OutPut1 2>&1
                                make install 1>>$OutPut1 2>&1
                                echo -e "-- Configuring Mysql ..\n"
                                cd /usr/local/mysql
                                chown -R mysql:mysql .
                                scripts/mysql_install_db --user=mysql &>>$OutPut
                                chown -R root .
                                chown -R mysql data
				chmod -R go-rwx data
                                cp support-files/my-medium.cnf /etc/my.cnf
                                cp -v support-files/mysql.server  /usr/local/etc/rc.d/
				bin/mysqld_safe --user=mysql & &>>$OutPut
				sleep 4
				echo 'mysql_enable="YES"' >> /etc/rc.conf
				echo "innodb_fast_shutdown=0" >> /etc/my.cnf
				echo "innodb_log_file_size=5M " >> /etc/my.cnf
				echo "innodb_buffer_pool_size = 10M" >> /etc/my.cnf

fi

                } || {

                        echo -e  "-- Downloading $url failed..\n"
}
done

if [ -f /etc/my.cnf ]; then
        dbname="test"
        echo -e "-- Creating database "test" ...\n"
	sleep 4
        /usr/local/mysql/bin/mysql -e "CREATE DATABASE ${dbname};"
        echo "Database successfully created!"
        echo ""
        username="test"
        userpass="welcome"
        echo -e "-- Creating new user...\n"
	sleep 4
        /usr/local/mysql/bin/mysql -e "CREATE USER ${username}@localhost IDENTIFIED BY '${userpass}';"
        echo -e "-- User successfully created! \n"
        echo ""
        echo -e "-- Granting required  privileges on ${dbname} to ${username}! \n"
	sleep 4
        /usr/local/mysql/bin/mysql -e "GRANT ALL PRIVILEGES ON ${dbname}.* TO '${username}'@'localhost';"
        /usr/local/mysql/bin/mysql -e "FLUSH PRIVILEGES;"
        echo -e "-- Read only User created \n"
        echo -e "MySQL installtion Completed ..\n"

else
        echo "--  /etc/my.cnf file Missing \n"
        echo "-- Exiting ...\n"
fi



echo -e "-- Configuring PF FIREWALL to allow Apache on Port 54321 for Public Interface .. \n"
	interface=`ifconfig | grep flags | egrep -v lo0 |awk -F : '{print $1}'`
		echo "ext_if="$interface"" > /etc/pf.conf
		echo "IP_PUB="$IP_PUB"" >> /etc/pf.conf
		echo 'icmp_types="echoreq"' >> /etc/pf.conf
		echo "# Custom port for ssh" >> /etc/pf.conf
		echo "SSH_CUSTOM = 22 " >> /etc/pf.conf
		echo 'scrub in on $ext_if all fragment reassemble' >> /etc/pf.conf
		echo "rdr on xn0 inet proto tcp to port 54321  -> 127.0.0.1 port 80" >> /etc/pf.conf
		echo "set skip on lo0" >> /etc/pf.conf
		echo 'antispoof for $ext_if' >> /etc/pf.conf
		echo "# --- EXTERNAL INTERFACE" >> /etc/pf.conf
		echo "# --- INCOMING -------------------------------------------------------------------" >> /etc/pf.conf
		echo "# --- TCP" >> /etc/pf.conf
		echo 'pass in  quick on $ext_if inet proto tcp from any to $ext_if  port $SSH_CUSTOM' >> /etc/pf.conf
		echo "# --- for authoritative DNS server" >> /etc/pf.conf
		echo 'pass in  quick on $ext_if inet proto udp from any to $ext_if  port domain' >> /etc/pf.conf
		echo "# --- UDP" >> /etc/pf.conf
  		echo "# --- for authoritative DNS server" >> /etc/pf.conf
		echo 'pass in  quick on $ext_if inet proto udp from any to $ext_if  port domain' >> /etc/pf.conf
		echo "# --- ICMP" >> /etc/pf.conf
		echo 'pass in  quick on $ext_if inet proto icmp from any to $ext_if icmp-type $icmp_types' >> /etc/pf.conf
		echo "# --- EXTERNAL INTERFACE" >> /etc/pf.conf
		echo "# --- OUTGOING --------------------------------------------------------------------" >> /etc/pf.conf
		echo "anchor TMP" >> /etc/pf.conf
		echo "# --- TCP" >> /etc/pf.conf
		echo 'pass  out quick     on $ext_if inet proto tcp from $ext_if to any port $SSH_CUSTOM' >> /etc/pf.conf
		echo "# --- UDP" >> /etc/pf.conf
		echo 'pass  out quick on $ext_if inet proto udp from $ext_if to any port domain' >> /etc/pf.conf
		echo 'pass  out quick on $ext_if inet proto udp from $ext_if to any port ntp' >> /etc/pf.conf
		echo "# --- ICMP" >> /etc/pf.conf
		echo 'pass  out quick on $ext_if inet proto icmp  from $ext_if to any' >> /etc/pf.conf
		echo 'pflog_logfile="/var/log/pflog"'  >> /etc/pf.conf
		echo "# ------------------------------------------------------" >> /etc/pf.conf
		echo "# --- DEFAULT POLICY " >> /etc/pf.conf
		echo "# ------------------------------------------------------" >> /etc/pf.conf
		echo 'block drop out quick proto tcp  to $IP_PUB port 80' >> /etc/pf.conf
		echo "# ----- end of pf.conf" >> /etc/pf.conf
		echo 'pf_enable="YES"' >> /etc/rc.conf
		chmod 755 /etc/pf.conf

echo -e "-- Starting PF service \n"
service pf start
echo -e "-- Script Execution completed..\n"

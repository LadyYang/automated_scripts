#!/bin/bash

. /etc/init.d/functions

MYSQL_URL="https://dev.mysql.com/get/Downloads/MySQL-5.6/mysql-5.6.37.tar.gz" 
MYSQL_FILE="mysql-5.6.37.tar.gz"
MYSQL_DIR="mysql-5.6.37"

APACHE_URL="http://mirrors.tuna.tsinghua.edu.cn/apache//httpd/httpd-2.4.27.tar.gz"
APACHE_FILE="httpd-2.4.27.tar.gz"
APACHE_DIR="httpd-2.4.27"


APR_URL="http://mirrors.hust.edu.cn/apache//apr/apr-1.6.2.tar.gz"
APR_FILE="apr-1.6.2.tar.gz"
APR_DIR="apr-1.6.2"

APR_UTIL_URL="http://mirrors.hust.edu.cn/apache//apr/apr-util-1.6.0.tar.gz"
APR_UTIL_FILE="apr-util-1.6.0.tar.gz"
APR_UTIL_DIR="apr-util-1.6.0"

PCRE_URL="http://jaist.dl.sourceforge.net/project/pcre/pcre/8.10/pcre-8.10.zip "
PCRE_FILE="pcre-8.10.zip"
PCRE_DIR="pcre-8.10"

PHP_URL="http://cn2.php.net/get/php-5.6.31.tar.gz/from/this/mirror"
PHP_FILE="php-5.6.31.tar.gz"
PHP_DIR="php-5.6.31"

NGINX_URL="http://nginx.org/download/nginx-1.13.5.tar.gz"
NGINX_FILE="nginx-1.13.5.tar.gz"
NGINX_DIR="nginx-1.13.5"


#check the results of the command execution 
 
function check(){
    if [ $? -eq 0 ];then
        echo -e "\n\n配置.......................................................\033[32m[ OK ]\033[0m\n\n"  
        #continue
    else
        echo -e "\n\n配置.......................................................\033[31m[ Error ]\033[0m\n\n"
        exit
    fi
}



function yum_update(){
 #set yum repos
 echo "===update yum repos,it will take serval mintinues==="
 yum install wget -y
 mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
 wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo #&>/dev/null
 wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo #&>/dev/null
 yum clean all #&>/dev/null
 yum makecache #&>/dev/null
 check
 action  "yum repos update is ok" /bin/true
}
 
function yum_depend(){
  #install dependencies packages
  yum install wget gcc gcc-c++ make cmake unzip pcre pcre-devel re2c curl curl-devel libxml2 libxml2-devel libjpeg libjpeg-devel libpng libpng-devel libmcrypt libmcrypt-devel zlib zlib-devel openssl openssl-devel freetype freetype-devel gdbm gdbm-devel gd gd-devel perl perl-devel ncurses ncurses-devel bison bison-devel libtool gettext gettext-devel cmake bzip2 bzip2-devel  mhash mhash-devel readline-devel libxslt-devel gmp-devel libcurl-devel -y
}




function install_mysql(){

    yum -y install ncurses-devel ncurses cmake gcc gcc-c++ wget ncurses-devel ncurses
#    rm -fr /usr/local/src/mysql*

    if [ ! -d /usr/local/mysql ];then
        echo -e "${MYSQL_DIR} will be installed, please be patient..."
	sleep 3
    	cd /usr/local/src
    
        if [ ! -f $MYSQL_FILE ];then
            wget -c $MYSQL_URL
        fi

    	if [ ! -d $MYSQL_DIR ];then
            tar -zxf $MYSQL_FILE
        fi
         
        if [ -d /data/mysql/ ];then
            rm -fr /data/mysql/*
        fi
		
	useradd -M -s /sbin/nologin mysql
	mkdir -p /data/mysql

    	cd $MYSQL_DIR
        cmake  -DCMAKE_INSTALL_PREFIX=/usr/local/mysql/ -DMYSQL_UNIX_ADDR=/tmp/mysql.sock -DMYSQL_DATADIR=/data/mysql -DSYSCONFDIR=/etc -DMYSQL_USER=mysql -DMYSQL_TCP_PORT=3306 -DWITH_XTRADB_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_PARTITION_STORAGE_ENGINE=1 -DWITH_BLACKHOLE_STORAGE_ENGINE=1 -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_READLINE=1 -DENABLED_LOCAL_INFILE=1 -DWITH_EXTRA_CHARSETS=1 -DDEFAULT_CHARSET=utf8 -DDEFAULT_COLLATION=utf8_general_ci -DEXTRA_CHARSETS=all -DWITH_BIG_TABLES=1 -DWITH_DEBUG=0

	check
	make && make install
	check
  
	chown -R mysql:mysql /data/mysql/
	chown -R mysql:mysql /usr/local/mysql/
	check
	cd /usr/local/mysql/scripts/
	./mysql_install_db --basedir=/usr/local/mysql/ --datadir=/data/mysql/ --user=mysql
	check
	/bin/cp -fa /usr/local/mysql/support-files/my-default.cnf  /etc/my.cnf
	sed -i '/^\[mysqld\]$/a\user = mysql\ndatadir = /data/mysql\ndefault_storage_engine = InnoDB\n' /etc/my.cnf
	check
  
	cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysqld
	check
	sed -i 's#^datadir=#datadir=/data/mysql#' /etc/init.d/mysqld
	check
	sed -i 's#^basedir=#basedir=/usr/local/mysql#' /etc/init.d/mysqld
	check
  
# 	iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 3306 -j ACCEPT
# 	/etc/init.d/iptables save
# 	check
	echo "export PATH=$PATH:/usr/local/mysql/bin" >>/etc/profile
	source /etc/profile
	check

	pkill mysqld
        sleep 2
        chkconfig --add mysqld
        chkconfig mysqld on
        service mysqld start
        check

    else
	echo "MySQL has installed ! "
  fi
}
 
function install_apache(){
	# 如果已经安装apache，无需重新编译apache,使用whereis openssl查找openssl路径，直接进入[source]/modules/ssl;
	# 执行[apache]/bin/apxs -a -i -c -L/usr/lib/openssl/engines/lib -c *.c -lcrypto -lssl -ldl；
    	# 如果执行上面的命令失败，请执行以下命令，验证成功

	# /usr/local/apache24/bin/apxs -a -i -DHAVE_OPENSSL=1 -I/usr/include/openssl -L/usr/lib64/openssl -c *.c -lcrypto -lssl -ldl

	# 这种方式加载之后，在apache的安装目录下的modules目录会生成一个mod_ssl.so，同时httpd.conf中会增加一行LoadModule php5_module modules/libphp5.so（[apache]表示Apache的安装目录，[source]表示Apache源码目录）
	# apxs命令参数说明：
	# -i  此选项表示需要执行安装操作，以安装一个或多个动态共享对象到服务器的modules目录中。
	# -a  此选项自动增加一个LoadModule行到httpd.conf文件中，以激活此模块，或者，如果此行已经存在，则启用之。
	# -A  与 -a 选项类似，但是它增加的LoadModule命令有一个井号前缀(#)，即此模块已经准备就绪但尚未启用。
	# -c  此选项表示需要执行编译操作。它首先会编译C源程序(.c)files为对应的目标代码文件(.o)，然后连接这些目标代码和files中其余的目标代码文件(.o和.a)，以生成动态共享对象dsofile 。如果没有指定 -o 选项，则此输出文件名由files中的第一个文件名推测得到，也就是默认为mod_name.so 
	
	
	# 建立服务器密钥  
	# openssl genrsa -des3 1024  > /usr/local/apache/conf/server.key   
	# 从密钥中删除密码（以避免系统启动后被询问口令） 
	# openssl rsa -in /usr/local/apache/conf/server.key > /usr/local/apache/conf/server2.key
	# mv /usr/local/apache/conf/server2.key  /usr/local/apache/conf/server.key
	# 建立服务器密钥请求文件
	# openssl req -new -key /usr/local/apache/conf/server.key -out /usr/local/apache/conf/server.csr
	# openssl x509 -in /usr/local/apache/conf/server.csr -out /usr/local/apache/conf/server.crt -req -signkey /usr/local/apache/conf/server.key -days 365
	# 建立服务器证书  
	
	
	# RewriteEngine on
	# RewriteCond %{SERVER_PORT} !^443$
	# RewriteRule ^/?(.*)$ https://%{SERVER_NAME}/$1 [L,R]
	
	yum -y install gcc wget pcre pcre-devel apr apr-devel apr-util apr-util-devel openssl openssl-devel 
    	rm -fr /usr/local/src/apache*
	echo "${APACHE_DIR} will be installed,please be patient..."
	sleep 3
    	cd /usr/local/src
 
    # 安装 apr 库的支持
    # wget $APR_URL
    # tar zxf $APR_FILE
    # cd $APR_DIR
    # ./configure --prefix=/usr/local/apr
    # check
    # make && make install
    # check
    # rm -fr /usr/local/src/apr*
  
    # 安装 apr-util 库的支持
    # cd /usr/local/src
    # wget $APR_UTIL_URL
    # tar zxf $APR_UTIL_FILE
    # cd $APR_UTIL_DIR
    # ./configure --prefix=/usr/local/apr-util --with-apr=/usr/local/apr
    # check
    # make && make install
    # check
    # rm -fr /usr/local/src/apr-util*

    # 安装 pcre 库的支持
   # cd /usr/local/src
   # wget $PCRE_URL
   # unzip -o $PCRE_FILE
   # cd $PCRE_DIR
   # ./configure --prefix=/usr/local/pcre
   # check
   # make && make install
    
    if [ ! -d /usr/local/apache2 ];then
        cd /usr/local/src
		
	if [ ! -f $APACHE_FILE ];then
            wget -c $APACHE_URL
        fi
		
        if [ ! -d $APACHE_DIR ];then
            tar zxf $APACHE_FILE
        fi
        # /bin/cp -r a $APR_DIR /usr/local/src/$APACHE_DIR/srclib/apr
        # /bin/cp -r a $APR_UTIL_DIR /usr/local/src/$APACHE_DIR/srclib/apr-util
        # /bin/cp -r a $PCRE_DIR /usr/local/src/$APACHE_DIR/srclib/pcre
	check

        cd $APACHE_DIR
        # ./configure --prefix=/usr/local/apache2 --with-apr=/usr/local/apr --with-apr-util=/usr/local/apr-util/ --with-pcre --enable-mods-shared=most --enable-so --with-included-apri --enable-rewrite 
	./configure --prefix=/usr/local/apache2 --enable-rewrite --enable-so --enable-ssl  #--enable-session
	check
        make && make install
        check
  
        echo "export PATH=$PATH:/usr/local/apache2/bin" >>/etc/profile
        source /etc/profile
        check
    fi

#++++++++++++++++++++++++++++++++++++++++++++++
# CentOS6 的防火墙配置：
# iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
# /etc/init.d/iptables save
# check


#++++++++++++++++++++++++++++++++++++++++++++++
# CentOS7 的防火墙配置：
#    firewall-cmd --permanent --add-port=80/tcp
    check

#++++++++++++++++++++++++++++++++++++++++++++++
# 设置Apache为Linux服务 开机自启
    cp -fa /usr/local/apache2/bin/apachectl /etc/rc.d/init.d/
    mv -f  /etc/rc.d/init.d/apachectl /etc/rc.d/init.d/httpd
    sed -i '1i\
#Comments to support chkconfig on RedHat Linux\
#chkconfig: 2345 90 90 \
#description: httpd server' /etc/rc.d/init.d/httpd
    chkconfig --add httpd
    chkconfig httpd on 

    pkill httpd
    service httpd start
    check
    sleep 2

}
 
function install_php(){
    # rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
	
	#用yum安装一些依赖库
	yum -y install libcurl-devel libXpm-devel libxml2-devel php-mbstring gcc gcc-c++ make 
    rm -fr /usr/local/src/php*

    echo "${PHP_DIR} will be installed,please be patient"
    cd /usr/local/src

#++++++++++++++++++++++++++++++++++++++++++
# 下载libiconv 依赖包

    if [ ! -d libiconv-1.14 ];then
        wget http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz
        tar -xzvf libiconv-1.14.tar.gz
    fi
    cd libiconv-1.14
    ./configure --prefix=/usr/local/
    check

# sed -i -e '/gets is a security/d' /usr/local/src/libiconv-1.14/srclib/stdio.in.h
    make && make install
    echo "/usr/local/lib" >> /etc/ld.so.conf
    /sbin/ldconfig

#++++++++++++++++++++++++++++++++++++++++++
#
    cd /usr/local/src
    if [ ! -d $PHP_DIR ];then
        tar zxf $PHP_FILE
    fi
    if [ -d /usr/local/php ];then
        rm -fr /usr/local/php
    fi    
    cd $PHP_DIR
#  ./configure  --prefix=/usr/local/php --with-apxs2=/usr/local/apache2/bin/apxs --with-config-file-path=/usr/local/php/etc --with-mysql=/usr/local/mysql --with-iconv=/usr/local/ --with-zlib --with-libxml-dir --with-gd --with-jpeg-dir --with-png-dir --with-freetype-dir --with-iconv-dir --with-zlib-dir --with-bz2 --with-openssl --with-mcrypt --enable-soap --enable-gd-native-ttf --enable-mbstring --enable-sockets --enable-exif --disable-ipv6

    ./configure --prefix=/usr/local/php --with-config-file-path=/etc --with-config-file-scan-dir=/etc/php.d --with-mysql=/usr/local/mysql/  --with-libxml-dir=/usr --enable-fpm --enable-maintainer-zts --enable-xml --enable-sockets --with-mcrypt --with-openssl --with-zlib --with-iconv --enable-mbstring --with-jpeg-dir --with-freetype-dir --with-openssl-dir --with-png-dir --enable-soap --with-xmlrpc --with-mhash --with-pcre-regex --with-sqlite3 --enable-bcmath --with-bz2 --enable-calendar --with-curl --with-cdb --enable-dom --enable-exif --enable-fileinfo --enable-filter --with-pcre-dir --enable-ftp --with-gd --with-zlib-dir  --enable-gd-native-ttf --enable-gd-jis-conv --with-gettext --with-gmp --with-mhash --enable-json --disable-mbregex --disable-mbregex-backtrack --with-libmbfl --with-onig --enable-pdo --with-pdo-mysql --with-zlib-dir --with-pdo-sqlite --with-readline --enable-session --enable-shmop --enable-simplexml --enable-sysvmsg --enable-sysvsem --enable-sysvshm --enable-wddx --with-xsl --enable-zip --enable-mysqlnd-compression-support --with-pear

    check
    make && make install
    check
  
    cp /usr/local/src/${PHP_DIR}/php.ini-production /usr/local/php/etc/php.ini
    sed -i 's#^;date.timezone =#date.timezone=Asia/Shanghai#' /usr/local/php/etc/php.ini
    check
  
}
 
function set_lamp(){
    sed -i '/AddType application\/x-gzip .gz .tgz/a\    AddType application/x-httpd-php .php\n' /usr/local/apache2/conf/httpd.conf
    sed -i 's#index.html#index.html index.php#' /usr/local/apache2/conf/httpd.conf
    sed -i '/#ServerName www.example.com:80/a\ServerName localhost:80\n' /usr/local/apache2/conf/httpd.conf
    check
   cat >>/usr/local/apache2/htdocs/test.php<<EOF
<?php
echo "PHP is OK\n";
?>
EOF
 
    /usr/local/apache2/bin/apachectl graceful
    check
    curl localhost/test.php
    check
    action "LAMP is install success" /bin/true
}
 
function install_phpfpm(){
    echo "${PHP_DIR} will be installed,please be patient"
    useradd -s /sbin/nologin php-fpm
    cd /usr/local/src
    if [ ! -d libiconv-1.14 ];then
        wget http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz
        tar -xzvf libiconv-1.14.tar.gz
    fi
    cd libiconv-1.14
    ./configure --prefix=/usr/local/
    make && make install
    echo "/usr/local/lib" >> /etc/ld.so.conf
    /sbin/ldconfig
    cd /usr/local/src
    if [ ! -d $PHP_DIR ];then
        tar zxf $PHP_FILE
    fi
    cd $PHP_DIR
    if [ -d /usr/local/php-fpm ];then
        rm -fr /usr/local/php-fpm
    fi
 #./configure --prefix=/usr/local/php-fpm --with-apx2=/usr/local/apache2/bin/apxs  --with-iconv-dir=/usr/local/ --with-config-file-path=/usr/local/php-fpm/etc --enable-fpm --enable-mbstring --with-fpm-user=php-fpm --with-fpm-group=php-fpm --with-mysql=mysqlnd  --with-pdo-mysql=mysqlnd --with-mysqli=mysqlnd --with-libxml-dir --with-gd --with-jpeg-dir --with-png-dir --with-freetype-dir --with-iconv-dir --with-zlib-dir --with-mcrypt --enable-soap --enable-gd-native-ttf --enable-ftp --enable-exif --disable-ipv6 --with-pear --with-curl --enable-bcmath --enable-mbstring --enable-sockets --with-gettext
    ./configure --enable-fpm --enable-mbstring --with-mysql=mysqlnd --with-iconv-dir=/usr/local 
    check
    make ZEND_EXTRA_LIBS='-liconv' && make install
    check
  
    cp /usr/local/src/$PHP_DIR/php.ini-production /usr/local/php-fpm/etc/php.ini
    sed -i 's#^;date.timezone =#date.timezone=Asia/Shanghai#' /usr/local/php-fpm/etc/php.ini
    cd /usr/local/php-fpm/etc/
    cp -a php-fpm.conf.default php-fpm.conf
    check
  
    cp /usr/local/src/$PHP_DIR/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
    chmod 755 /etc/init.d/php-fpm
    chkconfig --add php-fpm
    chkconfig php-fpm on
    service php-fpm start
    check
}

 
function install_nginx(){
    echo "${NGINX_DIR} will be installed,please be patient"
    cd /usr/local/src
   
    if [ ! -f $NGINX_FILE ];then
        wget -c $NGINX_URL
    fi
 
    if [ ! -d $NGINX_DIR ];then  
        tar zxf $NGINX_FILE
    fi
    cd $NGINX_DIR
    ./configure --prefix=/usr/local/nginx --with-pcre --with-http_stub_status_module --with-http_ssl_module --with-http_gzip_static_module
    check
    make && make install
    check
  
    /usr/local/nginx/sbin/nginx
    check
}
 
function set_lnmp(){
    sed -i '56a\location ~ \.php$ {\n\    root          html;\n\    fastcgi_pass  127.0.0.1:9000;\n\    fastcgi_index  index.php;\n\    fastcgi_param  SCRIPT_FILENAME  /usr/local/nginx/html$fastcgi_script_name;\n\    include        fastcgi_params;\n\}\n' /usr/local/nginx/conf/nginx.conf
    /usr/local/nginx/sbin/nginx -s reload
    check
    echo -e '<?php\n echo "nginx and PHP is OK";\n?>\n' >/usr/local/nginx/html/index.php
    curl localhost/index.php
    check
    action "LNMP is install success" /bin/true
}



#===============================================
# 菜单选择 

clear 
PS3="Enter your select: "
select options in "Install Apache" "Install MySQL" "Install Nginx" "Install PHP" "Set LAMP" "Set LNMP" "exit"
do
    case $options in
        "Install Apache")
            install_apache
            ;;
	"Install MySQL")
	    install_mysql
	    ;;
	"Install Nginx")
	    install_nginx
	    ;;
	"Install PHP")
	    install_php
	    ;;
	"Install LAMP")
	    set_lamp
	    ;;
	"Install LNMP")
	    set_lnmp
	    ;;
	"exit")
            break
	    ;;
    esac
done

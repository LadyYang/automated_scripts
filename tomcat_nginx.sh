#!/bin/bash
# Program:
# 	 配置多个Tomcat实例， 用Nginx做反向代理
# Author: 
#	陈涛    2017/9/15
#

VHOSTS="www.ladyyang.org"


#=============================================================
# Tmocat的相关变量
#
JDK="jdk1.8.0_144"
TOMCAT_URL="http://mirrors.tuna.tsinghua.edu.cn/apache/tomcat/tomcat-8/v8.5.20/bin/apache-tomcat-8.5.20.tar.gz"
TOMCAT_TAR_DIR="apache-tomcat-8.5.20.tar.gz"
TOMCAT_DIR="apache-tomcat-8.5.20"

#==============================================================
# Nginx的相关变量
#
NGINX_URL="http://nginx.org/download/nginx-1.13.5.tar.gz"
NGINX_FILE="nginx-1.13.5.tar.gz"
NGINX_DIR="nginx-1.13.5"


#===============================================================
# 检测错误函数

function check_ok(){
    if [ $? -eq 0 ];then
        echo -e "配置.......................................................\033[32m[ OK ]\033[0m"  
        continue
    else
        echo -e "配置.......................................................\033[31m[ Error ]\033[0m"
        exit
    fi
}


#==============================================================
# Tomcat的安装函数
#
function install_tomcat(){
    mkdir /usr/java/
    mv /usr/local/src/$JDK /usr/java/
    
    cat >> /etc/profile <<EOF

export JAVA_HOME=/usr/java/$JDK  
export CLASSPATH=\$CLASSPATH:\$JAVA_HOME/lib:\$JAVA_HOME/jre/lib  
export PATH=\$JAVA_HOME/bin:\$JAVA_HOME/jre/bin:\$PATH:\$JAVA_HOME/bin 
EOF
    source /etc/profile
    . /etc/profile
    echo -e "\033[32m--------------------------------------\033[0m\n"
    java -version
    echo -e "\n\033[32m--------------------------------------\033[0m"
    sleep 3

    cd /usr/local/src
    if [ ! -f $TOMCAT_TAR_DIR ];then
        wget $TOMCAT_URL
    fi
    tar xzf $TOMCAT_TAR_DIR
    
    if [ ! -d /usr/local/tomcat ];then
        mkdir -p /usr/local/tomcat
    fi
    
    # 判断/usr/local/tomcat 目录下是否有server_x 目录 ( x 代表数字)递增的增加目录
    NUM=`ls /usr/local/tomcat/ | gawk -F "_" '{print $2}' | sed -n '$p'`

    if [ -z $NUM ];then
        mv -f /usr/local/src/$TOMCAT_DIR  /usr/local/tomcat/server_1
        NUM=1
    else
        mv -f /usr/local/src/$TOMCAT_DIR  /usr/local/tomcat/server_`expr ${NUM} + 1`
        NUM=`expr $NUM + 1`
    fi

    PORT_1=`grep "port" /usr/local/tomcat/server_${NUM}/conf/server.xml | egrep -v "\--|Define" | awk '{print $2}' | grep -v "protocol" | sed 's/port=//g;s/\"//g' | sort -nr | grep -v 8443 | sed -n '1p'`
    
    # 创建 /data/webapps/www 目录作为 网页的发布目录
    mkdir -p /data/webapps/www/
 
    if [ ! -f /root/domain.txt ];then
        echo -e "缺少 domain.txt 请联系管理员.......................................................\033[31m[ Error ]\033[0m"
        exit
    fi

    # 将domain.txt 文件拷贝到 nginx 配置文件中去
    cp -rf /root/domain.txt  /usr/local/nginx/conf/domains/$VHOSTS
    
    sed -i "/^upstream/a            server 127.0.0.1:${PORT_1} weight=1 max_fails=2 fail_timeout=30s; "  /usr/local/nginx/conf/domains/$VHOSTS

    # 将多个tomcat 的发布目录设置为同一个目录
    sed -i '/<\/Host>/i\        <Context path="/" docBase="/data/webapps/www"  reloadable="true"/>\n' /usr/local/tomcat/server_${NUM}/conf/server.xml

    # 启动Tomcat服务
    pkill java
    /usr/local/tomcat/server_${NUM}/bin/shutdown.sh 
    /usr/local/tomcat/server_${NUM}/bin/startup.sh

    if [ $? -eq 0 ];then
        echo -e "\nTomcat启动................................................\033[32m[ OK ]\033[0m\n"
    fi

    unset PORT_1

}

#====================================================================
# Nginx安装函数
#
function install_nginx(){
    yum -y install pcre-devel pcre 
    cd /usr/local/src
    if [ ! -f $NGINX_FILE ];then
        wget -c $NGINX_URL
    fi
    tar xzf $NGINX_FILE
    if [ ! -d /usr/local/nginx ];then
        cd $NGINX_DIR
        ./configure --prefix=/usr/local/nginx  --with-http_stub_status_module --with-http_ssl_module
        check_ok
        make && make install
    fi
    pkill nginx
    /usr/local/nginx/sbin/nginx
    check_ok
}

#=====================================================================
# 整合nginx和tomcat

function nginx_tomcat(){
    grep "include domains" /usr/local/nginx/conf/nginx.conf >> /dev/null
    #if [ $? -ne 0 ];then
    #    sed -i '$d' /usr/local/nginx/conf/nginx.conf
    #    echo -e "\ninclude domains/*;\n}" >> /usr/local/nginx/conf/nginx.conf 
    #    mkdir -p /usr/local/nginx/conf/domains/
    #fi
    
    if [ $? -ne 0 ];then
        sed -i '$i\\ninclude domains\/*;\n' /usr/local/nginx/conf/nginx.conf  
        mkdir -p /usr/local/nginx/conf/domains/
    fi  
    
    TOMCAT_NUM=$1              # 要部署的TOMCAT的数量

    # 本地TOMCAT的数量
    LOCAL_NUM=`ls /usr/local/tomcat | gawk -F "_" '{print $2}' | sed -n '$p'`

    # 循环递增创建Tomcat
    I=1
    while [ $I  -le $TOMCAT_NUM ]
    do
        cp -fr /usr/local/tomcat/server_${LOCAL_NUM}  /usr/local/tomcat/server_`expr ${LOCAL_NUM} + 1`       

        # 检查tomcat的端口是多少 
        PORT_1=`grep "port" /usr/local/tomcat/server_${LOCAL_NUM}/conf/server.xml | egrep -v "\--|Define" | awk '{print $2}' | grep -v "protocol" | sed 's/port=//g;s/\"//g' | sort -nr | grep -v 8443 | sed -n '1p'`
        PORT_2=`grep "port" /usr/local/tomcat/server_${LOCAL_NUM}/conf/server.xml | egrep -v "\--|Define" | awk '{print $2}' | grep -v "protocol" | sed 's/port=//g;s/\"//g' | sort -nr | grep -v 8443 | sed -n '2p'`
        PORT_3=`grep "port" /usr/local/tomcat/server_${LOCAL_NUM}/conf/server.xml | egrep -v "\--|Define" | awk '{print $2}' | grep -v "protocol" | sed 's/port=//g;s/\"//g' | sort -nr | grep -v 8443 | sed -n '3p'`

        # PORT_1_NEW 是tomcat发布的端口
        PORT_1_NEW=`expr $PORT_1 + 1`
        PORT_2_NEW=`expr $PORT_2 + 1`
        PORT_3_NEW=`expr $PORT_3 - 1`

        sed -i "s/${PORT_1}/${PORT_1_NEW}/g"  /usr/local/tomcat/server_`expr ${LOCAL_NUM} + 1`/conf/server.xml
        sed -i "s/${PORT_2}/${PORT_2_NEW}/g"  /usr/local/tomcat/server_`expr ${LOCAL_NUM} + 1`/conf/server.xml
        sed -i "s/${PORT_3}/${PORT_3_NEW}/g"  /usr/local/tomcat/server_`expr ${LOCAL_NUM} + 1`/conf/server.xml

        # 将tomcat 部署到Nginx的upstream模块上 实现负载均衡
        sed -i "/^upstream/a            server 127.0.0.1:${PORT_1_NEW} weight=1 max_fails=2 fail_timeout=30s;"  /usr/local/nginx/conf/domains/$VHOSTS

        # 将多个tomcat 的发布目录设置为同一个目录
        #sed -i '/<\/Host>/i\        <Context path="/" docBase="/data/webapps/www"  reloadable="true"/>\n' /usr/local/tomcat/server_`expr $LOCAL_NUM + $I`/conf/server.xml

        # 启动Tomcat服务
        /usr/local/tomcat/server_`expr $LOCAL_NUM + 1`/bin/shutdown.sh
        /usr/local/tomcat/server_`expr $LOCAL_NUM + 1`/bin/startup.sh

        if [ $? -eq 0 ];then
            echo -e "\nTomcat启动................................................\033[32m[ OK ]\033[0m\n"
        fi

        LOCAL_NUM=`expr $LOCAL_NUM + 1`
        I=`expr $I + 1`

    done
    
    unset LOCAL_NUM

}

install_tomcat
nginx_tomcat $1
install_nginx

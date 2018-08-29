#!/bin/bash
# @Author: eastmoney@shimin.com
#CreateDate: 27-03-2017

cat << EOF
+-------------------------------------------+
|Cautions: Be Sure system_env is root
|Function: Auto install LA/NMP environment
|InstallPath: /application
+-------------------------------------------+
EOF
. /etc/init.d/functions
ExecuteUser=root
CurrentPath=$(pwd)
WebSite="www.eastmoney.com"

function EnvCheck(){
	CurrentUser=$(whoami)
	if [ "${CurrentUser}" != "${ExecuteUser}" ]
		then 
			action "Error, CurrentUser is ${CurrentUser},Need ${ExecuteUser}." /bin/false
			exit 1
		else
			HttpCode=`curl -I -o /dev/null -s -w %{http_code} www.baidu.com`
			if [ "${HttpCode}" -ne 200 ]
				then
					echo "$0 found the NetworkEnv is not connected to internet! "
					exit 1
				else
					action "$0 check UserEnv and NetEnv ..." /bin/true
			fi
 	fi		
}

function MainAppDownload(){
AppName=$1
AppDownloadUrl=$2
	wget ${AppDownloadUrl} > /dev/null 2>&1
	if [ $? == 0 ] 
		then	
			action "Download ${AppName} source packet "	/bin/true       
		else
			action "Download ${AppName} source packet "	/bin/false
			echo -e "\e[31;1mError, ${AppDownloadUrl} had been invaild!\e[0m"
			exit 1
	fi
}

function MainAppPktChk(){
    AppName=$1
    AppPacket=`ls ${AppName}*.tar.gz`
	if [ -z "${AppPacket}" ]
        then 
            action "$0 do not find the ${AppName} install packet. " /bin/false
            exit 1
    fi
    AppVersion=`ls ${AppName}*.tar.gz | egrep -o '([0-9].){2}[0-9]+'`
	AppInstallPath="/application/${AppName}-${AppVersion}"
	if [ ! -d "${AppInstallPath}" ]
		then 
			mkdir -p ${AppInstallPath}
		else
			read -t 30 -p "${AppInstallPath} was exist, cover it or not?[y/n]: " Choice
			if [ "${Choice}" != y ] && [ "${Choice}" != Y ]
				then 
					exit 0			
			fi
	fi
}

function MainAppInstChk(){
    if [ $? == 0 ]
		then 
            AppName=$1
            AppInstallPath=$2
            AppVersion=$3
			action "${AppName} install at ${AppInstallPath}" /bin/true
			cd .. 
			[ -d "${CurrentPath}/${AppName}-${AppVersion}" ] &&  \
            rm -rf ${AppName}-${AppVersion}
			cd /application && ln -s ${AppInstallPath} ${AppName} > /dev/null 2>&1 
		else
			action "The procedure of ${AppName} making encounter some error!" /bin/false
            cd ${CurrentPath}
			exit 1
	fi
}

function EnvValueSet(){
	APP_PATH=$1
	APP_NAME=$2
	BIN_TYPE=$3
	sed -i '$d' ~/.bash_profile
	cat << EOF >> ~/.bash_profile
${APP_NAME}_HOME=${APP_PATH};export ${APP_NAME}_HOME
PATH=\$${APP_NAME}_HOME/${BIN_TYPE}:\$PATH
export PATH
EOF
	source ~/.bash_profile
}

function NginxInstall(){
    MainAppDownload nginx "http://nginx.org/download/nginx-1.8.1.tar.gz"
    MainAppPktChk nginx 
    OpenWebName="EMW"
	groupadd nginx > /dev/null 2>&1
	useradd -g nginx -s /sbin/nologin -M nginx > /dev/null 2>&1
	yum -y install pcre pcre-devel \
                   zlib zlib-devel \
                   openssl openssl-devel
	tar -zxf ${AppName}-${AppVersion}.tar.gz
    # Nginx optimize: hide nginx version from HttpPkt response header
    # add line "server_tokens off" in http_module of nginx conf_file
	cd ${AppName}-${AppVersion}/ && \
        sed -i -r -e "s/([0-9]\.){2}[0-9]/25\.10\.2/g" \
                  -e "s/nginx\//${OpenWebName}\//g" \
                  -e 's/"NGINX"/"${OpenWebName}"/g' src/core/nginx.h
        sed -i "s/Server: nginx/Server: ${OpenWebName}/g" src/http/ngx_http_header_filter_module.c
        sed -i -e "s/NGINX_VER \"/NGINX_VER \"(${WebSite})/g" \
               -e "s/>nginx</>${OpenWebName}</g" src/http/ngx_http_special_response.c
            ./configure --prefix=${AppInstallPath} \
                        --user=nginx \
                        --group=nginx \
                        --with-http_ssl_module \
                        --with-http_stub_status_module \
                        --with-http_gzip_static_module \
                        --with-http_gunzip_module                               
	make && make install 
    MainAppInstChk nginx ${AppInstallPath} ${AppVersion}
}

function ApacheInstall(){
    MainAppDownload httpd "http://www-eu.apache.org/dist/httpd/httpd-2.2.32.tar.gz" 
    MainAppPktChk httpd 
    groupadd apache > /dev/null 2>&1
	useradd -g apache -s /sbin/nologin -M apache > /dev/null 2>&1
    yum -y install gcc gcc-c++ \
                   apr apr-util \
                   zlib-devel pcre-devel \
                   openssl-devel
    tar -zxf ${AppName}-${AppVersion}.tar.gz
    cd ${AppName}-${AppVersion}/ && ./configure --prefix=${AppInstallPath} \
                                                --enable-so --enable-rewrite \
                                                --enable-expires --enable-headers \
                                                --with-mpm=worker --enable-ssl \
                                                --enable-cgi --enable-deflate \
                                                --enable-ssl --enable-cache 
    make && make install
    MainAppInstChk httpd ${AppInstallPath} ${AppVersion}
}

function MysqlInstall(){
    rpm -qa | egrep '(myql|mariadb)' >> remain.txt
	if [ ! -s remain.txt ]
		then 
            for i in `cat remain.txt`;do rpm -e --nodeps $i > /dev/null 2>&1;done
            rm -rf remain.txt
    fi
    groupadd mysql > /dev/null 2>&1
    useradd -s /sbin/nologin -g mysql -M mysql > /dev/null 2>&1
    MainAppPktChk mysql
    yum -y install make gcc-c++ autoconfm4cmake cmake.x86_64 \
                   bison-devel ncurses-devel 
    tar -zxf ${AppName}-${AppVersion}.tar.gz
    cd ${AppName}-${AppVersion}/ && cmake -DCMAKE_INSTALL_PREFIX=${AppInstallPath} \
                                          -DMYSQL_UNIX_ADDR=${AppInstallPath}/mysql.sock \
                                          -DDEFAULT_COLLATION=utf8_general_ci \
                                          -DDEFAULT_CHARSET=utf8 \
                                          -DWITH_INNOBASE_STORAGE_ENGINE=1 \
                                          -DWIT_ARCHIVE_STORAGE_ENGINE=1 \
                                          -DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
                                          -DDOWNLOAD_BOOST=1
    make && make install
    MainAppInstChk mysql ${AppInstallPath} ${AppVersion}
    MysqlDataPath="/data/mysql"
    [ ! -d ${MysqlDataPath} ] && mkdir  -p ${MysqlDataPath}
    chown -R mysql:mysql ${AppInstallPath} ${MysqlDataPath}
    cd ${AppInstallPath}/scripts && ./mysql_install_db --user=mysql \
                                                         --group=mysql \
                                                         --datadir=${MysqlDataPath} \
                                                         --basedir=${AppInstallPath}
    if [ $? == 0 ]
        then
            action "Initial database at ${MysqlDataPath}..." /bin/true
            cp ${AppInstallPath}/support-files/my-default.cnf /etc/my.cnf
            basedir_line_num=`egrep -n "^.*basedir.*$" /etc/my.cnf | cut -d ":" -f1`
            datadir_line_num=`egrep -n "^.*datadir.*$" /etc/my.cnf | cut -d ":" -f1`
            sed -i -e "${basedir_line_num}a  basedir = ${AppInstallPath}" \
                   -e "${datadir_line_num}a  datadir = ${MysqlDataPath}" /etc/my.cnf
        else
            action "The procedure of initial database encounter some error!" /bin/false
            exit 1
    fi
}

function PhpInstall(){
    MainAppPktChk php
    yum -y install zlib-devel openssl-devel libxml2-devel libjpeg-devel \
                   libjpeg-turbo-devel freetype-devel libpng-devel \
                   gd-devel libcurl-devel libxslt-devel perl perl-devel \
                   openssl openssl-devel gettext gettext-devel 
    PhpDepList=(libiconv libmcrypt mhash)
    for i in `seq 0 $((${#PhpDepList[@]}-1))`
        do 
            tar -zxf ${PhpDepList[$i]}*.tar.gz
            if [ $? != 0 ]
                then 
                    action "$0 deal with ${PhpDepList[$i]} error, \
                    Check ${PhpDepList[$i]} whether exist." /bin/false
                    exit 1
                else
                    cd ${PhpDepList[$i]}* && \
                    ./configure --prefix=/usr/local/${PhpDepList[$i]}
                    # if your have substitude libiconv packet by youself, please do below
                    # delele operation before make libiconv, else will encounter error!
                    # sed -i '/gets is a security/d' /libiconv*/srclib/stdio.in.h
                    make && make install
                    if [ $? != 0 ]
                        then
                            action "Making ${PhpDepList[$i]} encounter error" /bin/false
                            exit 1
                        else
                            cd ..
                    fi
            fi
        done
    tar -zxf ${AppName}-${AppVersion}.tar.gz
    cd ${AppName}-${AppVersion} && \
        __MysqlInstallPath=mysqlnd
        # Default PHP will be installed in integrated server, if PHP and database install
        # on different server, please cancel annotation below and substitude 
        # "--with-mysqli" parameter. 
        # 1、__MysqlInstallPath="/application/mysql"
        # 2、--with-mysqli=${__MysqlInstallPath}/bin/mysql_config 
        if [ -d "/application/nginx" ]
            then
                ./configure --prefix=${AppInstallPath} \
                            --with-config-file-path=/usr/local/etc/cgi \
                            --with-mysql=${__MysqlInstallPath} \
                            --with-mysqli=${__MysqlInstallPath} \
                            --with-pdo-mysql=${__MysqlInstallPath} \
                            --with-iconv-dir=/usr/local/${PhpDepList[0]} \
                            --with-mcrypt=/usr/local/${PhpDepList[1]} \
                            --with-mhash=/usr/local/${PhpDepList[2]} \
                            --with-freetype-dir --with-xmlrpc \
                            --with-jpeg-dir --with-png-dir \
                            --with-zlib --with-openssl --with-pear \
                            --with-gd --with-gd-native-ttf \
                            --with-curl --with-curlwrapper \
                            --with-fpm-user=nginx \
                            --with-fpm-group=nginx \
                            --with-libxml-dir=/usr --with-xsl \
                            --enable-xml --enable-mysqlnd \
                            --enable-safe-mode --enable-bcmath \
                            --enable-shmop --enable-fpm \
                            --enable-ftp --enable-static \
                            --enable-soap --enable-zip \
                            --enable-short-tags --enable-pcntl \
                            --enable-mbregex --enable-inline-optimization \
                            --enable-mbstring --enable-sockets \
                            --enable-sysvshm --enable-sysvsem  
            else
                Httpd_APXS="/application/httpd/bin/apxs"
                if [ -f "${Httpd_APXS}" ]
                    then
                        ./configure --prefix=${AppInstallPath} \
                                    --with-mysql=${__MysqlInstallPath} \
                                    --with-mysqli=${__MysqlInstallPath} \
                                    --with-pdo-mysql=${__MysqlInstallPath} \
                                    --with-iconv-dir=/usr/local/${PhpDepList[0]} \
                                    --with-mcrypt=/usr/local/${PhpDepList[1]} \
                                    --with-mhash=/usr/local/${PhpDepList[2]} \
                                    --with-apxs2=${Httpd_APXS} \
                                    --with-freetype-dir --with-xmlrpc \
                                    --with-jpeg-dir --with-png-dir \
                                    --with-zlib --with-openssl --with-pear \
                                    --with-gd --with-gd-native-ttf \
                                    --with-curl --with-curlwrapper \
                                    --with-libxml-dir=/usr --with-xsl \
                                    --enable-xml --enable-mysqlnd \
                                    --enable-safe-mode --enable-bcmath \
                                    --enable-shmop \
                                    --enable-ftp --enable-static \
                                    --enable-soap --enable-zip \
                                    --enable-short-tags --enable-pcntl \
                                    --enable-mbregex --enable-inline-optimization \
                                    --enable-mbstring --enable-sockets \
                                    --enable-sysvshm --enable-sysvsem  
                    else
                        action "$0 not found ${Httpd_APXS},configure ${AppName} error" /bin/false
                        exit 1
                fi
        fi
    make && make install
    MainAppInstChk php ${AppInstallPath} ${AppVersion}
}

function Nginx(){
    NginxInstall
    EnvValueSet $AppInstallPath NGINX sbin
}

function Mysql(){
    MysqlInstall
    EnvValueSet $AppInstallPath MYSQL bin
}

function Php(){
    PhpInstall
    EnvValueSet $AppInstallPath PHP sbin
}

function Apache(){
    ApacheInstall
    EnvValueSet $AppInstallPath HTTPD bin
}

EnvCheck
while true
    do
cat << EOF
+----------------------------------------------+
|`echo -e "\e[31;5m       Current avaliable App above:\e[0m"` 
|`echo -e "\e[39;1m               1. Nginx\e[0m"`
|`echo -e "\e[36;1m               2. Apache\e[0m"`
|`echo -e "\e[35;1m               3. Mysql\e[0m"`
|`echo -e "\e[34;1m               4. Php\e[0m"`
|`echo -e "\e[32;1m               5. LNMP\e[0m"`
|`echo -e "\e[32;1m               6. LAMP\e[0m"`
|`echo -e "\e[31;1m               0. exit\e[0m"`
+----------------------------------------------+
EOF
        read  -t 30 -p "Please enter the soft choice you want to install: " Num
        ChkChoice=`echo ${Num} | sed s/[0-9]//`
        if [ -z "${ChkChoice}" ]
            then
                case ${Num} in
                    1)
                        Nginx
                                ;;
                    2)
                        Apache
                                ;;
                    3)
                        Mysql
                                ;;
                    4)
                        Php
                                ;;
                    5)
                        Nginx
                        Mysql
                        Php
                                ;;
                    6)
                        Apache
                        Mysql
                        Php
                                ;;
                    0|*)
                        exit 0
                                ;;
                esac
            else
                echo "Please enter correct choice in [0-6]. "
        fi
    done











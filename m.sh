#!/bin/bash
blue(){  
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}


function install_trojan(){

    green "Enter system type By number [1]centos [2]debian/ubuntu "
    read -p "(Default : 1   ):" system_type
    if [ -z "$systemPackage" ];then
	system_type="1"
	fi
	if [ "$system_type" == "1" ];then
	systemPackage="yum"
	elif [ "$system_type" == "2" ];then
	systemPackage="apt-get"
	fi
	
	systemctl stop firewalld >/dev/null 2>&1
	systemctl mask firewalld >/dev/null 2>&1

	yum install iptables-services -y >/dev/null 2>&1
	chkconfig iptables on >/dev/null 2>&1
	systemctl start iptables >/dev/null 2>&1

Port80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80`
Port443=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443`
if [ -n "$Port80" ]; then
    process80=`netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}'`
    echo "==========================================================="
    red "It is detected that port 80 is occupied, the occupation process is:${process80}，This installation is over"
    echo "==========================================================="
    exit 1
fi
if [ -n "$Port443" ]; then
    process443=`netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}'`
    echo "============================================================="
    red "It is detected that port 443 is occupied, the occupation process is：${process443}，This installation is over"
    echo "============================================================="
    exit 1
fi


pre_install  

	$systemPackage install -y epel-release
 	$systemPackage -y update
	$systemPackage -y install  git python-tools python-pip curl wget unzip zip socat
	
	sleep 1
	
	rm -rf /tmp/trojan-go 
	
	if [ ! -d /etc/trojan-go ];then
	mkdir -p /etc/trojan-go
	fi
	
	mkdir -p /tmp/trojan-go 
	sleep 2
	cd /tmp/trojan-go

	wget https://github.com/frainzy1477/trojan-go-sspanel/releases/download/v0.8.2/trojan-go-linux-amd64.zip
	unzip trojan-go-linux-amd64
	cp /tmp/trojan-go/trojan-go /etc/trojan-go/
	cp /tmp/trojan-go/geosite.dat /etc/trojan-go/
	cp /tmp/trojan-go/geoip.dat /etc/trojan-go/
	chmod +x /etc/trojan-go/trojan-go
	rm -rf /tmp/trojan-go >/dev/null 2>&1

	sleep 2
	cd /etc/trojan-go
	
	if [ ! -f /etc/trojan-go/acme/acme.sh ];then
	wget https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh
	chmod +x acme.sh
	./acme.sh --install --home /etc/trojan-go/acme
	fi
	
	bash /etc/trojan-go/acme/acme.sh --cert-home /etc/trojan-go --issue -d $your_domain  --standalone --force
	mv /etc/trojan-go/$your_domain/fullchain.cer /etc/trojan-go/$your_domain/fullchain.crt

if [ ! -f /etc/systemd/system/trojan-go.service ];then	
touch /etc/systemd/system/trojan-go.service
cat >/etc/systemd/system/trojan-go.service << EOF
[Unit]
Description=trojan
Documentation=https://github.com/p4gefau1t/trojan-go
After=network.target

[Service]
Type=simple
StandardError=journal
PIDFile=/etc/trojan/trojan.pid
ExecStart=/etc/trojan-go/trojan-go -config /etc/trojan-go/$your_domain.json
ExecReload=
ExecStop=/etc/trojan-go/trojan-go
LimitNOFILE=51200
Restart=on-failure
RestartSec=1s

[Install]
WantedBy=multi-user.target  
EOF
systemctl daemon-reload
fi

rm -rf /etc/trojan-go/$your_domain.json 2>/dev/null
cat > /etc/trojan-go/$your_domain.json <<-EOF
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 443,
  "remote_addr": "127.0.0.1",
  "remote_port": 80,
  "password": [],
  "log_level": 1,
  "buffer_size": 32,
  "dns": ["8.8.8.8","1.1.1.1"],
  "disable_http_check": true,
  "udp_timeout": 30,
  "ssl": {
    "verify": true,
    "verify_hostname": true,
    "cert": "/etc/trojan-go/$your_domain/fullchain.crt",
    "key": "/etc/trojan-go/$your_domain/$your_domain.key",
    "key_password": "",
    "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:AES128-SHA:AES256-SHA:DES-CBC3-SHA",
    "curves": "",
    "prefer_server_cipher": false,
    "sni": "$your_domain",
    "alpn": [
      "http/1.1"
    ],
    "session_ticket": true,
    "reuse_session": true,
    "plain_http_response": "tcp",
    "fallback_addr": "www.cloudflare.com",
    "fallback_port": 443,
    "fingerprint": "firefox"
  },
  "tcp": {
    "no_delay": true,
    "keep_alive": true,
    "prefer_ipv4": false
  },
  "mux": {
    "enabled": $enable_mux,
    "concurrency": 8,
    "idle_timeout": 60
  },
  "router": {
    "enabled": true,
    "default_policy": "proxy",
    "domain_strategy": "as_is",
    "geoip": "/etc/trojan-go/geoip.dat",
    "geosite": "/etc/trojan-go/geosite.dat"
  },
  "websocket": {
    "enabled": $enable_websocket,
    "path": "$websocket_path",
    "hostname": "$websocket_host"
  },
  "webapi":{
    "enabled": true, 
    "node_id":   $node_id,
    "panelUrl": "$panelurl",
    "panelKey": "$panelkey",
    "check_rate": $check_rate
  } 
}
EOF




if [ $? = 0 ]; then
	systemctl enable trojan-go
        systemctl restart trojan-go && systemctl daemon-reload
	#systemctl status trojan-go
	green "======================================================================"
	green "Trojan installation complete"
	echo "======================================================================"
fi	


}


pre_install(){   
 
    green "Please enter the domain name bound to this VPS"
    read -p "(There is no default value please make sure you input the right thing):" your_domain
    echo
    echo "---------------------------"
    echo "Domain Name = $your_domain"
    echo "---------------------------"
    echo
    
    green "Enable Mux"
    read -p "(Default : false 'true/false'):" enable_mux
    if [ -z "$enable_mux" ];then 
	enable_mux="false"
	fi
    echo
    echo "---------------------------"
    echo "Enable Mux = $enable_mux"
    echo "---------------------------"
    echo
    
    
    green "Enable websocket"
    read -p "(Default : false 'true/false'):" enable_websocket
    if [ -z "$enable_websocket" ];then 
	enable_websocket="false"
	fi
    echo
    echo "---------------------------"
    echo "Enable websocket = $enable_websocket"
    echo "---------------------------"
    echo
    
    if [ "$enable_websocket" == "true" ];then
    green "Websocket Path"
    read -p "(Default Path: /trojan):" websocket_path
    if [ -z "${websocket_path}" ];then
	websocket_path="/trojan"
	fi
    echo
    echo "---------------------------"
    echo "Websocket Path = $websocket_path"
    echo "---------------------------"
    echo 
    
    green "Websocket Hostname"
    read -p "(Default Hostname: ${your_domain}):" websocket_host
    if [ -z "$websocket_host" ];then
	websocket_host="$your_domain"
	fi
    echo
    echo "---------------------------"
    echo "Websocket Hostname = $websocket_host"
    echo "---------------------------"
    echo     
    fi
    
    green "PanelUrl"
    read -p "(Default : No default value):" panelurl
    echo
    echo "---------------------------"
    echo "PanelUrl = $panelurl"
    echo "---------------------------"
    echo 
	
	
    green "PanelKey"
    read -p "(Default: No default value):" panelkey
    echo
    echo "---------------------------"
    echo "PanelKey = $panelkey"
    echo "---------------------------"
    echo 
    
    green "Node Id"
    read -p "(Default : 1 ):" node_id
    if [ -z "$node_id" ];then
	node_id=1
	fi
    echo
    echo "---------------------------"
    echo "Enable Transport Plugin = $node_id"
    echo "---------------------------"
    echo 
    
    green "Check Rate"
    read -p "(Default : 60 ):" check_rate
    if [ -z "$check_rate" ];then
	check_rate=60
	fi
    echo
    echo "---------------------------"
    echo "Check Rate = $check_rate"
    echo "---------------------------"
    echo 
}   

start_menu(){
    clear
    echo " ======================================= "
    green " Introduction: One-click installation trojan "
    green " System： centos7+/debian9+/ubuntu16.04+ "
    blue " Statement："
    green " *Please do not use this script in any production environment"
    green " *Please do not have other programs occupying ports 80 and 443 "
    echo " ======================================= "
    echo
    green " 1. Install trojan-go"
    red " 0. Quit"
    echo
    read -p "Please enter the number:" num
    case "$num" in
    1)
    install_trojan
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    red "Please enter the correct number"
    sleep 1s
    start_menu
    ;;
    esac
}

start_menu
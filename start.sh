#!/bin/bash
echo "Write IP address of IPS - web interface, followed by [ENTER]";
read ips_ip;
echo "netmask in xxx.xxx.xxx.xxx format";
read ips_netmask;
#echo "gateway";
#read ips_gateway;

apt-get update
apt-get -y install openssh-server
#apache2
apt-get -y install apache2
service apache2 restart
#suricata
apt-get install libgeoip-dev libgeoip1
apt-get -y install libpcre3 libpcre3-dbg libpcre3-dev \
build-essential autoconf automake libtool libpcap-dev libnet1-dev \
libyaml-0-2 libyaml-dev zlib1g zlib1g-dev libcap-ng-dev libcap-ng0 \
make libmagic-dev pkg-config libnss3-dev libnspr4-dev wget libjansson-dev libjansson4
git clone git://phalanx.openinfosecfoundation.org/oisf.git && cd oisf && \
git clone https://github.com/ironbee/libhtp.git -b 0.5.x \
&& ./autogen.sh && ./configure --prefix=/usr/ --sysconfdir=/etc/ --localstatedir=/var/ \
--enable-geoip --with-libnss-libraries=/usr/lib --with-libnss-includes=/usr/include/nss/ \
--with-libnspr-libraries=/usr/lib --with-libnspr-includes=/usr/include/nspr \
&& make clean && make  && make install-full && sudo ldconfig

cd ~/easy-ips/
cp suricata.yaml /etc/suricata/ > installation.log 2>&1

apt-get update
apt-get -y install openjdk-7-jdk openjdk-7-jre-headless

wget https://download.elasticsearch.org/kibana/kibana/kibana-3.0.0.tar.gz
wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.1.0.deb
wget https://download.elasticsearch.org/logstash/logstash/packages/debian/logstash_1.4.0-1-c82dc09_all.deb

tar -C /var/www/ -xzf kibana-3.0.0.tar.gz
dpkg -i elasticsearch-1.1.0.deb
dpkg -i logstash_1.4.0-1-c82dc09_all.deb

touch /etc/logstash/conf.d/logstash.conf
cd /etc/logstash/conf.d
cat <<EOF>>logstash.conf
input {
  file { 
    path => ["/var/log/suricata/eve.json"]
    codec =>   json 
    type => "SuricataIDPS-logs" 
  }

}

filter {
  if [type] == "SuricataIDPS-logs" {
    date {
      match => [ "timestamp", "ISO8601" ]
    }
  }

  if [src_ip]  {
    geoip {
      source => "src_ip" 
      target => "geoip" 
      database => "/opt/logstash/vendor/geoip/GeoLiteCity.dat" 
      add_field => [ "[geoip][coordinates]", "%{[geoip][longitude]}" ]
      add_field => [ "[geoip][coordinates]", "%{[geoip][latitude]}"  ]
    }
    mutate {
      convert => [ "[geoip][coordinates]", "float" ]
    }
  }
}

output { 
  elasticsearch {
    host => localhost
  }
}
EOF

update-rc.d elasticsearch defaults 95 10
update-rc.d logstash defaults

service apache2 restart
service elasticsearch start
service logstash start

apt-get install ethtool

cat "">/etc/network/interfaces
cat <<EOF>>/etc/network/interfaces

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet manual
   up ifconfig eth0 0.0.0.0 up
   down ifconfig eth0 down
   post-up ethtool -K eth0 gro off

auto eth1
iface eth1 inet manual
   up ifconfig eth1 0.0.0.0 up
   down ifconfig eth1 down
   post-up ethtool -K eth1 gro off

auto eth2
iface eth2 inet static
   address $ips_ip
   netmask $ips_netmask
   
EOF

chmod 644 /etc/suricata/threshold.config
chmod 644 /etc/suricata/classification.config
chmod 644 /etc/suricata/reference.config

#suricata -c /etc/suricata/suricata.yaml --af-packet
echo "### WELL DONE ###"
echo "Now pls reboot the system using sudo reboot"
 
#END
#!/bin/bash
clientName=$1

CURR_PATH=$PWD

LIST_CLIENTS=@list_vpn_clients@

# Configuration
SERVER_NAME=@server@
SERVER_ADDRESS=@server@.@noip_domain@
SERVER_PORT=@vpn_port@
VPN_IP=@vpn_ip@
DNS_IP=@vpn_ip@

CLIENT_PATH=/root/ovpn/client
SERVER_PATH=/root/ovpn/server

EASYRSA_PATH=$(mktemp -d)/easyrsa
EASYRSA_VER=easyrsa3
EASYRSA_BIN=$EASYRSA_PATH/$EASYRSA_VER/easyrsa

OPENVPN_CFG=/etc/openvpn
OPENVPN_BIN=$(which openvpn)
OPENSSL_BIN=$(which openssl)

GIT_BIN=$(which git)

# Check packages install
if [ -z "$OPENVPN_BIN" ] || [ -z "$OPENSSL_BIN" ]; then
  echo "Installing openvpn package"
  apt-get update && apt-get install -y openvpn
  OPENVPN_BIN=$(which openvpn)
  OPENSSL_BIN=$(which openssl)
fi

if [ -z "$GIT_BIN" ]; then
  echo "Installing git package"
  apt-get update && apt-get install -y git
  GIT_BIN=$(which git)
fi

# Check inputs
if [ $# -lt 1 ]; then
  echo "No argument provided"
  echo "Usage: $0 <client-name> [<client-name>]..."
  echo "  -ALL: Reset of server certificates and all clients"
  exit 1
fi

# Check input
if [ "$clientName" = "-ALL" ];then
  clientList=$LIST_CLIENTS
else
  clientList=$@
fi

# Download and install easyrsa
$GIT_BIN clone git://github.com/OpenVPN/easy-rsa $EASYRSA_PATH

# Create server key
create_server() {

  #Create server
  rm -rf $SERVER_PATH; mkdir -p $SERVER_PATH

  # Copy RSA configuration 
  cp $EASYRSA_PATH/$EASYRSA_VER/openssl-1.0.cnf $SERVER_PATH
  cp -r $EASYRSA_PATH/$EASYRSA_VER/x509-types $SERVER_PATH

  # Create PKIs
  cd $SERVER_PATH 
  $EASYRSA_BIN init-pki
  $EASYRSA_BIN build-ca
  $EASYRSA_BIN gen-req $SERVER_NAME nopass
  $EASYRSA_BIN sign-req server $SERVER_NAME

  # Generate tls authorisation
  $OPENSSL_BIN dhparam -out $SERVER_PATH/dh2048.pem 2048

  # Generate key
  $OPENVPN_BIN --genkey --secret $SERVER_PATH/ta.key

  cd $CURR_PATH

}

generate_server() {

  echo "Generating Server..."

  # Copy generated keys
  echo "Copying Server keys..." 
  cp -v $SERVER_PATH/ta.key                          $OPENVPN_CFG
  cp -v $SERVER_PATH/dh2048.pem                      $OPENVPN_CFG
  cp -v $SERVER_PATH/pki/ca.crt                      $OPENVPN_CFG
  cp -v $SERVER_PATH/pki/private/$SERVER_NAME.key    $OPENVPN_CFG
  cp -v $SERVER_PATH/pki/issued/$SERVER_NAME.crt     $OPENVPN_CFG

  echo "Creating Server Configuration..."
  echo "Server Address: $SERVER_ADDRESS:$SERVER_PORT"
  echo "Server VPN IP : $VPN_IP"

  ovpnconf=$SERVER_PATH/server.conf
  rm -f $ovpnconf

  # Server configuration
  echo "port $SERVER_PORT"                               >$ovpnconf
  echo "proto udp"                                       >>$ovpnconf
  echo "dev tun"                                         >>$ovpnconf
  echo "ca ca.crt"                                       >>$ovpnconf
  echo "cert $SERVER_NAME.crt"                           >>$ovpnconf
  echo "key $SERVER_NAME.key"                            >>$ovpnconf
  echo "tls-auth ta.key 0"                               >>$ovpnconf
  echo "dh dh2048.pem"                                   >>$ovpnconf
  echo ""                                                >>$ovpnconf
 # echo "server ${VPN_IP} 255.255.255.0"                >>$ovpnconf
  echo "mode server"                                     >>$ovpnconf
  echo "tls-server"                                      >>$ovpnconf
  echo "topology subnet"                                 >>$ovpnconf
  echo "ifconfig ${VPN_IP} 255.255.255.0"                >>$ovpnconf
  echo "ifconfig-pool ${VPN_IP%.*}.100 ${VPN_IP%.*}.199" >>$ovpnconf
  echo ""                                                >>$ovpnconf
  echo "cipher AES-256-CBC"                              >>$ovpnconf
  echo "persist-key"                                     >>$ovpnconf
  echo "persist-tun"                                     >>$ovpnconf
  echo "user nobody"                                     >>$ovpnconf
  echo "group nogroup"                                   >>$ovpnconf
  echo "status openvpn-status.log"                       >>$ovpnconf
  echo "verb 3"                                          >>$ovpnconf
  echo ""                                                >>$ovpnconf
  echo "push \"topology subnet\""                        >>$ovpnconf
  echo "push \"route-gateway ${VPN_IP}\""                >>$ovpnconf
  echo "push \"redirect-gateway def1\""                  >>$ovpnconf
  echo "push \"dhcp-option DNS ${DNS_IP}\""              >>$ovpnconf
  echo "push \"dhcp-option DOMAIN-SEARCH saturn.net\""   >>$ovpnconf
  echo "keepalive 5 30"                                  >>$ovpnconf

  cp -v $ovpnconf $OPENVPN_CFG

  echo "Creating firewall configuration..."
  fwconf=$SERVER_PATH/firewall.sh
  rm -f $fwconf

  # Firewall configuration
  echo "#!/bin/bash"                                                               >$fwconf
  echo "iptables -t filter -F"                                                     >>$fwconf
  echo "iptables -t nat -F"                                                        >>$fwconf
  echo "iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT"        >>$fwconf
  echo "iptables -A FORWARD -s \"${VPN_IP%.*}.0/24\" -j ACCEPT"                    >>$fwconf
  echo "iptables -A FORWARD -j REJECT"                                             >>$fwconf
  echo "iptables -t nat -A POSTROUTING -s \"${VPN_IP%.*}.0/24\" -j MASQUERADE"     >>$fwconf

  chmod +x $fwconf

  cp -v $fwconf /usr/local/bin

  grep -q "/usr/local/bin/firewall.sh" /etc/rc.local
  if [ $? != 0 ]; then
    sed -i "s#^exit 0\$##g" /etc/rc.local
    echo   "$fwconf"     >> /etc/rc.local
    echo   "exit 0"      >> /etc/rc.local
  fi

  sed -i 's/\#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

}

create_client() {

  # Create client
  rm -rf $CLIENT_PATH; mkdir -p $CLIENT_PATH

  # Copy RSA configuration
  cp $EASYRSA_PATH/$EASYRSA_VER/openssl-1.0.cnf $CLIENT_PATH
  cp -r $EASYRSA_PATH/$EASYRSA_VER/x509-types $CLIENT_PATH

  # Create PKIs
  cd $CLIENT_PATH
  $EASYRSA_BIN init-pki
  cd $CURR_PATH

}

generate_client() {

  client=$1

  echo "Generating client $client..."

  mkdir -p $CLIENT_PATH/output/$client

  ovpndest=$CLIENT_PATH/output/$client/${SERVER_NAME}_${client}.ovpn

  # Clean previous certificates
  rm -f $CLIENT_PATH/pki/reqs/$client.req
  rm -f $CLIENT_PATH/pki/private/$client.key
  rm -f $SERVER_PATH/pki/reqs/$client.req
  rm -f $SERVER_PATH/pki/issued/$client.crt
  sed -i /$client/d $SERVER_PATH/pki/index.txt

  # Generate request
  cd $CLIENT_PATH
  $EASYRSA_BIN gen-req $client nopass

  # Import and sign request on server
  cd $SERVER_PATH
  $EASYRSA_BIN import-req $CLIENT_PATH/pki/reqs/$client.req $client
  $EASYRSA_BIN sign-req client $client
  cd $CURR_PATH

  # Copy certificates
  cp $SERVER_PATH/pki/issued/$client.crt $CLIENT_PATH/output/$client/$client.crt
  cp $CLIENT_PATH/pki/private/$client.key $CLIENT_PATH/output/$client/$client.key

  # Create ovpn configuration
  echo "client"                                                  > $ovpndest
  echo "dev tun"                                                >> $ovpndest
  echo "proto udp"                                              >> $ovpndest
  echo "remote $SERVER_ADDRESS $SERVER_PORT"                    >> $ovpndest
  echo "resolv-retry infinite"                                  >> $ovpndest
  echo "nobind"                                                 >> $ovpndest
  echo "persist-key"                                            >> $ovpndest
  echo "persist-tun"                                            >> $ovpndest
  echo "remote-cert-tls server"                                 >> $ovpndest
  echo "cipher AES-256-CBC"                                     >> $ovpndest
  echo "verb 3"                                                 >> $ovpndest
  echo "key-direction 1"                                        >> $ovpndest
  echo "<ca>"                                                   >> $ovpndest
  awk /BEGIN/,/END/ < $SERVER_PATH/pki/ca.crt                   >> $ovpndest
  echo "</ca>"                                                  >> $ovpndest
  echo "<tls-auth>"                                             >> $ovpndest
  awk /BEGIN/,/END/ < $SERVER_PATH/ta.key                       >> $ovpndest
  echo "</tls-auth>"                                            >> $ovpndest
  echo "<cert>"                                                 >> $ovpndest
  awk /BEGIN/,/END/ < $CLIENT_PATH/output/$client/$client.crt   >> $ovpndest
  echo "</cert>"                                                >> $ovpndest
  echo "<key>"                                                  >> $ovpndest
  awk /BEGIN/,/END/ < $CLIENT_PATH/output/$client/$client.key   >> $ovpndest
  echo "</key>"                                                 >> $ovpndest

}

# Create server and client in case do not exist
if [ ! -d "$SERVER_PATH" ]; then
  create_server
fi

# Create server and client in case do not exist
if [ ! -d "$CLIENT_PATH" ]; then
  create_client
fi

# Generate Server
generate_server

# Generate Clients
for client in $clientList; do
  generate_client $client
done

# Restart server
systemctl restart openvpn
systemctl status openvpn

#rm -rf $EASYRSA_PATH


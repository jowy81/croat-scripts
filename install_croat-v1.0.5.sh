#!/bin/bash
#
#
################################################################################
######  User's variables, set it to your desired config                   ######
################################################################################
## SCRIPT INSTALLS TO
INSTALL_NODE="yes"             # "yes" Install croat full node
INSTALL_WALLET="yes"           # "yes" Install and setup wallet service
INSTALL_POOL="yes"             # "yes" Install and setup pool node
INSTALL_OPTIONALS="yes"        # "yes" Install optional programs and tunnings
SCRIPT_HOME="/opt/Croat"       # Defaults to "/opt/Croat", leave it blank to use USER HOME DIR

## CROAT NODE CONFIGS
NODE_TIMEOUT="180"             # Timeout used by tail to wait until node is fully synced

## WALLET CONFIGS
WALLET_NAME="pool1wallet"      # Name for the wallet
WALLET_PASSWD="Pass1234"       # Password for that wallet
WALLET_TIMEOUT="90"            # Timeout used by tail to wait until wallet is synced
# Wallet restore should BE only one of them filled, otherwise Mnemo will be used to recover
WALLET_RESTORE_FROM_MNEMO=""   # "word1 word2 word3 .. word25"    - wallet mnemo
WALLET_RESTORE_FROM_FILE=""    # "/home/user/wallet_name.wallet"  - path and name, must end with extension .wallet
WALLET_RESTORE_FROM_PKEY=""    # "CxDe..priv_key..Nrd"            - wallet private key

## POOL CONFIGS
POOLFQDN=""                                          # "pool.example.com" or ip "11.22.33.111"
POOLPASSWD="POOLpass1234"                            # Pool Api password and also admin web interface
POOLEMAIL="pool@example.com"                         # Pool email
POOLTELEGRAM="https://t.me/CroatPool"
POOLDISCORD="https://discordapp.com/invite/CroatPool"
POOLBACKUP=""                                        # "/home/user/redis/dump.rdb" Full route to redis rdb backup file

## OPTIONALS SETUP AND CONFIGS, needs INSTALL_OPTIONALS="yes"
SETUP_LOGROTATE="yes"
SETUP_REDIS_BACKUP="yes"
SETUP_FAIL2BAN="no"
SETUP_UFW="no"

### TODO
#fer que cincideixi exactament el nom Linea:191 cat passwd OK fet

################################################################################
######     DO NOT TOUCH CODE'S BELLOW                                     ######
################################################################################
SCRIPTVER="1"
SCRIPTREV="0.5"

export DEBIAN_FRONTEND=noninteractive

print_status() {
    echo
    echo "### $1 ###"
    echo
}
load_colors(){
if test -t 1; then # if terminal
    ncolors=$(which tput > /dev/null && tput colors) # supports color
    if test -n "$ncolors" && test $ncolors -ge 8; then
        termcols=$(tput cols)
        bold="$(tput bold)"
        underline="$(tput smul)"
        standout="$(tput smso)"
        normal="$(tput sgr0)"
        black="$(tput setaf 0)"
        red="$(tput setaf 1)"
        green="$(tput setaf 2)"
        yellow="$(tput setaf 3)"
        blue="$(tput setaf 4)"
        magenta="$(tput setaf 5)"
        cyan="$(tput setaf 6)"
        white="$(tput setaf 7)"
    fi
fi
}
print_bold() {
    title="$1"
    text="$2"

    echo
    echo "${red}================================================================================${normal}"
    echo "${red}================================================================================${normal}"
    echo "${red}================================================================================${normal}"
    echo
    echo -e "  ${bold}${yellow}${title}${normal}"
    echo
    echo -en "  ${text}"
    echo
    echo "${red}================================================================================${normal}"
    echo "${red}================================================================================${normal}"
    echo "${red}================================================================================${normal}"
}
bail() {
    echo 'Error executing command, exiting'
    exit 1
}
exec_cmd_nobail() {
    echo "+ $1"
    bash -c "$1"
}
exec_cmd() {
    exec_cmd_nobail "$1" || bail
}
script_initializing() {
        print_bold \
"                   INITIALIZING SCRIPT VERSION $SCRIPTVER.$SCRIPTREV                         " "\

                  ██████╗██████╗  ██████╗  █████╗ ████████╗
                 ██╔════╝██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝
                 ██║     ██████╔╝██║   ██║███████║   ██║
                 ██║     ██╔══██╗██║   ██║██╔══██║   ██║
                 ╚██████╗██║  ██║╚██████╔╝██║  ██║   ██║
                  ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝

                   Script developed by CROAT Community!
                      ( https://CROAT.community )

"
}
script_ending() {
        print_bold \
"                         INSTALLATION FINISHED.                         " "\

                  ██████╗██████╗  ██████╗  █████╗ ████████╗
                 ██╔════╝██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝
                 ██║     ██████╔╝██║   ██║███████║   ██║
                 ██║     ██╔══██╗██║   ██║██╔══██║   ██║
                 ╚██████╗██║  ██║╚██████╔╝██║  ██║   ██║
                  ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝

                   Script developed by CROAT Community!
                      ( https://CROAT.community )

"
}
check_usersudo(){
# Check if script runs with a sudo user
if [[ $(id -u) -ne 0 ]] ; then print_status "The script must be run with sudo" ; exit 1 ; fi
USER=`who -m | awk '{print $1}'`
RUNASUSER="runuser -u $USER --"
if [ ${USER} = "root" ] ; then print_status "Don't run the script with user 'root', run it with a sudo user" ; exit 1 ; fi
}
install_dependencies(){
    PRE_INSTALL_PKGS=""

    # Check that HTTPS transport is available to APT
    # (Check snaked from: https://get.docker.io/ubuntu/)
    if [ ! -e /usr/lib/apt/methods/https ]; then
        PRE_INSTALL_PKGS="${PRE_INSTALL_PKGS} apt-transport-https"
    fi

    if [ ! -x /usr/bin/lsb_release ]; then
        PRE_INSTALL_PKGS="${PRE_INSTALL_PKGS} lsb-release"
    fi

    if [ ! -x /usr/bin/curl ]; then
        PRE_INSTALL_PKGS="${PRE_INSTALL_PKGS} curl"
    fi

    # Used by apt-key to add new keys
    if [ ! -x /usr/bin/gpg ]; then
        PRE_INSTALL_PKGS="${PRE_INSTALL_PKGS} gnupg"
    fi

    if [ ! -x /usr/bin/screen ]; then
        PRE_INSTALL_PKGS="${PRE_INSTALL_PKGS} screen"
    fi

    if [ ! -x /usr/bin/netstat ]; then
        PRE_INSTALL_PKGS="${PRE_INSTALL_PKGS} net-tools"
    fi

    # Populating Cache
    print_status "Populating apt cache..."
    exec_cmd "apt-get update > /dev/null 2>&1"

    if [ "X${PRE_INSTALL_PKGS}" != "X" ]; then
        print_status "Installing packages required for setup:${PRE_INSTALL_PKGS}..."
        # This next command needs to be redirected to /dev/null or the script will bork
        # in some environments
        exec_cmd "apt-get install -y${PRE_INSTALL_PKGS} > /dev/null 2>&1"
    fi
}
get_vars(){
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
IP_INT="$(echo -e "$(hostname -I)" | awk '{print $1}')"
IP_EXT=$(curl -s http://checkip.amazonaws.com/)
if [ -n "$SCRIPT_HOME" ] ; then USER_HOME=${SCRIPT_HOME}
else
USER_HOME=$(cat /etc/passwd | grep $USER | head -1 | cut -d: -f6)
fi
if [ ! -d ${USER_HOME} ]; then
  mkdir -p ${USER_HOME}
  chown -R $USER:$USER ${USER_HOME}
fi

}
check_installs(){

if [[  "$INSTALL_NODE" = "yes"  ]] ; then install_node ; fi
if [[  "$INSTALL_WALLET" = "yes"  ]] ; then install_wallet ; fi
if [[  "$INSTALL_POOL" = "yes"  ]] ; then install_pool ; fi
if [[  "$INSTALL_OPTIONALS" = "yes"  ]] ; then install_ops ; fi

script_ending

}

set_lockfile(){
    cat << 'EOF' > $1
#!/bin/bash
#
#
### HEADER ###
LOCKFILE="/var/lock/`basename $0`"
LOCKFD=99

# PRIVATE
_lock()             { flock -$1 $LOCKFD; }
_no_more_locking()  { _lock u; _lock xn && rm -f $LOCKFILE; }
_prepare_locking()  { eval "exec $LOCKFD>\"$LOCKFILE\""; trap _no_more_locking EXIT; }

# ON START
_prepare_locking

# PUBLIC
exlock_now()        { _lock xn; }  # obtain an exclusive lock immediately or fail
exlock()            { _lock x; }   # obtain an exclusive lock
shlock()            { _lock s; }   # obtain a shared lock
unlock()            { _lock u; }   # drop a lock

# Simplest example is avoiding running multiple instances of script.
exlock_now || exit 1

### BEGIN OF SCRIPT ###
EOF
}

node_build(){
    cd $USER_HOME
    print_status "Installing packages required for building the Croat-node ..."
    exec_cmd "apt-get install -y cmake build-essential libboost-all-dev libcurl4-openssl-dev > /dev/null 2>&1"
    print_status "Cloning Croat-node from repo ..."
    exec_cmd "$RUNASUSER git clone https://github.com/CroatApps/Croat.git CroatGit > /dev/null 2>&1"
    cd $USER_HOME/CroatGit/
    print_status "Building Croat-node ..."
    exec_cmd "$RUNASUSER make all > /dev/null 2>&1"
    exec_cmd "$RUNASUSER mkdir -p $USER_HOME/croatd > /dev/null 2>&1"
    exec_cmd "$RUNASUSER cp build/release/src/croatd $USER_HOME/croatd/ > /dev/null 2>&1"
    exec_cmd "$RUNASUSER cp build/release/src/simplewallet $USER_HOME/croatd/ > /dev/null 2>&1"
    cd $USER_HOME/croatd
    print_status "Setting up Croat-node for the first start ..."
    $RUNASUSER mkdir $USER_HOME/.croat
    $RUNASUSER screen -dmS croatd ./croatd  --data-dir $USER_HOME/.croat
    sleep 12
    $RUNASUSER screen -S croatd -p 0 -X stuff "^C"
    print_status "Done building Croat-node ..."
}
node_fastsync(){
    cd $USER_HOME/.croat ; rm $USER_HOME/.croat/*
    print_status "Syncronizing Croat-node with FastSync ..."
    #$RUNASUSER wget http://192.168.1.111/CROAT-BlockChain-LAST.tar.gz
    $RUNASUSER curl https://blockchain.croat.community/CROAT-BlockChain-LAST.tar.gz -o CROAT-BlockChain-LAST.tar.gz
    #$RUNASUSER cp ../CROAT-BlockChain-LAST.tar.gz .

    exec_cmd "$RUNASUSER tar -xvf CROAT-BlockChain-LAST.tar.gz > /dev/null 2>&1"

    rm CROAT-BlockChain-LAST.tar.gz
}
node_config(){
    cd $USER_HOME/croatd
    exec_cmd "$RUNASUSER mkdir $USER_HOME/croatd/logs > /dev/null 2>&1"
    exec_cmd "$RUNASUSER mkdir $USER_HOME/croatd/config > /dev/null 2>&1"
    exec_cmd "$RUNASUSER mkdir $USER_HOME/croatd/scripts > /dev/null 2>&1"
    exec_cmd "$RUNASUSER touch $USER_HOME/croatd/config/croatd.conf > /dev/null 2>&1"
    cat << EOF > $USER_HOME/croatd/config/croatd.conf
p2p-bind-port=46347
p2p-bind-ip=0.0.0.0
rpc-bind-port=46348
rpc-bind-ip=0.0.0.0
log-level=2
log-file=$USER_HOME/croatd/logs/croatd.log
restricted-rpc=true
EOF
}
node_service(){
    exec_cmd "$RUNASUSER touch $USER_HOME/croatd/scripts/start_croatd.sh > /dev/null 2>&1"
    set_lockfile $USER_HOME/croatd/scripts/start_croatd.sh
    cat << EOF >> $USER_HOME/croatd/scripts/start_croatd.sh
HOMEDIR=$USER_HOME/croatd
cd \$HOMEDIR

screen -dmS node-croatd sh -c "./croatd --config-file=config/croatd.conf --data-dir=$USER_HOME/.croat"
EOF
    exec_cmd "$RUNASUSER touch $USER_HOME/croatd/scripts/stop_croatd.sh > /dev/null 2>&1"
    set_lockfile $USER_HOME/croatd/scripts/stop_croatd.sh
    cat << EOF >> $USER_HOME/croatd/scripts/stop_croatd.sh
HOMEDIR=$USER_HOME/croatd
cd \$HOMEDIR

pkill -f \"$HOMEDIR/croatd\" &
PROC_ID=\$!
wait \$PROC_ID
EOF
    cat << EOF > /etc/systemd/system/croatd-node.service
[Unit]
Description=Croatd Full Node Service
After=network.target

[Service]
User=$USER
Group=$USER

Type=forking
ExecStart=$USER_HOME/croatd/scripts/start_croatd.sh
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=croatd-node
ExecStop=$USER_HOME/croatd/scripts/stop_croatd.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    exec_cmd "chmod +x $USER_HOME/croatd/scripts/*.sh > /dev/null 2>&1"
    systemctl daemon-reload
    systemctl enable croatd-node.service
    systemctl start croatd-node.service
    sleep 2
    IS_RUNNING=$(systemctl show -p SubState croatd-node.service | sed 's/SubState=//g')
    if [ "$IS_RUNNING" == "running" ]; then
        print_status "Service running, syncronizing Croatd-node ..."
    else
        print_status "Service not running, exiting ..."
        exit 1
    fi

    rm $USER_HOME/croatd/croatd.log

    check_sync=$(timeout ${NODE_TIMEOUT}m tail --pid=$(($BASHPID+2)) -c +0 -F "$USER_HOME/croatd/logs/croatd.log" | sed -n '/SYNCHRONIZED OK/{p; q}')
    if [ "$check_sync" == "" ]
    then
        NODESYNC="NO"
    else
        NODESYNC="YES"
    fi
    if [ "$NODESYNC" == "YES" ]; then
        print_status "Fully syncronized Croatd-node ..."
    else
        print_status "Not fully syncronized Croatd-node ..."
        exit 1
    fi
}
install_node(){
    node_build
    node_fastsync
    node_config
    node_service
}

wallet_check(){
print_status "Detecting if have to create a new wallet or recovery from old one ...."
cd $USER_HOME/croatd
if [ -n "$WALLET_RESTORE_FROM_PKEY" ] ; then TYPE_RESTORE="key"; WALLETGEN="no" ; fi
if [ -n "$WALLET_RESTORE_FROM_FILE" ] ; then TYPE_RESTORE="file"; WALLETGEN="no" ; fi
if [ -n "$WALLET_RESTORE_FROM_MNEMO" ] ; then TYPE_RESTORE="mnemo"; WALLETGEN="no" ; fi
if [ -z "$TYPE_RESTORE" ]; then
    WALLETGEN="yes"
    wallet_create
else
    WALLETGEN="no"
    wallet_restore_type
fi
}
wallet_export(){
    $RUNASUSER screen -S simplewallettemp -p 0 -X stuff export_keys^M
    $RUNASUSER screen -S simplewallettemp -p 0 -X stuff exit^M
    sleep 3
    if [ -f $USER_HOME/croatd/$WALLET_NAME.address.bak ]; then
        mv $USER_HOME/croatd/$WALLET_NAME.address.bak $USER_HOME/croatd/$WALLET_NAME.address
    fi
    print_status "Exporting wallet keys to file $USER_HOME/croatd/$WALLET_NAME.keys"
    $RUNASUSER touch $USER_HOME/croatd/$WALLET_NAME.keys
    echo "### -Wallet Keys- ####" >> $USER_HOME/croatd/$WALLET_NAME.keys
    SPEND_KEY=$(grep 'Spend' 0screen.log | sed 's/^.*Spend secret key: //')
    echo "Spend key: $SPEND_KEY" >> $USER_HOME/croatd/$WALLET_NAME.keys
    VIEW_KEY=$(grep 'View' 0screen.log | sed 's/^.*View secret key: //')
    echo "View key: $VIEW_KEY" >> $USER_HOME/croatd/$WALLET_NAME.keys
    PRIVATE_KEY=$(grep 'Private' 0screen.log | sed 's/^.*Private keys: //')
    echo "Private key: $PRIVATE_KEY" >> $USER_HOME/croatd/$WALLET_NAME.keys
    echo "MNEMO:" >> $USER_HOME/croatd/$WALLET_NAME.keys
    grep -A 8 'PLEASE NOTE' 0screen.log | tail -n 7 >> $USER_HOME/croatd/$WALLET_NAME.keys
    echo "### -Wallet Keys END- ####" >> $USER_HOME/croatd/$WALLET_NAME.keys
    rm 0screen.log
}
wallet_create(){
    print_status "Generating new wallet ..."
    $RUNASUSER screen -dmS simplewallettemp sh -c "./simplewallet --generate-new-wallet $WALLET_NAME --password $WALLET_PASSWD | tee 0screen.log"
    sleep 15
}
wallet_restore_type(){
    print_status "Recovery wallet from $TYPE_RESTORE"
    case "$TYPE_RESTORE" in
        mnemo)  wallet_restore_f_mnemo
        ;;
        file)  wallet_restore_f_file
        ;;
        key)  wallet_restore_f_key
        ;;
        *)  exit 1
        ;;
    esac
}
wallet_restore_f_mnemo(){
    $RUNASUSER touch $USER_HOME/croatd/$WALLET_NAME.address.bak
    $RUNASUSER screen -dmS simplewallettemp sh -c "./simplewallet --restore --wallet-file $WALLET_NAME --password $WALLET_PASSWD | tee 0screen.log"
    sleep 5
    $RUNASUSER screen -S simplewallettemp -p 0 -X stuff "$WALLET_RESTORE_FROM_MNEMO^M"
    sleep 5
    #for ((i = 1; i <= $WALLET_TIMEOUT; i++)); do echo "" >> 0screen.log ; sleep 60 ; done &
    inc=1
    while [ "$inc" -le "$WALLET_TIMEOUT" ]; do echo "" >> 0screen.log ; sleep 60 ; done &
    PIDLOOP="$!"
    ADDRESS=$(grep 'Generated' 0screen.log | sed 's/^.*Generated new wallet: //')
    ADDRESS2FIND=$(echo $ADDRESS | cut -c1-6)
    echo "$ADDRESS" >> $USER_HOME/croatd/$WALLET_NAME.address.bak

    check_sync=$(timeout ${WALLET_TIMEOUT}m tail --pid=$(($BASHPID+2)) -c +0 -F "0screen.log" | sed -n "/\[wallet $ADDRESS2FIND\]:/{p; q}")
    if [ "$check_sync" = "" ]
    then
        kill "$PIDLOOP"
        print_status "Couldn't recover wallet from Mnemo"
        exit 1
    fi
    kill "$PIDLOOP"
    print_status "Recovered wallet from Mnemo"
}
wallet_restore_f_file(){
    wpath=${WALLET_RESTORE_FROM_FILE%/*}
    wbase=${WALLET_RESTORE_FROM_FILE##*/}
    wext=${wbase##*.}
    wpref=${wbase%.*}
    if [ "$wext" != "wallet" ]; then print_status "Invalid wallet extension, aborting" ; exit 1 ; fi

    cp $WALLET_RESTORE_FROM_FILE $USER_HOME/croatd/$WALLET_NAME.wallet
    chown $USER:$USER $USER_HOME/croat/$WALLET_NAME.wallet
    $RUNASUSER touch $USER_HOME/croatd/$WALLET_NAME.address.bak
    $RUNASUSER screen -dmS simplewallettemp sh -c "./simplewallet --password $WALLET_PASSWD | tee 0screen.log"
    sleep 2
    $RUNASUSER screen -S simplewallettemp -p 0 -X stuff "O^M"
    sleep 0.8
    $RUNASUSER screen -S simplewallettemp -p 0 -X stuff "$WALLET_NAME^M"
    sleep 0.8
    #for ((i = 1; i <= $WALLET_TIMEOUT; i++)); do echo "" >> 0screen.log ; sleep 60 ; done &
    PASSERROR=$(grep 'check password' 0screen.log)
    if [ -n "$PASSERROR" ] ; then $RUNASUSER screen -S simplewallettemp -p 0 -X stuff "^C" ; print_status "Error: Check password provided to recover wallet file." ; exit 1 ; fi
    inc=1
    while [ "$inc" -le "$WALLET_TIMEOUT" ]; do echo "" >> 0screen.log ; sleep 60 ; done &
    PIDLOOP="$!"
    ADDRESS=$(grep 'Imported' 0screen.log | sed 's/^.*Imported wallet: //')
    ADDRESS2FIND=$(echo $ADDRESS | cut -c1-6)
    echo "$ADDRESS" >> $USER_HOME/croatd/$WALLET_NAME.address.bak

    check_sync=$(timeout ${WALLET_TIMEOUT}m tail --pid=$(($BASHPID+2)) -c +0 -F "0screen.log" | sed -n "/\[wallet $ADDRESS2FIND\]:/{p; q}")
    if [ "$check_sync" == "" ]
    then
        kill "$PIDLOOP"
        print_status "Couldn't recover wallet from File"
        exit 1
    fi
    kill "$PIDLOOP"
    print_status "Recovered wallet from File"
}
wallet_restore_f_key(){
    $RUNASUSER touch $USER_HOME/croatd/$WALLET_NAME.address.bak
    $RUNASUSER screen -dmS simplewallettemp sh -c "./simplewallet --password $WALLET_PASSWD | tee 0screen.log"
    sleep 3
    $RUNASUSER screen -S simplewallettemp -p 0 -X stuff "R^M"
    sleep 2
    $RUNASUSER screen -S simplewallettemp -p 0 -X stuff "$WALLET_NAME^M"
    sleep 2
    $RUNASUSER screen -S simplewallettemp -p 0 -X stuff "$WALLET_RESTORE_FROM_PKEY^M"
    sleep 2
    #for ((i = 1; i <= $WALLET_TIMEOUT; i++)); do echo "" >> 0screen.log ; sleep 60 ; done &
    inc=1
    while [ "$inc" -le "$WALLET_TIMEOUT" ]; do echo "" >> 0screen.log ; sleep 60 ; done &
    PIDLOOP="$!"
    ADDRESS=$(grep 'Imported' 0screen.log | sed 's/^.*Imported wallet: //')
    ADDRESS2FIND=$(echo $ADDRESS | cut -c1-6)
    echo "$ADDRESS" >> $USER_HOME/croatd/$WALLET_NAME.address.bak

    check_sync=$(timeout ${WALLET_TIMEOUT}m tail --pid=$(($BASHPID+2)) -c +0 -F "0screen.log" | sed -n "/\[wallet $ADDRESS2FIND\]:/{p; q}")
    if [ "$check_sync" == "" ]
    then
        kill "$PIDLOOP"
        print_status "Couldn't recover wallet from Private Key"
        exit 1
    fi
    kill "$PIDLOOP"
    print_status "Recovered wallet from Private Key"
}
wallet_config(){
    print_status "Setting up wallet config"
    $RUNASUSER touch $USER_HOME/croatd/config/simplewalletd.conf
    cat << EOF > $USER_HOME/croatd/config/simplewalletd.conf
data-dir=$USER_HOME/.croat
wallet-file=$USER_HOME/croatd/$WALLET_NAME.wallet
password=$WALLET_PASSWD
rpc-bind-ip=127.0.0.1
rpc-bind-port=46349
daemon-port=46348
EOF
}
wallet_service(){
    print_status "Deploying wallet services"
    $RUNASUSER touch $USER_HOME/croatd/scripts/start_simplewalletd.sh
    set_lockfile $USER_HOME/croatd/scripts/start_simplewalletd.sh
    cat << EOF >> $USER_HOME/croatd/scripts/start_simplewalletd.sh
HOMEDIR=$USER_HOME/croatd
cd \$HOMEDIR

screen -dmS simplewallet ./simplewallet --config-file config/simplewalletd.conf
EOF


    $RUNASUSER touch $USER_HOME/croatd/scripts/stop_simplewalletd.sh
    set_lockfile $USER_HOME/croatd/scripts/stop_simplewalletd.sh
    cat << EOF >> $USER_HOME/croatd/scripts/stop_simplewalletd.sh
HOMEDIR=$USER_HOME/croatd
cd \$HOMEDIR

screen -S simplewallet -p 0 -X stuff "^C"

sleep 10
EOF

touch /etc/systemd/system/croatd-wallet.service
cat << EOF > /etc/systemd/system/croatd-wallet.service
[Unit]
Description=SimpleWallet Croat Daemon RPC
After=croatd-node.service

[Service]
User=$USER
Group=$USER

Type=forking
ExecStart=$USER_HOME/croatd/scripts/start_simplewalletd.sh
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=croatd-wallet
ExecStop=$USER_HOME/croatd/scripts/stop_simplewalletd.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    chmod +x $USER_HOME/croatd/scripts/*.sh
    systemctl daemon-reload
    systemctl enable croatd-wallet.service
    systemctl start croatd-wallet.service
    sleep 2
    IS_RUNNING=$(systemctl show -p SubState croatd-wallet.service | sed 's/SubState=//g')
    if [ "$IS_RUNNING" == "running" ]; then
        echo "Simple wallet service running"
    else
        echo "Simple wallet service NOT running, exiting"
        exit 1
    fi
}
install_wallet(){
    wallet_check
    wallet_export
    wallet_config
    wallet_service
}

pool_dependencies(){
    print_status "Installing pool dependencies"
    cd $USER_HOME
    cat << 'EOF' > /etc/apt/sources.list.d/nodesource.list
deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_10.x focal main
deb-src [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_10.x focal main
EOF
    exec_cmd "curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg > /dev/null"

    exec_cmd "add-apt-repository ppa:chris-lea/redis-server -y > /dev/null"

    exec_cmd "apt-get update > /dev/null"
    exec_cmd "apt-get install -y nodejs redis-server > /dev/null"

}
pool_tunning(){
    IS_RUNNING=$(systemctl show -p SubState rc-local | sed 's/SubState=//g')
        if [ "$IS_RUNNING" == "running" ]; then
            echo "Servei rc-local engegat, podem continuar peró haureu de revisar el 'transparent huge page'"
            sleep 5
        else
            echo "Servei rc-local NO engegat, creant el servei i els patches del redis-server"
            cat << 'EOF' > /etc/systemd/system/rc-local.service
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
EOF
    cat << 'EOF' > /etc/rc.local
#!/bin/bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo 1024 > /proc/sys/net/core/somaxconn
systemctl restart redis-server.service
exit 0
EOF
        chmod +x /etc/rc.local
        systemctl enable rc-local
        systemctl start rc-local.service
        fi

    systemctl enable redis-server
    sudo sed -i '/ExecStart=/ a ExecStartPost=/bin/sh -c "echo $MAINPID > /var/run/redis/redis.pid"' /etc/systemd/system/redis.service
    systemctl daemon-reload
    systemctl restart redis-server.service
    pool_restore
    sleep 3
    IS_RUNNING=$(systemctl show -p SubState redis-server.service | sed 's/SubState=//g')
        if [ "$IS_RUNNING" == "running" ]; then
            echo "Servei redis engegat, podem continuar amb el pool"
            echo -e "`date` redis iniciat" >> $INSTALL_LOG
        else
            echo "Servei redis NO engegat, sortint"
            echo -e "`date` redis no iniciat, abortant" >> $INSTALL_LOG
            exit 1
        fi

}
pool_build(){
    exec_cmd "apt-get install -y libssl-dev libboost-all-dev libsodium-dev jq > /dev/null 2>&1"
    cd $USER_HOME
    exec_cmd "$RUNASUSER git clone https://github.com/jowy81/croat-nodejs-pool.git pool > /dev/null 2>&1"
    cd pool
    #sed -i 's/"async": "^3.2.0",/"async": "=1.5.2",/1' package.json
    exec_cmd "$RUNASUSER npm update > /dev/null 2>&1"
}
pool_config(){
    $RUNASUSER cp config_examples/croat.json croat.json
    POOLADDRESS=$(cat ../croatd/$WALLET_NAME.address)

    # comprovar si esta buida, i si es buida aplicar ip 0.0.0.0
    [  -z "$POOLFQDN" ] && POOLHOST="0.0.0.0" || POOLHOST="$POOLFQDN"

    sed -i "s/your.pool.host/$POOLHOST/1" croat.json
    #sed -i 's/http:\/\/blockexplorer.arqma.com\/block\/{id}/http:\/\/explorer.croat.community\/?hash={id}#blockchain_block/1' croat.json
    #sed -i 's/http:\/\/blockexplorer.arqma.com\/tx\/{id}/http:\/\/explorer.croat.community\/?hash={id}#blockchain_transaction/1' croat.json
    #sed -i 's/"cnBlobType": 2,/"cnBlobType": 0,\n"offset": 3,/1' croat.json
    #sed -i 's/"ssl": true/"ssl": false/1' croat.json
    sed -i "s/\*\* Your pool wallet address \*\*/$POOLADDRESS/1" croat.json
    sed -i "s/your_password/$POOLPASSWD/1" croat.json
    #sed -i 's/"addressSeparator": "."/"addressSeparator": "+"/2' croat.json
    jq . croat.json > config.json
    rm croat.json
    chown $USER:$USER config.json

}
pool_service(){
    cat << EOF > /etc/systemd/system/croatd-pool.service
[Unit]
Description=Croat Pool Service
After=network.target croatd-node.service croatd-wallet.service

[Service]
User=$USER
Group=$USER
Type=forking
Restart=always
SyslogIdentifier=croatd-pool
ExecStart=screen -dmS poold sh -c "/usr/bin/node init.js"
WorkingDirectory=$USER_HOME/pool

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable croatd-pool.service
    systemctl start croatd-pool.service
}
pool_restore(){
    if [ -n "$POOLBACKUP" ] ; then
        systemctl stop redis-server.service
        cat $POOLBACKUP > /var/lib/redis/dump.rdb
        systemctl start redis-server.service
    fi
}
pool_frontend(){
    exec_cmd "apt-get install -y nginx > /dev/null 2>&1"
    mv /var/www/html/index.nginx-debian.html /var/www/html/index.nginx-debian.html.orig
    cp -r website_example/* /var/www/html/

    # comprovar quines ips ficar o POOLFQDN
    if [ "$POOLFQDN" = "$POOLHOST" ]; then      #si POOLFQDN = poolHost -> api = POOLFQDN
      API="$POOLFQDN"
    elif [ "$IP_INT" = "$IP_EXT" ]; then        #si ip int = ip ext -> api = ip ext
        API="$IP_EXT"
        POOLHOST="$IP_INT"
     else
        API="$IP_INT"                           #si ip int on lan -> api = ip int
        POOLHOST="$IP_INT"
    fi

    cat << EOF > /var/www/html/config.js
var parentCoin = "croat";

var api = "http://$API:8117";
var poolHost = "$POOLHOST";

var email = "$POOLEMAIL";
var telegram = "$POOLTELEGRAM";
var discord = "$POOLDISCORD";

var marketCurrencies = ["{symbol}-BTC", "{symbol}-USD", "{symbol}-EUR"];

var blockchainExplorer = "http://explorer.croat.community/?hash={id}";
var transactionExplorer = "http://explorer.croat.community/?hash={id}";

var themeCss = "themes/default.css";
var defaultLang = "ca";
EOF

}
install_pool(){
    pool_dependencies
    pool_tunning
    pool_build
    pool_config
    pool_service
    pool_frontend
}

ops_logrotate(){
    $RUNASUSER mkdir -p $USER_HOME/utils/rotate
    $RUNASUSER touch $USER_HOME/utils/rotate/logrotate.conf
    cat << EOF >> $USER_HOME/utils/rotate/logrotate.conf
$USER_HOME/croatd/logs/*.log {
    daily
    rotate 7
    missingok
    compress
    create
}

$USER_HOME/pool/logs/*.log {
    daily
    rotate 7
    missingok
    compress
    create
}
EOF
    $RUNASUSER crontab -l > crontmp
    $RUNASUSER echo "0 23 * * * /usr/sbin/logrotate $USER_HOME/utils/rotate/logrotate.conf --state $USER_HOME/utils/rotate/logrotate-state" >> crontmp
    $RUNASUSER crontab crontmp
    $RUNASUSER rm -y crontmp
}
ops_bk_redis(){
    exec_cmd "apt-get install -y rdiff-backup > /dev/null 2>&1"
    $RUNASUSER mkdir -p $USER_HOME/utils/backups/redis
    #write out current crontab
    $RUNASUSER crontab -l > crontmp
    #echo new cron into cron file
    $RUNASUSER echo "0 */4 * * * rdiff-backup --preserve-numerical-ids --no-file-statistics /var/lib/redis $USER_HOME/utils/backups/redis" >> crontmp
    #install new cron file
    $RUNASUSER crontab crontmp
    $RUNASUSER rm -y crontmp
}
ops_fail2ban(){
    echo "TODO list"
}
ops_ufw(){
    echo "TODO list"
}
install_ops(){
    if [[  "$SETUP_LOGROTATE" = "yes"  ]] ; then ops_logrotate ; fi
    if [[  "$SETUP_REDIS_BACKUP" = "yes"  ]] ; then ops_bk_redis ; fi
    if [[  "$SETUP_FAIL2BAN" = "yes"  ]] ; then ops_fail2ban ; fi
    if [[  "$SETUP_UFW" = "yes"  ]] ; then ops_ufw ; fi
}


#INIT
load_colors
script_initializing
check_usersudo
install_dependencies
get_vars
check_installs


exit 0

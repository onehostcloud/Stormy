#!/bin/bash
# -*- Mode: sh; coding: utf-8; indent-tabs-mode: nil; tab-width: 4 -*-
# 
# =========================================================================== #
# Stormy, the easy onion service creator
# by Griffin Boyce <griffin@torproject.org>, with review from various dags
# 
# https://github.com/glamrock/Stormy
# 
# Usage: 
#   run script as root to install a service and set it as an onion service
# =========================================================================== #

# CHECK IF ROOT

function root {
    if [[ "$(whoami)" != root ]]; then
        echo "This install script should be run as root. (aka administrator)"
        exit;
    else
        keyfob
    fi
}

#----- VARIOUS ITEMS -----#
version=$(lsb_release -cs)
dist=$(lsb_release -is)


#----- ADD DEVELOPER KEYS -----#

function keyfob {
    gpg --keyserver keys.mayfirst.org --recv-keys 136221EE520DDFAF0A905689B9316A7BC7917B12 #node

# Tor build keys
    gpg --keyserver keys.mayfirst.org --recv-keys 74A941BA219EC810 A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89

# Other Tor development keys
    gpg --keyserver keys.mayfirst.org --recv-keys 4A90646C0BAED9D456AB3111E5B81856D0220E4B 35CD74C24A9B15A19E1A81A194373AA94B7C3223 8C4CD511095E982EB0EFBFA21E8BF34923291265 AD1AB35C674DF572FBCE8B0A6BC758CBC11F6276 0D24B36AA9A2A651787876451202821CBE2CD9C1 25FC1614B8F87B52FF2F99B962AF4031C82E0039 261C5FBE77285F88FB0C343266C8C2D7C5AA446D C963C21D63564E2B10BB335B29846B3C683686CC 68278CC5DD2D1E85C4E45AD90445B7AB9ABBEEC6 0291ECCBE42B22068E685545627DEE286B4D6475 02959AA7190AB9E9027E07363B9D093F31B0974B C2E34CFC13C62BD92C7579B56B8AAEB1F1F5C9B5 8738A680B84B3031A630F2DB416F061063FEE659 B35BF85BF19489D04E28C33C21194EBB165733EA F65CE37F04BA5B360AE6EE17C218525819F78451 B1172656DFF983C3042BC699EB5A896A28988BF5 879BDA5BF6B27B6127450A2503CF4A0AB3C79A63

# Update
    apt-get update -y -qq

addsource
}

#----- ADD SOFTWARE SOURCES -----#

function addsource {
# Adds sources for various dependencies
    echo 'Adding software sources'
    cp /etc/apt/sources.list /etc/apt/sources.list.original #backup original sources file

# Detect if Ubuntu or Debian
    if [[ $dist == "Ubuntu" ]]||[[ $dist == "Debian" ]]; then

    echo "deb  http://deb.torproject.org/torproject.org $version main"| tee -a /etc/apt/sources.list
# Detect Wat
    else
        echo 'Sorry, this script is just for Ubuntu or Debian systems!'
        echo 'Using another OS? Send a request to griffin@torproject.org'
        echo 'https://github.com/glamrock/stormy'
        exit
    fi

# Update after the new sources
        apt-get update -y -qq
        apt-get install deb.torproject.org-keyring #better safe than sorry
        apt-get update -y -qq
        echo 'Done.'

    wizard #fly off to the wizard function
}

#----- INSTALL Wizard / MENU -----#
function wizard {
INPUT=0
    echo ''
    echo 'MAIN MENU'
    echo 'What would you like to do? (Enter the number of your choice)'
    echo ''
    echo '1. Install hidden service dependencies' # webserver + tor
    echo '2. Set up a Ghost-based hidden service (blog)'
    echo '3. Create a personal cloud server (for files, calendar, tasks)'
    echo '4. Install a Jabber server'
    echo '5. Install a IRC server'
    echo '7. View more instructions'
    echo 'X. Exit without installing anything'
    echo ''
read INPUT

## set hstype=$(whatever) depending on which selected
## ask for hsnick at some point, and set it ("Set a nickname for this hidden service? [Y/n]")

    if [ "$INPUT" -eq 1 ]; then
        hstype=$(seance)
        seance

    elif [ "$INPUT" -eq 2 ]; then
        hstype=$(ghost)
        ghost

    elif [ "$INPUT" -eq 3 ]; then
        hstype=$(cozy)
        cloud

    elif [ "$INPUT" -eq 4 ]; then
        hstype=$(jabber)
        jabber

    elif [ "$INPUT" -eq 5 ]; then
        hstype=$(irc)
        irc

    elif [ "$INPUT" -eq 7 ]; then
        man

    elif [ "$INPUT" = X ]||[ "$INPUT" = x ]; then
        clear && end #goes to end function

    else
        clear
        echo 'Wrong option. Try again.'
        exit
    fi 
}



#----- Install Ghost and related dependencies -----#

function ghost {
    echo 'Installing dependencies...'
    apt-get build-dep python-defaults -y -qq
    apt-get update -y -qq
    apt-get install iptables python python-dev python-software-properties -y -qq
    apt-get install tor -y -qq

# NODE
    apt-get install g++ make nodejs -y -qq
    apt-get update -y -qq
    apt-get install npm -y -qq
    npm install forever -g --silent
    npm install ghost -g --silent
    npm config set loglevel warn # sets the log to only log warnings and above - good to reduce unnecessary noise


# Double-check for broken deps before finishing up
    echo 'Checking integrity...'
    apt-get check -y -qq

# Debian users are less nervous than Ubuntu users, but still.
    echo 'Dependencies installed!'

# Get and install Ghost from source

    echo 'Installing your blog'
    cd /var/www
    wget https://ghost.org/zip/ghost-latest.zip --quiet --server-response --timestamping --ignore-length
    unzip -d ghost ghost-latest.zip
    rm ghost-latest.zip
    cd ghost
    npm install --production #this installs Ghost

# Install nginx
    apt-get install nginx -y -qq 

# Start Ghost and set Forever
    cd /var/www/ghost
    NODE_ENV=production forever --minUptime=100ms --spinSleepTime=3000ms start index.js -e error.log

    echo 'Configuring your blog'
 if [[ $dist == "Ubuntu" ]]; then
    touch /etc/init/ghost.conf
    bash -c 'cat << EOF > /etc/init/ghost.conf
start on startup
stop on shutdown

exec forever --sourceDir=/var/www/ghost -p ~/.forever --minUptime=100ms --spinSleepTime=3000ms start index.js -e error.log
    EOF'

 else #For Debian and non-Debian derivatives, manual labor is required

# Init.d file to auto-start forever+ghost
  bash -c 'cat << EOF > /etc/init.d/forever
    #!/bin/sh

    export PATH=$PATH:/usr/local/bin
    export NODE_PATH=$NODE_PATH:/usr/local/lib/node_modules
    export SERVER_PORT=80
    export SERVER_IFACE=127.0.0.1

    case "$1" in
      start)
      exec forever --sourceDir=/var/www/ghost -p ~/.forever --minUptime=100ms --spinSleepTime=3000ms start index.js -e error.log
      ;;

      stop)
      exec forever stop --sourceDir=/var/www/ghost index.js
      ;;
    esac

    exit 0
EOF'
fi
    chmod +x /etc/init.d/forever
    ln -s /etc/init.d/forever /etc/rc.d/
    update-rc.d forever defaults #forever+ghost will now rise on boot

#backup content on a regular basis

  mkdir /var/lib/tor/backups

  bash -c 'cat << EOF > /etc/cron.monthly/ghost-backup
#!/bin/sh

for file in /var/www/ghost/content/data/*.db;
	do cp "$file" /var/lib/tor/backups/"${file}-ghost-`date +%Y-%m`";
done

EOF'

#check for updates, and if they exist, execute them

bash -c 'cat <<EOF> /etc/cron.daily/ghost
#!bin/sh

cd /var/www/ghost

wget https://ghost.org/zip/ghost-latest.zip --timestamping --ignore-length --quiet
unzip -d ghost-update ghost-latest.zip

service ghost stop #stop ghost before updating

cp ghost-update/*.md ghost-update/*.js ghost-update/*.json ..
rm -R core
cp -R ghost-update/core ..
cp -R ghost-update/content/themes/caspar content/themes
chown -R ghost:ghost /var/www/ghost

npm install --production

rm -R ghost-update

service ghost start #starts ghost again

EOF'

seance

}

function seance {

    echo 'Configuring your Tor Hidden Service'

# overwrite the existing torrc, but check if it contains an existing hs first

if ! grep -qw "#HiddenServiceDir /var/lib/tor/hidden_service" /etc/tor/torrc; then
    echo "You are about to replace an existing tor configuration file."
    echo 'Continue? (Y)es  /  (N)o' 
    read -p '' REPLY

  if [ "$REPLY" == "y" ]||[ "$REPLY" == "Y" ]; then
    cp /etc/tor/torrc /etc/tor/torrc.original
    >| /etc/tor/torrc #truncate the torrc

  bash -c 'cat << EOF > /etc/tor/torrc

#Log notice file /var/log/tor/notices.log
RunAsDaemon 1 # Will run tor in the background

HiddenServiceDir /var/lib/tor/ghost/
HiddenServicePort 80 127.0.0.1:2368
HiddenServicePort 2368 127.0.0.1:2368 #default ghost port

EOF'


  else #no - cancels hs setup
      echo "Stormy will now cancel hidden service setup. However, your blog is still installed."
            echo 'Delete blog? (Y)es  /  (N)o' 
            read -p '' SEANCE
          if [ "$SEANCE" == "y" ]||[ "$SEANCE" == "Y" ]; then
            rm -rf '/var/www/ghost'
            apt-get purge nodejs npm tor
            apt-get autoclean -y -qq
            apt-get autoremove -y -qq
            apt-get update -y -qq
            apt-get -f install -y -qq
            rm /etc/init.d/forever
            clear && echo "Goodbye."
            exit
          else
            clear && echo "Goodbye."
            exit
        fi
  fi
else 
    >| /etc/tor/torrc #empty the current torrc

  bash -c 'cat << EOF > /etc/tor/torrc

#Log notice file /var/log/tor/notices.log
RunAsDaemon 1 # Will run tor in the background

HiddenServiceDir /var/lib/tor/"$hstype"/
HiddenServicePort 80 127.0.0.1:80
HiddenServicePort 2368 127.0.0.1:2368 #default ghost port

EOF'

fi

    chown -hR debian-tor /var/lib/tor #set ownership for this folder and all subfolders to user debian-tor
    chmod 0700 /var/lib/tor/"$hstype"

    sed -i '/RUN_DAEMON="no"/c\RUN_DAEMON="yes"' ./etc/default/tor #allow to start on boot, even if it was previously set to no
    update-rc.d tor defaults
    echo 'Your hidden service will start on boot.'

hostname=$(cat /var/lib/tor/"$hstype"/hostname) #assign $hostname for address display later

popcon #disable popularity contest
}

#----- XMPP Server -----#

function jabber {

    echo "Use the default Jabber configuration file? [Y/n]"
      read -p '' JAB
      if [ "$JAB" == "y" ]||[ "$JAB" == "Y" ]; then
      # edit nginx and ejabberd conf files

        true 

        echo "Would you like to install a web-based chat client for your IRC service? [y/N]"
          read -p '' STAC
          if [ "$STAC" == "y" ]||[ "$STAC" == "Y" ]; then

            hstype=$(jab)

          else
            popcon 
        fi      #end of chat-client setup

      fi    # end of jabber configuration 
}


#----- IRC chat -----#

function irc {

    echo "Would you like to install a web-based chat client for your IRC service?"
      read -p '' IRC
      if [ "$IRC" == "Y" ]||[ "$IRC" == "y" ]; then
        hstype=$(IRC)

      else true 
      
      fi

}



#----- DISABLE POPULARITY -----#

function popcon {

# Long live the king
# Note: in Ubuntu, while it is a dep of ubuntu metapackages, removing both might
# not destroy the system. It is also toggled off by default: PARTICIPATE="no"
# http://ubuntuforums.org/showthread.php?t=1654103 gives me pause.

    if [ "$(dpkg-query -l | grep -c popularity-contest)" -ne 0 ];
    then     
        if [[ "$(lsb_release -is)" == "Debian" ]];then
          apt-get purge popularity-contest -y -qq #not a dependency for Debian
          cleanup
        elif [[ "$(lsb_release -is)" == "Ubuntu" ]];then
          sed -i '/PARTICIPATE/c\PARTICIPATE="no"' ./etc/popularity-contest.conf
          chmod -x /etc/cron.daily/popularity-contest #I need more info here
          cleanup
        fi
    else
        cleanup
    fi

cleanup
}

#----- Cleanup -----#
function cleanup {
    clear
    echo ''
    echo 'Finishing up!'
    echo ''

    # Check for broken packages
    echo 'Checking software integrity'
    apt-get -f install -y -qq

    # Remove leftover files
    echo 'Removing leftover packages...'
    apt-get autoremove -y -qq
    echo 'Cleaning up temporary cache...'
    apt-get clean -y -qq
    echo 'Done!'
    sleep 5
    clear

    echo "Please take a moment to write down your hidden service address."
    echo ""
    echo "Your onion address is":  "$hostname"
    echo ""
    echo "To access your blog dashboard, go to $hostname/ghost"
    echo ""
    echo "To easily download a copy of your posts, go to $hostname/debug"
    echo ""
    echo "Your hidden service's private key is located in /var/lib/tor/ghost"
    sleep 10


log #kick to logoff/reboot function
}

#----- Logout Dialogue -----#

function log {
    echo 'Please reboot if possible. Your hidden service will start automatically.'
    echo "(O)kay! / (I) can't yet."
    read -p "" REPLY 
    echo ""

if [ "$REPLY" = "o" ]||[ "$REPLY" = "O" ]; then
    shutdown -r +1 "Rebooting!"

else
    echo 'Please reboot your system when possible.'
    echo 'Remember, your hidden services will start automatically whenever the system starts.'
    exit
fi
}

#----- Man Page -----#

function man {
    echo 'You have exited the wizard.'
    man stormy
}

#----- Exit Dialogue -----#

function end {
    echo ''
    read -p "Are you sure you want to quit? (Y)es/(n)o     " REPLY
    if [ "$REPLY" = "n" ]; then
        clear && wizard
    else
        clear && exit
    fi

}

root #start at the beginning

## END OF TRANSMISSION ##

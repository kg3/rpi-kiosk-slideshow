#!/bin/bash
# Install the Rpi Kiosk
# created by Kurt Gibbons III for the purposes of helping out friends with small business
# that always ask me for something like this.
#
# Instead of reinventing the wheel; it uses the premade GUI environment provided by Raspbian.
# Utilizing premade Chromium-browser with a customized html page to display images.
# Get images on and off the pi through drive-google. Scheduling handled by crontab.
# Installed via systemd for total control.

###################################
#   colors and codes              #
###################################
BLK='\033[0;30m'	# black
RED='\033[0;31m'	# red
GRN='\033[0;32m'	# green
ORG='\033[0;33m'	# brown/orange
BLU='\033[0;34m'	# blue
PRP='\033[0;35m'	# purple
CYN='\033[0;36m'	# cyan
LGY='\033[0;37m'	# light gray
DGY='\033[1;30m'	# dark gray
LRD='\033[1;30m'	# light red
LGN='\033[1;32m'	# light green
YEL='\033[1;33m'	# yellow
LBE='\033[1;34m'	# light blue
LPR='\033[1;35m'	# light purple
LCY='\033[1;36m'	# light cyan
WHT='\033[1;37m'	# white
NC='\033[0m' 		# No Color
OPTERR=85           # unix standard invalid options exit code
messageColor=$WHT   # color of basic message output
errorColor=$RED     # color of error messages
DEBUG=''            # run script in debug mode
version=1.0
baseurl=https://raw.githubusercontent.com/kg3/rpi-kiosk-slideshow/master/

###################################
#   common functions              #
###################################

file_exists () {
    # $1: file or directory name with path
    # $2: directory or file ('f' or 'd')
    # by default we exit on nonexistent files/dirs

    if [[ "$2" == "f" ]]; then
        if [ ! -f "$1" ]; then
            message "Error file: $1 does not exist!" 1 1
        else
            return 1
        fi
    elif [[ "$2" == "d" ]]; then
        if [ ! -d "$1" ]; then
            message "Error directory: $1 is not a directory" 1 1
        else
            return 1
        fi
    else
        message "Programming Error; file_exits" 1 1
    fi
}

message () {
    # $1 = 'message'
    # $2 = error; true(1) or false(0)
    # $3 = exit code ( -1 don't exit )

    [ -z "$2" ] && echo -e $errorCkolor"[!] Programming error; message \$2: $2" && exit 1
    [ -z "$3" ] && echo -e $errorColor"[!] Programming error; message \$3: $3" && exit 1

    if [ "$2" -eq 1 ]; then
        # this is an error message
        echo -e $messageColor"\n[$errorColor!$messageColor] $1${NC}\n"
    elif [ "$2" -eq 0 ]; then
        # this is general ouput message
        echo -e $messageColor"[$GRN+$messageColor] $1${NC}"
    fi

    if [ "$3" -ge 0 ]; then
        exit $3
    fi
}

which_platform () {
    # $1: exit sig for bad platforms
    # manually set for good platform
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        message "Good OS: -$OSTYPE- assuming a Raspbian" 0 -1
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        message "Install at your own demise - Mac OS" 1 $1
    elif [[ "$OSTYPE" == "cygwin" ]]; then
        message "Install at your own demise - POSIX compatibale Cygwin, Windows" 1 $1
    elif [[ "$OSTYPE" == "msys" ]]; then
        message "Install at your own demise - MinGW on Windows" 1 $1
    elif [[ "$OSTYPE" == "freebsd"* ]]; then
        message "Install at your own demise - FreeBSD" 1 $1
    else
        message "Install at your own demise - Unknown!" 1 $1
    fi
}

list_array () {
    # $1: name of the array
    name=$1[@]
    a=("${!name}")

    for i in "${a[@]}"; do
        message "$PRP$1$WHT:$BLU $i" 0 -1
    done
}

read_whole_line () {
    # $1: filename
    while IFS='' read -r line || [[ -n "$line" ]]; do
        echo "Whole text line from $1: $line"
    done < "$1"
}

usage () {
    # $1: exit code
    name=$(basename $0)
    plus="$messageColor[$GRN+$messageColor]"
    echo -e $GRN"\tRaspberry Pi Slideshow Kiosk v${version}"
    echo -e $LBE"This slideshow kiosk will remove unecessary installs and make the system lighter"
    echo -e $LBE"in order to keep updates fast, harden a bit. Keeping a clean system only to display"
    echo -e $LBE"a slideshow (a.k.a digital signage)"
    echo -e $messageColor
    echo -e "$plus Options:"
    echo -e "\t-h this help menu"
    echo -e "\t-i Install the raspberrypi slideshow kiosk or reinstall (will overwrite current setup)"
    echo -e "$plus usage example: "
    echo -e "\t$name -i "
    echo -e "\n$plus Made Possible by -"
    echo -e "\t ${LPR}jquery-backstretch${messageColor} -- https://github.com/jquery-backstretch/jquery-backstretch"
    echo -e "\t ${LPR}drive-google${messageColor} -- https://github.com/odeke-em/drive"
    echo -e "\t ${LPR}Imagemagick${messageColor} -- https://www.imagemagick.org/Usage/"
    echo -e "\t ${LPR}Raspbian${messageColor} -- https://raspbian.org/"
    echo -e "$NC"
    exit $1
}

###################################
#    custom functions             #
#                                 #
###################################

array=( "cannot use spaces with =" "or the array won't initialize" "use strong quotes in arrays" )
readconfig () {
    # rosettacode method
    # redirect stdin to read from the given filename
    exec 0<"$1"

    # declare -l varname # only works on bash >4.0
    varname=()
    while IFS=$' =\t' read -ra words; do
        # is it a comment or blank line?
        if [[ ${#words[@]} -eq 0 || ${words[0]} == ["#;"]* ]]; then
            continue
        fi

        # get the variable name
        varname=${words[0]}

        # split all the other words by comma
        value="${words[*]:1}"
        oldIFS=$IFS IFS=,
        values=( $value )
        IFS=$oldIFS

        # assign the other words to a "scalar" variable or array
        case ${#values[@]} in
            0) printf '%s=true\n' "$varname" ;;
            1) printf '%s=%q\n' "$varname" "${values[0]}" ;;
            *) n=0
               for value in "${values[@]}"; do
                   value=${value# }
                   printf '%s[%d]=%q\n' "$varname" $((n++)) "${value% }"
               done
               ;;
        esac
    done
}

curlO () {
    # $1=file to downlaod
    # $2=location to download
    pushd $2
    curl -LO $baseurl/$1
    popd
}

md5Compare () {
    # if hashes don't match redownload
    jqueryJS=f1b490326bc48e1e22ba7f3da0595162
    jqueryBS=9745bbee276dd7d0e41148929bbee4fa
    startsSH=99322da2af154f324f8d645d36cdf2da
    slidekSV=89e73fdc6bf81c6fc4f8d307ed8e7eab

    [ ! "$(md5sum ~/slideshow/jquery.js | cut -d' ' -f1)" == "$jqueryJS" ] && message "~/slideshow/jquery.js md5sum didn't match, redownloading" 1 -1 && curlO slideshow/jquery.js ~/slideshow
    [ ! "$(md5sum ~/slideshow/jquery.backstretch.js | cut -d' ' -f1)" == "$jqueryBS" ] && message "~/slideshow/jquery.backstretch.js md5sum didn't match, redownloading" 1 -1 && curlO slideshow/jquery.backstretch.js ~/slideshow
    [ ! "$(md5sum ~/start-slideshow-kiosk.sh | cut -d' ' -f1)" == "$startsSH" ] && message "~/start-slideshow-kiosk.sh md5sum didn't match, redownloading" 1 -1 && curlO start-slideshow-kiosk.sh ~
    [ ! "$(md5sum ~/slideshow-kiosk.service | cut -d' ' -f1)" == "$slidekSV" ] && message "~/slideshow-kiosk.service md5sum didn't match, redownloading" 1 -1 && curlO slideshow-kiosk.service ~
}

install_check () {
    # plants a file notify_pi_needs_attention to prevent kiosk from starting and keep track of install
    # todo: if there is a botched install or broken system then try and auto repair with: start-slideshow-kiosk.sh -r
    # todo: come back on the first run in the system and finish the rest of what's necessary
    if [  -f "~/notify_pi_needs_attention" ]; then
        if [ "$(grep install ~/notify_pi_needs_attention)" == "" ]; then
            message "Fixing a broken install" 1 -1
            echo "install" > ~/notify_pi_needs_attention
        else
            message "an install has already or is already taking place. Continuing with this install..." 1 -1
            rm ~/notify_pi_needs_attention && echo "install" > ~/notify_pi_needs_attention
        fi
    else
        message "Starting a brand new installation" 0 -1
        echo "install" > ~/notify_pi_needs_attention
    fi
}

install () {
    # fresh or reinstall,
    # check platform
    which_platform 1
    install_check

    installFiles=( start-slideshow-kiosk.sh slideshow-kiosk.service )
    # ~/slideshow/slideshow.html is generated after drive is connected and directory chosen
    slideshowInstallFiles=( ~/slideshow/jquery.backstretch.js ~/slideshow/jquery.js )
    newwallpaper=~/wallpaper.jpg
    lxdeConfig=~/.config/pcmanfm/LXDE-pi/desktop-items-0.conf
    dependencies=( git golang-go ufw imagemagick xdotool )
    unneeded=( "timidity" "zenity*" "triggerhappy" "samba*" "galculator" "cups-*" "minecraft-pi*" "*libreoffice*" "squeak*" "scratch*" "wolfram*" "*bluej*" "*geany*" "*greenfoot*" "*nodered*" "*sense*" "*sonic*" "*thonny*" "*claws-mail*" )
    dumbRaspbianFolders=( '~/Documents/' '~/Music/' '~/Pictures/' '~/Public/' '~/python_games/' '~/Templates/' '~/Videos/' '~/Downloads/' )

    # check that necessary files and folder exist
    message "checking for Install files:" 0 -1
    list_array installFiles

    for i in "${installFiles[@]}"; do
        file_exists $i f
    done

    file_exists slideshow d
    for i in "${slideshowInstallFiles[@]}"; do
        file_exists $i f
    done

    # md5sum them to make sure they're clean
    md5Compare

    message "copying install files" 0 -1
    cp start-slideshow-kiosk.sh ~/
    cp -r slideshow ~/

    message "updating package repo" 0 -1
    sudo apt update

    # Install Dependencies
    message "installing dependencies:" 0 -1
    list_array dependencies

    for i in "${dependencies[@]}"; do
        # if it's already installed don't try to install it
        [ "$(dpkg -l $i | grep $i | cut -d' ' -f1)" != "ii" ] && message "installing: $i" 0 -1 && sudo apt install -y $i
    done
    # yes -- golang-go first then the other go package
    [ "$(dpkg -l gccgo-go | grep gccgo-go | cut -d' ' -f1)" != "ii" ] && sudo apt install -y gccgo-go

    message "installing drive-google" 0 -1
    # $GOPATH
    if [ "$(grep '/usr/local/go/bin/' ~/.bash_profile)" == "" ]; then
        message "adding gopath env" 0 -1
        echo -e "\n#slideshow kiosk\nexport PATH=$PATH:/usr/local/go/bin" >> ~/.bash_profile
        source ~/.bash_profile
    else
        echo -e "\n#slideshow kiosk\nexport PATH=$PATH:/usr/local/go/bin" >> ~/.bash_profile
        source ~/.bash_profile
    fi

    go get -u github.com/odeke-em/drive/drive-google

    message "doing a full upgrade" 0 -1
    sudo apt full-upgrade -y

    # Remove Bloatness
    message "removing most unnecessary installs" 0 -1
    sudo apt remove -y "${unneeded[@]}"
    sudo apt-get autoremove -y

    # System Configurations
    message "altering system configurations" 0 -1
    ## disable bluetooth
    bt_disable="dtoverlay=pi3-disable-bt"
    [ "$(grep $bt_disable /boot/config.txt)" == "" ] && message "disabling bluetooth" 0 -1 && sudo echo -e "\n# slideshow-kiosk\n$bt_disable" >> /boot/config.txt
    ## remove screensaver from user autostart
    sed -i '/xscreensaver/d' ~/.config/lxsession/LXDE-pi/autostart
    ## remove trash icon from desktop
    sed -i 's/show_trash=1/show_trash=0/g' $lxdeConfig
    ## Change background image
    sed -i "s/wallpaper[=].*/wallpaper=$newwallpaper/g" $lxdeConfig
    ## remove stupid folders
    for i in "${dumbRaspbianFolders[@]}"; do
        [ -d "$i" ] && message "deleting $i " 0 -1 && rm -rf $i
    done


    # Install the service
    # https://www.raspberrypi.org/documentation/linux/usage/systemd.md
    # https://docs.fedoraproject.org/en-US/quick-docs/understanding-and-administering-systemd/index.html
    message "installing Slideshow Kiosk as systemd service and enabling on startup" 0 -1
    sudo cp slideshow-kiosk.service /etc/systemd/system/slideshow-kiosk.service
    sudo systemctl enable slideshow-kiosk.service

    # timezone sync

    # reboot the system

    message "after rebooting the script will continue to install the rest of the system" 0 -1

    sleep 10
    sudo reboot


    # Connect drive
#     message "Connecting Google Drive: https://github.com/odeke-em/drive" 1 -1
#     message "prompts for a URL - have to copy and paste and then repaste the number given into the app" 1 -1
#     drive init ~/gdrive
# 	cd ~/gdrive

}

installGo () {
    # https://golang.org/doc/install
    echo
}

wifiSetup () {
    # https://www.raspberrypi.org/documentation/configuration/wireless/wireless-cli.md
    echo
}

configureXAuthority () {
    # https://raspberrypi.stackexchange.com/questions/1719/x11-connection-rejected-because-of-wrong-authentication
    echo
}

update () {
    # https://stackoverflow.com/questions/25482326/how-to-update-a-bash-script-with-the-old-version-of-this-script
    pushd /tmp
    # curl script location
    # md5 both files Or grep for version number
    # if md5 of curled is different - download update that

}

###################################
#    parse arguments              #
#                                 #
###################################

# show usage and exit on no parameters
[ ! "$#" -ge 1 ] && message "No parameters passed" 1 -1 && usage

while getopts ":Dhia:" o; do
    case "$o" in
        a)
            String="$OPTARG"
            message "-a equals: $OPTARG" 1 1
            ;;
        i)
            Install=1
            ;;
        u)
            update
            ;;
        h)
            usage 0
            ;;
        D)
            DEBUG=1
            ;;
        \?)
            message "Invalid option: -$OPTARG" 1 -1
            usage $OPTERR
            ;;
        :)
            message "Option: '-$OPTARG' needs an argument" 1 -1
            usage $OPTERR
            ;;
    esac
done




###################################
#      main                       #
#                                 #
###################################

if [ $DEBUG ]; then
    message "$PRP Debug $YEL Mode $LGN! " 1 -1
    echo
    list_array array

    # parse the config file and evaluate the output in the current shell
    source <( readconfig config.file )

    echo "fullname = $fullname"
    echo "favouritefruit = $favouritefruit"
    echo "needspeeling = $needspeeling"
    echo "seedsremoved = $seedsremoved"
    for i in "${!otherfamily[@]}"; do
        echo "otherfamily[$i] = ${otherfamily[i]}"
    done

else
    # exit if an optarg is not set
    [ ! -z "$Install" ] && message "Installing: Raspberry Pi Slideshow Kiosk ${LPR}v${version}${NC}" 0 -1 && install

fi


exit 0

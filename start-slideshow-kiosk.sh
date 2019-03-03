#!/bin/sh
# Controller for Raspberry Pi Slideshow Kiosk
# start / restart from systemd
# run cronjobs for drive-google from crontab
# the idea is to be successfully autonimous without any huan interaction
# display env variable, DISPLAY=:0, is passed from: /etc/systemd/system/slideshow-kiosk.service
# export DISPLAY=":0"

###################################
#    controller functions         #
#                                 #
###################################

slideshow=~/slideshow/slideshow.html

start () {
  cleanChromium
  keepOn
  chromium-browser --kiosk --incognito $slideshow
}

restart () {
  # something bad has happened try to give it a rest; kill all chromiums, clean, restart
  killall -9 chromium-browser
  sleep 5
  cleanChromium
  # never saw deleting the Singleton files change the notification but some setups have according the internets
  rm -rf ~/.config/chromium/Singleton*
  keepOn
  chromium-browser --kiosk --incognito $slideshow
}

cronjob () {
  # refresh chromium as if there's a user, because images are replaced and/or slideshow updated
  # refresh webpage https://www.raspberrypi.org/forums/viewtopic.php?p=403805
  WID=$(xdotool search --onlyvisible --class chromium | head -1)
  xdotool windowactivate ${WID}
  xdotool key ctrl+F5
}

cleanChromium () {
  # fixes the notification but incognito usually doesn't have it
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/Default/Preferences
  sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' ~/.config/chromium/Default/Preferences
}

keepOn () {
  # disable display going to sleep
  xset -dpms
  xset s off
}

webpageRefresh () {
  # https://www.raspberrypi.org/forums/viewtopic.php?p=403805
  echo
  WID=$(xdotool search --onlyvisible --class chromium|head -1)
  xdotool windowactivate ${WID}
  xdotool key ctrl+F5
}

###################################
#    parse arguments              #
#                                 #
###################################


# show usage and exit on no parameters
[ ! "$#" -ge 1 ] && message "No parameters passed" 1 -1 && echo "$(basename 0) not given any paramters when called!"

while getopts ":src:" o; do
    case "$o" in
        s)
            start
            ;;
        r)
            restart
            ;;
        c)
            cronjob
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

exit 0
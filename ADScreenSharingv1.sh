#!/bin/sh
# set access permissions for the AD network groups passed in $4 to $11 
# 
# The initial idea was to accept one group name (in $4) and call the same script several times. 
# But Jamf does not allow this. In 9.101 it calls the script twice, but both times with 
# the argument passed in the first case listed :(
#
# check if Mac is bound to domain

# global settings

# enable sshd ("remote login")
echo "Enabling 'Remote Login'"
systemsetup -f -setremotelogin on

# enable screen sharing
echo "Enabling 'Screen Sharing'"
defaults write /var/db/launchd.db/com.apple.launchd/overrides.plist com.apple.screensharing -dict Disabled -bool false
launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist

i=4
# treat all arguments from $4 on...
for userGroup in "${@:4}"; do

    # make sure we have a value
    if [ "$userGroup" != "" ]; then
        echo "handling parameter $i,  $userGroup"
        for accessGroup in "com.apple.loginwindow.netaccounts" "com.apple.access_ssh" "com.apple.access_screensharing" "admin"; do
            echo "Adding group $userGroup to $accessGroup"
            # check whether group exists, if not create it
            /usr/bin/dscl . -read /Groups/${accessGroup} > /dev/null 2>&1 || /usr/sbin/dseditgroup -o create -q ${accessGroup}
            /usr/sbin/dseditgroup -o edit -a ${userGroup} -t group ${accessGroup}
        done

        # And now we still have to add this
        userGroup="com.apple.loginwindow.netaccounts"
        accessGroup="com.apple.access_loginwindow"
        echo "Adding group $userGroup to $accessGroup"
        # would be surprising if it did not exist, but...
        /usr/bin/dscl . -read /Groups/${accessGroup} > /dev/null 2>&1 || /usr/sbin/dseditgroup -o create -q ${accessGroup}
        /usr/sbin/dseditgroup -o edit -n /Local/Default -a ${userGroup} -t group ${accessGroup}
    fi
    i=$(($i+1))
done
exit

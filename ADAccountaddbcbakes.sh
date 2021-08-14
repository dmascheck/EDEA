#!/bin/sh

adminUser="ec2-user"
adminPass="Gambit1227!"
DATE=`9-14-2021`


echo "Running cache AD User  Account"



ADuser=$(osascript -e 'set T to text returned of (display dialog "Enter AD User Name:" buttons {"Cancel", "OK"} default button "OK" default answer "")')

#Prompts User for Password
#-----------------------------------#
read -r -d '' applescriptCode <<'EOF'
    set dialogText to text returned of (display dialog "Enter your Current AD password to continue" default answer "" with icon stop buttons {"OK"} default button 1 with hidden answer)
    return dialogText
EOF

ADuserPWD=$(osascript -e "$applescriptCode");

echo "$ADuser"


#Do not use verbose mode as it shows users password in log
/System/Library/CoreServices/ManagedClient.app/Contents/Resources/createmobileaccount  -D  -n $ADuser -p $ADuserPWD 


## this should query AD to cache the user including the password
dscacheutil -q user -a name "$ADuser"


#Lets Set an encrypted on date as a back up to cache account

sudo -H -u $ADuser  touch /Users/$ADuser/Documents/image.txt
sudo -H -u $ADuser  echo "This Mac was Filevaulted on $DATE" > /Users/$ADuser/Documents/image.txt


# create the plist file:
/bin/echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>Username</key>
<string>'$adminUser'</string>
<key>Password</key>
<string>'$adminPass'</string>
<key>AdditionalUsers</key>
<array>
    <dict>
        <key>Username</key>
        <string>'$ADuser'</string>
        <key>Password</key>
        <string>'$ADuserPWD'</string>
    </dict>
</array>
<key>UseRecoveryKey</key>
<true/>
<key>ShowRecoveryKey</key>
<false/>
</dict>
</plist>' > /tmp/fvenable.plist  ### you can place this file anywhere just adjust the fdesetup line below

#now enable FileVault
/usr/bin/sudo fdesetup enable -inputplist < /tmp/fvenable.plist

rm -rf /tmp/fvenable.plist



diskutil apfs updatePreboot  /


/usr/bin/dscl .  -change /Users/onetimeuselocaluseraccountnamehere UserShell /bin/zsh /sbin/nologin

 dialog="$ADuser account has been added to Filevault, Please reboot to enable Filevault"
    echo "$dialog"
    cmd="Tell app "System Events" to display dialog "$dialog""
    /usr/bin/osascript -e "$cmd"

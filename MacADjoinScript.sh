#!/bin/bash
#
# 020_joinDomain.sh- AD joining script - covers all OS revisions that use native binding
# Sam Novak - May 2016
#############
# Variables #
#############
TEST=DOMAINJOINER
TESTPASS=DOMAINJOINERPW

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin

# Get the machine name
HOSTNAME=`/usr/sbin/scutil --get ComputerName`

# Uppercase it
HOSTNAME=$(/bin/echo $HOSTNAME | /usr/bin/tr '[:lower:]' '[:upper:]')

# Make sure the hostname is set
/usr/sbin/scutil --set HostName $HOSTNAME.domain.com
/usr/sbin/scutil --set LocalHostName $HOSTNAME
/usr/sbin/scutil --set ComputerName $HOSTNAME

# Get the machine model
AD_MODEL=$(/usr/sbin/system_profiler SPHardwareDataType | /usr/bin/grep "Model Name")
AD_MODEL=${AD_MODEL:18}
MODEL_TEST=`/bin/echo $AD_MODEL | /usr/bin/grep -E ^Mac[Bb]ook*`

# variables for a variety of AD commands
BASIC="-add domain.com -username $TEST -computer $HOSTNAME -force -password $TESTPASS"
ADVANCED="-mobileconfirm disable -protocol smb  -useuncpath disable -sharepoint disable"
MAP="-uid employeeID -nogid -noggid -authority enable -alldomains disable"
ADMIN="-nogroups -packetsign allow -packetencrypt allow"
REMOVE="-remove -username remover -password removeee -force"

# Disable mobile account creation by default
MOBILE="-mobile disable -passinterval 1"


#############
# Functions #
#############


DOMAINLog() {
    /usr/bin/syslog -s -k Facility local7 Level info Message "$1"
}

# Removes the local domain binding
ADunbind()
{
    /usr/sbin/dsconfigad ${REMOVE} 2> /dev/null
    DOMAINLog "$HOSTNAME unbound from the domain"
}

# Binds back to AD
ADbind()
{
    /usr/sbin/dsconfigad ${BASIC} ${MOBILE} ${ADVANCED} ${MAP} ${ADMIN} -ou OU=Macintosh Deployment,OU=Computers,DC=domain,DC=com
    /usr/sbin/dsconfigad -preferred ldap.domain.com 2> /dev/null
    DOMAINLog "$HOSTNAME bound to the domain"
}

####################
# Actual scripting #
####################

if [ "$MODEL_TEST" != "" ]; then
        MOBILE="-mobile enable"
fi

ADunbind
ADbind

##################################
# 090_Util_updateADAttributes.sh #
#######################################################
# The following sections update attributes on the    #
# AD object for this workstation and makes sure they  #
# are accurate for the current system                #
#######################################################
# serial number
SERIAL=$(/usr/sbin/system_profiler SPHardwareDataType Hardware | /usr/bin/grep Serial)
SERIAL=${SERIAL:30:12}

# Model
MODEL=$(/usr/sbin/system_profiler SPHardwareDataType Hardware | /usr/bin/grep Identifier)
MODEL=${MODEL:24}

# Processor Model
PROC_MOD=$(/usr/sbin/system_profiler SPHardwareDataType Hardware | /usr/bin/grep "Processor Name")
PROC_MOD=${PROC_MOD:22}

# Processor Speed
PROC_SPE=$(/usr/sbin/system_profiler SPHardwareDataType Hardware | /usr/bin/grep "Processor Speed")
PROC_SPE=${PROC_SPE:23}

# Processor Core Count
PROC_COR=$(/usr/sbin/system_profiler SPHardwareDataType Hardware | /usr/bin/grep "Number of Cores")
PROC_COR=${PROC_COR:29}

# RAM
RAM=$(/usr/sbin/system_profiler SPHardwareDataType Hardware | /usr/bin/grep "Memory")
RAM=${RAM:14}

# GPU
GPU=$(/usr/sbin/system_profiler SPDisplaysDataType | /usr/bin/grep -i chip | /usr/bin/sed -e 's/Chipset Model: //' | /usr/bin/tr -d '
' | /usr/bin/tr -s ' ')
GPU=${GPU:1}

DESCRIPTION="Model: $MODEL Serial: $SERIAL - Processor: $PROC_MOD $PROC_SPE - GPU: $GPU - RAM: $RAM"

COMMENT="$MODEL $SERIAL"

# OS Version
VERSION=$(/usr/bin/sw_vers | /usr/bin/grep ProductVersion)
VERSION=${VERSION:16}

ADRead() {
    # Sending error output to null, since it's a non-critical feature
    /usr/bin/dscl -u $TEST -P $TESTPASS /Active Directory/DOMAIN/All Domains -read Computers/$HOSTNAME$ $1 2>/dev/null
    if [ $? = 1 ]; then
        /usr/bin/dscl -u $TEST -P $TESTPASS /Active Directory/DOMAIN/DOMAIN.com -read Computers/$HOSTNAME$ $1 2>/dev/null
    fi
}

ADAppend() {
    # Sending error output to null, since it's a non-critical feature
    /usr/bin/dscl -u $TEST -P $TESTPASS /Active Directory/DOMAIN/All Domains -append Computers/$HOSTNAME$ $1 "$2" 2>/dev/null
    if [ $? = 1 ]; then
        /usr/bin/dscl -u $TEST -P $TESTPASS /Active Directory/DOMAIN/DOMAIN.com -append Computers/$HOSTNAME$ $1 "$2" 2>/dev/null
    fi
}

ADUpdate() {
    # Sending error output to null, since it's a non-critical feature
    /usr/bin/dscl -u $TEST -P $TESTPASS /Active Directory/DOMAIN/All Domains -change Computers/$HOSTNAME$ $1 "$2" "$3" 2>/dev/null
    if [ $? = 1 ]; then
        /usr/bin/dscl -u $TEST -P $TESTPASS /Active Directory/DOMAIN/DOMAIN.com -change Computers/$HOSTNAME$ $1 "$2" "$3" 2>/dev/null
    fi
}

# Let's sleep a little here, so AD can get up to date
/bin/sleep 10

# Read old OS
OLD_OS=$(ADRead dsAttrTypeNative:operatingSystemVersion)
OLD_OS=${OLD_OS:41}
OLD_OS=${OLD_OS## } # Strip spaces from the front of the text
OLD_OS=${OLD_OS%% } # Strip spaces from the back of the text

if [ "$OLD_OS" == "" ]; then
    # ADAppend the new attribute
    /bin/echo "Adding OS version for the first time"
    ADAppend dsAttrTypeNative:operatingSystemVersion "$VERSION"
elif [ "$OLD_OS" != "$VERSION" ]; then
    # Update OS
    /bin/echo "Updating the OS version"
    ADUpdate dsAttrTypeNative:operatingSystemVersion "$OLD_OS" "$VERSION"
fi

# Read old serial
OLD_SERIAL=$(ADRead dsAttrTypeNative:serialNumber)
OLD_SERIAL=${OLD_SERIAL:31:12}
OLD_SERIAL=${OLD_SERIAL## } # Strip spaces from the front of the text
OLD_SERIAL=${OLD_SERIAL%% } # Strip spaces from the back of the text

if [ "$OLD_SERIAL" == "" ]; then
    # ADAppend the new attribute
    /bin/echo "Adding serial number for the first time"
    ADAppend dsAttrTypeNative:serialNumber "$SERIAL"
elif [ "$OLD_SERIAL" != "$SERIAL" ]; then
    # Update Serial
    /bin/echo "Updating the serial number"
    ADUpdate dsAttrTypeNative:serialNumber "$OLD_SERIAL" "$SERIAL"
fi

# Read old description
OLD_DES=$(ADRead dsAttrTypeNative:adminDescription)
OLD_DES=${OLD_DES:35} # Strip the front of the text
OLD_DES=${OLD_DES## } # Strip spaces from the front of the text
OLD_DES=${OLD_DES%% } # Strip spaces from the back of the text

if [ "$OLD_DES" == "" ]; then
    # ADAppend the new attribute
    /bin/echo "Adding the system description for the first time"
    ADAppend dsAttrTypeNative:adminDescription "$DESCRIPTION"
elif [ "$OLD_DES" != "$DESCRIPTION" ]; then
    # Update Admin description
    # Ex: USED BY SAM NOVAK Model: iMac14,2 Serial: D25MT11XF8J9 - Processor: Intel Core i5 3.2 GHz - GPU: NVIDIA GeForce GT 755M - RAM: 6 GB LOLOLOL
    # Prefix /usr/bin/grep: USED BY SAM NOVAK Model:
    # Prefix /usr/bin/sed : USED BY SAM NOVAK
    # Suffix /usr/bin/grep #1: RAM: 6 GB LOLOLOL
    # Suffix /usr/bin/grep #2: GB LOLOLOL
    # Suffix sed: LOLOLOL
    PREFIX=$(/bin/echo "$OLD_DES" | /usr/bin/grep -o '.{0,40}Model:' | /usr/bin/sed -e "s/ *Model:$//")
    SUFFIX=$(/bin/echo "$OLD_DES" | /usr/bin/grep -o 'RAM: [0-9][0-9]? GB.{0,20}' | /usr/bin/sed -e 's/RAM: [0-9]{0,2} GB *//')
    OUTPUT="$PREFIX $DESCRIPTION $SUFFIX"
    OUTPUT=${OUTPUT## }
    OUTPUT=${OUTPUT%% }
    if [ "$OLD_DES" != "$OUTPUT" ]; then
        /bin/echo "Updating the system description, with prefix and suffix."
        /bin/echo "PREFIX: $PREFIX"
        /bin/echo "SUFFIX: $SUFFIX"
        ADUpdate dsAttrTypeNative:adminDescription "$OLD_DES" "$OUTPUT"
    fi
fi

# Read old comment
OLD_COM=$(ADRead dsAttrTypeNative:comment)
OLD_COM=${OLD_COM:26}
OLD_COM=${OLD_COM## } # Strip spaces from the front of the text
OLD_COM=${OLD_COM%% } # Strip spaces from the back of the text

if [ "$OLD_COM" == "" ]; then
    # ADAppend the new attribute
    /bin/echo "Adding the system comment for the first time."
    ADAppend dsAttrTypeNative:comment "$COMMENT"
elif [ "$OLD_COM" != "$COMMENT" ]; then
    # Update Comment
    # Ex: ASDASDASD iMac14,2 D25MT11XF8J9 ASDASDASD
    # Prefix /usr/bin/grep: ASDASDASD iMac14,2
    # Prefix /usr/bin/sed : ASDASDASD
    # Suffix /usr/bin/grep: iMac14,2 D25MT11XF8J9 ASDASDAS
    # Suffix /usr/bin/sed: ASDASDAS
    PREFIX=$(/bin/echo "$OLD_COM" | /usr/bin/grep -o '.{0,40}i?[Mm]ac[[:alpha:]]{0,10}[0-9]+,[0-9]+' | /usr/bin/sed -e 's/ i{0,1}[Mm]ac[a-zA-Z]*[0-9]{1,2},[0-9]$//')
    SUFFIX=$(/bin/echo "$OLD_COM" | /usr/bin/grep -o 'i?[Mm]ac[[:alpha:]]{0,10}[0-9]+,[0-9]+.{0,40}'  | /usr/bin/sed -e 's/i{0,1}[Mm]ac[a-zA-Z]*[0-9]{1,2},[0-9] [a-zA-Z0-9]{0,12} //')
    OUTPUT="$PREFIX $COMMENT $SUFFIX"
    OUTPUT=${OUTPUT## }
    OUTPUT=${OUTPUT%% }
    if [ "$OLD_COM" != "$OUTPUT" ]; then
        /bin/echo "Updating the system comment with prefix and suffix."
        /bin/echo "PREFIX: $PREFIX"
        /bin/echo "SUFFIX: $SUFFIX"
        ADUpdate dsAttrTypeNative:comment "$OLD_COM" "$OUTPUT"
    fi
fi

# Read old comment (The actual comment field in ADUC)
OLD_COM2=$(ADRead Comment)
OLD_COM2=${OLD_COM2:9}
OLD_COM2=${OLD_COM2## } # Strip spaces from the front of the text
OLD_COM2=${OLD_COM2%% } # Strip spaces from the back of the text

if [ "$OLD_COM2" == "" ]; then
    # ADAppend the new attribute
    /bin/echo "Adding the secondary system comment for the first time."
    ADAppend Comment "$DESCRIPTION"
elif [ "$OLD_COM2" != "$DESCRIPTION" ]; then
    # Update Comment
    # Ex: USED BY SAM NOVAK Model: iMac14,2 Serial: D25MT11XF8J9 - Processor: Intel Core i5 3.2 GHz - GPU: NVIDIA GeForce GT 755M - RAM: 6 GB LOLOLOL
    # Prefix /usr/bin/grep: USED BY SAM NOVAK Model:
    # Prefix /usr/bin/sed : USED BY SAM NOVAK
    # Suffix /usr/bin/grep #1: RAM: 6 GB LOLOLOL
    # Suffix /usr/bin/sed: LOLOLOL
    PREFIX=$(/bin/echo "$OLD_COM2" | /usr/bin/grep -o '.{0,40}Model:' | /usr/bin/sed -e "s/ *Model:$//")
    SUFFIX=$(/bin/echo "$OLD_COM2" | /usr/bin/grep -o 'RAM: [0-9][0-9]? GB.{0,20}' | /usr/bin/sed -e 's/RAM: [0-9]{0,2} GB *//')
    OUTPUT="$PREFIX $DESCRIPTION $SUFFIX"
    OUTPUT=${OUTPUT## }
    OUTPUT=${OUTPUT%% }
    if [ "$OLD_COM2" != "$OUTPUT" ]; then
        /bin/echo "Updating the secondary comment, with prefix and suffix."
        /bin/echo "PREFIX: $PREFIX"
        /bin/echo "SUFFIX: $SUFFIX"
        ADUpdate Comment "$OLD_COM2" "$OUTPUT"
    fi
fi

exit 0

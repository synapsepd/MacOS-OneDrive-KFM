#!/bin/bash
###################################################################
#Script Name    : onedrive-enable.sh
#Description	: This script is to ensure that OneDrive is installed, enabled, and syncing
#Author       	: Brian McFarlane
#Email         	: samspade@synapse.com
###################################################################

#Read in Script preferences.  These can be set with a 'sudo defaults write' command or using a mobileconfig with your MDM
defaultTenantID=$(/usr/bin/python -c "from Foundation import CFPreferencesCopyAppValue; print CFPreferencesCopyAppValue('TenantID', 'com.cambridgeconsultants.onedrive-kfm')")
defaultOneDriveName=$(/usr/bin/python -c "from Foundation import CFPreferencesCopyAppValue; print CFPreferencesCopyAppValue('OneDriveFolderName', 'com.cambridgeconsultants.onedrive-kfm')")

#Only enable OneDrive KFM for machines with a preference file turning it on
if [ "$defaultTenantID" == "None" ] || [ "$defaultOneDriveName" == "None" ]; then
    logger -s -p user.error "OneDrive-Enable: This script not yet enabled on this computer.  To enable ensure that TenantID, and OneDriveFolderName are set within the /Library/Preferences/com.cambridgeconsultants.onedrive-kfm.plist file."
    exit
fi

#Get Current Username
user="$(whoami)"

#If this is run as root, instead of the current user - exit out
if [ "$user" == "root" ]; then
    logger -s -p user.error "OneDrive-Enable: This script not intened to be run as root."
    exit
fi

#Get this user's home directory path (can't assume it is in /Users/username - even though that is probably right)
userHomeDirectory=$(dscl . -read /Users/$user NFSHomeDirectory | cut -d' ' -f2)

#Define this user's onedrive folder path
defaultOneDriveFolder="$userHomeDirectory/$defaultOneDriveName"

#Ensure OneDrive is set to OpenAtLogin.  The next time it launches, it will add itself to the Login Items of the current user (if it isn't there yet)
defaults write "$userHomeDirectory/Library/Preferences/com.microsoft.OneDrive.plist" OpenAtLogin 1 >/dev/null 2>&1

#Setup default sync for tennant and path
/usr/libexec/PlistBuddy -c "Add :Tenants:$defaultTenantID:DefaultFolder string '$defaultOneDriveFolder'" "$userHomeDirectory/Library/Preferences/com.microsoft.OneDrive.plist" 2>/dev/null

# If the user's OneDrive folder does not exist, then they are not yet setup
# TODO: need a better way to determine if OneDrive logged in and Syncing - any ideas?
if ! [ -d "$defaultOneDriveFolder" ]; then

    #Launch OneDrive and put it in the background (hide errors if not installed)
    open -a OneDrive.app >/dev/null 2>&1

fi

exit 0
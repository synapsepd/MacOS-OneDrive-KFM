#!/bin/bash
###################################################################
#Script Name    : onedrive-kfm.sh
#Description	: This script sets up OneDrive Known Folder Migration on MacOS for the Desktop and Documents folder
#               : It is designed to be run as root and is enabled machine wide with a plist setting of: sudo defaults write "/Library/Preferences/com.cambridgeconsultants.onedrive-kfm" EnableKFM -bool YES
#               : Thus allowing you to use your MDM to set this setting.  One way to run this script is using Outset https://github.com/chilcote/outset in one of the privileged execution directories
#               : This script is designed to work with the OneDrive version as deployed from https://macadmins.software/ vs the AppStore version
#               : Modifications could easily be made to support the AppStore version of OneDrive if desired
#Author       	: Brian McFarlane
#Email         	: samspade@synapse.com
###################################################################

#Read in Script preferences.  These can be set with a 'sudo defaults write' command or using a mobileconfig with your MDM
defaultTenantID=$(/usr/bin/python -c "from Foundation import CFPreferencesCopyAppValue; print CFPreferencesCopyAppValue('TenantID', 'com.cambridgeconsultants.onedrive-kfm')")
defaultOneDriveName=$(/usr/bin/python -c "from Foundation import CFPreferencesCopyAppValue; print CFPreferencesCopyAppValue('OneDriveFolderName', 'com.cambridgeconsultants.onedrive-kfm')")
oneDriveKFMEnabled=$(/usr/bin/python -c "from Foundation import CFPreferencesCopyAppValue; print CFPreferencesCopyAppValue('EnableKFM', 'com.cambridgeconsultants.onedrive-kfm')")
fixBadFileNames=$(/usr/bin/python -c "from Foundation import CFPreferencesCopyAppValue; print CFPreferencesCopyAppValue('FixBadFileNames', 'com.cambridgeconsultants.onedrive-kfm')")

#Only enable OneDrive KFM for machines with a preference file turning it on
if [ "$oneDriveKFMEnabled" != "True" ] && [ "$defaultTenantID" == "None" ] && [ "$defaultOneDriveName" == "None" ]; then
    logger -s -p user.error "OneDrive-KFM: Not enabled on this computer.  To enable ensure that EnableKFM, FixBadFileNames, TenantID, and OneDriveFolderName are set within the /Library/Preferences/com.cambridgeconsultants.onedrive-kfm.plist file."
    exit
fi

#If this is run as root, instead of the current user - exit out
if [ "$(whoami)" != "root" ]; then
    logger -s -p user.error "OneDrive-KFM: Please make sure this script is running as root."
    exit
fi

#Determine if we will fix bad file names or not
if [ "$fixBadFileNames" != "True" ]; then
    fixBadFileNames="False"
fi

userList=$(dscl . list /Users UniqueID | awk '$2 > 500 {print $1}')

for user in $userList; do

    logger -s -p user.notice "OneDrive-KFM: Processing $user..."

    #Get this user's home directory path (can't assume it is in /Users/username - even though that is probably right)
    userHomeDirectory=$(dscl . -read /Users/$user NFSHomeDirectory | cut -d' ' -f2)

    #Define this user's onedrive folder path
    defaultOneDriveFolder="$userHomeDirectory/$defaultOneDriveName"

    #Ensure OneDrive is set to OpenAtLogin.  The next time it launches, it will add itself to the Login Items of the current user (if it isn't there yet)
    defaults write "$userHomeDirectory/Library/Preferences/com.microsoft.OneDrive.plist" OpenAtLogin 1 >/dev/null 2>&1

    #Setup default sync for tennant and path
    /usr/libexec/PlistBuddy -c "Add :Tenants:$defaultTenantID:DefaultFolder string '$defaultOneDriveFolder'" "$userHomeDirectory/Library/Preferences/com.microsoft.OneDrive.plist" 2>/dev/null

    #Ensure that plist ownership is correct
    /usr/sbin/chown -Rv "$user" "$userHomeDirectory/Library/Preferences/com.microsoft.OneDrive.plist" >/dev/null 2>&1

    #Full path to the root of where the backup files will be stored
    backupPath="$userHomeDirectory/OneDrive Conflicts From $(hostname)"

    # Only continue if the user's $defaultOneDriveFolder folder exists (meaning they have logged in and started syncing already)
    if [ -d "$defaultOneDriveFolder" ]; then

        #If Documents and Desktop are already links, and the OneDrive folder exists - then nothing to do.
        if [ -L "$userHomeDirectory/Documents" ] && [ -L "$userHomeDirectory/Desktop" ]; then
            logger -s -p user.notice "OneDrive-KFM: OneDrive KFM already configured for $user."

        else #We need to setup OneDrive for this user

            #Close OneDrive if it is running and the user is the console user
            if [ "$(stat -f "%Su" /dev/console)" == "$user" ]; then
                logger -s -p user.notice "OneDrive-KFM: Closing OneDrive."
                osascript -e 'display notification "Configuring OneDrive sync for Documents and Desktop..." with title "OneDrive Sync"'
                osascript -e 'quit app "OneDrive.app"'
            fi

            #Create backup directory path
            logger -s -p user.notice "OneDrive-KFM: creating backup path: $backupPath"
            mkdir -p "$backupPath"

            if [ -d "$userHomeDirectory/Documents" ] && [ ! -L "$userHomeDirectory/Documents" ]; then
                logger -s -p user.notice "OneDrive-KFM: Moving documents folder for $user."
                mv -f "$userHomeDirectory/Documents" "$backupPath/Documents"

                logger -s -p user.notice "OneDrive-KFM: Building symlink for documents folder for $user."
                mkdir -p "$defaultOneDriveFolder/Documents"
                ln -s "$defaultOneDriveFolder/Documents" "$userHomeDirectory/Documents"
                /usr/sbin/chown -Rv "$user" "$defaultOneDriveFolder/Documents" >/dev/null 2>&1
            else
                logger -s -p user.error "OneDrive-KFM: Documents folder not moved or already moved for $user"
            fi

            if [ -d "$userHomeDirectory/Desktop" ] && [ ! -L "$userHomeDirectory/Desktop" ]; then
                logger -s -p user.notice "OneDrive-KFM: Moving desktop folder for $user."
                mv -f "$userHomeDirectory/Desktop" "$backupPath/Desktop"

                logger -s -p user.notice "OneDrive-KFM: Building symlink for desktop folder for $user."
                mkdir -p "$defaultOneDriveFolder/Desktop"
                ln -s "$defaultOneDriveFolder/Desktop" "$userHomeDirectory/Desktop"
                /usr/sbin/chown -Rv "$user" "$defaultOneDriveFolder/Desktop" >/dev/null 2>&1
            else
                logger -s -p user.error "OneDrive-KFM: Desktop folder not moved or already moved for $user"
            fi

            logger -s -p user.notice "OneDrive-KFM: Ensuring ownership of backup data set to $user."
            /usr/sbin/chown -Rv "$user" "$backupPath" >/dev/null 2>&1

            #if this user is the console user, then we need to relaunch the finder and onedrive
            if [ "$(stat -f "%Su" /dev/console)" == "$user" ]; then
                logger -s -p user.notice "OneDrive-KFM: $user is console user - relaunch Finder and launch OneDrive"
                #Restart the finder to ensure it is happy with the migration
                killall -KILL Finder
                #Launch OneDrive and put it in the background (hide errors if not installed)
                open -a OneDrive.app -g >/dev/null 2>&1
            fi

        fi

        #If we have a backup path, we need to move the files into the new home
        #Note, this runs every time - even if the symlinks are already built.  This is to ensure that we don't leave behind any user data
        if [ -d "$backupPath" ]; then
            logger -s -p user.notice "OneDrive-KFM: Moving backup files into proper OneDrive folders for $user."
            #We want to only move files that don't exist in the destination and we want to remove them from the source after we are done moving them
            #Thus the only files left in the backup source should be the ones there were conflicted
            rsyncResults=$(rsync --checksum --remove-source-files --ignore-existing -avhE "$backupPath/" "$defaultOneDriveFolder/")
            /usr/sbin/chown -Rv "$user" "$defaultOneDriveFolder" >/dev/null 2>&1
            logger -s -p user.notice "OneDrive-KFM: $rsyncResults"

            #Get rid of .ds_store files that are left over, as that will make it look like there are directories with conflicts when there are not
            find "$backupPath" -name ".DS_Store" -depth -exec rm {} \;
            #Get rid of empty directories
            find "$backupPath" -type d -empty -delete

            #If the backup folder is now empty, delete it - otherwise put it on the user's new desktop folder in OneDrive
            if find "$backupPath" -mindepth 1 | read; then
                mv -f "$backupPath" "$defaultOneDriveFolder/Desktop/"
                logger -s -p user.error "OneDrive-KFM: Conflict files found.  Moved to $user desktop. "
            else
                rm -rf "$backupPath"
                logger -s -p user.notice "OneDrive-KFM: $user backup data migration complete."
            fi

            #Fix names of OneDrive files that are bad if the preference is set to true
            #This is the last step to take place
            if [ "$fixBadFileNames" == "True" ]; then
                logger -s -p user.notice "OneDrive-KFM: Attempting to clean file names for $user with /usr/local/bin/onedrive-name-fix.sh"
                #If the user being processed is the console user, then display a message - otherwise run silent
                if [ "$(stat -f "%Su" /dev/console)" == "$user" ]; then
                    /usr/local/bin/onedrive-name-fix.sh -p "$defaultOneDriveFolder" -n "$defaultOneDriveFolder/Desktop"
                else
                    /usr/local/bin/onedrive-name-fix.sh -p "$defaultOneDriveFolder" -n "$defaultOneDriveFolder/Desktop" -s
                fi                
            fi

        fi

    else
        logger -s -p user.notice "OneDrive-KFM: OneDrive folder does not yet exist for $user."
    fi

done

exit 0
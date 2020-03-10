#!/bin/bash

###################################################################
#
# Script to rename files to work with OneDrive
# Based on the work from: https://github.com/UoE-macOS/jss/blob/master/utilities-fix-file-names.sh
# Also from: https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
#
##################################################################

logger -s -p user.notice "OneDrive-Name-Fix: Loading..."

#Get Params for script and set defaults
runSilent=NO #Default to not be silent
pathToNotice=/tmp #Default to put notice in /tmp
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
    -p | --pathtoclean)
        pathToClean="$2"
        shift # past argument
        shift # past value
        ;;
    -s | --silent)
        runSilent=YES
        shift # past argument
        ;;
    -n | --pathtonotice)
        pathToNotice="$2"
        shift # past argument
        shift # past value
        ;;
    *) # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift              # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

#Ensure that pathToClean is a valid directory
if [[ -d "$pathToClean" ]]; then
    logger -s -p user.notice "OneDrive-Name-Fix: pathtoclean = $pathToClean   silent = $runSilent   pathtonotice = $pathToNotice"
else
    logger -s -p user.error "OneDrive-Name-Fix: Please call this script with the following params: --pathtoclean"
    exit
fi

###################################################################
# Function Definitions
###################################################################

Check_Trailing_Chars() {

    cat /tmp/cln.ffn | grep -v ".pkg" | grep -v ".app" >/tmp/fixtrail.ffn
    linecount=$(wc -l /tmp/fixtrail.ffn | awk '{print $1}') >/dev/null 2>&1
    counter=$linecount
    echo "count: ${counter}"
    date
    while read line; do
        # echo $(($(gdate +%s%N)/1000000))     
        # line="$(sed -n ${counter}p /tmp/fixtrail.ffn)"
        # lastChar="$(sed -n ${counter}p /tmp/fixtrail.ffn | grep -Eo '.$')"
        lastChar="$(echo ${line} | grep -Eo '.$')"
        # echo $(($(gdate +%s%N)/1000000))     
        # echo "processing $line counter: $counter"

        if [ "$lastChar" == " " ] || [ "$lastChar" == "." ]; then
            echo "fixing $line"
            name=$(basename "$line")                                              # get the filename we need to change
            path=$(dirname "$line")                                               # dirname to get the path
            fixedname=$(echo "$name" | tr '.' '-' | awk '{sub(/[ \t]+$/, "")};1') # remove/replace the trailing whitespace or period
            echo "'$line' -> '$path/$fixedname'" >>/tmp/allfixed.ffn
            logger -s -p user.notice "OneDrive-Name-Fix: Trailing Chars - '$line' -> '$path/$fixedname'"
            mv -f "$line" "$path/$fixedname" # rename the file or folder
        fi

        let "counter = $counter -1"
    done < /tmp/fixtrail.ffn
    date
}

Check_Leading_Spaces() {

    cat /tmp/cln.ffn | grep -v ".pkg" | grep -v ".app" | grep "/[[:space:]]" >/tmp/fixlead.ffn
    linecount=$(wc -l /tmp/fixlead.ffn | awk '{print $1}') >/dev/null 2>&1
    counter=$linecount
    while ! [ "$counter" == 0 ]; do

        line="$(sed -n ${counter}p /tmp/fixlead.ffn)"
        name=$(basename "$line")                       # get the filename we need to change
        path=$(dirname "$line")                        # dirname to get the path
        fixedname=$(echo $name | sed -e 's/^[ \t]*//') # sed out the leading whitespace
        echo "'$line' -> '$path/$fixedname'" >>/tmp/allfixed.ffn
        logger -s -p user.notice "OneDrive-Name-Fix: Leading Spaces - '$line' -> '$path/$fixedname'"
        mv -f "$line" "$path/$fixedname" # rename the file or folder

        let "counter = $counter -1"
    done
}

Fix_Names() {
    linecount=$(wc -l /tmp/cln.ffn | awk '{print $1}') >/dev/null 2>&1
    counter=$linecount
    while ! [ "$counter" == 0 ]; do

        line="$(sed -n ${counter}p /tmp/cln.ffn)"
        name=$(basename "$line")                                                                                                                         # get the filename we need to change
        path=$(dirname "$line")                                                                                                                          # dirname to get the path
        fixedname=$(echo "$name" | tr ':' '-' | tr '\\\' '-' | tr '?' '-' | tr '*' '-' | tr '"' '-' | tr '<' '-' | tr '>' '-' | tr '%' '-' | tr '|' '-') # sed out the leading whitespace
        echo "'$line' -> '$path/$fixedname'" >>/tmp/allfixed.ffn
        logger -s -p user.notice "OneDrive-Name-Fix: Bad Chars - '$line' -> '$path/$fixedname'"
        mv -f "$line" "$path/$fixedname" # rename the file or folder

        let "counter = $counter -1"
    done
}

Save_Notice() {
    rm -f "$pathToNotice/onedrive-renames.txt" >/dev/null 2>&1

    echo "---OneDrive Sync Directory/File Rename Notice---" >>"$pathToNotice/onedrive-renames.txt"
    echo "$(date) ">>"$pathToNotice/onedrive-renames.txt"
    echo "------------------------------------------------" >>"$pathToNotice/onedrive-renames.txt"
    echo "It is necessary for folder or file names containing any illegal characters to be renamed. These characters are the following: \ / : * ? \" < > % | they also include leading spaces, trailing . and trailing spaces." >>"$pathToNotice/onedrive-renames.txt"
    echo " " >>"$pathToNotice/onedrive-renames.txt"
    echo "This message is to advise you of any such files or folders that have been affected so that you are aware that of these characters in their names will now have been replaced by a hyphen or removed." >>"$pathToNotice/onedrive-renames.txt"
    echo " " >>"$pathToNotice/onedrive-renames.txt"
    echo "Here are the files and folders that have been renamed in your case:" >>"$pathToNotice/onedrive-renames.txt"
    echo " " >>"$pathToNotice/onedrive-renames.txt"
    cat /tmp/allfixed.ffn >>"$pathToNotice/onedrive-renames.txt"
    echo " " >>"$pathToNotice/onedrive-renames.txt"
    echo "This file can safely be deleted. If you have any issues on this matter, please contact IT." >>"$pathToNotice/onedrive-renames.txt"
    echo " " >>"$pathToNotice/onedrive-renames.txt"
    echo "Regards, IT Services" >>"$pathToNotice/onedrive-renames.txt"
}

###################################################################
# Main Program
###################################################################

# Clear any previous temp files from previous runs
rm -f /tmp/*.ffn >/dev/null 2>&1
touch /tmp/allfixed.ffn

# Remove local fstemps so they won't clog the server
find "$pathToClean" -name ".fstemp*" -exec rm -dfR '{}' \;

# Process Illegal Chars
logger -s -p user.notice "OneDrive-Name-Fix: Fixing illegal chars..."
find "${pathToClean}" -name '*[\\/:*?"<>%|]*' -print >>/tmp/cln.ffn
Fix_Names
rm -f /tmp/cln.ffn >/dev/null 2>&1

# Process Trailing Spaces and Periods
logger -s -p user.notice "OneDrive-Name-Fix: Fixing trailing spaces and periods..."
find "${pathToClean}" -name "*" >>/tmp/cln.ffn
Check_Trailing_Chars
rm -f /tmp/cln.ffn >/dev/null 2>&1

# Process Leading Spaces
logger -s -p user.notice "OneDrive-Name-Fix: Fixing leading spaces..."
find "${pathToClean}" -name "*" >>/tmp/cln.ffn
Check_Leading_Spaces
rm -f /tmp/cln.ffn >/dev/null 2>&1

totalFixed=$(wc -l /tmp/allfixed.ffn | awk '{print $1}') >/dev/null 2>&1

# If any files were fixed, then save a report to the pathToNotice
if [ "0$totalFixed" -gt "0" ] 2>/dev/null; then
    #Rename any existing rename notices
    mv -f "$pathToNotice/onedrive-renames.txt" mv -f "$pathToNotice/onedrive-renames.txt.bak" >/dev/null 2>&1
    Save_Notice

    if [ "$runSilent" == "NO" ]; then
        osascript -e 'display notification "Some files and/or folders renamed due to invalid OneDrive names." with title "OneDrive Sync"'
        open "$pathToNotice/onedrive-renames.txt"
    fi
fi

exit 0

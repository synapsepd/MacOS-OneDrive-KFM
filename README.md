
# MacOS-OneDrive-KFM (Known Folder Move)

## Purpose

Microsoft OneDrive has a super great feature (for Windows) called [Known Folder Move](https://docs.microsoft.com/en-us/onedrive/redirect-known-folders). This redirects the Desktop, Documents, and Pictures folders to your OneDrive folder. This allows you to have multiple computers stay in sync. This application brings this same functionality to MacOS through the use of SymLinks thus enabling sync between your Desktop and Documents folders and OneDrive.

### Notes

- This application does not currently work with the Apple Store version of OneDrive. Please use the stand alone version instead. It can be downloaded from here: [https://macadmins.software/](https://macadmins.software/).

- [OutSet](https://github.com/chilcote/outset) is required for this application.

- As this applicaiton interacts with User data, please do your own testing for your enviorment.  Feel free to submit detailed issues if you find bugs.

## Getting started

You can choose to either download a release pkg or build your own. These steps assume that you are using a release, or have already built your own pkg.

1. Install [OneDrive standalone](https://macadmins.software/) (***not*** the one from the AppStore).

2. Set preferences. You can either set them with a `sudo defaults write` command, a .mobileconfig profile, or an MDM profile. A sample.mobileconfig file is included in this repo.

 `sudo defaults write "/Library/Preferences/com.cambridgeconsultants.onedrive-kfm" EnableKFM -bool YES` 

 `sudo defaults write "/Library/Preferences/com.cambridgeconsultants.onedrive-kfm" FixBadFileNames -bool YES` 

 `sudo defaults write "/Library/Preferences/com.cambridgeconsultants.onedrive-kfm" TenantID "12345678-1234-1234-1234-1234567891011"` 

 `sudo defaults write "/Library/Preferences/com.cambridgeconsultants.onedrive-kfm" OneDriveFolderName "OneDrive - Companyname"` 

Here is what each setting does:

-  **EnableKFM**  *(required)* : If set to True then KFM attempts to run. If False or does not exist - the script will just exit. This gives control on a per machine basis of if KFM shall be turned on.

-  **TenantID**  *(required)* : This is your AzureAD Tenant ID. If you do not know what this is, you can look it up with instructions [here](https://docs.microsoft.com/en-us/onedrive/find-your-office-365-tenant-id).

-  **OneDriveFolderName**  *(required)* : This is the default name of your OneDrive sync folder. This will be something like *"OneDrive - Company Name"*. This is the directory that OneDrive creates in your home directory for syncing.

-  **FixBadFileNames**  *(optional)* : If this is set to True, then an attempt is made after setting up KFM to fix file names that are not valid with OneDrive. A report is saved on the desktop letting the user know what was changed. If this is set to False or not set, then no attempt will be made to rename files.

3. Install [OutSet](https://github.com/chilcote/outset). OutSet is used to run logon/startup scripts on MacOS. This is a dependency of this application.

4. Install the latest version of *MacOS-OneDrive-KFM-X. X.pkg*

## Building the package

1. Install [munki-pkg](https://github.com/munki/munki-pkg) and ensure it is in your path

2. Clone this git repo

 `cd ~/keep/this/here` 

 `git clone https://github.com/synapsepd/MacOS-OneDrive-KFM.git` 

3. Edit the build-info.json file to include your certificate information, or remove the cert section alltogether if you will not be signing the package.

4. MunkiPkg will now create a new build:

 `munkipkg .` 

## Tips, Tricks, and Troubleshooting

- Things are not going well. Help!

- Use your Console.app and filter for *'OneDrive'*. This will let you see the output of the scripts.

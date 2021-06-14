#!/bin/bash

rpiAccesspTag="#rpi-accessp"

##################################################
# L O C A T I O N S
##################################################

dhcpcdConfig="/etc/dhcpcd.conf"
dnsmasqConfig="/etc/dnsmasq.conf"
hostapdConfig="/etc/hostapd/hostapd.conf"

##################################################
# F U N C T I O N S
##################################################

##################################################
# Extracts the static [ip_address] and subnet mask
# from the dhcpcd.conf file from a previous rpi-accessp
# installation.
#
# RETURNS: 0 if the IP Address and Subnet Mask are extracted, 1 if no IP Address was found.
#          [accessPointEnabled] The enabled state for the access point.
#          [dhcpcdConfigIP] The static IP Address for the device.
#          [dhcpcdConfigMask] The Subnet Mask for the IP Address.
accessPointEnabled="" # Initialize Whether or Not the Access Point is Enabled in the dhcpcd.conf
dhcpcdConfigIP="" # Initialize the IP Address Extracted from the dhcpcd.conf
dhcpcdConfigMask="" # Initialize the Subnet Mask Extracted from the dhcpcd.conf
dhcpcdConfigExtract() {
    # Initialize the Returns
    accessPointEnabled=""
    dhcpcdConfigIP=""
    dhcpcdConfigMask=""

    ##################################################
    # Read the dhcpcd.conf File Line-by-Line and Search for the [ip_address]
    while IFS=, read -r readline; do
        # Search the Current Line for the [ip_address]
        if [[ "${readline}" == *"static ip_address="* ]]; then # Found the [ip_address]
            # Extract the Entire Line
            dhcpcdConfigIP="${readline}"

            # Check the Enabled Status of the Access Point by Checking if the [ip_address] is Commented Out
            if [[ "${dhcpcdConfigIP:0:1}" == "#" ]]; then # Check if the First Character in the Line is a Number Sign #
                # The [ip_address] is Commented Out, the Access Point is Disabled
                accessPointEnabled="false"
                # Remove the Number Sign from the Static IP Address
                dhcpcdConfigIP="${dhcpcdConfigIP:1}" # Trim the First Character in the IP Address 
            # The [ip_address] is Not Commented Out, the Access Point is Enabeled
            else accessPointEnabled="true"; fi

            # Remove the [ip_address] Tag from the Front of the String Using #
            dhcpcdConfigIP="${dhcpcdConfigIP#*static ip_address=}"
            # # Remove Any Remaining Whitespace from the Extracted IP Address
            # dhcpcdConfigIP="${dhcpcdConfigIP// /}"
            
            # Extract the Subnet Mask
            dhcpcdConfigMask="${dhcpcdConfigIP#*/}" # Remove the IP Address Before the Forward Slash /
            # Extract the IP Address
            dhcpcdConfigIP="${dhcpcdConfigIP%/*}" # Remove the Subnet Mask After the Forward Slash /

            # Return that an IP Address was Extracted
            return 0
        fi
    ##################################################
    done < "${dhcpcdConfig}" # Read from the dhcpcd.conf File

    # Return that No IP Address was Found
    return 1
}

##################################################
# Extracts the DHCP and DNS configuration from the
# dnsmasq.conf file from a previous rpi-accessp
# installation.
#
# RETURNS: [dnsmasqConfigRangeStart] The DHCP IP Address starting range.
#          [dnsmasqConfigRangeEnd] The DHCP IP Address ending range.
#          [dnsmasqConfigRange] The total number of deliverable IP Addresses.
#          [dnsmasqConfigDomain] The DNS domain.
#          [dnsmasqConfigAddress] The router alias address.
dnsmasqConfigRangeStart="" # Initialize the DHCP IP Address Starting Range Extracted from the dnsmasq.conf
dnsmasqConfigRangeEnd="" # Initialize the DHCP IP Address Ending Range Extracted from the dnsmasq.conf
dnsmasqConfigRange="" # Initialize the DHCP IP Address Range Count Calculated from the Starting and Ending Ranges
dnsmasqConfigDomain="" # Initialize the DNS Domain Extracted from the dnsmasq.conf
dnsmasqConfigAddress="" # Initialize the Router Alias Extracted from the dnsmasq.conf. Ex: /test.wlan/192.168.4.1 extracts as test
dnsmasqConfigExtract() {
    # Initialize the Returns
    dnsmasqConfigRangeStart=""
    dnsmasqConfigRangeEnd=""
    dnsmasqConfigRange=""
    dnsmasqConfigDomain=""
    dnsmasqConfigAddress=""

    ##################################################
    # Read the dnsmasq.conf File Line-by-Line
    while IFS=, read -r readline; do
        ##################################################
        # Search the Current Line for the DHCP IP Address Range
        if [[ "${readline}" == *"dhcp-range="* ]]; then # Found the [dhcp-range]
            # Extract the Entire Line
            dnsmasqConfigRangeEnd="${readline}"
            # Remove the [dhcp-range] Tag from the Front of the String Using #
            dnsmasqConfigRangeEnd="${dnsmasqConfigRangeEnd#*dhcp-range=}"
            # Remove Any Remaining Whitespace from the Extracted IP Address Range
            dnsmasqConfigRangeEnd="${dnsmasqConfigRangeEnd// /}"
            
            # Extract the DHCP IP Address Starting Range
            dnsmasqConfigRangeStart="${dnsmasqConfigRangeEnd%%,*}" # Remove All IP Addresses After the First Comma , | Ex: 192.168.4.2,192.168.4.9,255.255.255.0,24h to 192.168.4.2
            # Extract the DHCP IP Address Ending Range
            dnsmasqConfigRangeEnd="${dnsmasqConfigRangeEnd#*,}" # Remove the IP Address Starting Range Before the First Comma , | Ex: 192.168.4.2,192.168.4.9,255.255.255.0,24h to 192.168.4.9,255.255.255.0,24h
            dnsmasqConfigRangeEnd="${dnsmasqConfigRangeEnd%%,*}" # Remove All IP Address Starting Range After the Second Comma , (Now the First Comma) | Ex: 192.168.4.9,255.255.255.0,24h to 192.168.4.9

            # Calculate the Total Number of IP Addresses Deliverable to DHCP Clients
            dnsmasqConfigRangeStartCount="${dnsmasqConfigRangeStart##*.}" # Remove All Blocks Before the Final Period .
            dnsmasqConfigRangeEndCount="${dnsmasqConfigRangeEnd##*.}" # Remove All Blocks Before the Final Period .
            dnsmasqConfigRange=$((dnsmasqConfigRangeEndCount-dnsmasqConfigRangeStartCount)) # Subtract the Range End from the Range Start

        ##################################################
        # Search the Current Line for the DNS Domain
        elif [[ "${readline}" == *"domain="* ]]; then # Found the [domain]
            # Extract the Entire Line
            dnsmasqConfigDomain="${readline}"
            # Remove the [domain] Tag from the Front of the String Using #
            dnsmasqConfigDomain="${dnsmasqConfigDomain#*domain=}"
            # Remove Any Comments from the DNS Domain by Removing All Characters After the First Whitespace
            dnsmasqConfigDomain="${dnsmasqConfigDomain%% *}"

        ##################################################
        # Search the Current Line for the DNS Domain
        elif [[ "${readline}" == *"address="* ]]; then # Found the [domain]
            # Extract the Entire Line
            dnsmasqConfigAddress="${readline}"
            # # Remove the [address] Tag from the Front of the String Using #
            # dnsmasqConfigAddress="${dnsmasqConfigAddress#"address="}"
            # # Remove All Characters After the First Period .
            # dnsmasqConfigAddress="${dnsmasqConfigAddress%"."}"
            # # Remove Any Remaining Forward Slash / Characters
            # dnsmasqConfigAddress="${dnsmasqConfigAddress//\//}"

            # Remove All Characters Before the First Forward Slash /
            dnsmasqConfigAddress="${dnsmasqConfigAddress#*/}"
            # Remove All Characters After the Second Forward Slash / (Now the First Forward Slash)
            dnsmasqConfigAddress="${dnsmasqConfigAddress%%/*}"

        fi
    ##################################################
    done < "${dnsmasqConfig}" # Read from the dnsmasq.conf File
}

##################################################
# Extracts the Access Point configuration from the
# hostapd.conf file from a previous rpi-accessp
# installation.
#
# RETURNS: [hostapdConfigCountry] The Access Point Country Code.
#          [hostapdConfigSSID] The Access Point SSID.
#          [hostapdConfigHWMODE] The Access Point hardware mode.
#          [hostapdConfigChannel] The Access Point channel.
#          [hostapdConfigPassphrase] The Access Point WPA passphrase.
hostapdConfigCountry="" # Initialize the Access Point Country Code Extracted from the hostapd.conf
hostapdConfigSSID="" # Initialize the Access Point SSID Extracted from the hostapd.conf
hostapdConfigHWMODE="" # Initialize the Access Point Hardware Mode Extracted from the hostapd.conf
hostapdConfigChannel="" # Initialize the Access Point Channel Extracted from the hostapd.conf
hostapdConfigPassphrase="" # Initialize the Access Point WPA Passphrase Extracted from the hostapd.conf
hostapdConfigExtract() {
    # Initialize the Returns
    hostapdConfigCountry=""
    hostapdConfigSSID=""
    hostapdConfigHWMODE=""
    hostapdConfigChannel=""
    hostapdConfigPassphrase=""

    ##################################################
    # Read the hostapd.conf File Line-by-Line
    while IFS=, read -r readline; do
        ##################################################
        # Search the Current Line for the Country Code
        if [[ "${readline}" == *"country_code="* ]]; then # Found the [country_code]
            # Extract the Entire Line
            hostapdConfigCountry="${readline}"
            # Remove the [country_code] Tag from the Front of the String Using #
            hostapdConfigCountry="${hostapdConfigCountry#*country_code=}"
            # Remove Any Remaining Whitespace from the Extracted Country Code
            hostapdConfigCountry="${hostapdConfigCountry// /}"

        ##################################################
        # Search the Current Line for the SSID
        elif [[ "${readline}" == *"ssid="* && "${readline}" != *"_ssid="* ]]; then # Found the [ssid]
            # Extract the Entire Line
            hostapdConfigSSID="${readline}"
            # Remove the [ssid] Tag from the Front of the String Using #
            hostapdConfigSSID="${hostapdConfigSSID#*ssid=}"
            # # Remove Any Remaining Whitespace from the Extracted SSID
            # hostapdConfigSSID="${hostapdConfigSSID// /}"

        ##################################################
        # Search the Current Line for the Hardware Mode
        elif [[ "${readline}" == *"hw_mode="* ]]; then # Found the [hw_mode]
            # Extract the Entire Line
            hostapdConfigHWMODE="${readline}"
            # Remove the [hw_mode] Tag from the Front of the String Using #
            hostapdConfigHWMODE="${hostapdConfigHWMODE#*hw_mode=}"
            # Remove Any Remaining Whitespace from the Extracted Hardware Mode
            hostapdConfigHWMODE="${hostapdConfigHWMODE// /}"

        ##################################################
        # Search the Current Line for the Channel
        elif [[ "${readline}" == *"channel="* ]]; then # Found the [channel]
            # Extract the Entire Line
            hostapdConfigChannel="${readline}"
            # Remove the [channel] Tag from the Front of the String Using #
            hostapdConfigChannel="${hostapdConfigChannel#*channel=}"
            # Remove Any Remaining Whitespace from the Extracted Channel
            hostapdConfigChannel="${hostapdConfigChannel// /}"

        ##################################################
        # Search the Current Line for the WPA Passphrase
        elif [[ "${readline}" == *"wpa_passphrase="* ]]; then # Found the [wpa_passphrase]
            # Extract the Entire Line
            hostapdConfigPassphrase="${readline}"
            # Remove the [wpa_passphrase] Tag from the Front of the String Using #
            hostapdConfigPassphrase="${hostapdConfigPassphrase#*wpa_passphrase=}"
            # # Remove Any Remaining Whitespace from the Extracted WPA Passphrase
            # hostapdConfigPassphrase="${hostapdConfigPassphrase// /}"

        fi
    ##################################################
    done < "${hostapdConfig}" # Read from the hostapd.conf File
}

##################################################
# Enables and disables the Access Point by commenting
# and uncommenting out the Access Point configuration
# within the dhcpcd.conf file.
#
# [enabled] "enable" or "disable" Based on the desired Access Point enabled status. Leave empty to return the current enabled status.
# RETURNS: 0 if the Access Point is enabled, 1 if it is disabled.
accessPointStatus() {
    # Extract the Inputs
    newAccessPointStatus="${1}"

    ##################################################
    # Read the dhcpcd.conf File Line-by-Line and Search for the [ip_address] and the Enabled Status
    oldAccessPointStatus="enable" # Initialize the Current Access Point Status as Enabled
    while IFS=, read -r readline; do
        # Search the Current Line for the [ip_address] and Check the Enabled Status of the Access Point by Checking if the [ip_address] is Commented Out
        if [[ "${readline}" == *"static ip_address="* && "${readline:0:1}" == "#" ]]; then # Found the [ip_address] and the First Character in the Line is a Number Sign #
            # The [ip_address] is Commented Out, the Access Point is Disabled
            oldAccessPointStatus="disable"; fi
    ##################################################
    done < "${dhcpcdConfig}" # Read from the dhcpcd.conf File

    ##################################################
    # Update the Access Point Status if a New Enabled Status was Input
    if [[ -n "$newAccessPointStatus" ]]; then if [[ "$newAccessPointStatus" == "enable" || "$newAccessPointStatus" == "disable" ]]; then # The Input Access Point Enabled Status is Valid
        # Update the Access Point Status if the Desired Input Access Point Enabled Status is Not the Current Access Point Status
        if [[ "$oldAccessPointStatus" != "$newAccessPointStatus" ]]; then # The Current and Desired Enabled Status are Different
            # Read the dhcpcd.conf File and Edit the Access Point Status
            ##################################################
            # Initialize the Temporary File for Writing the Output Line-by-Line
            dhcpcdConfigTemp="${dhcpcdConfig}.temp" # Initialize the Name of the Temporary File
            sudo truncate -s 0 "$dhcpcdConfigTemp" # Create the Empty Temporary File, -s 0 for Empty Size 
 
            ##################################################
            # Read the dhcpcd.conf File Line-by-Line, Comment Out Each Line, and Write to a Temporary File
            dhcpcdConfigAPTagFound="false" # Determines Whether or Not the #rpi-accessp Tag has been Found
            while IFS=, read -r readline; do
                # Import the Line for Writing
                writeline="${readline}"

                ##################################################
                # Search for the #rpi-accessp Tag Until Found
                if [[ "$dhcpcdConfigAPTagFound" == "false" ]]; then
                    # Flag the #rpi-accessp Tag as Found and to Begin Commenting Out the Next Lines
                    if [[ "${readline}" == *"${rpiAccesspTag}"* ]]; then dhcpcdConfigAPTagFound="true"; fi
                ##################################################
                else # The #rpi-accessp Tag is Found, Enable the Access Point
                    if [[ "$newAccessPointStatus" == "enable" ]]; then
                        # Continue Uncommenting Each Line Until the [nohook wpa_supplicant] Tag is Found
                        if [[ "${readline}" == *"nohook wpa_supplicant"* ]]; then # Found the [nohook wpa_supplicant] Tag, Stop Uncommenting Lines
                            # Uncomment the Line
                            writeline="${writeline:1}" # Start the String at the Second Character to Remove the Number Sign # Character
                            # Stop Uncommenting Lines
                            dhcpcdConfigAPTagFound="false"
                        # Uncomment the Line
                        else writeline="${writeline:1}"; fi # Start the String at the Second Character to Remove the Number Sign # Character
                    ##################################################
                    # The #rpi-accessp Tag is Found, Disable the Access Point
                    elif [[ "$newAccessPointStatus" == "disable" ]]; then
                        # Continue Commenting Out Each Line Until the [nohook wpa_supplicant] Tag is Found
                        if [[ "${readline}" == *"nohook wpa_supplicant"* ]]; then # Found the [nohook wpa_supplicant] Tag, Stop Commenting Out Lines
                            # Comment Out the Line
                            writeline="#${writeline}" # Append a Number SIgn # Character to the Start the of String
                            # Stop Commenting Out Lines
                            dhcpcdConfigAPTagFound="false"
                        # Comment Out the Line
                        else writeline="#${writeline}"; fi # Append a Number SIgn # Character to the Start the of String
                    fi
                fi

                ##################################################
                # Write the Line Output to the Temporary File
                echo "${writeline}" | sudo tee -a "$dhcpcdConfigTemp" > /dev/null # tee -a to Append the Line to the File

            ##################################################
            done < "${dhcpcdConfig}" # Read from the dhcpcd.conf File
            ##################################################
            # Replace the dhcpcd.conf File with the Temporary File
            sudo rm "${dhcpcdConfig}" && sudo mv "${dhcpcdConfigTemp}" "${dhcpcdConfig}" # Remove and Replace the File

            ##################################################
            # Unmask the Access Point Service Status and Unblock the WiFi Radio if it was Disabled
            if [[ "$newAccessPointStatus" == "enable" ]]; then sudo systemctl -q unmask hostapd && sudo rfkill unblock wlan > /dev/null; fi
            # Update the Access Point Service Status
            sudo systemctl -q "$newAccessPointStatus" hostapd
        fi
    # No Access Point Enabled Status was Input, Store the Current Access Point Status for Returning Below
    else newAccessPointStatus="$oldAccessPointStatus"; fi; fi

    ##################################################
    # Properly Return the Enabled Status
    if [[ "$newAccessPointStatus" == "enable" ]]; then return 0
    elif [[ "$newAccessPointStatus" == "disable" ]]; then return 1; fi
}

##################################################
# W H I P T A I L
##################################################

##################################################
# Applies Training Mode's Overflow Theme to Whiptail.
#
# [color] The main color for the theme.
#     Supported: red, green, blue, cyan, & magenta.
# [foreground] The foreground color for the theme. Text, etc.
# [background] The background color for the theme.
# [root] The terminal background color for the theme.
whiptailThemeOverflow() {
    # Export Whiptail Colors to newt
    export NEWT_COLORS="
        root=${2},${4}

        window=${2},bright${1}
        border=${1},bright${1}
        title=${2},${1}

        textbox=${2},bright${1}
        acttextbox=${2},${1}

        entry=${2},${1}
        disentry=${2},gray

        listbox=${2},bright${1}
        actsellistbox=${2},${1}
        actlistbox=bright${1},${1}

        compactbutton=bright${1},${1}
        actbutton=bright${1},${1}
        button=${2},${1}

        fullscale=${2},${1}
        emptyscale=${2},${3}
    "
}

####################################################
# Applies a color theme to Whiptail based on the
# input [color] using the Overflow Theme.
#
# [color] The main color for the theme.
#     Supported: red, green, blue, cyan, & magenta.
# [colorRoot] The terminal background color for the theme. Default is "black".
whiptailColorTheme() {
    # Default Inputs
    rootColor="black"
    if [[ -n "${2}" ]]; then rootColor="${2}"; fi # Set the Root Color if a Color was Specified
    # Set the Appropriate Overflow Theme Foreground and Background Colors
    fgColor="white";  bgColor="black";
    if [[ "${1}" == "green" || "${1}" == "cyan" ]]; then
        # Use Black on White for Brighter Colors
        fgColor="black"; bgColor="white"; fi
    # Set the Whiptail Theme
    whiptailThemeOverflow "${1}" "${fgColor}" "${bgColor}" "${rootColor}"
}

####################################################
# Set the Whiptail Theme Color
whiptailCurrentThemeColor="green"
whiptailCurrentThemeColorWarning="red"
whiptailColorTheme "$whiptailCurrentThemeColor"
####################################################
# Set the Whiptail Theme Size
whiptailGaugeWindowSize=(7 50) #"${whiptailGaugeWindowSize[@]}"

####################################################
# Opens a Whiptail dialog to ask for a valid file
# or directory path, depending on the input flags.
#
# [titleText] The title of the Whiptail dialog.
# [descriptionText] The description for the Whiptail dialog.
#   -d | Dialog with checks for directory paths.
# RETURNS: [path] The user specified path.
whiptailInputPathReturn="" # Initialize the Function Return
whiptailInputPath() {
    # Extract Flags
    local OPTIND=1 # Initialize the Options Index
    cflag=""
    dflag=""
    jflag=""
    cancelButtonText="EXIT"
    isDirectory="false"
    jumptoExitTag="customreset"
    while getopts "d" flag; do
        case "${flag}" in
            c) cflag="-${flag}"; cancelButtonText="${OPTARG}" ;;
            d) dflag="-${flag}"; isDirectory="true" ;;
            j) jflag="-${flag}"; jumptoExitTag="${OPTARG}" ;;
            *) echo "Unhandled argument." ;;
    esac; done; shift $((OPTIND-1)) # Reset the Options Index
    # Initialize the Function Returns
    whiptailInputPathReturn=""

    # Set the Specified Dialog Options
    pathDialogText="file"
    pathDialogTitleText="FILE"
    if [[ $isDirectory == "true" ]]; then
        pathDialogText="directory"
        pathDialogTitleText="DIRECTORY"; fi

    # Initialize the Custom Readme File Path for Replacing Invalid Whiptail Input Dialog Entries
    inputPath=""
    while true; do # Loop Until a Valid Readme File is Entered
        # Specify the Readme Filepath
        ##################################################
        # Whiptail Input for Directory Path
        whiptailInputDialogPath=$(whiptail --title " ${1} " --ok-button "OK" --cancel-button "${cancelButtonText}" \
            --inputbox "\n${2}" 0 0 ${inputPath} \
            3>&1 1>&2 2>&3 ) dialogExit=$? ###############
        # Whiptail Dialog Canceled, Exit the Path Installer
        if [[ $dialogExit != 0 ]]; then jumpto "${jumptoExitTag}"; fi # Reset the Customizer Back to Start
        ##################################################
        # Store the Input Path
        inputPath="${whiptailInputDialogPath}"
        ##################################################
        # Confirm the Specified Path Exists
        if [[ -e "${whiptailInputDialogPath}" ]]; then
            # Specified Path Exists, Return the Path
            whiptailInputPathReturn="${whiptailInputDialogPath}"
            return 0 # Return Without Errors
        ##################################################
        # Specified Directory Does Not Exist
        else whiptail --title " INVALID $pathDialogTitleText " --msgbox "The input $pathDialogText does not exist." 0 0 --ok-button "OK" 3>&1 1>&2 2>&3; fi
        ##################################################
    done
}

####################################################
# Ensure package is installed and asks to install
# if the package is not found.
#
# [packageCommand] The package to check for. Ex: npm
# RETURNS: [installStatus] 0 if the package is installed, 1 if it is NOT installed.
whiptailPackageStatus() {
    # Extract Inputs
    packageCommand="${1}"

    # Ensure the Specified Package is Installed
    if command -v "${packageCommand}" > /dev/null; then # [command] to Check Installed Programs/Commands Only
        # Return that the Package is Installed
        return 0

    # Package Not Found, Prompt to Install the Missing Package
    else
        ##################################################
        # Whiptail Confiration to Install Package
        if (whiptail --title " ${packageCommand^^} REQUIRED " --yesno "${packageCommand} is required.\nWould you like to install ${packageCommand}?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
            ####################################################
            # Install the Input Package
            { ##################################################
            echo 45 # Move Progress Gauge
            sudo apt-get install "${packageCommand}" -y > /dev/null
            echo 100
            } | whiptail --gauge "\nInstalling ${packageCommand}..." "${whiptailGaugeWindowSize[@]}" 0
            # Return that the Package is Installed
            return 0
        # Return that the Package is Not Installed
        else return 1; fi

    fi
}

##################################################
##################################################
#
# S C R I P T
#
##################################################
##################################################

##################################################
# Properly Cleans Up whenever rpi-accessp is Exited
accesspCleanUp() {
    ##################################################
    # Clear the ANSI xterm Terminal
    TERM=ansi whiptail --clear --infobox "Cleaning up..." 0 0 
    ##################################################
}
# Properly Exits rpi-accessp
accesspExit() { accesspCleanUp; exit; }

##################################################
#
# P R E P A R A T I O N
#
##################################################

##################################################
# Ensure the Access Point Software is Installed
##################################################

##################################################
# Ensure the Access Point Software hostapd is Installed
if ! whiptailPackageStatus hostapd; then # hostapd is Not Installed, Cancel Access Point Setup
    ##################################################
    whiptail --title " SETUP CANCELLED " --msgbox "hostapd was not installed. Access point setup cancelled." 0 0 --ok-button "OK"
    ##################################################
    accesspExit; fi
##################################################
# Ensure dnsmasq is Installed for DNS & DHCP Services
if ! whiptailPackageStatus dnsmasq; then # dnsmasq is Not Installed, Cancel Access Point Setup
    ##################################################
    whiptail --title " SETUP CANCELLED " --msgbox "dnsmasq was not installed. Access point setup cancelled." 0 0 --ok-button "OK"
    ##################################################
    accesspExit; fi

##################################################
# Construct the Newtork Router Setup
##################################################

##################################################
TERM=ansi whiptail --title " CHECKING NETWORK ROUTER " --infobox "Checking if a previous network router\nwas configured on this device..." 0 0 
##################################################
# Check if Previous rpi-accessp Network Router dhcpcd.conf Configuration Exists
accessPointExists="false" # Initialize Whether or Not the Access Point is Enabled
if [[ -e "${dhcpcdConfig}" ]]; then # Previous dhcpcd.conf File was Found
    ##################################################
    # Search the Entire dhcpcd.conf File for the #rpi-accessp Tag
    if [[ $(<"${dhcpcdConfig}") == *"${rpiAccesspTag}"* ]]; then # The #rpi-accessp Tag was Found
        accessPointExists="true" # Flag the Access Point as Enabled
        # Safely Extract the Static IP Address and Subnet Mask
        if dhcpcdConfigExtract; then # The [ip_address] was Found
            ##################################################
            TERM=ansi whiptail --title " ACCESS POINT FOUND " --infobox "Reading the previous access point configuration..." 0 0 
            ##################################################
        else # The [ip_address] was Not Found
            ##################################################
            whiptail --title " IP ADDRESS ERROR " --msgbox "A previous Access Point was found, but \nthe IP address could not be extracted." 0 0 --ok-button "OK"
            ##################################################
        fi
    ##################################################
    # The #rpi-accessp Tag was Not Found in the dhcpcd.conf File, Backup the Original File
    else sudo cp -b "${dhcpcdConfig}" "${dhcpcdConfig}.orig"; fi # -b to Backup and Prevent Overwriting Previous Files
fi
##################################################
# Initialize the dhcpcd.conf File if a Previous Access Point was Not Found
if [[ "$accessPointExists" == "false" ]]; then
    ##################################################
    # Whiptail Confiration to Install an Access Point
    if (! whiptail --title " ACCESS POINT INSTALL " --yesno "An access point is not configured.\nWould you like to install an access point?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
        # Whiptail Dialog Exited, Exit the Access Point Installation
        ##################################################
        whiptail --title " CANCELLED SETUP " --msgbox "The access point setup was cancelled." 0 0 --ok-button "OK"
        ##################################################
        accesspExit; fi # Exit the Access Point Setup
    ##################################################

    ##################################################
    TERM=ansi whiptail --title " CREATING ACCESS POINT " --infobox "Creating a new access point configuration..." 0 0 
    ##################################################
    # Import the Default Recommended IP Address https://www.raspberrypi.org/documentation/configuration/wireless/access-point-routed.md
    dhcpcdConfigIP="192.168.4.1"
    dhcpcdConfigMask="24"
    accessPointEnabled="false" # Flag the Access Point as Disabled, as the Access Point Service Needs First Initialization
    # Write a New dhcpcd.conf Configuration File, Initialized as Disabled by Commenting Out Each Line
    echo -e "${rpiAccesspTag} Access Point\n#interface wlan0\n#    static ip_address=${dhcpcdConfigIP}/${dhcpcdConfigMask}\n#    nohook wpa_supplicant\n" | sudo tee "${dhcpcdConfig}" > /dev/null
fi

##################################################
# Construct the DHCP & DNS Configuration
##################################################

##################################################
TERM=ansi whiptail --title " CHECKING DHCP & DNS " --infobox "Checking if a previous DHCP & DNS\nservice was configured on this device..." 0 0 
##################################################
# Check if Previous rpi-accessp DHCP & DNS dnsmasq.conf Configuration Exists
dnsmasqExists="false" # Initialize Whether or Not the DHCP & DNS Service have been Configured
if [[ -e "${dnsmasqConfig}" ]]; then # Previous dnsmasq.conf File was Found
    ##################################################
    # Search the Entire dnsmasq.conf File for the #rpi-accessp Tag
    if [[ $(<"${dnsmasqConfig}") == *"${rpiAccesspTag}"* ]]; then # The #rpi-accessp Tag was Found
        dnsmasqExists="true" # Flag the DHCP & DNS Services as Enabled
        ##################################################
        whiptail --title " READING DHCP & DNS CONFIG " --infobox "A previous DHCP & DNS service was found.\nExtracting the DHCP & DNS service configuration... " 0 0
        ##################################################
        # Safely Extract the DHCP & DNS Service Configuration
        dnsmasqConfigExtract
    ##################################################
    # The #rpi-accessp Tag was Not Found in the dnsmasq.conf File, Backup the Original dnsmasq.conf File
    else sudo mv -b "${dnsmasqConfig}" "${dnsmasqConfig}.orig"; fi # -b to Backup and Prevent Overwriting Previous Files
fi
##################################################
# Initialize the dnsmasq.conf File if a DHCP & DNS Configuration was Not Found
if [[ "$dnsmasqExists" == "false" ]]; then
    ##################################################
    TERM=ansi whiptail --title " CREATING DHCP & DNS SERVICE " --infobox "Creating a new DHCP & DNS service configuration..." 0 0 
    ##################################################
    # Import the Default Recommended Setup https://www.raspberrypi.org/documentation/configuration/wireless/access-point-routed.md
    dnsmasqConfigRangeStart="192.168.4.2"
    dnsmasqConfigRangeEnd="192.168.4.20"
    dnsmasqConfigRange="18"
    dnsmasqConfigDomain="wlan"
    dnsmasqConfigAddress="gw.wlan"
    # Write a New dnsmasq.conf Configuration File
    echo -e "${rpiAccesspTag} DHCP & DNS Service\ninterface wlan0\ndhcp-range=${dnsmasqConfigRangeStart},${dnsmasqConfigRangeEnd},255.255.255.0,24h\ndomain=${dnsmasqConfigDomain}\naddress=/${dnsmasqConfigAddress}/${dhcpcdConfigIP}\n" | sudo tee "${dnsmasqConfig}" > /dev/null
fi

##################################################
# Construct the Access Point Configuration
##################################################

##################################################
TERM=ansi whiptail --title " CHECKING ACCESS POINT " --infobox "Checking if a previous access point\nwas configured on this device..." 0 0 
##################################################
# Check if Previous rpi-accessp Access Point hostapd.conf Configuration Exists
hostapdExists="false" # Initialize Whether or Not the Access Point Service have been Configured
if [[ -e "${hostapdConfig}" ]]; then # Previous hostapd.conf File was Found
    ##################################################
    whiptail --title " READING ACCESS POINT " --infobox "A previous access point was found.\nExtracting the access point configuration... " 0 0
    ##################################################
    hostapdExists="true" # Flag the Access Point Services as Enabled
    # Safely Extract the Access Point Service Configuration
    hostapdConfigExtract
fi
##################################################
# Initialize the hostapd.conf File if a Access Point Configuration was Not Found
if [[ "$hostapdExists" == "false" ]]; then
    ##################################################
    TERM=ansi whiptail --title " CREATING ACCESS POINT SERVICE " --infobox "Creating a new Access Point service configuration..." 0 0 
    ##################################################
    # Import the Default Recommended Setup https://www.raspberrypi.org/documentation/configuration/wireless/access-point-routed.md
    hostapdConfigCountry="GB"
    hostapdConfigSSID="NameOfNetwork"
    hostapdConfigHWMODE="g"
    hostapdConfigChannel="7"
    hostapdConfigPassphrase="AardvarkBadgerHedgehog"
    # Write a New hostapd.conf Configuration File
    echo -e "country_code=${hostapdConfigCountry}\ninterface=wlan0\nssid=${hostapdConfigSSID}\nhw_mode=${hostapdConfigHWMODE}\nchannel=${hostapdConfigChannel}\nmacaddr_acl=0\nauth_algs=1\nignore_broadcast_ssid=0\nwpa=2\nwpa_passphrase=${hostapdConfigPassphrase}\nwpa_key_mgmt=WPA-PSK\nwpa_pairwise=TKIP\nrsn_pairwise=CCMP\n" | sudo tee "${hostapdConfig}" > /dev/null
fi

##################################################
#
# A C C E S S  P O I N T  S E T U P
#
##################################################

##################################################
# Initialize Whether or Not a Reboot is Required
# Used to Prompt for Reboot After Configuration
accesspRebootRequired="false"

##################################################
# Loop Until Exited
while true; do

    ##################################################
    # Determine the Enabled or Disable Menu Option
    accesspSetupEnableMenuItem=(" ENABLE" "Enable the access point.") # Initialize the Access Point Enable Menu Item for an Disabled Access Point
    if [[ "$accessPointEnabled" == "true" ]]; then # The Access Point is Currently Enabled
        # Set the Access Point Disable Menu Item for an Enabled Access Point
        accesspSetupEnableMenuItem=("DISABLE" "Disable the access point." "CONNECT" "Guide for new connections."); fi
    ##################################################
    # Whiptail Menu for rpi-accessp Setup
    accesspSetupMenu=$(
        whiptail --title " ACCESS POINT SETUP " --ok-button "OK" --cancel-button "EXIT" \
        --menu "\nWhat would you like to do?" 0 0 0 \
        "${accesspSetupEnableMenuItem[@]}" \
        " CONFIG" "Configure the access point." \
        " REMOVE" "Uninstall the access point." \
    3>&2 2>&1 1>&3 ) dialogExit=$? ##################
    # Whiptail Dialog Canceled, Exit rpi-accessp
    if [[ $dialogExit != 0 ]]; then
        # Prompt to Reboot if a Configuration was Updated
        if [[ "$accesspRebootRequired" == "true" ]]; then
            ##################################################
            # Whiptail Confiration to Reboot
            if (whiptail --title " REBOOT REQUIRED " --yesno "A reboot is required to apply the changes.\nWould you like to reboot now?" 0 0 --defaultno --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
                # Reboot to Apply the Changes
                sudo systemctl reboot
            # Do Not Reboot
            else accesspExit; fi # Exit rpi-accessp
            ##################################################
        # No Reboot Necessary
        else accesspExit; fi # Exit rpi-accessp
    fi
    ##################################################
    # Determine the Menu Item Selection
    ##################################################
    # Remove All Whitespace from the Selected Menu Item
    accesspSetupMenu="${accesspSetupMenu// /}"
    ##################################################
    # Update the Access Point Enabled Status
    if [[ "$accesspSetupMenu" == "ENABLE" || "$accesspSetupMenu" == "DISABLE" ]]; then
        ##################################################
        TERM=ansi whiptail --title " UPDATING STATUS " --infobox "Updating the access point status..." 0 0 
        ##################################################
        # Safely Update the Access Point Status Using the Menu Item with All Lowercase ,, Letters
        if accessPointStatus "${accesspSetupMenu,,}"; then # The Access Point was Enabled
            # Flag the Intrernal Access Point Status as Enabled
            accessPointEnabled="true"
            ##################################################
            whiptail --title " ACCESS POINT ENABLED " --msgbox "The access point was enabled." 0 0 --ok-button "OK"
            ##################################################
        # The Access Point was Disabled
        else # Show the Access Point Disabled Status
            # Flag the Intrernal Access Point Status as Disabled
            accessPointEnabled="false"
            ##################################################
            whiptail --title " ACCESS POINT DISABLE " --msgbox "The access point was disabled." 0 0 --ok-button "OK"
            ##################################################
        fi
        # Flag that a Reboot is Required
        accesspRebootRequired="true"
        ##################################################
        # Whiptail Confiration to Reboot
        if (whiptail --title " REBOOT REQUIRED " --yesno "A reboot is required to apply the changes.\nWould you like to reboot now?" 0 0 --defaultno --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
            # Reboot to Apply the Changes
            sudo systemctl reboot
        ##################################################
        # Do Not Reboot, Clear the ANSI xterm Terminal
        else TERM=ansi whiptail --clear --infobox "Access point status updated." 0 0; fi
        ##################################################
            
    ##################################################
    # Update the Access Point Configuration
    elif [[ "$accesspSetupMenu" == "CONFIG" ]]; then
        # Loop Until Exited
        while true; do
            ##################################################
            # Determine the Proper Hardware Mode and Channel Menu List Items
            accesspConfigHWModeChannelMenuItem=("    HW MODE" "$hostapdConfigHWMODE") # Initialize the Channel Menu List Items Without the Channel
            if [[ "$hostapdConfigHWMODE" == "a" ]]; then # The Access Point Hardware Mode is 802.11a for 5GHz
                # Add the Channel to the Menu List Item, as the Hardware Mode may Require Channel Setup
                accesspConfigHWModeChannelMenuItem=("    HW MODE" "$hostapdConfigHWMODE" "    CHANNEL" "$hostapdConfigChannel"); fi
            ##################################################
            # Whiptail Menu for rpi-accessp Configuration
            accesspConfigMenu=$(
                whiptail --title " ACCESS POINT CONFIG " --ok-button "OK" --cancel-button "APPLY" \
                --menu "\nWhat would you like to configure?" 0 0 0 \
                "       SSID" "${hostapdConfigSSID}" \
                " PASSPHRASE" "${hostapdConfigPassphrase}" \
                "  STATIC IP" "${dhcpcdConfigIP}" \
                "      ALIAS" "${dnsmasqConfigAddress}" \
                " DNS DOMAIN" "${dnsmasqConfigDomain}" \
                " DHCP START" "${dnsmasqConfigRangeStart}" \
                "CONNECTIONS" "${dnsmasqConfigRange}" \
                "    COUNTRY" "${hostapdConfigCountry}" \
                "    IP MASK" "${dhcpcdConfigMask}" \
                "${accesspConfigHWModeChannelMenuItem[@]}" \
            3>&2 2>&1 1>&3 ) dialogExit=$? ##################
            # Whiptail Dialog Canceled, Return to the rpi-accessp Main Menu
            if [[ $dialogExit != 0 ]]; then
                # Prompt to Reboot if a Configuration was Updated
                if [[ "$accesspRebootRequired" == "true" ]]; then
                    ##################################################
                    # Whiptail Confiration to Reboot
                    if (whiptail --title " REBOOT REQUIRED " --yesno "A reboot is required to apply the changes.\nWould you like to reboot now?" 0 0 --defaultno --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
                        # Reboot to Apply the Changes
                        sudo systemctl reboot
                    # Do Not Reboot
                    else break; fi # Exit rpi-accessp Configuration Menu
                    ##################################################
                # No Reboot Necessary
                else break; fi # Exit rpi-accessp Configuration Menu
            fi
            ##################################################
            # Extract the Selected Menu Item Without Leading Whitespaces
            accesspConfigMenuSelected="$(echo "$accesspConfigMenu" | sed 's/^ *//')"
            # Edit the Selected Access Point Config Menu Item
            case "$accesspConfigMenuSelected" in
                ##################################################
                "SSID") # Edit the SSID
                    ##################################################
                    defaultInputValue="${hostapdConfigSSID}" # Import the Default Input Box Value
                    accesspSSID=$(whiptail --title " $accesspConfigMenuSelected " --inputbox "\nPlease type the new $accesspConfigMenuSelected." 0 0 $defaultInputValue --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
                    # Whiptail Dialog Confimred, Continue Updating the Configuration
                    if [[ $dialogExit == 0 ]]; then
                        ##################################################
                        # Update the hostapd.conf SSID
                        ##################################################
                        TERM=ansi whiptail --title " UPDATING $accesspConfigMenuSelected " --infobox "Updating the access point configuration..." 0 0
                        ##################################################
                        # Config Tag and File
                        configTag='ssid='
                        confFile="${hostapdConfig}"
                        # Edit the Configuration File # Match Config Tag from the Start to End of Line # Replacement Value # Configuration File
                        sudo sed -i 's|^'"$configTag"'.*|'"${configTag}${accesspSSID}"'|' "${confFile}"
                        ##################################################
                        # Update the Internal Config Value
                        hostapdConfigSSID="${accesspSSID}"
                        # Flag that a Reboot is Required
                        accesspRebootRequired="true"
                    fi;;
                ##################################################
                "PASSPHRASE") # Edit the Passphrase
                    ##################################################
                    defaultInputValue="${hostapdConfigPassphrase}" # Import the Default Input Box Value
                    accesspPassphrase=$(whiptail --title " $accesspConfigMenuSelected " --inputbox "\nPlease type the new $accesspConfigMenuSelected." 0 0 $defaultInputValue --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
                    # Whiptail Dialog Confimred, Continue Updating the Configuration
                    if [[ $dialogExit == 0 ]]; then
                        ##################################################
                        # Update the hostapd.conf Passphrase
                        ##################################################
                        TERM=ansi whiptail --title " UPDATING $accesspConfigMenuSelected " --infobox "Updating the access point configuration..." 0 0
                        ##################################################
                        # Config Tag and File
                        configTag='wpa_passphrase='
                        confFile="${hostapdConfig}"
                        # Edit the Configuration File # Match Config Tag from the Start to End of Line # Replacement Value # Configuration File
                        sudo sed -i 's|'"$configTag"'.*|'"${configTag}${accesspPassphrase}"'|' "${confFile}"
                        ##################################################
                        # Update the Internal Config Value
                        hostapdConfigPassphrase="${accesspPassphrase}"
                        # Flag that a Reboot is Required
                        accesspRebootRequired="true"
                    fi;;
                ##################################################
                "STATIC IP") # Edit the Static IP Address
                    ##################################################
                    defaultInputValue="${accesspStaticIP}" # Import the Default Input Box Value
                    accesspStaticIP=$(whiptail --title " $accesspConfigMenuSelected " --inputbox "\nPlease type the new $accesspConfigMenuSelected." 0 0 $defaultInputValue --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
                    # Whiptail Dialog Confimred, Continue Updating the Configuration
                    if [[ $dialogExit == 0 ]]; then
                        ##################################################
                        # Update the dhcpcd.conf Static IP Address
                        ##################################################
                        TERM=ansi whiptail --title " UPDATING $accesspConfigMenuSelected " --infobox "Updating the access point configuration..." 0 0
                        ##################################################
                        # Config Tag and File
                        configTag='static ip_address='
                        confFile="${dhcpcdConfig}"
                        # Edit the Configuration File # Match Config Tag to End of Line # Replacement Value # Configuration File
                        sudo sed -i 's|'"$configTag"'.*|'"${configTag}${accesspStaticIP}/${dhcpcdConfigMask}"'|' "${confFile}"
                        ##################################################
                        # Update the dnsmasq.conf Static IP Address
                        ##################################################
                        # Config Tag and File
                        configTag='address='
                        confFile="${dnsmasqConfig}"
                        # Edit the Configuration File # Match Config Tag to End of Line # Replacement Value # Configuration File
                        sudo sed -i 's|'"$configTag"'.*|'"${configTag}/${dnsmasqConfigAddress}/${accesspStaticIP}"'|' "${confFile}"
                        ##################################################
                        # Update the Internal Config Value
                        dhcpcdConfigIP="${accesspStaticIP}"
                        # Flag that a Reboot is Required
                        accesspRebootRequired="true"
                    fi;;
                ##################################################
                "ALIAS") # Edit the Static IP Address Alias
                    ##################################################
                    defaultInputValue="${dnsmasqConfigAddress}" # Import the Default Input Box Value
                    accesspAddress=$(whiptail --title " $accesspConfigMenuSelected " --inputbox "\nPlease type the new $accesspConfigMenuSelected." 0 0 $defaultInputValue --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
                    # Whiptail Dialog Confimred, Continue Updating the Configuration
                    if [[ $dialogExit == 0 ]]; then
                        ##################################################
                        # Update the dnsmasq.conf Static IP Address Alias
                        ##################################################
                        TERM=ansi whiptail --title " UPDATING $accesspConfigMenuSelected " --infobox "Updating the access point configuration..." 0 0
                        ##################################################
                        # Config Tag and File
                        configTag='address='
                        confFile="${dnsmasqConfig}"
                        # Edit the Configuration File # Match Config Tag to End of Line # Replacement Value # Configuration File
                        sudo sed -i 's|'"$configTag"'.*|'"${configTag}/${accesspAddress}/${dhcpcdConfigIP}"'|' "${confFile}"
                        ##################################################
                        # Update the Internal Config Value
                        dnsmasqConfigAddress="${accesspAddress}"
                        # Flag that a Reboot is Required
                        accesspRebootRequired="true"
                    fi;;
                ##################################################
                "DNS DOMAIN") # Edit the DNS Domain
                    ##################################################
                    defaultInputValue="${dnsmasqConfigDomain}" # Import the Default Input Box Value
                    accesspDomain=$(whiptail --title " $accesspConfigMenuSelected " --inputbox "\nPlease type the new $accesspConfigMenuSelected." 0 0 $defaultInputValue --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
                    # Whiptail Dialog Confimred, Continue Updating the Configuration
                    if [[ $dialogExit == 0 ]]; then
                        ##################################################
                        # Update the dnsmasq.conf DNS Domain
                        ##################################################
                        TERM=ansi whiptail --title " UPDATING $accesspConfigMenuSelected " --infobox "Updating the access point configuration..." 0 0
                        ##################################################
                        # Config Tag and File
                        configTag='domain='
                        confFile="${dnsmasqConfig}"
                        # Edit the Configuration File # Match Config Tag to End of Line # Replacement Value # Configuration File
                        sudo sed -i 's|'"$configTag"'.*|'"${configTag}${accesspDomain}"'|' "${confFile}"
                        ##################################################
                        # Update the Internal Config Value
                        dnsmasqConfigDomain="${accesspDomain}"
                        # Flag that a Reboot is Required
                        accesspRebootRequired="true"
                    fi;;
                ##################################################
                "DHCP START") # Edit the DHCP Starting Range
                    ##################################################
                    defaultInputValue="${dnsmasqConfigRangeStart}" # Import the Default Input Box Value
                    accesspRangeStart=$(whiptail --title " $accesspConfigMenuSelected " --inputbox "\nPlease type the new $accesspConfigMenuSelected." 0 0 $defaultInputValue --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
                    # Whiptail Dialog Confimred, Continue Updating the Configuration
                    if [[ $dialogExit == 0 ]]; then
                        ##################################################
                        # Extract the Input DHCP IP Base and Starting Range
                        accesspRangeBase="${accesspRangeStart%.*}" # Extract the IP Base by Removing the Block After the Final Period . | Ex: 192.168.4.2 extracts as 192.168.4
                        accesspRangeEnd="${accesspRangeStart##*.}" # Extract the Last Block by Removing All Blocks Before the Final Period . | Ex: 192.168.4.2 extracts as 2
                        # Ensure the DHCP Ending Range Does Not Overflow
                        if [[ $((accesspRangeEnd+dnsmasqConfigRange)) -gt 255 ]]; then # The Desired DHCP IP Address Range is Overflowing
                            # Decrease and Update the Total Allowed Connections
                            dnsmasqConfigRange=$((255-accesspRangeEnd)) # Calcuate the Delta Between the Starting Range and the Maximum Range
                            ##################################################
                            whiptail --title " IP RANGE OVERFLOW " --msgbox "The specified DHCP range is out of bounds.\n\nPlease choose another starting range to\nincrease the $dnsmasqConfigRange available connections." 0 0 --ok-button "OK"; fi
                            ##################################################
                        # Calculate the DHCP Ending Range
                        accesspRangeEnd="${accesspRangeBase}."$((accesspRangeEnd+dnsmasqConfigRange)) # Combine the Ending Range Block with the IP Base and Add the Missing . Period
                        ##################################################
                        # Update the dnsmasq.conf DHCP Starting Range
                        ##################################################
                        TERM=ansi whiptail --title " UPDATING $accesspConfigMenuSelected " --infobox "Updating the access point configuration..." 0 0
                        ##################################################
                        # Config Tag and File
                        configTag='dhcp-range='
                        confFile="${dnsmasqConfig}"
                        # Edit the Configuration File # Match Config Tag to End of Line # Replacement Value # Configuration File
                        sudo sed -i 's|'"$configTag"'.*|'"${configTag}${accesspRangeStart},${accesspRangeEnd}"',255.255.255.0,24h|' "${confFile}"
                        ##################################################
                        # Update the Internal Config Value
                        dnsmasqConfigRangeStart="${accesspRangeStart}"
                        # Flag that a Reboot is Required
                        accesspRebootRequired="true"
                    fi;;
                ##################################################
                "CONNECTIONS") # Edit the DHCP IP Address Range
                    ##################################################
                    defaultInputValue="${dnsmasqConfigRange}" # Import the Default Input Box Value
                    accesspRange=$(whiptail --title " $accesspConfigMenuSelected " --inputbox "\nPlease type the new $accesspConfigMenuSelected." 0 0 $defaultInputValue --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
                    # Whiptail Dialog Confimred, Continue Updating the Configuration
                    if [[ $dialogExit == 0 ]]; then
                        ##################################################
                        # Extract the Internal DHCP IP Base and Starting Range
                        accesspRangeBase="${dnsmasqConfigRangeStart%.*}" # Extract the IP Base by Removing the Block After the Final Period . | Ex: 192.168.4.2 extracts as 192.168.4
                        accesspRangeEnd="${dnsmasqConfigRangeStart##*.}" # Extract the Last Block by Removing All Blocks Before the Final Period . | Ex: 192.168.4.2 extracts as 2
                        # Ensure the DHCP Ending Range Does Not Overflow
                        if [[ $((accesspRangeEnd+accesspRange)) -gt 255 ]]; then # The Desired DHCP IP Address Range is Overflowing
                            # Decrease and Update the Total Allowed Connections
                            accesspRange=$((255-accesspRangeEnd)) # Calcuate the Delta Between the Starting Range and the Maximum Range
                            ##################################################
                            whiptail --title " IP RANGE OVERFLOW " --msgbox "The specified DHCP range is out of bounds.\n\nPlease choose another starting range to\nincrease the $accesspRange available connections." 0 0 --ok-button "OK"; fi
                            ##################################################
                        # Calculate the DHCP Ending Range
                        accesspRangeEnd="${accesspRangeBase}."$((accesspRangeEnd+accesspRange)) # Combine the Ending Range Block with the IP Base and Add the Missing . Period
                        ##################################################
                        # Update the dnsmasq.conf DHCP Ending Range
                        ##################################################
                        TERM=ansi whiptail --title " UPDATING $accesspConfigMenuSelected " --infobox "Updating the access point configuration..." 0 0
                        ##################################################
                        # Config Tag and File
                        configTag='dhcp-range='
                        confFile="${dnsmasqConfig}"
                        # Edit the Configuration File # Match Config Tag to End of Line # Replacement Value # Configuration File
                        sudo sed -i 's|'"$configTag"'.*|'"${configTag}${dnsmasqConfigRangeStart},${accesspRangeEnd}"',255.255.255.0,24h|' "${confFile}"
                        ##################################################
                        # Update the Internal Config Value
                        dnsmasqConfigRange="${accesspRange}"
                        # Flag that a Reboot is Required
                        accesspRebootRequired="true"
                    fi;;
                ##################################################
                "COUNTRY") # Edit the Country Code
                    ##################################################
                    defaultInputValue="${hostapdConfigCountry}" # Import the Default Input Box Value
                    accesspCountry=$(whiptail --title " $accesspConfigMenuSelected " --inputbox "\nPlease type the new $accesspConfigMenuSelected." 0 0 $defaultInputValue --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
                    # Whiptail Dialog Confimred, Continue Updating the Configuration
                    if [[ $dialogExit == 0 ]]; then
                        ##################################################
                        # Update the hostapd.conf Country Code
                        ##################################################
                        TERM=ansi whiptail --title " UPDATING $accesspConfigMenuSelected " --infobox "Updating the access point configuration..." 0 0
                        ##################################################
                        # Config Tag and File
                        configTag='country_code='
                        confFile="${hostapdConfig}"
                        # Edit the Configuration File # Match Config Tag to End of Line # Replacement Value # Configuration File
                        sudo sed -i 's|'"$configTag"'.*|'"${configTag}${accesspCountry}"'|' "${confFile}"
                        ##################################################
                        # Update the Internal Config Value
                        hostapdConfigCountry="${accesspCountry}"
                        # Flag that a Reboot is Required
                        accesspRebootRequired="true"
                    fi;;
                ##################################################
                "IP MASK") # Edit the IP Mask
                    ##################################################
                    defaultInputValue="${dhcpcdConfigMask}" # Import the Default Input Box Value
                    accesspMask=$(whiptail --title " $accesspConfigMenuSelected " --inputbox "\nPlease type the new $accesspConfigMenuSelected." 0 0 $defaultInputValue --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
                    # Whiptail Dialog Confimred, Continue Updating the Configuration
                    if [[ $dialogExit == 0 ]]; then
                        ##################################################
                        # Update the dhcpcd.conf IP Mask
                        ##################################################
                        TERM=ansi whiptail --title " UPDATING $accesspConfigMenuSelected " --infobox "Updating the access point configuration..." 0 0
                        ##################################################
                        # Config Tag and File
                        configTag='static ip_address='
                        confFile="${dhcpcdConfig}"
                        # Edit the Configuration File # Match Config Tag to End of Line # Replacement Value # Configuration File
                        sudo sed -i 's|'"$configTag"'.*|'"${configTag}${dhcpcdConfigIP}/${accesspMask}"'|' "${confFile}"
                        ##################################################
                        # Update the Internal Config Value
                        dhcpcdConfigMask="${accesspMask}"
                        # Flag that a Reboot is Required
                        accesspRebootRequired="true"
                    fi;;
                ##################################################
                "HW MODE") # Edit the Hardware Mode
                    ##################################################
                    # Whiptail Menu for Access Point Hardware Mode
                    accesspHWMode=$(
                        whiptail --title " $accesspConfigMenuSelected " --ok-button "OK" --cancel-button "CANCEL" \
                        --menu "\nPlease select the new $accesspConfigMenuSelected." 0 0 0 \
                        "a" "802.11a, 5.0 GHz (RPi 3B+ Onwards)" \
                        "b" "802.11b, 2.4 GHz" \
                        "g" "802.11g, 2.4 GHz" \
                    3>&2 2>&1 1>&3 ) dialogExit=$? ##################
                    # Whiptail Dialog Confimred, Continue Updating the Configuration
                    if [[ $dialogExit == 0 ]]; then
                        ##################################################
                        # Update the hostapd.conf Hardware Mode
                        ##################################################
                        TERM=ansi whiptail --title " UPDATING $accesspConfigMenuSelected " --infobox "Updating the access point configuration..." 0 0
                        ##################################################
                        # Config Tag and File
                        configTag='hw_mode='
                        confFile="${hostapdConfig}"
                        # Edit the Configuration File # Match Config Tag to End of Line # Replacement Value # Configuration File
                        sudo sed -i 's|'"$configTag"'.*|'"${configTag}${accesspHWMode}"'|' "${confFile}"
                        ##################################################
                        # Update the Internal Config Value
                        hostapdConfigHWMODE="${accesspHWMode}"
                        # Flag that a Reboot is Required
                        accesspRebootRequired="true"
                    fi;;
                ##################################################
                "CHANNEL") # Edit the Channel
                    ##################################################
                    defaultInputValue="${hostapdConfigChannel}" # Import the Default Input Box Value
                    accesspChannel=$(whiptail --title " $accesspConfigMenuSelected " --inputbox "\nPlease type the new $accesspConfigMenuSelected." 0 0 $defaultInputValue --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
                    # Whiptail Dialog Confimred, Continue Updating the Configuration
                    if [[ $dialogExit == 0 ]]; then
                        ##################################################
                        # Update the hostapd.conf Hardware Mode
                        ##################################################
                        TERM=ansi whiptail --title " UPDATING $accesspConfigMenuSelected " --infobox "Updating the access point configuration..." 0 0
                        ##################################################
                        # Config Tag and File
                        configTag='channel='
                        confFile="${hostapdConfig}"
                        # Edit the Configuration File # Match Config Tag from the Start to End of Line # Replacement Value # Configuration File
                        sudo sed -i 's|^'"$configTag"'.*|'"${configTag}${accesspChannel}"'|' "${confFile}"
                        ##################################################
                        # Update the Internal Config Value
                        hostapdConfigChannel="${accesspChannel}"
                        # Flag that a Reboot is Required
                        accesspRebootRequired="true"
                    fi;;
            esac
        done

    ##################################################
    # Remove the Access Point
    elif [[ "$accesspSetupMenu" == "REMOVE" ]]; then
        ##################################################
        # Confirm Uninstallation
        ##################################################
        # Whiptail Confiration to Uninstall Access Point
        if (whiptail --title " REMOVE ACCESS POINT " --yesno "Are you sure you want to remove the access point?\n\nThis will remove all configuration files and\nrestore all previous configurations." 0 0 --defaultno --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
        ##################################################
            TERM=ansi whiptail --title " REMOVING CONFIGS " --infobox "Removing the access point onfigurations..." 0 0 
            ##################################################
            # Remove All rpi-accessp Configuration Files
            sudo rm "${dhcpcdConfig}" && sudo rm "${dnsmasqConfig}" && sudo rm "${hostapdConfig}"
            # Restore All Original Configuration Files
            sudo mv "${dhcpcdConfig}.orig" "${dhcpcdConfig}" && sudo mv "${dnsmasqConfig}.orig" "${dnsmasqConfig}"

            ##################################################
            TERM=ansi whiptail --title " REMOVING ACCESS POINT " --infobox "Removing the access point..." 0 0 
            ##################################################
            # Disable and Remove the Access Point Service
            sudo systemctl -q disable hostapd
            sudo apt-get -qq remove hostapd -y > /dev/null
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Access point status updated." 0 0 
            ##################################################

            ##################################################
            # Whiptail Confiration to Uninstall Access Point
            if (whiptail --title " REMOVE DNSMASQ " --yesno "Would like to remove dnsmasq?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
            ##################################################
                TERM=ansi whiptail --title " REMOVING DNSMASQ " --infobox "Removing dnsmasq..." 0 0 
                ##################################################
                # Remove dnsmasq and Clean Up Dangling Packages
                sudo apt-get remove dnsmasq -y > /dev/null && sudo apt-get autoremove -y > /dev/null
            fi
            ##################################################

            ##################################################
            # Whiptail Confiration to Apply Uninstallation
            if (whiptail --title " REBOOT REQUIRED " --yesno "A reboot is required to apply the changes.\nWould you like to reboot now?" 0 0 --defaultno --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
                # Reboot to Apply the Changes
                sudo systemctl reboot
            # Do Not Reboot
            else accesspExit; fi # Exit rpi-accessp
            ##################################################
        fi
        ##################################################

    ##################################################
    # View the Help Guide for New Connections
    elif [[ "$accesspSetupMenu" == "CONNECT" ]]; then
    connectHelpGuide="Connecting New Devices
_____________________________________________________

1. Search for the \"${hostapdConfigSSID}\" network using
   the wireless device you want to connect.

2. Connect using the passphrase:
   ${hostapdConfigPassphrase}

VNC
-  Connect to ${dhcpcdConfigIP} using your root password.

SSH
-  ssh $(whoami)@${dnsmasqConfigAddress}
-  ssh $(whoami)@${dhcpcdConfigIP}

"
    ##################################################
    whiptail --title " CONNECTION GUIDE " --msgbox "${connectHelpGuide}" 0 0 --ok-button "OK"
    ##################################################

    fi

done

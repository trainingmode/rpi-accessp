# ***rpi-accessp***

> A quick access point configuration utility for Raspberry Pi.

-----

![rpi-accessp_Demo](https://user-images.githubusercontent.com/52793789/121887367-7fd49e00-cccb-11eb-857a-afaaecd8d79a.gif)

-----

# Features

- Install a private access point on wireless-enabled Raspberry Pis.

- One-click enable/disable the access point.

- Easily configure basic network settings.

-----

# Guide

## *Install an Access Point*

1. Launch the configuration tool:

        bash rpi-accessp.sh

2. Follow the prompts to install the access point.

3. Select `CONFIG` to configure your access point.

4. After configuring the access point, select `APPLY` and do **not** reboot.

5. Select `ENABLE` to enable the access point and reboot to apply the changes.

## *Connect a Device*

1. Launch the configuration tool:

        bash rpi-accessp.sh

2. Select `CONNECT` to view the auto-guide on connecting new devices.

3. Using the wireless device you want to connect, search for your Raspberry Pi's SSID.

4. Connect to the network using the passphrase you configured.

-----

# *Full Walkthrough*

Below is a walkthrough (no audio) demonstrating the installation & configuration process.

https://user-images.githubusercontent.com/52793789/121887318-72b7af00-cccb-11eb-9736-450118c9720a.mp4

## Install

1. Run the utility.
2. Install the access point.
3. Install the DHCP & DNS service.
4. Install the access point service.

## Configure

1. Open the configuration menu.
2. Edit the SSID, passphrase, alias, and [country code](https://en.wikipedia.org/wiki/ISO_3166-1).
3. Enable the access point service.
4. View the auto-generated guide for connecting new devices.

-----

# TODO

- Improve input validation.

-----

# Credits

This utility is based on the official [Setting up a Raspberry Pi as a routed wireless access point](https://www.raspberrypi.org/documentation/configuration/wireless/access-point-routed.md) Guide.

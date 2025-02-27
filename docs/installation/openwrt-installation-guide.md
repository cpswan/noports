---
description: How to install NoPorts onto an OpenWrt router.
icon: router
---

# OpenWrt Installation Guide

### Using the LuCI web interface

First download the latest packages for your chosen architecture from our [releases](https://github.com/atsign-foundation/Atsign_OpenWRT_packages/releases) page.

We've created packages for x86\_64, aarch64\_cortex-a53, ramips and mips\_siflower; but if your chosen architecture isn't there please let us know by opening an [issue](https://github.com/atsign-foundation/Atsign_OpenWRT_packages/issues).

With the packages ready to go, sign into the web interface for your router and go to `System`> `Software` in the menu. Click on `Upload Package` and `Browse` to the csshnpd package you downloaded. Click `Open` then `Upload` and `Install`. Repeat that process with the luci-app-csshnpd package.

For the new menu to appear you'll need to `Log out` then sign in again.

You can now go to `Network`>`NoPorts` and fill out the config tab with your device atSign, manager atSign, device name and the OTP for key generation. Click the `Enabled` box then hit `Save & Apply`.

No go to the `NoPorts Enrollment` tab and follow the instructions there to generate a device key.

With the key in place navigate to `System`>`Startup` and `Start` the `sshnpd` service.

### Command line installation

The [releases](https://github.com/atsign-foundation/Atsign_OpenWRT_packages/releases) page includes instructions for command line installation, though these may need to be edited to suit your system architecture.

Those command line snippets set some variables for the `RELEASE` number and `PACKAGE` name then use `wget` to download the package from GitHub.

Packages are installed using `opkg install` for OpenWrt 24.10 and earlier releases that use `.ipk` type packages, or `apk add` for newer OpenWrt which uses `.apk` packages.

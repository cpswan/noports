---
icon: file-import
---

# Reuse your client atSign on another machine

## Want to use your atSign on a different machine?

You can either:

1. Generate a new set of cryptographic keys (Recommended), or
2. Copy the cryptographic keys from the machine where it's been activated in the past (Not recommended)

### **1) Generate a new set of cryptographic keys (Recommended)**

* We will use the same approach as in the other installation guides for setting up devices
* i) Generate a passcode. On the _original_ client machine, run

```
~/.local/bin/at_activate otp -a @<REPLACE>_client
```

* ii) Make an authorization request. On the _new_ client machine, run

```
~/.local/bin/at_activate enroll -a @<REPLACE>_client \
  -s <PASSCODE> \
  -p noports \
  -k ~/.atsign/keys/@<REPLACE_client>_key.atKeys \
  -d <client_device_name> \
  -n "sshnp:rw,sshrvd:rw"
```

* iii) Approve the authorization request. On the _original_ client machine, run

```
~/.local/bin/at_activate approve -a @<REPLACE>_client \
  --arx noports \
  --drx <client_device_name>
```

### **2) Copy the cryptographic keys from the machine where it's been activated in the past (Not recommended)**

* The atSign keys file will be located at `~/.atsign/keys/` directory with a filename that will include the atSign. Copy this file from your other machine to the same location on the machine that you are installing SSH No Ports on, using `scp` or similar.

Why don't we recommend this approach?

> When you use method 1, it creates a new set of cryptographic keys. These keys can be disabled individually, which means if a device's keys are compromised, you can disable those keys without affecting your other devices.

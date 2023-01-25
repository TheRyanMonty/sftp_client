# sFTP Client

## Introduction

The purpose of this client is to ease the movement of files via command line arguements to push or pull bulk files to/from another system.

### Goals of the configuration:
1. To move files within a specified path to an sftp server
2. Flexes to enable email notifications
3. Ties into system logging service best practices for issues or errors
4. Error checking which checks for common problems

### What's doing the work:
- Open source sftp program bundled with the openssh code base

Network accessible service IPs will be assigned via MetalLB and yamls (i.e. using 192.168.1.200-210). Network router dhcp reservation space must be updated to accomodate the range used or IP conflicts will occur.

# sftp client shell script
 - Configuration file should be stored in /etc/sftp.conf
 - CANNOT have any filenames with ' -' in them

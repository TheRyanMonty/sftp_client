# HomeLab Setup

## Introduction

The purpose of this client is to ease via command line arguements to move or pull bulk files to/from another system.

### Goals of the configuration:
1. 

### What's doing the work:
- Open source sftp program bundled with the openssh code base

Network accessible service IPs will be assigned via MetalLB and yamls (i.e. using 192.168.1.200-210). Network router dhcp reservation space must be updated to accomodate the range used or IP conflicts will occur.

# sftp client shell script
 - Configuration file should be stored in /etc/sftp.conf
 - CANNOT have any filenames with ' -' in them

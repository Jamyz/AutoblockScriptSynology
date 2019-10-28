# AutoblockScriptSynology
AutoblockScriptSynology is a simple script to update ip blacklisted from the internet.

## How to use:
##### Download the script. Place it in a directory of your choice.

##### For DSM, create a scheduled task and run it as root.
##### sh /volume1/homes/myusername/Scripts/Blacklist/autoblocksynology.sh


##### For SRM, create a scheduled task and run it as root.
##### Enter your router as root. And add a line in contrab with the command:
##### vi /etc/crontab
##### add a line like :
##### 0       *       *       *       *       root    /bin/sh /volume1/homes/myusername/Scripts/Blacklist/blacklist.sh

##### To choose the periodicity. Inquire here:
##### [Crontab-Generator] (https://crontab-generator.org/)

### Special Thanks To :
##### - [NAS-FORUM](https://www.nas-forum.com)
##### - PPJP
##### - Superthx
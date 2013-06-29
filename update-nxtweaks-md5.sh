#!/bin/bash
md5sum res/misc/payload/NXTweaks.apk | awk '{print $1}' > res/nxtweaks_md5;
chmod 644 res/stweaks_md5;
cat res/stweaks_md5;


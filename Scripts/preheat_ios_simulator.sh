#!/bin/bash

if [ "$1" = "" ]; then
    echo "Usage: launch-ios-simulator.sh <device name>"
    exit 1;
fi

device="$1"
ios="$2"
printf "Closing any open instances of the iphone simulator...\n"
killall "Simulator" || true
if [ -z "$ios" ]; then
  printf "Determining latest iOS simulator...\n"
  ios=$(xcodebuild -showsdks | grep -Eo "iphonesimulator(.+)" | tail -1)
  ios=${ios##iphonesimulator}
  printf "Detected latest iOS simulator version: ${ios}\n"
fi
printf "Pre-Launching iphone simulator for ${device} (${ios})\n"
simulator_id=$(xcrun instruments -s | grep -Eo "${device} \(${ios}\) \[.*\]" | grep -Eo "\[.*\]" | sed "s/^\[\(.*\)\]$/\1/")
open -b com.apple.iphonesimulator --args -CurrentDeviceUDID $simulator_id

RETVALUE=$?
if [ "$RETVALUE" != "0" ]; then
   printf "Something went wrong when attempting to launch the simulator for ${device} (${ios})\n"
   exit 1;
fi
printf "Simulator launched for ${device} (${ios})\n"

#!/bin/bash

touch current_version

location="$(curl -sI https://github.com/ewoudje/estore/releases/latest?$RANDOM | grep location:)"
current="$(cat current_version)"

if [[ "$location" != "$current" ]]
then
   echo NEW_VERSION!
   rc-service estore stop

   rm -r estore
   wget https://github.com/ewoudje/estore/releases/latest/download/estore.zip
   unzip estore.zip
   rm estore.zip

   rc-service estore start

   echo $location > current_version
fi

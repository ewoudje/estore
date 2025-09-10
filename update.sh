#!/bin/bash

touch current_version

location="$(curl -sI https://github.com/ewoudje/estore/releases/latest | grep location:)"
current="$(cat current_version)"

if [[ "$location" != "$current" ]]
then
   echo NEW_VERSION!

   rm -r estore
   wget https://github.com/ewoudje/estore/releases/latest/download/estore.zip
   unzip estore.zip
   rm estore.zip

   echo $location > current_version
fi

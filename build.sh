#/bin/sh

make clean package

make clean package THEOS_PACKAGE_SCHEME=rootless

make clean package THEOS_PACKAGE_SCHEME=roothide

make clean

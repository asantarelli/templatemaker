#!/bin/sh
# Copies the template set into C:\clarion12\accessory (the headless test install)
# and re-registers it. CRLF enforced.
cd "$(dirname "$0")"
for f in myTaskPanel.tpl MyTaskPanel.inc MyTaskPanel.clw mtpd2d.c; do sed -i 's/\r$//; s/$/\r/' $f; done
cp myTaskPanel.tpl /c/clarion12/accessory/template/win/
cp MyTaskPanel.inc MyTaskPanel.clw mtpd2d.c /c/clarion12/accessory/libsrc/win/
/c/clarion12/bin/ClarionCL.exe -tr "C:\clarion12\accessory\template\win\myTaskPanel.tpl" && echo registered

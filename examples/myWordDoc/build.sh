#!/bin/bash
# Build Spike.exe from the template's class files (copied in, CRLF).
set -e
cd "$(dirname "$0")"
MSB="C:/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe"
for f in WordDocClass.inc WordDocClass.clw wdoc.c; do
  sed 's/\r$//; s/$/\r/' ../../templates/myWordDoc/$f > $f
done
sed -i 's/\r$//; s/$/\r/' Spike.clw
rm -rf obj
"$MSB" Spike.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32 \
       -p:ClarionBinPath="C:\clarion12\bin" -v:m 2>&1 | grep -iE "error|warning" || true
ls -l Spike.exe

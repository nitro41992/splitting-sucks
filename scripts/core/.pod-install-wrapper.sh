#!/bin/sh
# M1 Mac pod installation wrapper script
# This script runs pod install with x86_64 architecture to avoid M1-specific issues

cd ios
arch -x86_64 pod install --repo-update 
#!/bin/bash
# Read current build + marketing version from the project
cd ~/Documents/Projects/mira-apps
xcrun agvtool what-version 2>/dev/null
grep 'MARKETING_VERSION' OllamaSearch.xcodeproj/project.pbxproj | head -2

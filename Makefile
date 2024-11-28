# Makefile for qlZipInfo

# project settings

PROJNAME   = qlZipInfo
PROJEXT    = qlgenerator
PROJVERS   = 1.2.8
BUNDLEID   = "org.calalum.ranga.$(PROJNAME)"

# extra files to include in the package

SUPPORT_FILES = README.txt LICENSE.txt

# code signing information

include ../sign.mk

# build and packaging tools

XCODEBUILD = /usr/bin/xcodebuild
XCRUN      = /usr/bin/xcrun
HIUTIL     = /usr/bin/hiutil
ALTOOL     = $(XCRUN) altool
NOTARYTOOL = xcrun notarytool
STAPLER    = $(XCRUN) stapler
HDIUTIL    = /usr/bin/hdiutil
CODESIGN   = /usr/bin/codesign
GPG        = /opt/local/bin/gpg

# code sign arguments
# based on:
# https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow
# https://stackoverflow.com/questions/53112078/how-to-upload-dmg-file-for-notarization-in-xcode

CODESIGN_ARGS = --force \
                --verify \
                --verbose \
                --timestamp \
                --options runtime \
                --sign $(SIGNID)

# Xcode build target

BUILD_CONFIG = Release

# build results directory

BUILD_RESULTS_DIR = build/$(BUILD_CONFIG)/$(PROJNAME).$(PROJEXT)
BUILD_RESULTS_FRAMEWORKS_DIR = $(BUILD_RESULTS_DIR)/Contents/Frameworks/

# build the app

all:
	$(XCODEBUILD) -project $(PROJNAME).xcodeproj -configuration $(BUILD_CONFIG)

# sign the app, if frameworks are included, then sign_frameworks should
# be the pre-requisite target instead of "all"

sign: sign_frameworks
	$(CODESIGN) $(CODESIGN_ARGS) $(BUILD_RESULTS_DIR)

# sign any included frameworks (not always needed)

sign_frameworks: all
	if [ -d $(BUILD_RESULTS_FRAMEWORKS_DIR) ] ; then \
        $(CODESIGN) $(CODESIGN_ARGS) \
                    $(BUILD_RESULTS_FRAMEWORKS_DIR) ; \
    fi

# create a disk image with the signed app

dmg: all sign
	/bin/mkdir $(PROJNAME)-$(PROJVERS)
	/bin/mv build/Release/$(PROJNAME).$(PROJEXT) $(PROJNAME)-$(PROJVERS)
	/bin/cp $(SUPPORT_FILES) $(PROJNAME)-$(PROJVERS)
	$(HDIUTIL) create -srcfolder $(PROJNAME)-$(PROJVERS) \
                      -format UDBZ $(PROJNAME)-$(PROJVERS).dmg

# sign the disk image

sign_dmg: dmg
	$(CODESIGN) $(CODESIGN_ARGS) $(PROJNAME)-$(PROJVERS).dmg

# notarize the signed disk image

# Xcode13 notarization
# See: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow?preferredLanguage=occ
#      https://scriptingosx.com/2021/07/notarize-a-command-line-tool-with-notarytool/
#      https://indiespark.top/programming/new-xcode-13-notarization/

notarize: sign_dmg
	$(NOTARYTOOL) submit $(PROJNAME)-$(PROJVERS).dmg \
                  --apple-id $(USERID) --team-id $(TEAMID) \
                  --wait

# Pre-Xcode13 notarization

notarize_old: sign_dmg
	$(ALTOOL) --notarize-app \
              --primary-bundle-id $(BUNDLEID) \
              --username $(USERID) \
              --file $(PROJNAME)-$(PROJVERS).dmg

# staple the ticket to the dmg

staple: notarize
	$(STAPLER) staple $(PROJNAME)-$(PROJVERS).dmg
	$(STAPLER) validate $(PROJNAME)-$(PROJVERS).dmg

# sign the dmg with a gpg public key

clearsign: staple
	$(GPG) -asb $(PROJNAME)-$(PROJVERS).dmg

clean:
	/bin/rm -rf ./build $(PROJNAME)-$(PROJVERS) $(PROJNAME)-$(PROJVERS).dmg
	$(XCODEBUILD) -project $(PROJNAME).xcodeproj -alltargets clean


# Makefile for qlZipInfo

PROJNAME   = qlZipInfo
PROJEXT    = qlgenerator
PROJVERS   = 1.1.7
BUNDLEID   = "org.calalum.ranga.$(PROJNAME)"

# code signing information

include sign.mk

# build and packaging tools

XCODEBUILD = /usr/bin/xcodebuild
XCRUN      = /usr/bin/xcrun
ALTOOL     = $(XCRUN) altool
STAPLER    = $(XCRUN) stapler
HDIUTIL    = /usr/bin/hdiutil
CODESIGN   = /usr/bin/codesign

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

# extra files to include in the package

SUPPORT_FILES = README.txt LICENSE.txt

# build the app

all:
	$(XCODEBUILD) -project $(PROJNAME).xcodeproj -configuration Release

sign: all
	$(CODESIGN) $(CODESIGN_ARGS) build/Release/$(PROJNAME).$(PROJEXT)
	if [ -d build/Release/$(PROJNAME).$(PROJEXT)/Contents/Frameworks/ ] ; then \
        $(CODESIGN) $(CODESIGN_ARGS) \
                build/Release/$(PROJNAME).$(PROJEXT)/Contents/Frameworks/* ; \
    fi

# sign the disk image

sign_dmg: dmg
	$(CODESIGN) $(CODESIGN_ARGS) $(PROJNAME)-$(PROJVERS).dmg

dmg: clean all sign
	/bin/mkdir $(PROJNAME)-$(PROJVERS)
	/bin/mv build/Release/$(PROJNAME).$(PROJEXT) $(PROJNAME)-$(PROJVERS)
	/bin/cp $(SUPPORT_FILES) $(PROJNAME)-$(PROJVERS)
	$(HDIUTIL) create -srcfolder $(PROJNAME)-$(PROJVERS) \
                      -format UDBZ $(PROJNAME)-$(PROJVERS).dmg

# notarize the signed disk image

notarize: sign_dmg
	$(ALTOOL) --notarize-app \
              --primary-bundle-id $(BUNDLEID) \
              --username $(USERID) \
              --file $(PROJNAME)-$(PROJVERS).dmg

# staple the ticket to the dmg, but notarize needs to complete first,
# so we can't list notarize as a pre-requisite target

staple: 
	$(STAPLER) staple $(PROJNAME)-$(PROJVERS).dmg
	$(STAPLER) validate $(PROJNAME)-$(PROJVERS).dmg

clean:
	/bin/rm -rf ./build $(PROJNAME)-$(PROJVERS) $(PROJNAME)-$(PROJVERS).dmg
	$(XCODEBUILD) -project $(PROJNAME).xcodeproj -alltargets clean


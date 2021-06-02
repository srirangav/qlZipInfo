README
------

qlZipInfo v1.0.11
By Sriranga Veeraraghavan <ranga@calalum.org>

qlZipInfo is a QuickLook generator for Zip and Jar files.  qlZipInfo
relies on Minizip 1.2 (https://github.com/nmoinvaz/minizip/tree/1.2).

Information for each file in a zip file is displayed in the following 
format:

    Filename | Size (Compression ratio) | Date Modified

If a file is encrypted a * is displayed after the filename.

Install:

    1. Create the directory ~/Library/QuickLook if it doesn't exist

    2. Copy qlZipInfo.qlgenerator to ~/Library/QuickLook

    3. Restart QuickLook:

       /usr/bin/qlmanage -r
       /usr/bin/qlmanage -r cache

Supported MacOSX versions:

    v. 1.0.9 onwards     - 10.9+
    v. 1.0.8 and earlier - 10.6+

History:

    v1.0.11 - add support for non-UTF8 filenames
    v1.0.10 - add darkmode support
    v1.0.9  - build on Big Sur (11.x)
    v1.0.8  - add support for 1Password backups
    v1.0.7  - update to Minizip 1.2, show compression method
    v1.0.6  - updates for Xcode 10.2
    v1.0.5  - internal updates
    v1.0.4  - internal updates
    v1.0.3  - localize the date, change compression reporting, and 
              escape any HTML characters in file / folder names
    v1.0.2  - add icons, display file compression, size in B, KB, MB, 
              etc.
    v1.0.1  - initial release

License:

    Please see LICENSE.txt


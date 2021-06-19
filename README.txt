README
------

qlZipInfo v1.1.1
By Sriranga Veeraraghavan <ranga@calalum.org>

qlZipInfo is a QuickLook generator for zip, jar, tar, tar.gz 
(.tgz), tar.bz2 (.tbz2), tar.Z (.tZ), and xar (.xar, .pkg) 
files.  It relies on libarchive (https://libarchive.org/).

Information for each file in an archive is displayed in the following 
format:

    Icon | Filename | Size | Date Modified

A folder icon is shown for folders / directories, a file icon is 
shown for regular files, and a lock icon is shown for encypted files.

Install:

    1. Create the directory ~/Library/QuickLook if it doesn't 
       exist

    2. Copy qlZipInfo.qlgenerator to ~/Library/QuickLook

    3. Restart QuickLook:

       /usr/bin/qlmanage -r
       /usr/bin/qlmanage -r cache

Supported MacOSX versions:

    v. 1.0.9 onwards     - 10.9+
    v. 1.0.8 and earlier - 10.6+

History:

    v1.1.1  - add support for xar / pkg files
    v1.1.0  - switch to libarchive and add support for .tar,
              .tar.gz (.tgz), .tar.bz2 (tbz2), and tar.Z 
              (.tZ) files
    v1.0.15 - show a lock icon for encrypted files
    v1.0.14 - fixes to make darkmode and light mode better
              match the BigSur Finder
    v1.0.13 - make sure days and months are zero prefixed
    v1.0.12 - increase size used to display the compressed
              file size; disable showing the compression
              method
    v1.0.11 - add support for zip files with non-UTF8 filenames
    v1.0.10 - add darkmode support
    v1.0.9  - build on Big Sur (11.x)
    v1.0.8  - add support for 1Password backups
    v1.0.7  - update to Minizip 1.2, show compression method
    v1.0.6  - updates for Xcode 10.2
    v1.0.5  - internal updates
    v1.0.4  - internal updates
    v1.0.3  - localize the date, change compression reporting, 
              and escape any HTML characters in file / folder 
              names
    v1.0.2  - add icons, display file compression, size in B, 
              KB, MB, etc.
    v1.0.1  - initial release

License:

    Please see LICENSE.txt


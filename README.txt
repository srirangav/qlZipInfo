README
------

qlZipInfo v1.0.4
By Sriranga Veeraraghavan <ranga@calalum.org>

qlZipInfo is a QuickLook generator for Zip and Jar files.  qlZipInfo
relies on Minizip (http://www.winimage.com/zLibDll/minizip.html).

To install:

1. Create the directory ~/Library/QuickLook if it doesn't exist

2. Copy qlZipInfo.qlgenerator to ~/Library/QuickLook

3. Restart QuickLook: 

   /usr/bin/qlmanage -r 
   /usr/bin/qlmanage -r cache

History:

v1.0.4 - internal updates
v1.0.3 - localize the date, change compression reporting, and escape any
         HTML characters in file / folder names
v1.0.2 - add icons, display file compression, size in B, KB, MB, etc.
v1.0.1 - initial release

README
------

qlZipInfo v1.0.7
By Sriranga Veeraraghavan <ranga@calalum.org>

qlZipInfo is a QuickLook generator for Zip and Jar files.  qlZipInfo
relies on Minizip 1.2 (https://github.com/nmoinvaz/minizip/tree/1.2).

qlZipInfo displays information for each file in the following format:

Filename | Size (Compression ratio) Compression Method | Date Modified

If a file is encrypted a * is displayed after the filename.  

The compression methods are abbreviated as follows:

B  - BZip2
F  - Fast Deflate
H  - Shrunk
I  - Imploded
L  - LMZA
N  - Normal Deflate
NT - New Terse
M  - Maximum Compression Deflate (slowest)
OT - Old Terse
P  - PPMd
S  - Stored (no compression)
T  - Tokenized
U  - Unknown
X  - Fastest Deflate
1  - Reduced Level 1
2  - Reduced Level 2
3  - Reduced Level 3
4  - Reduced Level 4
77 - LZ77 / PFS
64 - Deflate64

To install:

1. Create the directory ~/Library/QuickLook if it doesn't exist

2. Copy qlZipInfo.qlgenerator to ~/Library/QuickLook

3. Restart QuickLook: 

   /usr/bin/qlmanage -r 
   /usr/bin/qlmanage -r cache

History:

v1.0.7 - update to Minizip 1.2, show compression method
v1.0.6 - updates for Xcode 10.2
v1.0.5 - internal updates
v1.0.4 - internal updates
v1.0.3 - localize the date, change compression reporting, and escape any
         HTML characters in file / folder names
v1.0.2 - add icons, display file compression, size in B, KB, MB, etc.
v1.0.1 - initial release

License: 

Please see LICENSE.txt

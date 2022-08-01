/*
    sit.h - list the entries in a Stuffit Archive

    History:

    v. 0.1.0 (08/01/2022) - initial release

    Based on:

    sit.c / sit.h from 2.0b3 of macutil (22-OCT-1992)
    http://fileformats.archiveteam.org/wiki/StuffIt
    https://github.com/ParksProjets/Maconv/blob/master/docs/stuffit/Stuffit_v1.md
    https://gswv.apple2.org.za/a2zine/GS.WorldView/Resources/The.MacShrinkIt.Project/ARCHIVES.TXT

    Copyright (c) 2022 Sriranga R. Veeraraghavan <ranga@calalum.org>

    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software") to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject
    to the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/*
    Stuffit File Format:

        SIT Header                      -  22 bytes
        Entry1 Header                   - 112 bytes
        Entry1 Compressed Resource Fork (0 bytes for folder entries)
        Entry1 Compressed Data Fork     (0 bytes for folder entires)
        ...

    SIT Header Format (22 bytes):

        magic number 1                - 4 bytes
        number of top level entires   - 2 bytes
        archive length                - 4 bytes
        magic number 2 (rLau)         - 4 bytes
        version                       - 1 byte
        unknown                       - 1 byte
        header size (if version != 1) - 4 bytes
        header CRC                    - 2 bytes

    Entry Header Format (112 bytes)

        Resource fork compression type    -  1 byte (32/33 for folders)
        Data fork compression type        -  1 byte
        Filename length                   -  1 byte
        Filename                          - 64 bytes
        MacOS Finder file type            -  4 bytes
        MacOS Finder creator              -  4 bytes
        MacOS Finder flags                -  1 byte
        Creation date                     -  4 bytes
        Last modified date                -  4 bytes
        Uncompressed Resource Fork length -  4 bytes
        Uncompressed Data Fork length     -  4 bytes
        Compressed Resource Fork length   -  4 bytes
        Compressed Data Fork length       -  4 bytes
        Resource fork CRC                 -  2 bytes
        Data fork CRC                     -  2 bytes
        Reserved                          -  6 bytes
        Entry Header CRC                  -  2 bytes
*/

#ifndef qlZipInfo_sit_h
#define qlZipInfo_sit_h

/* defines */

#define SITFNAMEMAX 64

/* return codes */

enum
{
    gSitErr  = -1,
    gSitOkay =  0,
    gSitEOF  =  1,
};

enum
{
    SitEntryFolderStart = 1,
    SitEntryFolderEnd   = 2,
};

/* compression types */

enum
{
    SitCompNone        =  0,
    SitCompRLE         =  1,
    SitCompLZC         =  2,
    SitCompHuff        =  3,
    SitCompLZAH        =  5,
    SitCompFixedHuff   =  6,
    SitCompMW          =  8,
    SitCompLZHuff      = 13,
    SitCompInstaller   = 14,
    SitCompArsenic     = 15,
    SitCompEncrypted   = 16,
    SitCompFolderStart = 32,
    SitCompFolderEnd   = 33,
};

/* SIT File Header */

typedef struct sitHeader
{
    char           sig1[4];
    unsigned short topLevelEntries;
    unsigned long  archiveLen;
    char           sig2[4];
    unsigned char  version;
    unsigned char  extra;
    char           headerSize[4];
    unsigned short crc;
} sitHeader_t;

/* SIT Entry Header */

typedef struct sitEntryHeader
{
    unsigned char  rsrcCompType;
    unsigned char  dataCompType;
    char           name[SITFNAMEMAX+1];
    char           asciiName[SITFNAMEMAX+1];
    char           type[5];
    char           creator[5];
    unsigned short finderFlags;
    unsigned long  creationDate;
    unsigned long  modDate;
    unsigned long  rsrcLen;
    unsigned long  dataLen;
    unsigned long  rsrcCompLen;
    unsigned long  dataCompLen;
    unsigned short rsrcCRC;
    unsigned short dataCRC;
    char           reserved[6];
    unsigned short hdrCRC;
} sitEntryHeader_t;

/* SIT file handle */

typedef struct sitFileHandle
{
    int fd;
    FILE *fp;
    unsigned short numEntries;
    unsigned long  archiveLen;
    unsigned char  version;
} sitFileHandle_t;

/* prototypes */

int sitInitFileHandle(const char *fname,
                      sitFileHandle_t *sitFile);
int sitGetNextEntry(sitFileHandle_t *sitFile,
                    sitEntryHeader_t *entry);
int sitIsEntryFolder(sitEntryHeader_t *entry);
int sitIsEntryEncrypted(sitEntryHeader_t *entry);
int sitIsEntryApplication(sitEntryHeader_t *entry);
char * sitEntryGetFilename(sitEntryHeader_t *entry);
char * sitEntryGetAsciiName(sitEntryHeader_t *entry);
unsigned long sitEntryGetCompressedSize(sitEntryHeader_t *entry);
unsigned long sitEntryGetUnCompressedSize(sitEntryHeader_t *entry);
unsigned long sitEntryGetModifiedDate(sitEntryHeader_t *entry);
unsigned long sitGetSize(sitFileHandle_t *sitFile);
int sitReleaseFileHandle(sitFileHandle_t *sitFile);

#endif /* qlZipInfo_sit_h */

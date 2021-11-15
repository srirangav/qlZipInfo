/*
    binhex.c - decode a binhex file
 
    History:
 
    v. 0.1.0 (11/13/2021) - initial release
 
    Copyright (c) 2021 Sriranga R. Veeraraghavan <ranga@calalum.org>
 
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

#ifndef qlZipInfo_binhex_h
#define qlZipInfo_binhex_h

/* constants */

enum
{
    gHqxErr  = -1,
    gHqxOkay = 0,
};

/* maximum length of a file name in a binhex'ed file */

#define HQXFNAMEMAX 64

/* structures */

/* binhex 4.0 header, although type and creator are 4 bytes,
   we allocate 5 to store the trailing '\0' */
   
typedef struct hqxHeader
{
    char name[HQXFNAMEMAX];
    char type[5];
    char creator[5];
    short flags;
    long dataLen;
    long rsrcLen;
    short headerCRC;
} hqxHeader_t;

/* binhex 4.0 file handle */

typedef struct hqxFileHandle
{
    const char *fname;
    int fd;
    FILE *fp;
    hqxHeader_t hqxHeader;
    short crc;
    short dataCRC;
    short rsrcCRC;
    int haveExtractedDataFork;
    int repeat;
    int repeatChar;
    int eof;
    char outputBuffer[3];
    char *outputPtr;
    char *outputEnd;
    char readBuf[1024];
    ssize_t readBufIndex;
    ssize_t readBufSize;
    int readBufAtEOF;
} hqxFileHandle_t;

/* prototypes */

int hqxInitFileHandle(const char *fname, hqxFileHandle_t *hqxFile);
int hqxReleaseFileHandle(hqxFileHandle_t *hqxFile);
int hqxGetHeader(hqxFileHandle_t *hqxFile);

#endif /* qlZipInfo_binhex_h */

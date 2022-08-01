/*
    binhex.c - decode a binhex file

    History:

    v. 0.1.0 (11/13/2021) - initial release

    Based on:

    https://files.stairways.com/other/binhex-40-specs-info.txt
    http://www.natural-innovations.com/binhex/binhex-src.txt
    https://en.m.wikipedia.org/wiki/BinHex

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

#include <assert.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <sys/errno.h>
#include <sys/stat.h>

#include "macosroman2ascii.h"
#include "binhex.h"

enum
{
    RUNCHAR  = 0x90,
    BYTEMASK = 0xff,
    CRCCONSTANT = 0x1021,
    F_BUNDLE = 0x2000,
    F_LOCKED = 0x8000,
    WORDMASK = 0xffff,
};

enum
{
    OPT_NONE = 0,
    OPT_EXCLUDE_FROM_CRC = 1,
};

/* valid characters for a binhex'ed file */

static const char *gHqxValidChars =
    "!\"#$%&'()*+,-012345689@ABCDEFGHIJKLMNPQRSTUVXYZ[`abcdefhijklmpqr";

#ifdef HQXMAIN

/* command line arguments */

static const char *gStrModeHelpShort = "-h";
static const char *gStrModeHelpLong  = "-help";
static const char *gStrDontExtract = "-n";

#endif /* HQXMAIN */

static const char gHqxValidCharsLookupTable[83] =
{
    0xFF, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
    0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0xFF, 0xFF,
    0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13, 0xFF,
    0x14, 0x15, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D,
    0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23, 0x24, 0xFF,
    0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0xFF,
    0x2C, 0x2D, 0x2E, 0x2F, 0xFF, 0xFF, 0xFF, 0xFF,
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0xFF,
    0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0xFF, 0xFF,
    0x3D, 0x3E, 0x3F
};

#ifdef HQXMAIN

/*
    Prefix and suffix for storing the resource fork, see:
       https://stackoverflow.com/questions/66620681/
       https://en.m.wikipedia.org/wiki/Resource_fork
       https://files.stairways.com/other/binhex-40-specs-info.txt
*/

static const char *gRsrcForkPrefix = "._";
static const char *gRsrcForkSuffix = "/..namedfork/rsrc";

/* maximum buffer size */

static const int gMaxBuf = 8192;

#endif /* HQXMAIN */

/* prototypes */

static int hqxFindHeader(hqxFileHandle_t *hqxFile);
static int hqxGetByte(hqxFileHandle_t *hqxFile);
static int hqxGetByteWithOptions(hqxFileHandle_t *hqxFile, int options);
static int hqxGetByteWithRL(hqxFileHandle_t *hqxFile);
static int hqxGetByteRaw(hqxFileHandle_t *hqxFile);
static short hqxGet2Bytes(hqxFileHandle_t *hqxFile);
static short hqxGet2BytesWithOptions(hqxFileHandle_t *hqxFile, int options);
static long hqxGet4Bytes(hqxFileHandle_t *hqxFile);
static int hqxGet6Bits(hqxFileHandle_t *hqxFile);
static int hqxGetBuffer(hqxFileHandle_t *hqxFile, char *buf, int len);
static void hqxUpdateCRC(int c, hqxFileHandle_t *hqxFile);
static int hqxVerifyCRC(short calculatedCRC, short expectedCRC);
#ifdef HQXMAIN
static int isArg(const char *arg, const char *longMode, const char *shortMode);
static int hqxExtractFork(hqxFileHandle_t *hqxFile, const char *prefix);
static int hqxExtractForks(hqxFileHandle_t *hqxFile);
#endif /* HQXMAIN */
#ifdef HQXDEBUG
static void hqxInterpretFinderFlags(short flags);
#endif /* HQXDEBUG */

/* private functions */

#ifdef HQXMAIN

/* isArg - check whether the supplied argument is one of the
           two specified arguments, return 1 if one of the
           specified arguments match the supplied argument,
           otherwise returns 0 */

int isArg(const char *arg,
           const char *longMode,
           const char *shortMode)
{
    size_t modeStrLen = 0;

    /* return 0 if the supplied argument is null */

    if (arg == NULL || arg[0] == '\0')
    {
        return 0;
    }

    /* if a non-null long mode is specified, check if
       the supplied argument matches it */

    if (longMode != NULL)
    {
        modeStrLen = strlen(longMode);
        if (strncasecmp(arg, longMode, modeStrLen) == 0)
        {
            return (strlen(arg) == modeStrLen ? 1 : 0);
        }
    }

    /* if a non-null short mode is specified, check if
       the supplied argument matches it */

    if (shortMode != NULL)
    {
        modeStrLen = strlen(shortMode);
        if (strncasecmp(arg, shortMode, modeStrLen) == 0)
        {
            return (strlen(arg) == modeStrLen ? 1 : 0);
        }
    }

    /* no match, return 0 */

    return 0;
}
#endif /* HQXMAIN */

/* hqxInitFileHandle - initialize a binhex file handle */

int hqxInitFileHandle(const char *fname, hqxFileHandle_t *hqxFile)
{
    if (fname == NULL || hqxFile == NULL)
    {
        return gHqxErr;
    }

    /* store the specified file name */

    hqxFile->fname = fname;

    /* open the specified file in readonly mode */

    hqxFile->fd = open(hqxFile->fname, O_RDONLY);
    if (hqxFile->fd < 0)
    {
        fprintf(stderr,
                "ERROR: '%s': %s\n",
                hqxFile->fname,
                strerror(errno));
        return gHqxErr;
    }

    /* get a stream pointer to the specified file */

    hqxFile->fp = fdopen(hqxFile->fd, "r");
    if (hqxFile->fp == NULL)
    {
        close(hqxFile->fd);
        return gHqxErr;
    }

    /* clear the CRCs */

    hqxFile->crc = 0;
    hqxFile->dataCRC = 0;
    hqxFile->rsrcCRC = 0;

    /* clear the run length encoding variables */

    hqxFile->repeat = 0;
    hqxFile->repeatChar = 0;
    hqxFile->eof = 0;

    hqxFile->haveExtractedDataFork = 0;

    /* initialize the read buffer */

    memset(hqxFile->readBuf, '\0',
           sizeof(hqxFile->readBuf));
    hqxFile->readBufIndex = -1;
    hqxFile->readBufSize = -1;
    hqxFile->readBufAtEOF = 0;

    /* initialize the output buffer */

    memset(hqxFile->outputBuffer, '\0',
           sizeof(hqxFile->outputBuffer));
    hqxFile->outputPtr = hqxFile->outputBuffer;
    hqxFile->outputEnd =
        hqxFile->outputBuffer + sizeof(hqxFile->outputBuffer);

    /* zero out the binhex header */

    memset(hqxFile->hqxHeader.name, '\0',
           sizeof(hqxFile->hqxHeader.name));
    memset(hqxFile->hqxHeader.type, '\0',
           sizeof(hqxFile->hqxHeader.type));
    memset(hqxFile->hqxHeader.creator, '\0',
           sizeof(hqxFile->hqxHeader.creator));

    hqxFile->hqxHeader.flags = 0;
    hqxFile->hqxHeader.dataLen = -1;
    hqxFile->hqxHeader.rsrcLen = -1;
    hqxFile->hqxHeader.headerCRC = 0;

    return gHqxOkay;
}

/* hqxReleaseFileHandle - release a binhex file handle */

int hqxReleaseFileHandle(hqxFileHandle_t *hqxFile)
{

    /* validate the file handle */

    if (hqxFile == NULL)
    {
        return gHqxErr;
    }

    /* if we have a file stream, fclose(3) it, which also
       should close the underlying file descriptor from
       open(2) that was opened by hqxInitFileHandle */

    if (hqxFile->fp != NULL)
    {
        return fclose(hqxFile->fp);
    }

    /* if we do not have a file stream, but we have a
       valid file descriptor close it */

    if (hqxFile->fd >= 0)
    {
        return close(hqxFile->fd);
    }

    /* default - return an error */

    return gHqxErr;
}

/* hqxFindHeader - find the binhex header */

static int hqxFindHeader(hqxFileHandle_t *hqxFile)
{
    int lineStart = 0, rc = gHqxErr, headerStart = 0;
    ssize_t numread = 0;
    char readbuf;

    /* validate the file handle */

    if (hqxFile == NULL || hqxFile->fd < 0)
    {
        return gHqxErr;
    }

    /* read the file one character at a time to look for the
       start of binhex'ed data (this is slow and inefficient,
       but reliable since binhex files can be embedded in other
       files like emails) */

    while (1)
    {
        numread = read(hqxFile->fd, &readbuf, sizeof(readbuf));
        if (numread <= 0)
        {
            break;
        }

        switch(readbuf)
        {

            /* a newline ('\n') or a carriage return ('\r')
               indicates a start of line. */

            case '\n':
            case '\r':

                lineStart = 1;
                break;

            /* a ':' as the first character on a line potentially
               indicates the start of the header of a binhex'ed
               file */

            case ':':

                if (lineStart == 1)
                {
                    headerStart = 1;
                }
                break;

            default:
                if (headerStart == 1)
                {
                    /* if the header has started, make sure the
                       next character is a valid binhex character */
                    if (strchr(gHqxValidChars, readbuf) != NULL)
                    {
                        rc = gHqxOkay;
                        break;
                    }
                    headerStart = 0;
                }
                lineStart = 0;
                break;
        }

        /* if we found a header, stop reading characters */

        if (rc == gHqxOkay)
        {

            /* rewind by one byte, since we read ahead one byte
               to make sure we had a valid binhex character */

            if (lseek(hqxFile->fd, -1, SEEK_CUR) == -1)
            {
                rc = gHqxErr;
            }

            break;
        }
    }

    return rc;
}

/* hqxGetHeader - retrieve and decode a binhex header */

int hqxGetHeader(hqxFileHandle_t *hqxFile)
{
#if 0
    char *np = NULL;
#endif
    int rc = gHqxErr;
    int nameLen = 0;

    /* validate the file handle */

    if (hqxFile == NULL || hqxFile->fd < 0)
    {
        return rc;
    }

    /* look for a binhex header */

    if (hqxFindHeader(hqxFile) != gHqxOkay)
    {
        fprintf(stderr,
                "ERROR: '%s': could not find valid binhex header\n",
                hqxFile->fname);
        return rc;
    }

#ifdef HQXDEBUG
    fprintf(stderr,"DEBUG: Found header!\n");
#endif

    /* read the file name's length, which is stored in the first byte
       after the initial ':' in a binhex file */

    nameLen = hqxGetByte(hqxFile);
    if (nameLen == EOF)
    {
        fprintf(stderr, "ERROR: Can't read filename length!\n");
        return rc;
    }

    /* increment the name length because it needs to include
       the trailing 0 byte that occurs after the filename in
       a binhex file */

    nameLen++;

    /* make sure the name length is valid */

    if (nameLen >= HQXFNAMEMAX)
    {
        fprintf(stderr,
                "ERROR: Filename length is too long: %d!\n",
                nameLen);
        return rc;
    }

#ifdef HQXDEBUG
    fprintf(stderr, "DEBUG: Filename length is %d\n", nameLen);
#endif

    /* read the filename */

    if (hqxGetBuffer(hqxFile,
                     hqxFile->hqxHeader.name,
                     nameLen) == gHqxErr)
    {
        fprintf(stderr, "ERROR: Can't read filename!\n");
        return rc;
    }

#ifdef HQXDEBUG
    fprintf(stderr, "DEBUG: Raw filename is '%s'\n", hqxFile->hqxHeader.name);
#endif

    /* clean up the file name by changing potential directory
       separators characters (:, /, \,) and non-printable /
       problematic ascii characters to '_' */

    macosroman2ascii(hqxFile->hqxHeader.name,
                     sizeof(hqxFile->hqxHeader.name),
                     hqxFile->hqxHeader.asciiName,
                     sizeof(hqxFile->hqxHeader.asciiName));
#if 0
    for (np = hqxFile->hqxHeader.name; *np != '\0'; np++)
    {
        if (*np == ':' || *np == '/' || *np == '\\' ||
            *np == ';' || *np == ' ' || *np == '<' ||
            *np == '>' || *np == '?' || *np == '`' ||
            *np == '[' || *np == ']' || *np == '^' ||
            *np == '{' || *np == '}' || *np == '|' ||
            *np == '\'' || *np < '+' ||  *np > '~')
        {
            *np = '_';
        }
    }
#endif

#ifdef HQXDEBUG
    fprintf(stderr,
            "DEBUG: Clean filename is '%s'\n",
            hqxFile->hqxHeader.name);
#endif

    /* read the file type; shorten the length by 1 so that we
       have room for a null at the end of the string */

    if (hqxGetBuffer(hqxFile,
                     hqxFile->hqxHeader.type,
                     sizeof(hqxFile->hqxHeader.type)-1) == gHqxErr)
    {
        fprintf(stderr, "ERROR: Can't read file type!\n");
        return rc;
    }

#ifdef HQXDEBUG
    fprintf(stderr,
            "DEBUG: Type is '%s'\n",
            hqxFile->hqxHeader.type);
#endif

    /* read the file creator; shorten the length by 1 so that we
       have room for a null at the end of the string */

    if (hqxGetBuffer(hqxFile,
                     hqxFile->hqxHeader.creator,
                     sizeof(hqxFile->hqxHeader.creator)-1) == gHqxErr)
    {
        fprintf(stderr, "ERROR: Can't read file creator!\n");
        return rc;
    }

#ifdef HQXDEBUG
    fprintf(stderr,
            "DEBUG: Creator is '%s'\n",
            hqxFile->hqxHeader.creator);
#endif

    /* get the flags */

    hqxFile->hqxHeader.flags = hqxGet2Bytes(hqxFile);
    if (hqxFile->hqxHeader.flags == gHqxErr)
    {
        fprintf(stderr, "ERROR: Can't read flags!\n");
        return rc;
    }

#ifdef HQXDEBUG
    fprintf(stderr,
            "DEBUG: Flags are 0x%x\n",
            hqxFile->hqxHeader.flags);
#endif

    hqxFile->hqxHeader.dataLen = hqxGet4Bytes(hqxFile);
    if (hqxFile->hqxHeader.dataLen < 0)
    {
        fprintf(stderr, "ERROR: Can't read data fork length!\n");
        return rc;
    }

#ifdef HQXDEBUG
    fprintf(stderr,
            "DEBUG: Data fork is %ld bytes\n",
            hqxFile->hqxHeader.dataLen);
#endif

    hqxFile->hqxHeader.rsrcLen = hqxGet4Bytes(hqxFile);
    if (hqxFile->hqxHeader.rsrcLen < 0)
    {
        fprintf(stderr, "ERROR: Can't read resource fork length!\n");
        return rc;
    }

#ifdef HQXDEBUG
    fprintf(stderr,
            "DEBUG: Resource fork is %ld bytes\n",
            hqxFile->hqxHeader.rsrcLen);
#endif

    /* read the header CRC, but exclude it from the
       running CRC calculation */

    hqxFile->hqxHeader.headerCRC =
        hqxGet2BytesWithOptions(hqxFile, OPT_EXCLUDE_FROM_CRC);
    if (hqxFile->hqxHeader.headerCRC == gHqxErr)
    {
        fprintf(stderr, "ERROR: Can't read header crc!\n");
        return rc;
    }

#ifdef HQXDEBUG
    fprintf(stderr,
            "DEBUG: Header crc should be 0x%x\n",
            hqxFile->hqxHeader.headerCRC);
#endif

    /* verify that the expected header CRC specified in the
       binhex file matches the one we calculated */

    if (hqxVerifyCRC(hqxFile->crc, hqxFile->hqxHeader.headerCRC) == 0)
    {
        fprintf(stderr,
                "ERROR: Header CRC mismatch: 0x%x != 0x%x\n",
                hqxFile->hqxHeader.headerCRC,
                hqxFile->crc);
        return rc;
    }

#ifdef HQXDEBUG
    fprintf(stderr, "DEBUG: Header crc okay!\n");
#endif

    return gHqxOkay;
}

/* hqxVerifyCRC - verify that the calculated CRC matches
                  the expected CRC */

static int hqxVerifyCRC(short calculatedCRC, short expectedCRC)
{
    calculatedCRC &= WORDMASK;
    expectedCRC &= WORDMASK;

    return (calculatedCRC == expectedCRC ? 1 : 0);
}

/* hqxGetBuffer - read exactly len characters from the binhex file
                  into the specified buffer */

static int hqxGetBuffer(hqxFileHandle_t *hqxFile, char *buf, int len)
{
    int c = EOF, i = 0;

    /* validate the supplied arguments */

    if (hqxFile == NULL ||
        hqxFile->fd < 0 ||
        buf == NULL ||
        len <= 0)
    {
        return gHqxErr;
    }

    /* clear the provided buffer */

    memset(buf, '\0', len);

    /* fill the buffer, one byte at a time */

    for (i = 0; i < len; i++) {
        c = hqxGetByte(hqxFile);
        if (c == EOF)
        {
            return gHqxErr;
        }
        *buf++ = c;
    }

    return gHqxOkay;
}

/* hqxGet2Bytes - read 2 bytes as a short from a binhex file */

static short hqxGet2Bytes(hqxFileHandle_t *hqxFile)
{

    /* get two bytes without any options */

    return hqxGet2BytesWithOptions(hqxFile, OPT_NONE);
}

/* hqxGet2BytesWithOptions - read 2 bytes as a short from a binhex
                             file, using the specified options */

static short hqxGet2BytesWithOptions(hqxFileHandle_t *hqxFile,
                                     int options)
{
    int c = 0;
    short value = gHqxErr;

    /* validate the file handle */

    if (hqxFile == NULL || hqxFile->fd < 0)
    {
        return value;
    }

    /* read the first byte with the specified options */

    c = hqxGetByteWithOptions(hqxFile, options);
    if (c == EOF)
    {
        return value;
    }

    value = (c & BYTEMASK) << 8;

    /* read the second byte with the specified options */

    c = hqxGetByteWithOptions(hqxFile, options);
    if (c == EOF)
    {
        return gHqxErr;
    }

    value |= (c & BYTEMASK);

    return value;
}

/* hqxGet4Bytes - read 4 bytes as a long from the binhex'ed file */

static long hqxGet4Bytes(hqxFileHandle_t *hqxFile)
{
    int i = 0, c = 0;
    long value = 0;

    /* validate the file handle */

    if (hqxFile == NULL || hqxFile->fd < 0)
    {
        return gHqxErr;
    }

    for (i = 0; i < 4; i++)
    {
        c = hqxGetByte(hqxFile);
        if (c == EOF)
        {
            value = gHqxErr;
            break;
        }
        value <<= 8;
        value |= (c & BYTEMASK);
    }

    return value;
}

/* hqxGetByte - read 1 byte from a binhex file */

static int hqxGetByte(hqxFileHandle_t *hqxFile)
{
    /* read 1 byte without any options */

    return hqxGetByteWithOptions(hqxFile, OPT_NONE);
}

/* hqxGetByteWithOptions - read a byte from a binhex file with the
                           specified options */

static int hqxGetByteWithOptions(hqxFileHandle_t *hqxFile,
                                 int options)
{
    int c = EOF;

    /* validate the file handle */

    if (hqxFile == NULL || hqxFile->fd < 0)
    {
        return c;
    }

    /* get a byte from the file */

    c = hqxGetByteWithRL(hqxFile);

    /* if the byte we read is not EOF, see if we need to update
       the CRC, per the options; for example, when computing the
       CRCs for the header, data fork, and resource fork, 0 must
       be used instead of the byte we read */

    if (c != EOF)
    {
        if (options != OPT_EXCLUDE_FROM_CRC)
        {
            hqxUpdateCRC(c, hqxFile);
        }
        else
        {
            hqxUpdateCRC(0, hqxFile);
        }
    }

    /* return the byte we read */

    return c;
}

/* hqxUpdateCRC - update the running CRC */

static void hqxUpdateCRC(int c, hqxFileHandle_t *hqxFile)
{
    int i, temp;

    /* validate the file handle */

    if (hqxFile == NULL || hqxFile->fd < 0)
    {
        return;
    }

#ifdef HQXDEBUG
    fprintf(stderr, "DEBUG: crc starts as 0x%x\n", hqxFile->crc);
#endif /* HQXDEBUG */

    for (i=0; i<8; i++)
    {
        temp = ((hqxFile->crc & 0x8000) != 0 ? 1 : 0);
        hqxFile->crc <<= 1;
        hqxFile->crc |= c >> 7;
        if (temp != 0)
        {
            hqxFile->crc ^= CRCCONSTANT;
        }
        c <<= 1;
        c &= BYTEMASK;
    }

#ifdef HQXDEBUG
    fprintf(stderr, "DEBUG: crc is now 0x%x\n", hqxFile->crc);
#endif /* HQXDEBUG */
}

/* hqxGetByteWithRL - read a byte from a binhex file, taking run
                      length encoding into account */

static int hqxGetByteWithRL(hqxFileHandle_t *hqxFile)
{
    int c = EOF;

    /* validate the file handle */

    if (hqxFile == NULL || hqxFile->fd < 0)
    {
        return c;
    }

    /* if repeat is non-zero, we previously encountered
       a run length encoding indicator, so return the
       repeated character and decrement the repeat counter */

    if (hqxFile->repeat > 0)
    {
        hqxFile->repeat--;
        return hqxFile->repeatChar;
    }

    c = hqxGetByteRaw(hqxFile);

    /* end of file occurred */

    if (c == EOF)
    {
        hqxFile->eof = 1;
        return c;
    }

    /* a regular byte was found, save it as the repeat
       character and return it */

    if (c != RUNCHAR)
    {
        hqxFile->repeatChar = c;
        return c;
    }

    /* the byte we just read was the start of run length
       encoding indicator, so read the next byte to get
       the number of repeats */

    hqxFile->repeat = hqxGetByteRaw(hqxFile);

    /* EOF occurred instead of the repeat count, return it */

    if (hqxFile->repeat == EOF)
    {
        hqxFile->eof = 1;
        return EOF;
    }

    /* the repeat count was zero, so the byte was a literal
       run length encoding start indicator, so return that */

    if (hqxFile->repeat == 0)
    {
        hqxFile->repeatChar = RUNCHAR;
        return RUNCHAR;
    }

    /* reduce the repeat count and return the saved repeated character */

    hqxFile->repeat -= 2;
    return hqxFile->repeatChar;
}

/* hqxGetByteRaw - read a byte from a bin hex file */

static int hqxGetByteRaw(hqxFileHandle_t *hqxFile)
{
    char readBuffer[4];
    char *readBufferPtr = NULL;
    char *readBufferEnd = NULL;
    int c = EOF;

    /* validate the file handle */

    if (hqxFile == NULL || hqxFile->fd < 0)
    {
        return c;
    }

    memset(readBuffer, '\0', sizeof(readBuffer));
    readBufferPtr = readBuffer;
    readBufferEnd = readBuffer + sizeof(readBuffer);

    if (hqxFile->outputPtr == hqxFile->outputBuffer)
    {
        for (readBufferPtr = readBuffer;
             readBufferPtr < readBufferEnd;
             readBufferPtr++)
        {
            c = hqxGet6Bits(hqxFile);

            if (c == EOF)
            {
                if (readBufferPtr <= &readBuffer[1])
                {
                    return c;
                }

                if (readBufferPtr == &readBuffer[2])
                {
                    hqxFile->eof = 1;
                }
                else
                {
                    hqxFile->eof = 2;
                }
            }

            *readBufferPtr = c;
        }

        hqxFile->outputBuffer[0] =
            (readBuffer[0] << 2 | readBuffer[1] >> 4);
        hqxFile->outputBuffer[1] =
            (readBuffer[1] << 4 | readBuffer[2] >> 2);
        hqxFile->outputBuffer[2] =
            (readBuffer[2] << 6 | readBuffer[3]);
    }

    /* at EOF */

    if (hqxFile->eof != 0 &&
        (hqxFile->outputPtr >= &(hqxFile->outputPtr[hqxFile->eof])))
    {
        return EOF;
    }

    c = *(hqxFile->outputPtr++);

    if (hqxFile->outputPtr >= hqxFile->outputEnd)
    {
        hqxFile->outputPtr = hqxFile->outputBuffer;
    }

    return (c & BYTEMASK);
}

/* hqxGetByteRaw - read 6 bits from a bin hex file */

static int hqxGet6Bits(hqxFileHandle_t *hqxFile)
{
    int tc = 0, needRead = 0;
    char nextChar = EOF;

    /* validate the file handle */

    if (hqxFile == NULL || hqxFile->fd < 0)
    {
        return EOF;
    }

    /* if we have reached the end of the file, return EOF */

    if (hqxFile->readBufAtEOF != 0)
    {
        return EOF;
    }

    do
    {

        /* if either the read buffer index is -1 or the read buffer size
           is -1, we need to try to read from the input file */

        if (hqxFile->readBufIndex == -1 || hqxFile->readBufSize == -1)
        {
            needRead = 1;
        }

        /* if the read buffer index is greater than or equal to the
            read buffer size, we need to try to read from the input
            file */

        if (hqxFile->readBufIndex >= hqxFile->readBufSize)
        {
            needRead = 1;
        }

        /* if we need to read from the input file, do so */

        if (needRead == 1)
        {

            /* clear the read buffer */

            memset(hqxFile->readBuf, '\0', sizeof(hqxFile->readBuf));

            /* try to read up to the size of the read buffer from
               the input file and store the number of bytes read */

            hqxFile->readBufSize = read(hqxFile->fd,
                                        hqxFile->readBuf,
                                        sizeof(hqxFile->readBuf));

            /* if the number of bytes read == 0, we are at the end
               of the input file, so return EOF */

            if (hqxFile->readBufSize == 0)
            {
                hqxFile->readBufAtEOF = 1;
                return EOF;
            }

            /* if the number of bytes read is less than 0, an error
               occurred, report the error and return EOF */

            if (hqxFile->readBufSize < 0)
            {
                fprintf(stderr,
                        "ERROR: %s: %s\n", hqxFile->fname,
                        strerror(errno));
                hqxFile->readBufAtEOF = 1;
                return EOF;
            }

            /* reset the read buffer index to the beginning of the
               read buffer and clear the flag indicating we need
               to read from the input file */

            hqxFile->readBufIndex = 0;
            needRead = 0;
        }

        /* read the next character from the read buffer */

        nextChar = hqxFile->readBuf[hqxFile->readBufIndex];
        hqxFile->readBufIndex++;

        switch(nextChar)
        {

            /* skip new lines and carriage returns */

            case '\n':
            case '\r':
                continue;

            /* a : or EOF, indicates end of the file, so
               return that */

            case ':':
            case EOF:
                hqxFile->readBufAtEOF = 1;
                return EOF;

            /* make sure the next character is a valid
               character for a binhex file */

            default:
                tc = ((nextChar-' ') < 83) ?
                      gHqxValidCharsLookupTable[nextChar-' '] :
                      0xff;
                if (tc != 0xff)
                {
                    return (tc);
                }
                fprintf(stderr, "ERROR: bad char: '%c'\n", nextChar);
                hqxFile->readBufAtEOF = 1;
                return EOF;
        }
    } while(1);
#if HQX_KEEPCOMPILERHAPPY
    hqxFile->readBufAtEOF = 1;
    return EOF;
#endif
}

#ifdef HQXMAIN

/* hqxExtractFork - extract either the data fork or the rsrc fork from
                    a bin hex file; if the prefix is specified, then
                    the resource fork is extracted.

   NOTE: the data fork must be extracted first; asking for the rsrc fork
         first will result in an error */

static int hqxExtractFork(hqxFileHandle_t *hqxFile, const char *prefix)
{
    int outfd = -1, c = 0, setPerms = 1;
    ssize_t err = 0;
    unsigned long outFileNameLen = 0;
    unsigned long freeOutFileName = 0;
    unsigned long altFileNameLen = 0;
    long forkLen = 0, i = 0, j = 0;
    char *outFileName = NULL, *altFileName = NULL, *outBuf = NULL;

    if (hqxFile == NULL ||
        hqxFile->fd < 0 ||
        hqxFile->hqxHeader.name[0] == '\0')
    {
        return gHqxErr;
    }

    if (prefix != NULL && hqxFile->haveExtractedDataFork != 1)
    {
        return gHqxErr;
    }

    /* if a prefix is specified, we are extracting the rsrc fork */

    forkLen = (prefix == NULL ?
               hqxFile->hqxHeader.dataLen :
               hqxFile->hqxHeader.rsrcLen);

    /* if the fork length is less than zero, the header may not have
       been read / initialized properly, return an error */

    if (forkLen < 0)
    {
        return gHqxErr;
    }

    /* if the fork we are extracting is 0 size, skip it */

    if (forkLen == 0)
    {

        /* if no prefix was specified, then we are dealing
           with a 0 size data fork - just read and store
           the crc so that the rsrc fork can be extracted
           properly; no need to do this for a zero sized
           rsrc fork */

        if (prefix == NULL)
        {
            hqxFile->dataCRC = hqxGet2Bytes(hqxFile);
        }

        fprintf(stderr, "DEBUG: forkLen == 0, skipping.\n");
        return gHqxOkay;
    }

    if (prefix != NULL)
    {
        /* if the prefix is specified, allocate memory to store the
           output file name plus the resource fork prefix */

        outFileNameLen =
            strlen(hqxFile->hqxHeader.name) + strlen(prefix) + 1;

        outFileName = calloc(outFileNameLen, sizeof(char));
        if (outFileName == NULL)
        {
            fprintf(stderr,
                    "ERROR: Cannot allocate memory for rsrc fork filename.\n");
            return gHqxErr;
        }

        freeOutFileName = 1;

        err = snprintf(outFileName,
                       outFileNameLen,
                       "%s%s",
                       prefix,
                       hqxFile->hqxHeader.name);
        if (err < 0)
        {
            fprintf(stderr,
                    "ERROR: Cannot store rsrc fork filename.\n");
            free(outFileName);
            return gHqxErr;
        }

        /* allocate memory to store the alternate name for the
           resource fork */

        altFileNameLen = strlen(hqxFile->hqxHeader.name) +
                         strlen(gRsrcForkSuffix) + 1;
        altFileName = calloc(altFileNameLen, sizeof(char));
        if (altFileName != NULL)
        {
            err = snprintf(altFileName,
                           altFileNameLen,
                           "%s%s",
                           hqxFile->hqxHeader.name,
                           gRsrcForkSuffix);
            if (err < 0)
            {
                free(altFileName);
                altFileName = NULL;
            }
        }
    }
    else
    {
        outFileName = hqxFile->hqxHeader.name;
    }

#ifdef HQXDEBUG
    fprintf(stderr, "DEBUG: output file is: '%s'\n", outFileName);
#endif /* HQXDEBUG */

    /* remove write permissions for group and others */

    umask(S_IWGRP | S_IWOTH);

    /* open the output file for writing, creating it if it doesn't
       exist, but erroring if it already exists; if the alternate
       name is not null, we start with it first */

    if (altFileName != NULL && altFileName[0] != '\0')
    {
        outfd = open(altFileName, O_WRONLY | O_CREAT | O_EXCL);
#ifdef HQXDEBUG
        if (outfd < 0)
        {
            fprintf(stderr,
                    "DEBUG: can't open %s: %s!\n.",
                    altFileName,
                    strerror(errno));
        }
#endif /*HQXDEBUG */

        free(altFileName);
    }

    /* check if we have already opened an output file (for
       example, using the alternate name for rsrc forks); if
       not, open it */

    if (outfd < 0) {
        /* make sure we have a valid output file name */

        if (outFileName == NULL || outFileName[0] == '\0')
        {
            if (freeOutFileName != 0)
            {
                free(outFileName);
            }
            fprintf(stderr,
                    "ERROR: output filename was NULL!\n");
            return gHqxErr;
        }

        outfd = open(outFileName, O_WRONLY | O_CREAT | O_EXCL);
    }
    else
    {

        /* we are using the name rsrc fork, so don't try to
          set permissions for it (which would fail) */

        setPerms = 0;

#ifdef HQXDEBUG
        fprintf(stderr,
                "DEBUG: writing to %s%s\n",
                hqxFile->hqxHeader.name,
                gRsrcForkSuffix);
#endif /* HQXDEBUG */

    }

    if (freeOutFileName != 0)
    {
        free(outFileName);
    }

    if (outfd < 0)
    {
        fprintf(stderr,
                "ERROR: can't open output file: %s\n",
                strerror(errno));
        return gHqxErr;
    }

    /* set the permissions for the file we just opened */

    if (setPerms != 0)
    {
        err = fchmod(outfd, S_IRUSR | S_IWUSR | S_IRGRP);
        if (err < 0)
        {
            fprintf(stderr,
                    "ERROR: Can't set output file permissions: %s\n",
                    strerror(errno));
            return gHqxErr;
        }
    }

    /* reset the running crc */

    hqxFile->crc = 0;

    outBuf = calloc(gMaxBuf, sizeof(char));
    if (outBuf == NULL)
    {
        fprintf(stderr,
                "ERROR: Can't allocate output buffer: %s\n",
                strerror(errno));
        return gHqxErr;
    }

    for (i = 0, j = 0; i < forkLen; i++, j++)
    {
        /* read a byte from the binhex'ed file */

        c = hqxGetByte(hqxFile);
        if (c == EOF)
        {
            fprintf(stderr, "ERROR: unexpected end of input file!\n");
            err = -1;
            break;
        }

        /* while the output buffer is not full, store the
           byte we just read in the output buffer */

        if (j < gMaxBuf)
        {
            outBuf[j] = c;
            continue;
        }

        /* the output buffer is full, so write it to the file */

        err = write(outfd, outBuf, j);
        if (err < 0 || err != j)
        {
            fprintf(stderr,
                    "ERROR: can't write to output file: %s!\n",
                    strerror(errno));
            break;
        }

        /* go back to the beginning of the output buffer
           and store the byte we just read */

        j = 0;
        outBuf[j] = c;
    }

    /* if there was no error in the read / write loop above,
       and there is data in the output buffer, write it to
       the output file */

    if (err >= 0 && j > 0 && j < gMaxBuf)
    {
        err = write(outfd, outBuf, j);
        if (err < 0)
        {
            fprintf(stderr,
                    "ERROR: can't write to output file: %s!\n",
                    strerror(errno));
        }

#ifdef HQXDEBUG
        fprintf(stderr,
                "DEBUG: read=%ld, lastbuf=%ld, total=%ld, len=%ld\n",
                i, j, forkLen);
#endif /* HQXDEBUG */
    }

    /* we don't need the output buffer anymore, so free it */

    if (outBuf != NULL)
    {
        free(outBuf);
    }

    /* we don't need the file descriptor for the output file anymore,
       so close it */

    close(outfd);

    /* if the prefix is null, check the the data fork's CRC
       and return */

    if (prefix == NULL)
    {
        hqxFile->dataCRC =
            hqxGet2BytesWithOptions(hqxFile, OPT_EXCLUDE_FROM_CRC);
        if (hqxFile->dataCRC == gHqxErr)
        {
            fprintf(stderr, "ERROR: Can't read data fork crc!\n");
            return gHqxErr;
        }

        if (hqxVerifyCRC(hqxFile->crc, hqxFile->dataCRC) == 0)
        {
            fprintf(stderr,
                    "ERROR: data fork crc mismatch: 0x%x != 0x%x\n",
                     hqxFile->dataCRC,
                     hqxFile->crc);
            return gHqxErr;
        }

#ifdef HQXDEBUG
        fprintf(stderr,
                "DEBUG: data fork crc (0x%x) match.\n",
                hqxFile->crc);
#endif /* HQXDEBUG */

        /* data fork extraction completed successfully, note that
           in the file handle */

        hqxFile->haveExtractedDataFork = 1;

        return gHqxOkay;
    }

    /* the prefix wasn't null, so we were dealing with the rsrc
       fork, check its crc and return */

    hqxFile->rsrcCRC =
        hqxGet2BytesWithOptions(hqxFile, OPT_EXCLUDE_FROM_CRC);
    if (hqxFile->rsrcCRC == gHqxErr)
    {
        fprintf(stderr, "ERROR: Can't read rsrc fork crc!\n");
        return gHqxErr;
    }

    if (hqxVerifyCRC(hqxFile->crc, hqxFile->rsrcCRC) == 0)
    {
        fprintf(stderr,
                "ERROR: rsrc fork crc mismatch: 0x%x != 0x%x\n",
                 hqxFile->rsrcCRC,
                 hqxFile->crc);
        return gHqxErr;
    }

#ifdef HQXDEBUG
        fprintf(stderr,
                "DEBUG: rsrc fork crc (0x%x) match.\n",
                hqxFile->crc);
#endif /* HQXDEBUG */

    return gHqxOkay;
}

static int hqxExtractForks(hqxFileHandle_t *hqxFile)
{

    /* validate the file handle */

    if (hqxFile == NULL ||
        hqxFile->fd < 0 ||
        hqxFile->hqxHeader.name[0] == '\0')
    {
        return gHqxErr;
    }

#ifdef HQXDEBUG
    fprintf(stderr, "DEBUG: Starting to write data fork.\n");
#endif /* HQXDEBUG */

    if (hqxExtractFork(hqxFile, NULL) != gHqxOkay)
    {
        fprintf(stderr,
                "ERROR: '%s': data fork not extracted correctly\n",
                hqxFile->hqxHeader.name);
        return gHqxErr;
    }

    fprintf(stderr,
            "DEBUG: '%s': extracted data fork\n",
            hqxFile->hqxHeader.name);

    /* extract the resource fork */

#ifdef HQXDEBUG
    fprintf(stderr, "DEBUG: Starting to write rsrc fork.\n");
#endif /* HQXDEBUG */

    if (hqxExtractFork(hqxFile, gRsrcForkPrefix) != gHqxOkay)
    {
        fprintf(stderr,
                "ERROR: '%s': rsrc fork not extracted correctly\n",
                hqxFile->hqxHeader.name);
        return gHqxErr;
    }

    fprintf(stderr,
            "DEBUG: '%s': extracted rsrc fork\n",
            hqxFile->hqxHeader.name);

    return gHqxOkay;
}
#endif /* HQXMAIN */

#ifdef HQXDEBUG
/* hqxInterpretFinderFlags - interpret finder flags

   TODO: add more flags from Tech Note 40:
   https://spinsidemacintosh.neocities.org/tn405.html#tn040 */

static void hqxInterpretFinderFlags(short flags)
{
    if (flags == 0)
    {
        return;
    }

    fprintf (stderr, "DEBUG: flags are: ");

    if ((flags ^ F_BUNDLE) == 0)
    {
        fprintf(stderr, "'locked' ");
    }

    if ((flags ^ F_LOCKED) == 0)
    {
        fprintf(stderr, "'bundle' ");
    }

    fprintf (stderr, "\n");
}
#endif /* HQXDEBUG */

#ifdef HQXMAIN
/* main */

int main (int argc, char **argv)
{
    hqxFileHandle_t hqxFile;
    int dontExtract = 0, fileIndex = 1, rc = 0;

    /* print a usage message if no was specified */

    if (argc < 2 || argv[1] == NULL)
    {
        fprintf(stderr,"Usage: %s [-h] | [-n] [file]\n", argv[0]);
        return 1;
    }

    /* at least one argument */

    if (argc >= 2)
    {
        /* if the argument is -h for help, print a usage message */

        if (isArg(argv[1], gStrModeHelpLong, gStrModeHelpShort) == 1)
        {
            fprintf(stderr,"Usage: %s [-h] | [-n] [file]\n", argv[0]);
            return 0;
        }

        /* if the argument is -n for don't extract, assume the next
           argument is the file */

        if (isArg(argv[1], gStrDontExtract, NULL) == 1)
        {
            dontExtract = 1;
            fileIndex = 2;
        }
    }

    if (argc < (fileIndex+1) || argv[fileIndex] == NULL)
    {
        fprintf(stderr,"Usage: %s [-h] | [-n] [file]\n", argv[0]);
        return 1;
    }

    if (hqxInitFileHandle(argv[fileIndex], &hqxFile) != gHqxOkay)
    {
        fprintf(stderr, "ERROR: could not initialize file handle\n");
        return 1;
    }

    if (hqxGetHeader(&hqxFile) != gHqxOkay)
    {
        hqxReleaseFileHandle(&hqxFile);
        return 1;
    }

    /* print a summary of the contents of the file */

    fprintf(stdout,
            "%s: %s %s 0x%04x %ld B (data) %ld B (rsrc) %ld B (total)\n",
            hqxFile.hqxHeader.name,
            hqxFile.hqxHeader.type,
            hqxFile.hqxHeader.creator,
            hqxFile.hqxHeader.flags,
            hqxFile.hqxHeader.dataLen,
            hqxFile.hqxHeader.rsrcLen,
            hqxFile.hqxHeader.dataLen +
            hqxFile.hqxHeader.rsrcLen);

#ifdef HQXDEBUG
    hqxInterpretFinderFlags(hqxFile.hqxHeader.flags);
#endif /* HQXDEBUG */

    if (dontExtract == 1)
    {
        return 0;
    }

    /* extract the data and rsrc forks */

    if (hqxExtractForks(&hqxFile) != gHqxOkay)
    {
        rc = 1;
    }

    hqxReleaseFileHandle(&hqxFile);

    return rc;
}
#endif /* HQXMAIN */

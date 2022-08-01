/*
    sit.c - list the entries in a Stuffit Archive

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

#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>

#include "sit.h"
#include "macosroman2ascii.h"

/* defines */

#define SITHDRLEN       22
#define SITENTRYHDRLEN 112

/* globals */

static const char *gTypeApplication = "APPL";

/* sit magic numbers */

static const char *gSitMagicNumber1s[] =
{
    "SIT!",
    "ST46",
    "ST50",
    "ST60",
    "ST65",
    "STin",
    "STi2",
    "STi3",
    "STi4",
    NULL
};

static const char *gSitMagicNumber2 = "rLau";

enum
{
    gMaskNibble = 0x0000000f,
    gMaskByte   = 0x000000ff,
    gMaskWord   = 0x0000ffff,
};

/* offsets for the entires in a sit file's header */

enum
{
    SitHdrOffsetSig1       =  0,
    SitHdrOffSetNumFiles   =  4,
    SitHdrOffsetArchiveLen =  6,
    SitHdrOffsetSig2       = 10,
    SitHdrOffsetVersion    = 14,
};

/* offsets for data stored in each entry */

enum
{
    SitEHdrOffsetRsrcCompType =   0,
    SitEHdrOffsetDataCompType =   1,
    SitEHdrOffsetNameLen      =   2,
    SitEHdrOffsetName         =   3,
    SitEHdrOffsetType         =  66,
    SitEHdrOffsetCreator      =  70,
    SitEHdrOffsetFinderFlags  =  74,
    SitEHdrOffsetCreationDate =  76,
    SitEHdrOffsetModDate      =  80,
    SitEHdrOffsetRsrcLen      =  84,
    SitEHdrOffsetDataLen      =  88,
    SitEHdrOffsetRsrcCompLen  =  92,
    SitEHdrOffsetDataCompLen  =  96,
    SitEHdrOffsetRsrcCRC      = 100,
    SitEHdrOffsetDataCRC      = 102,
    SitEHdrOffsetCRC          = 110,
};

/* private functions */

static unsigned long getULong(char *buf);
static unsigned short getUShort(char *buf);
#ifdef SITMAIN
static int sitListEntries(sitFileHandle_t *sitFile);
#endif /* SITMAIN */

/* getULong - get an unsigned long from the specified buffer */

static unsigned long getULong(char *buf)
{
    int i = 0;
    unsigned long value = 0;

    if (buf == NULL)
    {
        return value;
    }

    for(i = 0; i < 4; i++)
    {
        value <<= 8;
        value |= (*buf & gMaskByte);
        buf++;
    }

    return value;
}

/* getUShort - get an unsigned short from the specified buffer */

static unsigned short getUShort(char *buf)
{
    int i = 0;
    unsigned short value = 0;

    if (buf == NULL)
    {
        return value;
    }

    for(i = 0; i < 2; i++)
    {
        value <<= 8;
        value |= (*buf & gMaskByte);
        buf++;
    }

    return (unsigned short)value;
}

/* sitInitFileHandle - initialize a SIT file handle */

int sitInitFileHandle(const char *fname,
                      sitFileHandle_t *sitFile)
{
    char hdr[SITHDRLEN];
    size_t hdrLen = 0;
    size_t i = 0;
    int haveMagic1 = 0;

    if (fname == NULL || sitFile == NULL)
    {
        return gSitErr;
    }

    sitFile->fd = -1;
    sitFile->fp = NULL;
    sitFile->numEntries = 0;
    sitFile->archiveLen = 0;
    sitFile->version = 0;

    sitFile->fd = open(fname, O_RDONLY);
    if (sitFile->fd < 0)
    {
        fprintf(stderr,"Error: cannot open '%s'\n", fname);
        return gSitErr;
    }

    sitFile->fp = fdopen(sitFile->fd, "r");
    if (sitFile->fp == NULL)
    {
        close(sitFile->fd);
        fprintf(stderr,"Error: cannot open '%s'\n", fname);
        return gSitErr;
    }

    hdrLen = sizeof(hdr);

    memset(hdr, '\0', hdrLen);

    if (fread(hdr, 1, hdrLen, sitFile->fp) != hdrLen)
    {
        fclose(sitFile->fp);
        close(sitFile->fd);
        fprintf(stderr,"Error: cannot read SIT header in '%s'\n", fname);
        return gSitErr;
    }

    /* look for the first magic number */

    for (i = 0; gSitMagicNumber1s[i] != NULL; i++)
    {
        if (strncmp(hdr + SitHdrOffsetSig1,
                    gSitMagicNumber1s[i],
                    strlen(gSitMagicNumber1s[i])) == 0)
        {
            haveMagic1 = 1;
            break;
        }
    }

    if (haveMagic1 != 1)
    {
        fclose(sitFile->fp);
        close(sitFile->fd);
        fprintf(stderr,"Error: SIT Magic No. 1 not found in '%s'\n", fname);
        return gSitErr;
    }

    if (strncmp(hdr + SitHdrOffsetSig2,
                gSitMagicNumber2,
                strlen(gSitMagicNumber2)) != 0)
    {
        fclose(sitFile->fp);
        close(sitFile->fd);
        fprintf(stderr,"Error: SIT Magic No. 2 not found in '%s'\n", fname);
        return gSitErr;
    }

    sitFile->numEntries = getUShort(hdr + SitHdrOffSetNumFiles);
    sitFile->archiveLen = getULong(hdr + SitHdrOffsetArchiveLen);
    sitFile->version = hdr[SitHdrOffsetVersion];

    return gSitOkay;
}

/* sitReleaseFileHandle - release a SIT file handle */

int sitReleaseFileHandle(sitFileHandle_t *sitFile)
{
    int ret = gSitOkay;

    if (sitFile == NULL)
    {
        return gSitErr;
    }

    if (sitFile->fp != NULL && fclose(sitFile->fp) != 0)
    {
        ret = gSitErr;
    }

    if (sitFile->fd >= 0 && close(sitFile->fd) != 0)
    {
        ret = gSitErr;
    }

    return ret;
}

/*
    sitIsEntryEncrypted - returns 1 if the entry is encrypted,
                          otherwise returns 0
*/

int sitIsEntryEncrypted(sitEntryHeader_t *entry)
{

    if (entry != NULL &&
        entry->rsrcCompType == SitCompEncrypted)
    {
        return 1;
    }
    return 0;
}

/*
    sitIsEntryFolder - returns 1, if the entry is the start of
                       a folder,
                       returns 2, if the entry is the end of a
                       folder,
                       otherwise returns 0
*/

int sitIsEntryFolder(sitEntryHeader_t *entry)
{
    if (entry == NULL)
    {
        return 0;
    }

    if (entry->rsrcCompType == SitCompFolderStart)
    {
        return SitEntryFolderStart;
    }

    if (entry->rsrcCompType == SitCompFolderEnd)
    {
        return SitEntryFolderEnd;
    }

    return 0;
}

/* sitIsEntryApplication - return 1, if the entry is an application,
                           return 0 otherwise
*/

int sitIsEntryApplication(sitEntryHeader_t *entry)
{
    if (entry != NULL &&
        strcmp(entry->type, gTypeApplication) == 0)
    {
        return 1;
    }

    return 0;
}

/* sitEntryGetFileName - return the file name stored in the entry */

char * sitEntryGetFilename(sitEntryHeader_t *entry)
{
    if (entry == NULL)
    {
        return NULL;
    }

    return entry->name;
}

/* sitEntryGetFileName - return the file name stored in the entry */

char * sitEntryGetAsciiName(sitEntryHeader_t *entry)
{
    if (entry == NULL)
    {
        return NULL;
    }

    return entry->asciiName;
}

/* sitEntryGetCompressedSize - get the entry's compressed size */

unsigned long sitEntryGetCompressedSize(sitEntryHeader_t *entry)
{
    if (entry == NULL)
    {
        return 0;
    }

    return (entry->rsrcCompLen + entry->dataCompLen);
}

/* sitEntryGetUnCompressedSize - get the entry's uncompressed size */

unsigned long sitEntryGetUnCompressedSize(sitEntryHeader_t *entry)
{
    if (entry == NULL)
    {
        return 0;
    }

    return (entry->rsrcLen + entry->dataLen);
}

/* sitEntryGetModifiedDate - get the entry's last modified date */

unsigned long sitEntryGetModifiedDate(sitEntryHeader_t *entry)
{
    if (entry == NULL)
    {
        return 0;
    }

    return (entry->modDate);
}

/* sitGetSize - get the sit file's size */

unsigned long sitGetSize(sitFileHandle_t *sitFile)
{
    if (sitFile == NULL)
    {
        return 0;
    }
    return sitFile->archiveLen;
}

/* sitGetNextEntry - get the next entry in the SIT file */

int sitGetNextEntry(sitFileHandle_t *sitFile,
                    sitEntryHeader_t *entry)
{
    char fHdrBuf[SITENTRYHDRLEN];
    size_t fHdrLen = 0;
    size_t fNameLen = 0;
    size_t fNameLenAcutal = 0;
    size_t typeLen = 0;
    size_t creatorLen = 0;

    if (sitFile == NULL || entry == NULL)
    {
        return gSitErr;
    }

    fHdrLen = sizeof(fHdrBuf);
    fNameLen = sizeof(entry->name);
    typeLen = sizeof(entry->type);
    creatorLen = sizeof(entry->creator);

    if (feof(sitFile->fp) != 0)
    {
        return gSitEOF;
    }

    memset(fHdrBuf, '\0', fHdrLen);

    if (fread(fHdrBuf, 1, fHdrLen, sitFile->fp) != fHdrLen)
    {
        if (feof(sitFile->fp) == 0)
        {
            fprintf(stderr,"Error: Could not read header\n");
            return gSitErr;
        }
        return gSitEOF;
    }

    memset(entry->name, '\0', fNameLen);
    memset(entry->asciiName, '\0', fNameLen);
    memset(entry->type, '\0', typeLen);
    memset(entry->creator, '\0', creatorLen);

    entry->rsrcCompType = fHdrBuf[SitEHdrOffsetRsrcCompType];
    entry->dataCompType = fHdrBuf[SitEHdrOffsetDataCompType];

    fNameLenAcutal = fHdrBuf[SitEHdrOffsetNameLen] & gMaskByte;
    if (fNameLenAcutal >= fNameLen)
    {
        fNameLenAcutal = fNameLen-1;
    }

    strncpy(entry->name, fHdrBuf + SitEHdrOffsetName, fNameLenAcutal);
    strncpy(entry->type, fHdrBuf + SitEHdrOffsetType, typeLen-1);
    strncpy(entry->creator, fHdrBuf + SitEHdrOffsetCreator, creatorLen-1);

    macosroman2ascii(entry->name, (int)fNameLenAcutal,
                     entry->asciiName, (int)fNameLenAcutal);

    entry->finderFlags = getUShort(fHdrBuf + SitEHdrOffsetFinderFlags);
    entry->creationDate = getULong(fHdrBuf + SitEHdrOffsetCreationDate);
    entry->modDate = getULong(fHdrBuf + SitEHdrOffsetModDate);
    entry->rsrcLen = getULong(fHdrBuf + SitEHdrOffsetRsrcLen);
    entry->dataLen = getULong(fHdrBuf + SitEHdrOffsetDataLen);
    entry->rsrcCompLen = getULong(fHdrBuf + SitEHdrOffsetRsrcCompLen);
    entry->dataCompLen = getULong(fHdrBuf + SitEHdrOffsetDataCompLen);
    entry->rsrcCRC = getUShort(fHdrBuf + SitEHdrOffsetRsrcCRC);
    entry->dataCRC = getUShort(fHdrBuf + SitEHdrOffsetDataCRC);
    entry->hdrCRC = getUShort(fHdrBuf + SitEHdrOffsetCRC);

    if (entry->rsrcCompType != SitCompFolderStart &&
        entry->rsrcCompType != SitCompFolderEnd)
    {
        if (fseek(sitFile->fp,
                  entry->rsrcCompLen + entry->dataCompLen,
                  SEEK_CUR) < 0)
        {
            return gSitErr;
        }
    }

    return gSitOkay;
}

#ifdef SITMAIN

/* sitListFiles - list entries in a SIT file */

int sitListEntries(sitFileHandle_t *sitFile)
{
    int ret = gSitOkay;
    sitEntryHeader_t eHdr;
    size_t entryUncompressedSize = 0;
    size_t totalUncompressedSize = 0;
    size_t totalEntries = 0;

    if (sitFile == NULL)
    {
        return gSitErr;
    }

    do
    {
        ret = sitGetNextEntry(sitFile, &eHdr);
        if (ret != gSitOkay)
        {
            break;
        }

        if (eHdr.rsrcCompType == SitCompFolderEnd)
        {
            continue;
        }

        totalEntries++;

        if (eHdr.rsrcCompType == SitCompFolderStart)
        {
            fprintf(stdout, "Folder: '%s'\n", eHdr.name);
            continue;
        }

        entryUncompressedSize = eHdr.rsrcLen + eHdr.dataLen;
        totalUncompressedSize += entryUncompressedSize;

        fprintf(stdout,
                "File:   '%s' (%s), %lu b (comp), %lu b (uncomp)\n",
                eHdr.name,
                eHdr.type,
                eHdr.rsrcCompLen + eHdr.dataCompLen,
                entryUncompressedSize);

    } while (ret == gSitOkay);

    fprintf(stdout,
            "Total:  %ld entries, %lu b (comp), %lu b (uncomp), %4.2f%%\n",
            totalEntries,
            sitFile->archiveLen,
            totalUncompressedSize,
            100.0 * (1.0 - ((float)(sitFile->archiveLen * 1.0) /
            (float)(totalUncompressedSize * 1.0))));

    return ret;
}

int main (int argc, char **argv)
{
    sitFileHandle_t sitFile;

    if (argc <= 1)
    {
        fprintf(stderr,"Usage: sitls [file]\n");
        return 1;
    }

    if (argv[1] == NULL || argv[1][0] == '\0')
    {
        fprintf(stderr,"Error: filename is null!\n");
        return 1;
    }

    if (sitInitFileHandle(argv[1], &sitFile) != gSitOkay)
    {
        return 1;
    }

    sitListEntries(&sitFile);

    if (sitReleaseFileHandle(&sitFile) != gSitOkay)
    {
        return 1;
    }

    return 0;
}
#endif /* SITMAIN */

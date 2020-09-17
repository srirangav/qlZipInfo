/*
    GeneratePreviewForURL - generate a preview of a zip file
    $Id: GeneratePreviewForURL.c 1435 2015-08-14 16:48:34Z ranga $
 
    History:
 
    v. 0.1.0 (08/19/2015) - Initial Release
    v. 0.1.1 (08/27/2015) - Add icon support, file sizes in B, KB,
                            MB, GB, and TB, and compression ratio
    v. 0.1.2 (09/16/2015) - Localize the date output, fix compression reporting,
                            and escape any HTML characters in filenames
    v. 0.1.3 (07/16/2019) - Update to use minizip 1.2, show compression method

    Copyright (c) 2015 Sriranga R. Veeraraghavan <ranga@calalum.org>
 
    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:
 
    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.
 
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
    THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.
 */

@import Foundation;
@import AppKit;

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include <sys/syslimits.h>

#include "unzip.h"
#include "minishared.h"
#import "GTMNSString+HTML.h"

/* structs */

typedef struct fileSizeSpec {
    char spec[3];
    Float64 size;
} fileSizeSpec_t;

/* 
    Default error code (MacOS extractErr error code from MacErrors.h) See:
    https://opensource.apple.com/source/CarbonHeaders/CarbonHeaders-18.1/MacErrors.h
 */

enum {
    zipQLFailed = -3104,
};

/* 
    Default values for output
 */

enum
{
    gBorder          = 1,
    gFontSize        = 2,
    gIconHeight      = 16,
    gIconWidth       = 16,
    gColPadding      = 8,
    gColFileSize     = 72,
    gColFileCompress = 44,
    gColFileModDate  = 56,
    gColFileModTime  = 56,
    gColFileType     = 24,
    gColFileName     = 292,
};

/*
    Constants for different zip compression methods.  See:
    https://pkware.cachefly.net/webdocs/APPNOTE/APPNOTE-6.3.0.TXT
 */

enum
{
    gZipStored    = 0,
    gZipShrunk    = 1,
    gZipReduced1  = 2,
    gZipReduced2  = 3,
    gZipReduced3  = 4,
    gZipReduced4  = 5,
    gZipImploded  = 6,
    gZipTokenized = 7,
    gZipDeflated  = 8,
    gZipDeflate64 = 9,
    gZipOldTerse  = 10,
    gZipBZip2     = 12,
    gZipLMZA      = 14,
    gZipNewTerse  = 18,
    gZipLZ77      = 19,
    gZipPPMd      = 98,
};

/* constants */

static const NSString *gTableHeaderName   = @"Name";
static const NSString *gTableHeaderSize   = @"Size";
static const NSString *gTableHeaderDate   = @"Modified";
static const NSString *gBackgroundColor   = @"#F6F6F6";
static const NSString *gTableHeaderColor  = @"#F4F4F4";
static const NSString *gTableRowEvenColor = @"#F0F0F0";
static const NSString *gTableRowOddColor  = @"#FFFFFF";
static const NSString *gTableBorderColor  = @"#CCCCCC";
static const NSString *gFolderIcon        = @"&#x1F4C1";
static const NSString *gFileIcon          = @"&#x1F4C4";
static const NSString *gFontFace          = @"sans-serif";
static const char     *gFileSizeBytes     = "B";
static const char     *gFileSizeKiloBytes = "K";
static const char     *gFileSizeMegaBytes = "M";
static const char     *gFileSizeGigaBytes = "G";
static const char     *gFileSizeTeraBytes = "T";
static const NSString *gCompressMethodStored           = @"S";
static const NSString *gCompressMethodShrunk           = @"H";
static const NSString *gCompressMethodImploded         = @"I";
static const NSString *gCompressMethodTokenized        = @"T";
static const NSString *gCompressMethodDeflate64        = @"6";
static const NSString *gCompressMethodDeflateLevel0    = @"";
/*
 static const NSString *gCompressMethodDeflateLevel0    = @"N";
 */
static const NSString *gCompressMethodDeflateLevel1    = @"M";
static const NSString *gCompressMethodDeflateLevel2    = @"F";
static const NSString *gCompressMethodDeflateLevel3    = @"X";
static const NSString *gCompressMethodReducedLevel1    = @"1";
static const NSString *gCompressMethodReducedLevel2    = @"2";
static const NSString *gCompressMethodReducedLevel3    = @"3";
static const NSString *gCompressMethodReducedLevel4    = @"4";
static const NSString *gCompressMethodOldTerse         = @"O";
static const NSString *gCompressMethodNewTerse         = @"N";
static const NSString *gCompressMethodBZ2              = @"B";
static const NSString *gCompressMethodLMZA             = @"L";
static const NSString *gCompressMethodLZ77             = @"7";
static const NSString *gCompressMethodPPMd             = @"P";
static const NSString *gCompressMethodUnknown          = @"U";

/* prototypes */

OSStatus GeneratePreviewForURL(void *thisInterface,
                               QLPreviewRequestRef preview,
                               CFURLRef url,
                               CFStringRef contentTypeUTI,
                               CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);
static int getFileSizeSpec(uLong fileSizeInBytes, fileSizeSpec_t *fileSpec);
static float getCompression(Float64 uncompressedSize, Float64 compressedSize);

/* GeneratePreviewForURL - generate a zip file's preview */

OSStatus GeneratePreviewForURL(void *thisInterface,
                               QLPreviewRequestRef preview,
                               CFURLRef url,
                               CFStringRef contentTypeUTI,
                               CFDictionaryRef options)
{
    NSMutableDictionary *qlHtmlProps = nil;
    NSMutableString *qlHtml = nil;
    NSMutableString *fileDateStringInZip = nil;
    NSDateFormatter *fileDateFormatterInZip = nil;
    NSDateFormatter *fileLocalDateFormatterInZip = nil;
    NSDate *fileDateInZip = nil;
    CFStringRef zipFileName = NULL;
    const char *zipFileNameStr = NULL;
    unzFile zipFile = NULL;
    unz_global_info64 zipFileInfo;
    unz_file_info64 fileInfoInZip;
    char fileNameInZip[PATH_MAX];
    NSString *fileNameInZipEscaped = nil;
    int zipErr = UNZ_OK;
    uLong i = 0;
    uLong totalSize = 0;
    uLong totalCompressedSize = 0;
    bool isFolder = FALSE;
    fileSizeSpec_t fileSizeSpecInZip;
    Float64 compression = 0;
    struct tm tmu_date = { 0 };
    uint16_t compressLevel = 0;
    
    if (url == NULL) {
        return zipQLFailed;
    }
    
    /* get the local file system path for the specified file */
    
    zipFileName = CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
    if (zipFileName == NULL) {
        return zipQLFailed;
    }
    
    /* covert the file system path to a c string */
    
    zipFileNameStr = CFStringGetCStringPtr(zipFileName, kCFStringEncodingUTF8);
    if (zipFileName == NULL) {
        return zipQLFailed;
    }

    /*  exit if the user canceled the preview */
    
    if (QLPreviewRequestIsCancelled(preview)) {
        return noErr;
    }
    
    /* open the zip file */
    
    zipFile = unzOpen64(zipFileNameStr);
    if (zipFile == NULL) {
        return zipQLFailed;
    }

    /* get the zip files global info */

    zipErr = unzGetGlobalInfo64(zipFile, &zipFileInfo);
    if (zipErr != UNZ_OK) {
        unzClose(zipFile);
        return zipQLFailed;
    }

    /*  exit if the user canceled the preview */
    
    if (QLPreviewRequestIsCancelled(preview)) {
        unzClose(zipFile);
        return noErr;
    }
    
    /* initialize the HTML output */

    qlHtmlProps = [[NSMutableDictionary alloc] init];
    [qlHtmlProps setObject: @"UTF-8"
                forKey: (NSString *)kQLPreviewPropertyTextEncodingNameKey];
    [qlHtmlProps setObject: @"text/html"
                forKey: (NSString*)kQLPreviewPropertyMIMETypeKey];
    
    qlHtml = [[NSMutableString alloc] init];
    
    /* start html header */
    
    [qlHtml appendString: @"<!DOCTYPE html>\n"];
    [qlHtml appendString: @"<html xmlns=\"http://www.w3.org/1999/xhtml\">\n"];
    [qlHtml appendString: @"<head>\n"];
    [qlHtml appendString: @"<meta http-equiv=\"Content-Type\" content=\"text/html; "];
    [qlHtml appendString: @"charset=utf-8\" />\n"];
    
    /* start the style sheet */
    
    [qlHtml appendString: @"<style>\n"];
    
    /*
        put a border around the table only
        based on: https://stackoverflow.com/questions/10131729/removing-border-from-table-cell
     */
    
    [qlHtml appendFormat: @"table { width: %dpx; border: %dpx solid %@; ",
                          ((gColFileSize + gColPadding) +
                          (gColFileCompress + gColPadding) +
                          (gColFileModDate + gColPadding) +
                          (gColFileModTime + gColPadding) +
                          (gColFileName + gColPadding)),
                          gBorder,
                          gTableBorderColor];
    [qlHtml appendString: @"table-layout: fixed; border-collapse: collapse; }\n"];
    [qlHtml appendString: @"td { border: none; }\n"];
    [qlHtml appendFormat: @"th { background: %@}\n", gTableHeaderColor];
    
    /* 
        borders for table row top, bottom, and sides
        based on: http://webdesign.about.com/od/tables/ht/how-to-add-internal-lines-in-a-table-with-CSS.htm
     */
    
    [qlHtml appendFormat: @".border-top { border-top: solid %dpx %@; }\n",
                          gBorder, gTableBorderColor];
    [qlHtml appendFormat: @".border-bottom { border-bottom: solid %dpx %@; }\n",
                          gBorder, gTableBorderColor];
    [qlHtml appendFormat: @".border-side { border-right: solid %dpx %@;\n",
                          gBorder, gTableBorderColor];
    
    /* close the style sheet */
    
    [qlHtml appendString: @"</style>\n"];
    
    /* close the html header */
    
    [qlHtml appendString: @"</head>\n"];

    /* start the html body */

    [qlHtml appendFormat: @"<body bgcolor=\"%@\">\n", gBackgroundColor];
    [qlHtml appendFormat: @"<font size=\"%d\" face=\"%@\">\n",
                          gFontSize, gFontFace];
    
    /* 
       start the table
       based on: http://www.w3.org/TR/html4/struct/tables.html
     */

    [qlHtml appendFormat: @"<table align=\"center\" cellpadding=\"%d\">\n",
                           (gColPadding/2)];
    [qlHtml appendFormat: @"<colgroup width=\"%d\" />\n",
                          (gColFileType + gColPadding)];
    [qlHtml appendFormat: @"<colgroup width=\"%d\" />\n",
                          (gColFileName + gColPadding)];
    [qlHtml appendFormat: @"<colgroup width=\"%d\" />\n",
                          (gColFileSize + gColPadding)];
    [qlHtml appendFormat: @"<colgroup width=\"%d\" />\n",
                          (gColFileCompress + gColPadding)];
    [qlHtml appendFormat: @"<colgroup width=\"%d\" />\n",
                          (gColFileModDate + gColPadding)];
    [qlHtml appendFormat: @"<colgroup width=\"%d\" />\n",
                          (gColFileModTime + gColPadding)];
    
    /* add the table header */
    
    [qlHtml appendString: @"<thead><tr class=\"border-bottom\">"];
    [qlHtml appendFormat: @"<th class=\"border-side\" colspan=\"2\">%@</th>",
                          gTableHeaderName];
    [qlHtml appendFormat: @"<th class=\"border-side\" colspan=\"2\">%@</th>",
                          gTableHeaderSize];
    [qlHtml appendFormat: @"<th colspan=\"2\">%@</th>",
                          gTableHeaderDate];
    [qlHtml appendString: @"</tr></thead>\n"];
    
    /* start the table body */
    
    [qlHtml appendString: @"<tbody>\n"];
    
    /* list the files in the zip file */
    
    for (i=0; i <= zipFileInfo.number_entry; i++) {

        /* look up the next file in the zip file */

        if (i > 0) {
            zipErr = unzGoToNextFile(zipFile);
            if (zipErr != UNZ_OK) {
                break;
            }
        }
        
        /*  stop listing files if the user canceled the preview */
        
        if (QLPreviewRequestIsCancelled(preview)) {
            break;
        }

        /* clear the file name */
        
        memset(fileNameInZip, 0, sizeof(fileNameInZip));

        /* get info for the current file in the zip file */
        
        zipErr = unzGetCurrentFileInfo64(zipFile,
                                         &fileInfoInZip,
                                         fileNameInZip,
                                         sizeof(fileNameInZip),
                                         NULL,
                                         0,
                                         NULL,
                                         0);
        if (zipErr != UNZ_OK) {
            break;
        }
        
        /* check if this entry is a file or a folder */
        
        isFolder = (fileNameInZip[strlen(fileNameInZip) - 1] == '/') ? TRUE : FALSE;
        
        /* start the table row for this file (with alternating colors) */
        
        [qlHtml appendFormat: @"<tr bgcolor=\"%@\">",
                              i % 2 == 0 ? gTableRowEvenColor : gTableRowOddColor];
   
        /*
            add an icon depending on whether the entry is a file or a
            directory.
            based on: http://apps.timwhitlock.info/emoji/tables/unicode
                      http://www.unicode.org/emoji/charts/full-emoji-list.html
                      https://stackoverflow.com/questions/10580186/how-to-display-emoji-char-in-html
         */
        
        [qlHtml appendFormat: @"<td align=\"center\">%@</td>",
         isFolder == TRUE ? gFolderIcon : gFileIcon];
        
        /*
            HTML escape the file name, print it out, and force it to wrap
            based on: https://stackoverflow.com/questions/1258416/word-wrap-in-an-html-table
                      https://stackoverflow.com/questions/659602/objective-c-html-escape-unescape
         
            For encyrpted files, print a '*' after the file name.  See:
            https://github.com/nmoinvaz/minizip/blob/1.2/miniunz.c
         */
        
        fileNameInZipEscaped = [[NSString stringWithUTF8String: fileNameInZip]
                                          gtm_stringByEscapingForHTML];
        
        [qlHtml appendString: @"<td><div style=\"display:block; "];
        [qlHtml appendFormat: @"word-wrap: break-word; width: %dpx;\">%@%@</div></td>",
                              (gColFileName - (gColPadding*2)),
                              fileNameInZipEscaped,
                              ((fileInfoInZip.flag & 1) != 0) ? @"*" : @""];

        /* if the entry is a folder, don't print out its size, which is always 0 */
        
        if (isFolder == TRUE) {
            [qlHtml appendString:
                    @"<td align=\"center\" colspan=\"2\"><pre>--</pre></td>"];
        } else {

            /* clear the file size spec */
            
            memset(&fileSizeSpecInZip, 0, sizeof(fileSizeSpec_t));

            /* get the file's size spec */
            
            getFileSizeSpec(fileInfoInZip.uncompressed_size,
                            &fileSizeSpecInZip);
            
            /* print out the file's size in B, K, M, G, or T */
            
            [qlHtml appendFormat:
                    @"<td align=\"right\"><pre>%-.1f %-1s</pre></td>",
                    fileSizeSpecInZip.size,
                    fileSizeSpecInZip.spec];
            
            /* print out the % compression for this file */
            
            if (fileInfoInZip.uncompressed_size > 0) {
                compression = getCompression((Float64)fileInfoInZip.uncompressed_size,
                                             (Float64)fileInfoInZip.compressed_size);
                [qlHtml appendFormat:
                        @"<td align=\"right\"><pre>(%3.0f%%) ",
                        compression];
            } else {
                [qlHtml appendString:
                        @"<td align=\"right\"><pre>&nbsp;"];
            }
            
            /*
                print out the compression method for this file. See:
                https://pkware.cachefly.net/webdocs/APPNOTE/APPNOTE-6.3.0.TXT
                https://github.com/nmoinvaz/minizip/blob/1.2/miniunz.c
             */
            
            if (fileInfoInZip.compression_method == gZipStored)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodStored];
            }
            else if (fileInfoInZip.compression_method == gZipShrunk)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodShrunk];
            }
            else if (fileInfoInZip.compression_method == gZipImploded)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodImploded];
            }
            else if (fileInfoInZip.compression_method == gZipTokenized)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodTokenized];
            }
            else if (fileInfoInZip.compression_method == gZipDeflate64)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodDeflate64];
            }
            else if (fileInfoInZip.compression_method == gZipOldTerse)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodOldTerse];
            }
            else if (fileInfoInZip.compression_method == Z_BZIP2ED)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodBZ2];
            }
            else if (fileInfoInZip.compression_method == gZipLMZA)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodLMZA];
            }
            else if (fileInfoInZip.compression_method == gZipNewTerse)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodNewTerse];
            }
            else if (fileInfoInZip.compression_method == gZipLZ77)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodLZ77];
            }
            else if (fileInfoInZip.compression_method == gZipPPMd)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodPPMd];
            }
            else if (fileInfoInZip.compression_method == gZipReduced1)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodReducedLevel1];
            }
            else if (fileInfoInZip.compression_method == gZipReduced2)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodReducedLevel2];
            }
            else if (fileInfoInZip.compression_method == gZipReduced3)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodReducedLevel3];
            }
            else if (fileInfoInZip.compression_method == gZipReduced4)
            {
                [qlHtml appendFormat: @"%@", gCompressMethodReducedLevel4];
            }
            else if (fileInfoInZip.compression_method == Z_DEFLATED)
            {
                /*
                    Determine the delfate level:
                    https://pkware.cachefly.net/webdocs/APPNOTE/APPNOTE-6.3.0.TXT
                    https://tools.ietf.org/html/rfc1950
                    https://github.com/nmoinvaz/minizip/blob/1.2/miniunz.c
                 */
                
                compressLevel = (uint16_t)((fileInfoInZip.flag & 0x6) / 2);
                switch (compressLevel)
                {
                    case 0:
                        [qlHtml appendFormat: @"%@", gCompressMethodDeflateLevel0];
                        break;
                    case 1:
                        [qlHtml appendFormat: @"%@", gCompressMethodDeflateLevel1];
                        break;
                    case 2:
                        [qlHtml appendFormat: @"%@", gCompressMethodDeflateLevel2];
                        break;
                    case 3:
                        [qlHtml appendFormat: @"%@", gCompressMethodDeflateLevel3];
                        break;
                    default:
                        [qlHtml appendFormat: @"%@", gCompressMethodUnknown];
                        break;
                }
            }
            else
            {
                [qlHtml appendFormat: @"%@", gCompressMethodUnknown];
            }
            
            [qlHtml appendString: @"</pre></td>"];

        }
    
        /* 
            print out the modified date and time for the file in the local format
            based on: https://stackoverflow.com/questions/9676435/how-do-i-format-the-current-date-for-the-users-locale
                      https://stackoverflow.com/questions/4895697/nsdateformatter-datefromstring
                      http://unicode.org/reports/tr35/tr35-4.html#Date_Format_Patterns
         */
        
        /* init the date string (if needed) and clear it */
         
        if (fileDateStringInZip == nil) {
            fileDateStringInZip = [[NSMutableString alloc] initWithString: @""];
        } else {
            [fileDateStringInZip setString: @""];
        }

        /* initialize the date formatter corresponding to this file's date, as 
           stored in the zip file */
        
        if (fileDateFormatterInZip == nil) {
            fileDateFormatterInZip = [[NSDateFormatter alloc] init];
            [fileDateFormatterInZip setDateFormat:@"MM-dd-yy HH:mm"];
        }
        
        /* initialize the date formatter for the local date format */
        
        if (fileLocalDateFormatterInZip == nil) {
            fileLocalDateFormatterInZip = [[NSDateFormatter alloc] init];
        }
        
        /* create a string that holds the date for this file */
        
        dosdate_to_tm(fileInfoInZip.dos_date, &tmu_date);
        
        [fileDateStringInZip appendFormat: @"%2.2lu-%2.2lu-%2.2lu %2.2lu:%2.2lu",
                                           (uLong)tmu_date.tm_mon + 1,
                                           (uLong)tmu_date.tm_mday,
                                           (uLong)tmu_date.tm_year % 100,
                                           (uLong)tmu_date.tm_hour,
                                           (uLong)tmu_date.tm_min];

        /* get a date object for the file's date */
        
        fileDateInZip = [fileDateFormatterInZip dateFromString: fileDateStringInZip];
        
        /* if the date object is not nil, print out one table cell corresponding
           to the date and another table cell corresponding to the time, both in
           the local format; but if the date is nil, use a default format */
         
        if (fileDateInZip != nil) {
            
            [fileLocalDateFormatterInZip setDateStyle: NSDateFormatterShortStyle];
            [fileLocalDateFormatterInZip setTimeStyle: NSDateFormatterNoStyle];
            [qlHtml appendFormat: @"<td align=\"right\">%@</td>",
                                  [fileLocalDateFormatterInZip stringFromDate:
                                                               fileDateInZip]];

            [fileLocalDateFormatterInZip setDateStyle: NSDateFormatterNoStyle];
            [fileLocalDateFormatterInZip setTimeStyle: NSDateFormatterShortStyle];
            [qlHtml appendFormat: @"<td align=\"right\">%@</td>",
                                  [fileLocalDateFormatterInZip stringFromDate:
                                                               fileDateInZip]];
        } else {
            [qlHtml appendFormat: @"<td align=\"center\">%2.2lu-%2.2lu-%2.2lu</td>",
                                  (uLong)tmu_date.tm_mon + 1,
                                  (uLong)tmu_date.tm_mday,
                                  (uLong)tmu_date.tm_year % 100];
            
            [qlHtml appendFormat: @"<td align=\"center\">%2.2lu:%2.2lu</td>",
                                  (uLong)tmu_date.tm_hour,
                                  (uLong)tmu_date.tm_min];
        }
        
        /* close the row */
        
        [qlHtml appendString:@"</tr>\n"];

        /* update the total compressed and uncompressed sizes */
        
        totalSize += fileInfoInZip.uncompressed_size;
        totalCompressedSize += fileInfoInZip.compressed_size;
    }

    /* close the zip file */
    
    unzClose(zipFile);

    /* close the table body */
    
    [qlHtml appendString: @"</tbody>\n"];
    
    /* start the summary row for the zip file - [total size] [blank] [ no. of files] */

    [qlHtml appendString: @"<tbody>\n"];
    [qlHtml appendFormat: @"<tr class=\"border-top\" style=\"background: %@;\">",
                          gTableHeaderColor];
    
    /* print out the total number of files in the zip file */
    
    [qlHtml appendFormat: @"<td align=\"center\" colspan=\"2\">%lu file%s</td>\n",
                          (unsigned long)zipFileInfo.number_entry,
                          (zipFileInfo.number_entry > 1 ? "s" : "")];

    /* clear the file size spec */
    
    memset(&fileSizeSpecInZip, 0, sizeof(fileSizeSpec_t));
    
    /* get the file's total size spec */
    
    getFileSizeSpec(totalSize,
                    &fileSizeSpecInZip);
    
    /* print out the zip file's total size in B, K, M, G, or T */
    
    [qlHtml appendFormat:
            @"<td align=\"right\"><pre>%-.1f %-1s</pre></td>",
            fileSizeSpecInZip.size,
            fileSizeSpecInZip.spec];

    /* print out the % compression for the whole zip file */

    if (totalSize > 0) {
        compression = getCompression((Float64)totalSize,
                                     (Float64)totalCompressedSize);
        [qlHtml appendFormat:
                @"<td align=\"right\"><pre>(%3.0f%%)</pre></td>",
                compression];
    } else {
        [qlHtml appendString:
                @"<td align=\"right\"><pre>&nbsp;</pre></td>"];
    }
    
    [qlHtml appendString:
            @"<td align=\"right\" colspan=\"2\"><pre>&nbsp;</pre></td>"];
    
    /* close the summary row */
    
    [qlHtml appendString:@"</tr>\n"];
    
    /* close the table body */
    
    [qlHtml appendString: @"</tbody>\n"];
    
    /* close the table */
    
    [qlHtml appendString: @"</table>\n"];

    /* close the html */
    
    [qlHtml appendString: @"</font>\n</body>\n</html>\n"];
    
    QLPreviewRequestSetDataRepresentation(preview,
                                          (__bridge CFDataRef)[qlHtml dataUsingEncoding:
                                                                NSUTF8StringEncoding],
                                          kUTTypeHTML,
                                          (__bridge CFDictionaryRef)qlHtmlProps);
    
    return (zipErr == UNZ_OK ? noErr : zipQLFailed);
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
}

/* getFileSizeSpec - return a string corresponding to the size of the file */

static int getFileSizeSpec(uLong fileSizeInBytes, fileSizeSpec_t *fileSpec)
{
    Float64 fileSize = 0.0;
    int err = -1;
    
    if (fileSpec == NULL) {
        return err;
    }

    err = 0;
    
    memset(fileSpec->spec, 0, 3);
    
    /* print the file size in B, KB, MB, GB, or TB */
    
    if (fileSizeInBytes < 100) {
        snprintf(fileSpec->spec, 3, "%s", gFileSizeBytes);
        fileSpec->size = (Float64)fileSizeInBytes;
        return err;
    }
    
    fileSize = (Float64)fileSizeInBytes / 1000.0;
    
    if (fileSize < 1000.0) {
        snprintf(fileSpec->spec, 3, "%s", gFileSizeKiloBytes);
        fileSpec->size = fileSize;
        return err;
    }

    fileSize /= 1000.0;

    if (fileSize < 1000.0) {
        snprintf(fileSpec->spec, 3, "%s", gFileSizeMegaBytes);
        fileSpec->size = fileSize;
        return err;
    }

    fileSize /= 1000.0;
    
    if (fileSize < 1000.0) {
        snprintf(fileSpec->spec, 3, "%s", gFileSizeGigaBytes);
        fileSpec->size = fileSize;
        return err;
    }

    snprintf(fileSpec->spec, 3, "%s", gFileSizeTeraBytes);
    fileSpec->size = fileSize;
    return err;
}

/* getCompression - calculate the % a particular file has been compressed */

static float getCompression(Float64 uncompressedSize, Float64 compressedSize)
{
    Float64 compression = 0.0;

    if (uncompressedSize > 0) {
        compression = 100 *  (compressedSize / uncompressedSize);
    }
    
    if (compression <= 0) {
        compression = 0.0;
    }
    
    return compression;
}

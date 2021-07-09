/*
    GeneratePreviewForURL - generate a preview of a zip file
 
    History:
 
    v. 0.1.0 (08/19/2015) - Initial Release
    v. 0.1.1 (08/27/2015) - Add icon support, file sizes in B, KB,
                            MB, GB, and TB, and compression ratio
    v. 0.1.2 (09/16/2015) - Localize the date output, fix compression
                            reporting, and escape any HTML characters
                            in filenames
    v. 0.1.3 (07/16/2019) - Update to use minizip 1.2, show compression
                            method
    v. 0.1.4 (05/03/2021) - Add darkmode support
    v. 0.1.5 (06/02/2021) - Add support for zipfiles with non-UTF8
                            characters in their filenames; increase size
                            for displaying the compressed size
    v. 0.1.6 (06/03/2021) - make sure days and months are zero prefixed
    v. 0.1.7 (06/04/2021) - separate constants for dark and light mode
                            styles
    v. 0.1.8 (06/15/2021) - add icon for encrypted files
    v. 0.2.0 (06/18/2021) - switch to using libarchive
    v. 0.2.1 (06/18/2021) - add support for xar / pkg files, and isos,
                            make the header row fixed
    v. 0.2.2 (06/20/2021) - add support for rar, rar4, lha, 7z, xz, and
                            debian (.deb) archives
 
    Copyright (c) 2015-2021 Sriranga R. Veeraraghavan <ranga@calalum.org>
 
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

@import Foundation;
@import AppKit;

#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <QuickLook/QuickLook.h>
#import <CommonCrypto/CommonDigest.h>

#include <sys/syslimits.h>
#include <sys/stat.h>
#include <iconv.h>

#include "config.h"
#include "archive.h"
#include "archive_entry.h"
#import "GTMNSString+HTML.h"

/* structs */

typedef struct fileSizeSpec
{
    char spec[3];
    Float64 size;
} fileSizeSpec_t;

/* 
    Default error code (MacOS extractErr error code from MacErrors.h) See:
    https://opensource.apple.com/source/CarbonHeaders/CarbonHeaders-18.1/MacErrors.h
 */

enum
{
    zipQLFailed = -3104,
};

/* 
    Default values for spacing of the output
 */

enum
{
    gBorder          = 1,
    gFontSize        = 2,
    gIconHeight      = 16,
    gIconWidth       = 16,
    gColPadding      = 8,
    gColFileSize     = 72,
    gColFileCompress = 46,
    gColFileModDate  = 58,
    gColFileModTime  = 56,
    gColFileType     = 24,
    gColFileName     = 288,
};

/* constants */

/* table headings */

static const NSString *gTableHeaderName   = @"Name";
static const NSString *gTableHeaderSize   = @"Size";
static const NSString *gTableHeaderDate   = @"Modified";

/* darkmode styles */

static const NSString *gDarkModeBackground = @"#232323";
static const NSString *gDarkModeForeground = @"lightgrey";
static const NSString *gDarkModeTableRowEvenBackgroundColor
                                           = @"#313131";
static const NSString *gDarkModeTableRowEvenForegroundColor
                                           = @"white";
static const NSString *gDarkModeTableBorderColor
                                            = @"#232323";
static const NSString *gDarkModeTableHeaderBorderColor
                                            = @"#555555";
/* light mode styles */

static const NSString *gLightModeBackground = @"white";
static const NSString *gLightModeForeground = @"black";
static const NSString *gLightModeTableRowEvenBackgroundColor
                                            = @"#F5F5F5";
static const NSString *gLightModeTableRowEvenForegroundColor
                                            = @"black";
static const NSString *gLightModeTableBorderColor
                                            = @"white";
static const NSString *gLightModeTableHeaderBorderColor
                                            = @"#E7E7E7";

/* icons */

static const NSString *gFolderIcon        = @"&#x1F4C1";
static const NSString *gFileIcon          = @"&#x1F4C4";
static const NSString *gFileEncyrptedIcon = @"&#x1F512";
static const NSString *gFileLinkIcon      = @"&#x1F4D1";
static const NSString *gFileSpecialIcon   = @"&#x2699";
static const NSString *gFileUnknownIcon   = @"&#x2753";

/* unknown file name */

static const char *gFileNameUnavilable = "[Unavailable]";

/* default font style - sans serif */

static const NSString *gFontFace = @"sans-serif";

/* filesize abbreviations */

static const char     *gFileSizeBytes     = "B";
static const char     *gFileSizeKiloBytes = "K";
static const char     *gFileSizeMegaBytes = "M";
static const char     *gFileSizeGigaBytes = "G";
static const char     *gFileSizeTeraBytes = "T";

/* prototypes */

OSStatus GeneratePreviewForURL(void *thisInterface,
                               QLPreviewRequestRef preview,
                               CFURLRef url,
                               CFStringRef contentTypeUTI,
                               CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface,
                             QLPreviewRequestRef preview);
static int getFileSizeSpec(off_t fileSizeInBytes,
                           fileSizeSpec_t *fileSpec);
static float getCompression(off_t uncompressedSize,
                            off_t compressedSize);

/* GeneratePreviewForURL - generate a zip file's preview */

OSStatus GeneratePreviewForURL(void *thisInterface,
                               QLPreviewRequestRef preview,
                               CFURLRef url,
                               CFStringRef contentTypeUTI,
                               CFDictionaryRef options)
{
    NSMutableDictionary *qlHtmlProps = nil;
    NSString *qlEntryIcon = nil;
    NSMutableString *qlHtml = nil;
    NSMutableString *fileDateStringInZip = nil;
    NSMutableString *localeString = nil;
    NSDateFormatter *fileDateFormatterInZip = nil;
    NSDateFormatter *fileLocalDateFormatterInZip = nil;
    NSDate *fileDateInZip = nil;
    CFMutableStringRef zipFileName = NULL;
    const char *zipFileNameStr = NULL;
    char zipFileNameCStr[PATH_MAX];
    NSString *fileNameInZipEscaped = nil;
    const char *fileNameInZip;
    struct archive *a;
    struct archive_entry *entry;
    int r = 0;
    int zipErr = 0;
    struct stat fileStats;
    unsigned long i = 0, fileCount = 0;
    off_t totalSize = 0;
    off_t totalCompressedSize = 0;
    Float64 compression = 0;
    bool isFolder = FALSE;
    fileSizeSpec_t fileSizeSpecInZip;
    
    if (url == NULL) {
        fprintf(stderr, "qlZipInfo: ERROR: url is null\n");
        return zipQLFailed;
    }
    
    /* get the local file system path for the specified file */
    
    zipFileName =
        (CFMutableStringRef)CFURLCopyFileSystemPath(url,
                                                    kCFURLPOSIXPathStyle);
    if (zipFileName == NULL) {
        fprintf(stderr, "qlZipInfo: ERROR: file name is null\n");
        return zipQLFailed;
    }
    
    /* normalize the file name */
    
    CFStringNormalize(zipFileName, kCFStringNormalizationFormC);
    
    /* covert the file system path to a c string */
    
    zipFileNameStr = CFStringGetCStringPtr(zipFileName,
                                           kCFStringEncodingUTF8);
    if (zipFileNameStr == NULL) {
        
        /*
            if CFStringGetCStringPtr returns NULL, try to get the
            file path using CFStringGetCString() b/c the file path
            might have non-UTF8 characters, see:
            https://developer.apple.com/documentation/corefoundation/1542133-cfstringgetcstringptr
         */
        
        if (CFStringGetCString(zipFileName,
                               zipFileNameCStr,
                               PATH_MAX - 1,
                               kCFStringEncodingUTF8) != true)
        {
            fprintf(stderr,
                    "qlZipInfo: ERROR: can't get filename\n");
            return zipQLFailed;
        }
        
        zipFileNameStr = zipFileNameCStr;
    }
    
    /*  exit if the user canceled the preview */
    
    if (QLPreviewRequestIsCancelled(preview)) {
        return noErr;
    }

    /*
        set the locale to UTF-8 to decode non-ASCII filenames:
        
        https://github.com/libarchive/libarchive/issues/587
        https://github.com/libarchive/libarchive/issues/1535
        https://stackoverflow.com/questions/1085506/how-to-get-language-locale-of-the-user-in-objective-c
        https://developer.apple.com/documentation/foundation/nslocale/1416263-localeidentifier?language=objc
        
     */
    
    localeString = [[NSMutableString alloc] init];
    [localeString appendString:
        [[NSLocale currentLocale] localeIdentifier]];
    [localeString appendString: @".UTF-8"];
    
    setlocale (LC_ALL, [localeString UTF8String]);

    a = archive_read_new();

    archive_read_support_filter_compress(a);
    archive_read_support_filter_gzip(a);
    archive_read_support_filter_bzip2(a);
    archive_read_support_filter_xz(a);
    archive_read_support_format_tar(a);
    archive_read_support_format_zip(a);
    archive_read_support_format_xar(a);
    archive_read_support_format_iso9660(a);
    archive_read_support_format_rar(a);
    archive_read_support_format_rar5(a);
    archive_read_support_format_lha(a);
    archive_read_support_format_ar(a);
    archive_read_support_format_7zip(a);
    archive_read_support_format_cab(a);
    
    if ((r = archive_read_open_filename(a, zipFileNameStr, 10240)))
    {
        fprintf(stderr,
                "qlZipInfo: ERROR: %s\n",
                archive_error_string(a));
        archive_read_close(a);
        archive_read_free(a);
        return zipQLFailed;
    }
    
    /*  exit if the user canceled the preview */
    
    if (QLPreviewRequestIsCancelled(preview)) {
        archive_read_close(a);
        archive_read_free(a);
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
    [qlHtml appendString: @"<html>\n"];
    [qlHtml appendString: @"<head>\n"];
    [qlHtml appendString:
        @"<meta http-equiv=\"Content-Type\" content=\"text/html; "];
    [qlHtml appendString: @"charset=utf-8\" />\n"];
    
    /* start the style sheet */
    
    [qlHtml appendString: @"<style>\n"];

    /* darkmode styles */
    
    [qlHtml appendString:
        @"@media (prefers-color-scheme: dark) { "];

    /* set darkmode background and foreground colors */
    
    [qlHtml appendFormat:
        @"body { background-color: %@; color: %@; }\n",
        gDarkModeBackground,
        gDarkModeForeground];
    
    /*
        put a border around the table only, but make it the same color
        as the background to better match the BigSur finder
        based on: https://stackoverflow.com/questions/10131729/removing-border-from-table-cell
     
        set y-direction overflow to auto to support a fixed header
        based on:
            https://www.w3docs.com/snippets/html/how-to-create-a-table-with-a-fixed-header-and-scrollable-body.html
            https://stackoverflow.com/questions/50361698/border-style-do-not-work-with-sticky-position-element
     */

    [qlHtml appendFormat: @"table { width: 100%%; border: %dpx solid %@; ",
                          gBorder,
                          gDarkModeTableBorderColor];
    [qlHtml appendString: @"table-layout: fixed; overflow-y: auto;"];
    [qlHtml appendString:
        @"border-collapse: separate; border-spacing: 0; }\n"];
    
    /* set the darkmode colors for the even rows of the table */
    
    [qlHtml appendFormat:
        @"tr:nth-child(even) { background-color: %@ ; color: %@; }\n",
        gDarkModeTableRowEvenBackgroundColor,
        gDarkModeTableRowEvenForegroundColor];

    /* disable internal borders for table cells */
    
    [qlHtml appendString: @"td { border: none; z-index: 1; }\n"];

    /*
        add a bottom border for the header row items only, to better
        match the BigSur finder, and make the header fixed.
        based on:
            https://www.w3docs.com/snippets/html/how-to-create-a-table-with-a-fixed-header-and-scrollable-body.html
     */
    
    [qlHtml appendFormat: @"th { border-bottom: %dpx solid %@; ",
                          gBorder,
                          gDarkModeTableHeaderBorderColor];
    [qlHtml appendString: @" position: sticky; position: -webkit-sticky; "];
    [qlHtml appendFormat: @"top: 0; z-index: 3; background-color: %@ ;}\n",
                          gDarkModeBackground];
    
    /* close darkmode styles */
    
    [qlHtml appendString: @"}\n"];

    /* light mode styles */
    
    [qlHtml appendString:
        @"@media (prefers-color-scheme: light) { "];
    
    /* light mode background and foreground colors */
    
    [qlHtml appendFormat:
        @"body { background-color: %@; color: %@; }\n",
        gLightModeBackground,
        gLightModeForeground];

    /*
        put a border around the table only
        based on: https://stackoverflow.com/questions/10131729/removing-border-from-table-cell
     */

    [qlHtml appendFormat: @"table { width: 100%%; border: %dpx solid %@; ",
                          gBorder,
                          gLightModeTableBorderColor];
    [qlHtml appendString: @"table-layout: fixed; overflow-y: auto;"];
    [qlHtml appendString:
        @"border-collapse: separate; border-spacing: 0; }\n"];

    /* no internal borders */
    
    [qlHtml appendString: @"td { border: none; }\n"];

    /* make the header sticky */

    [qlHtml appendFormat: @"th { border-bottom: %dpx solid %@; ",
                          gBorder,
                          gLightModeTableHeaderBorderColor];
    [qlHtml appendString: @" position: sticky; position: -webkit-sticky; "];
    [qlHtml appendFormat: @"top: 0; z-index: 3; background-color: %@ ;}\n",
                          gLightModeBackground];

    /* colors for the even rows */
    
    [qlHtml appendFormat:
        @"tr:nth-child(even) { background-color: %@ ; color: %@; }\n",
        gLightModeTableRowEvenBackgroundColor,
        gLightModeTableRowEvenForegroundColor];
    
    /* close light mode styles */
    
    [qlHtml appendString: @"}\n"];

    /*
        style for preventing wrapping in table cells, based on:
        https://stackoverflow.com/questions/300220/how-to-prevent-text-in-a-table-cell-from-wrapping
     */

    [qlHtml appendString: @".nowrap { white-space: nowrap; }\n"];
    
    /* close the style sheet */
    
    [qlHtml appendString: @"</style>\n"];
    
    /* close the html header */
    
    [qlHtml appendString: @"</head>\n"];

    /* start the html body */

    [qlHtml appendFormat: @"<body>\n"];

    [qlHtml appendFormat: @"<font face=\"%@\">\n", gFontFace];

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
    for (i = 0; i >= 0; i++)
    {
        /* look up the next file in the zip file */

        r = archive_read_next_header(a, &entry);
        if (r == ARCHIVE_EOF)
        {
            break;
        }

        if (r == ARCHIVE_WARN)
        {
            fprintf(stderr,
                    "qlZipInfo: WARN: %s\n",
                    archive_error_string(a));
        }
        else if (r != ARCHIVE_OK)
        {
            zipErr = zipQLFailed;
            fprintf(stderr,
                    "qlZipInfo: ERROR: %s\n",
                    archive_error_string(a));
            break;
        }
        
        /*  stop listing files if the user canceled the preview */
        
        if (QLPreviewRequestIsCancelled(preview)) {
            break;
        }

        fileNameInZip = archive_entry_pathname(entry);
        if (fileNameInZip == NULL)
        {
            fileNameInZip = archive_entry_pathname_utf8(entry);
        }

        if (fileNameInZip == NULL)
        {
            fileNameInZip = gFileNameUnavilable;
        }
        
        isFolder =
            archive_entry_filetype(entry) == AE_IFDIR ? TRUE : FALSE;

        /* start the table row for this file */

        [qlHtml appendFormat: @"<tr>"];

        /*
            add an icon depending on whether the entry is a file,
            folder/directory, or encrypted.
         
            based on: http://apps.timwhitlock.info/emoji/tables/unicode
                      http://www.unicode.org/emoji/charts/full-emoji-list.html
                      https://stackoverflow.com/questions/10580186/how-to-display-emoji-char-in-html
                      https://github.com/nmoinvaz/minizip/blob/1.2/miniunz.c
         */
        
        qlEntryIcon = (NSString *)gFileIcon;
        
        if (isFolder == TRUE)
        {
            qlEntryIcon = (NSString *)gFolderIcon;
        }
        else if (archive_entry_is_encrypted(entry))
        {
            qlEntryIcon = (NSString *)gFileEncyrptedIcon;
        }
        else if (archive_entry_filetype(entry) == AE_IFLNK)
        {
            qlEntryIcon = (NSString *)gFileLinkIcon;
        }
        else if (archive_entry_filetype(entry) != AE_IFREG)
        {
            qlEntryIcon = (NSString *)gFileSpecialIcon;
        }
        
        [qlHtml appendFormat: @"<td align=\"center\">%@</td>",
                              qlEntryIcon];
        
        /* output the filename with HTML escaping */
        
        fileNameInZipEscaped =
            [[NSString stringWithUTF8String: fileNameInZip]
                                             gtm_stringByEscapingForHTML];
        
        [qlHtml appendString: @"<td><div style=\"display:block; "];

        [qlHtml appendFormat: @"word-wrap: break-word;\">%@</div></td>",
                              fileNameInZipEscaped];
        
        /*
            if the entry is a folder, don't print out its size,
            which is always 0
         */
        
        if (isFolder == TRUE) {
            [qlHtml appendString:
                    @"<td align=\"center\" colspan=\"2\"><pre>--</pre></td>"];
        } else {

            /* clear the file size spec */
            
            memset(&fileSizeSpecInZip, 0, sizeof(fileSizeSpec_t));

            /* get the file's size spec */

            getFileSizeSpec(archive_entry_size(entry),
                            &fileSizeSpecInZip);
            
            /* print out the file's size in B, K, M, G, or T */
            
            [qlHtml appendFormat:
                    @"<td align=\"right\">%-.1f %-1s</td>",
                    fileSizeSpecInZip.size,
                    fileSizeSpecInZip.spec];

            [qlHtml appendString:
                    @"<td align=\"right\">&nbsp;"];
           
            [qlHtml appendString: @"</td>"];
        }
    
        /* 
            print out the modified date and time for the file in the local
            format. based on: https://stackoverflow.com/questions/9676435/how-do-i-format-the-current-date-for-the-users-locale
                      https://stackoverflow.com/questions/4895697/nsdateformatter-datefromstring
                      http://unicode.org/reports/tr35/tr35-4.html#Date_Format_Patterns
         */
        
        /* init the date string (if needed) and clear it */
         
        if (fileDateStringInZip == nil) {
            fileDateStringInZip =
                [[NSMutableString alloc] initWithString: @""];
        } else {
            [fileDateStringInZip setString: @""];
        }

        /*
            initialize the date formatter corresponding to this file's
            date, as stored in the zip file
         */
        
        if (fileDateFormatterInZip == nil) {
            fileDateFormatterInZip = [[NSDateFormatter alloc] init];
            [fileDateFormatterInZip setDateFormat: @"MM-dd-yy HH:mm"];
        }
        
        /* initialize the date formatter for the local date format */
        
        if (fileLocalDateFormatterInZip == nil) {
            fileLocalDateFormatterInZip = [[NSDateFormatter alloc] init];
        }
        
        /* create a string that holds the date for this file */

        fileDateInZip =
            [NSDate dateWithTimeIntervalSince1970:
             archive_entry_mtime(entry)];
        
        /*
            if the date object is not nil, print out one table cell
            corresponding to the date and another table cell corresponding
            to the time, both in the local format; but if the date is nil,
            use a default format
         */
         
        if (fileDateInZip != nil) {

            /*
                Make sure the days and months are zero prefixed.
                Based on:

                https://nsdateformatter.com/
                https://developer.apple.com/documentation/foundation/nsdateformatter/1417087-setlocalizeddateformatfromtempla?language=objc
             */
            
            [fileLocalDateFormatterInZip setLocale:
                [NSLocale currentLocale]];

            [fileLocalDateFormatterInZip
                setLocalizedDateFormatFromTemplate: @"MM-dd-yyyy"];
                        
            [qlHtml appendFormat:
                @"<td align=\"right\">%@</td>",
                [fileLocalDateFormatterInZip stringFromDate: fileDateInZip]];
            
            [fileLocalDateFormatterInZip
                setLocalizedDateFormatFromTemplate: @"HH:mm"];

            [qlHtml appendFormat:
                @"<td align=\"right\">%@</td>",
                [fileLocalDateFormatterInZip stringFromDate: fileDateInZip]];
        } else {
            [qlHtml appendFormat:
                @"<td align=\"center\">&nbsp;</td>"];
        }
        
        /* close the row */
        
        [qlHtml appendString:@"</tr>\n"];

        /* update the total compressed and uncompressed sizes */

        totalSize += archive_entry_size(entry);
    }

    /* close the zip file */

    archive_read_close(a);
    archive_read_free(a);
    
    /* close the table body */
    
    [qlHtml appendString: @"</tbody>\n"];
    
    /*
        start the summary row for the zip file -
        [total size] [blank] [ no. of files]
     */

    [qlHtml appendString: @"<tbody>\n"];
    [qlHtml appendFormat: @"<tr class=\"border-top\" ;\">"];
    
    /* print out the total number of files in the zip file */

    fileCount = archive_file_count(a);
    
    [qlHtml appendFormat:
        @"<td align=\"center\" colspan=\"2\">%lu item%s</td>\n",
        fileCount,
        (fileCount > 1 ? "s" : "")];
    
    /* clear the file size spec */
    
    memset(&fileSizeSpecInZip, 0, sizeof(fileSizeSpec_t));
    
    /* get the file's total uncompressed size spec */
    
    getFileSizeSpec(totalSize,
                    &fileSizeSpecInZip);

    /* print out the zip file's total size in B, K, M, G, or T */
    
    [qlHtml appendFormat:
            @"<td align=\"right\">%-.1f %-1s</td>",
            fileSizeSpecInZip.size,
            fileSizeSpecInZip.spec];

    if (stat(zipFileNameStr, &fileStats) == 0)
    {
        totalCompressedSize = fileStats.st_size;
    }
    
    /* print out the % compression for the whole zip file */

    if (totalSize > 0 && totalCompressedSize > 0) {
        compression = getCompression(totalSize,
                                     totalCompressedSize);
        [qlHtml appendFormat:
                @"<td align=\"right\">(%3.0f%%)</td>",
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
    return (zipErr == 0 ? noErr : zipQLFailed);
}

/* CancelPreviewGeneration - handle a user canceling the preview */

void CancelPreviewGeneration(void *thisInterface,
                             QLPreviewRequestRef preview)
{
}

/* getFileSizeSpec - return a string corresponding to the size of the file */

static int getFileSizeSpec(off_t fileSizeInBytes,
                           fileSizeSpec_t *fileSpec)
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

static float getCompression(off_t uncompressedSize,
                            off_t compressedSize)
{
    Float64 compression = 0.0;
    
    if (uncompressedSize > 0)
    {
        compression = uncompressedSize / (Float64)(compressedSize);
        if (compression >= 1.0) {
            compression = 1.0 / compression;
        }
        compression = 100.0 * (1.0 - compression);
    }
    
    if (compression <= 0 || compression >= 99.9)
    {
        compression = 0.0;
    }
    
    return compression;
}

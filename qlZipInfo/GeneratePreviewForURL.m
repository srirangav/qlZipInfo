/*
    GeneratePreviewForURL.m - preview generation for archives

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
    v. 0.2.3 (07/21/2021) - add support for indiviudal files that are
                            gzip'ed
    v. 0.2.4 (07/22/2021) - modularize preview generation
    v. 0.2.5 (10/26/2021) - add support for uu encoded archives and rpms
    v. 0.3.0 (11/13/2021) - add support for binhex archives
    v. 0.4.0 (08/01/2022) - add support for stuffit archives

    Copyright (c) 2015-2022 Sriranga R. Veeraraghavan <ranga@calalum.org>

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

#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <QuickLook/QuickLook.h>
#import <CommonCrypto/CommonDigest.h>

#import <stdio.h>
#import <sys/syslimits.h>
#import <sys/stat.h>
#import <iconv.h>

#import "config.h"
#import "archive.h"
#import "archive_entry.h"
#import "binhex.h"
#import "sit.h"
#import "GTMNSString+HTML.h"
#import "GeneratePreviewForURL.h"

/* public functions */

/* GeneratePreviewForURL - generate an archives preview */

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
    off_t fileCompressedSize = 0;
    bool isFolder = FALSE;
    bool isGZFile = false;
    fileSizeSpec_t fileSizeSpecInZip;

    if (url == NULL)
    {
        fprintf(stderr, "qlZipInfo: ERROR: url is null\n");
        return zipQLFailed;
    }

    /* binhex file */

    if (CFEqual(contentTypeUTI, gUTIBinHex) == true)
    {
        return GeneratePreviewForHQX(thisInterface,
                                     preview,
                                     url,
                                     contentTypeUTI,
                                     options);
    }

    /* stuffit archive */

    if (CFEqual(contentTypeUTI, gUTISIT1) == true ||
        CFEqual(contentTypeUTI, gUTISIT2) == true)
    {
        return GeneratePreviewForSIT(thisInterface,
                                     preview,
                                     url,
                                     contentTypeUTI,
                                     options);
    }

    /* get the local file system path for the specified file */

    zipFileName =
        (CFMutableStringRef)CFURLCopyFileSystemPath(url,
                                                    kCFURLPOSIXPathStyle);
    if (zipFileName == NULL)
    {
        fprintf(stderr, "qlZipInfo: ERROR: file name is null\n");
        return zipQLFailed;
    }

    /* normalize the file name */

    CFStringNormalize(zipFileName, kCFStringNormalizationFormC);

    /* covert the file system path to a c string */

    zipFileNameStr =
        CFStringGetCStringPtr(zipFileName, kCFStringEncodingUTF8);

    if (zipFileNameStr == NULL)
    {

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

    if (QLPreviewRequestIsCancelled(preview))
    {
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

    /* initialize the archive object */

    a = archive_read_new();

    /* enable filters */

    archive_read_support_filter_compress(a);
    archive_read_support_filter_gzip(a);
    archive_read_support_filter_bzip2(a);
    archive_read_support_filter_xz(a);
    archive_read_support_filter_uu(a);
    archive_read_support_filter_rpm(a);

    /* enable archive formats */

    archive_read_support_format_cpio(a);
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

    /* open the archive for reading */

    r = archive_read_open_filename(a, zipFileNameStr, 10240);

    /* return an error if the file couldn't be opened */

    if (r != ARCHIVE_OK)
    {
        fprintf(stderr,
                "qlZipInfo: ERROR: %s\n",
                archive_error_string(a));

        archive_read_close(a);
        archive_read_free(a);

        r = zipQLFailed;
    }

    if (r == zipQLFailed)
    {
        /* if this is a gzip'ed file, re-try opening in raw mode */

        if (CFEqual(contentTypeUTI, gUTIGZip) != true)
        {
            return r;
        }

        isGZFile = true;

        a = archive_read_new();
        archive_read_support_format_raw(a);
        archive_read_support_filter_gzip(a);

        r = archive_read_open_filename(a, zipFileNameStr, 10240);

        /* return an error if the gzip'ed couldn't be opened */

        if (r != ARCHIVE_OK)
        {
            fprintf(stderr,
                    "qlZipInfo: ERROR: gz: %s\n",
                    archive_error_string(a));
            archive_read_close(a);
            archive_read_free(a);
            return zipQLFailed;
        }
    }

    /*  exit if the user canceled the preview */

    if (QLPreviewRequestIsCancelled(preview))
    {
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

    /* create the html header */

    formatOutputHeader(qlHtml);

    /* start the html body */

    startOutputBody(qlHtml);

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

        if (isGZFile == true)
        {
            isFolder = FALSE;
        }
        else
        {
            isFolder =
                (archive_entry_filetype(entry) == AE_IFDIR ? TRUE : FALSE);
        }

        /* start the table row for this entry */

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

        if (isGZFile != true)
        {
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
        }

        [qlHtml appendFormat: @"<td align=\"center\">%@</td>",
                              qlEntryIcon];

        /* output the filename with HTML escaping */

        fileNameInZipEscaped =
            [[NSString stringWithUTF8String: fileNameInZip]
                                             gtm_stringByEscapingForHTML];
        if (fileNameInZipEscaped == nil)
        {
            fileNameInZipEscaped = (NSString *)gFileNameUnavilableStr;
        }

        [qlHtml appendString: @"<td><div style=\"display: block; "];

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

            if (isGZFile == true)
            {
                fileCompressedSize = getGZExpandedFileSize(zipFileNameStr);
            }
            else
            {
                fileCompressedSize = archive_entry_size(entry);
            }

            /* clear the file size spec */

            memset(&fileSizeSpecInZip, 0, sizeof(fileSizeSpec_t));

            /* get the file's size spec */

            getFileSizeSpec(fileCompressedSize,
                            &fileSizeSpecInZip);

            /* print out the file's size in B, K, M, G, or T */

            [qlHtml appendFormat:
                    @"<td align=\"right\">%-.1f %-1s</td>",
                    fileSizeSpecInZip.size,
                    fileSizeSpecInZip.spec];

            [qlHtml appendString:
                    @"<td align=\"right\">&nbsp;</td>"];

            //[qlHtml appendString: @"</td>"];
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

        /* update the total compressed size */

        totalSize += fileCompressedSize;

        /* if this was a GZip'ed file, no need to repeat the loop */

        if (isGZFile == true)
        {
            break;
        }
    }

    /* close the zip file */

    archive_read_close(a);
    archive_read_free(a);

    /* close the main table's body */

    [qlHtml appendString: @"</tbody>\n"];

    /*
        start the summary row for the zip file -
        [# files] [expanded size / compressed size] [% compression]
     */

    [qlHtml appendString: @"<tbody>\n<tr>\n"];

    /* print out the total number of files in the zip file */

    fileCount = archive_file_count(a);

    [qlHtml appendString:
        @"<td align=\"center\" colspan=\"2\" class=\"border-top\">"];

    [qlHtml appendFormat: @"%lu item%s</td>\n",
                          fileCount,
                          (fileCount > 1 ? "s" : "")];

    /* clear the file size spec */

    memset(&fileSizeSpecInZip, 0, sizeof(fileSizeSpec_t));

    /* get the file's total uncompressed size spec */

    getFileSizeSpec(totalSize,
                    &fileSizeSpecInZip);

    /* print out the zip file's total size in B, K, M, G, or T */

    [qlHtml appendString:
        @"<td align=\"right\" colspan=\"3\" class=\"border-top\">"];
    [qlHtml appendFormat: @"%-.1f&nbsp;%-1s",
                          fileSizeSpecInZip.size,
                          fileSizeSpecInZip.spec];

    if (stat(zipFileNameStr, &fileStats) == 0)
    {
        totalCompressedSize = fileStats.st_size;

        if (totalCompressedSize > 0)
        {
            /* clear the file size spec */

            memset(&fileSizeSpecInZip, 0, sizeof(fileSizeSpec_t));

            /* get the file's total uncompressed size spec */

            getFileSizeSpec(totalCompressedSize,
                            &fileSizeSpecInZip);

            [qlHtml appendFormat: @" / %-.1f&nbsp;%-1s",
                                  fileSizeSpecInZip.size,
                                  fileSizeSpecInZip.spec];
        }
    }

    /* print out the % compression for the whole zip file */

    if (totalSize > 0 && totalCompressedSize > 0)
    {
        [qlHtml appendFormat: @" (%3.0f%%)",
                              getCompression(totalSize,
                                             totalCompressedSize)];
    }

    [qlHtml appendString: @"</td>"];

    [qlHtml appendString:
        @"<td class=\"border-top\"><pre>&nbsp;</pre></td>\n"];

    /* close the summary row */

    [qlHtml appendString:@"</tr>\n"];

    /* close the table body */

    [qlHtml appendString: @"</tbody>\n"];

    /* close the table */

    [qlHtml appendString: @"</table>\n"];

    /* close the html */

    endOutputBody(qlHtml);

    QLPreviewRequestSetDataRepresentation(preview,
                                          (__bridge CFDataRef)[qlHtml dataUsingEncoding:
                                                NSUTF8StringEncoding],
                                          kUTTypeHTML,
                                          (__bridge CFDictionaryRef)qlHtmlProps);

    return (zipErr == 0 ? noErr : zipQLFailed);
}

/* GeneratePreviewForHQX - generate the preview for a binhex archive */

static OSStatus GeneratePreviewForHQX(void *thisInterface,
                                      QLPreviewRequestRef preview,
                                      CFURLRef url,
                                      CFStringRef contentTypeUTI,
                                      CFDictionaryRef options)
{
    NSMutableDictionary *qlHtmlProps = nil;
    NSMutableString *qlHtml = nil;
    int zipErr = 0;
    CFMutableStringRef zipFileName = NULL;
    const char *zipFileNameStr = NULL;
    char zipFileNameCStr[PATH_MAX];
    NSString *escapedStr = nil;
    hqxFileHandle_t hqxFile;
    fileSizeSpec_t fileSizeSpecInZip;

    if (url == NULL)
    {
        fprintf(stderr, "qlZipInfo: ERROR: url is null\n");
        return zipQLFailed;
    }

    if (CFEqual(contentTypeUTI, gUTIBinHex) != true)
    {
        fprintf(stderr,
                "qlZipInfo: ERROR: UTI is not binhex\n");
        return zipQLFailed;
    }

    /* get the local file system path for the specified file */

    zipFileName =
        (CFMutableStringRef)CFURLCopyFileSystemPath(url,
                                                    kCFURLPOSIXPathStyle);
    if (zipFileName == NULL)
    {
        fprintf(stderr, "qlZipInfo: ERROR: file name is null\n");
        return zipQLFailed;
    }

    /* normalize the file name */

    CFStringNormalize(zipFileName, kCFStringNormalizationFormC);

    /* covert the file system path to a c string */

    zipFileNameStr =
        CFStringGetCStringPtr(zipFileName, kCFStringEncodingUTF8);

    if (zipFileNameStr == NULL)
    {

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

    if (QLPreviewRequestIsCancelled(preview))
    {
        return noErr;
    }

    if (hqxInitFileHandle(zipFileNameStr, &hqxFile) != gHqxOkay)
    {
        fprintf(stderr,
                "qlZipInfo: ERROR: could not initialize hqx file handle\n");
        return zipQLFailed;
    }

    /*  exit if the user canceled the preview */

    if (QLPreviewRequestIsCancelled(preview))
    {
        hqxReleaseFileHandle(&hqxFile);
        return noErr;
    }

    if (hqxGetHeader(&hqxFile) != gHqxOkay)
    {
        fprintf(stderr,
                "qlZipInfo: ERROR: could not read hqx handle\n");
        hqxReleaseFileHandle(&hqxFile);
        return zipQLFailed;
    }

    if (QLPreviewRequestIsCancelled(preview))
    {
        hqxReleaseFileHandle(&hqxFile);
        return noErr;
    }

    /* initialize the HTML output */

    qlHtmlProps = [[NSMutableDictionary alloc] init];
    [qlHtmlProps setObject: @"UTF-8"
                 forKey: (NSString *)kQLPreviewPropertyTextEncodingNameKey];
    [qlHtmlProps setObject: @"text/html"
                 forKey: (NSString*)kQLPreviewPropertyMIMETypeKey];

    qlHtml = [[NSMutableString alloc] init];

    /* create the html header */

    formatOutputHeader(qlHtml);

    /* start the html body */

    startOutputBody(qlHtml);

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
                          (gColFileMacType + gColPadding)];
    [qlHtml appendFormat: @"<colgroup width=\"%d\" />\n",
                          (gColFileMacCreator + gColPadding)];

    /* add the table header */

    [qlHtml appendString: @"<thead><tr class=\"border-bottom\">"];
    [qlHtml appendFormat: @"<th class=\"border-side\" colspan=\"2\">%@</th>",
                          gTableHeaderName];
    [qlHtml appendFormat: @"<th class=\"border-side\">%@</th>",
                          gTableHeaderSize];
    [qlHtml appendFormat: @"<th class=\"border-side\">%@</th>",
                          gTableHeaderType];
    [qlHtml appendFormat: @"<th class=\"border-side\">%@</th>",
                          gTableHeaderCreator];
    [qlHtml appendString: @"</tr></thead>\n"];

    /* start the table body */

    [qlHtml appendString: @"<tbody>\n"];

    /* start the table row for this file */

    [qlHtml appendFormat: @"<tr>"];

    /* add the icon */

    if (strncmp(gMacFileTypeApplication,
                hqxFile.hqxHeader.type,
                4) == 0)
    {
        escapedStr = (NSString *)gFileAppIcon;
    }
    else if (strncmp(gMacFileTypeSIT,
                     hqxFile.hqxHeader.type,
                     4) == 0 ||
             strncmp(gMacFileTypeSIT5,
                              hqxFile.hqxHeader.type,
                              4) == 0)
    {
        escapedStr = (NSString *)gFilePkgIcon;
    }
    else
    {
        escapedStr = (NSString *)gFileIcon;
    }

    [qlHtml appendFormat: @"<td align=\"center\">%@</td>",
                          escapedStr];

    escapedStr =
        [[NSString stringWithUTF8String: hqxFile.hqxHeader.asciiName]
                                         gtm_stringByEscapingForHTML];
    if (escapedStr == nil)
    {
        escapedStr = (NSString *)gFileNameUnavilableStr;
    }

    [qlHtml appendString: @"<td><div style=\"display: block; "];
    [qlHtml appendFormat: @"word-wrap: break-word;\">%@</div></td>",
                          escapedStr];

    /* clear the file size spec */

    memset(&fileSizeSpecInZip, 0, sizeof(fileSizeSpec_t));

    /* get the file's size spec */

    getFileSizeSpec(hqxFile.hqxHeader.dataLen +
                    hqxFile.hqxHeader.rsrcLen,
                    &fileSizeSpecInZip);

    /* print out the file's size in B, K, M, G, or T */

    [qlHtml appendFormat:
            @"<td align=\"center\">%-.1f %-1s</td>",
            fileSizeSpecInZip.size,
            fileSizeSpecInZip.spec];

//    [qlHtml appendString:
//            @"<td align=\"right\">&nbsp;</td>"];

    escapedStr =
        [[NSString stringWithUTF8String: hqxFile.hqxHeader.type]
                                         gtm_stringByEscapingForHTML];
    [qlHtml appendFormat: @"<td align=\"center\">%@</td>", escapedStr];

    escapedStr =
        [[NSString stringWithUTF8String: hqxFile.hqxHeader.creator]
                                         gtm_stringByEscapingForHTML];
    [qlHtml appendFormat: @"<td align=\"center\">%@</td>", escapedStr];

    /* close the row */

    [qlHtml appendString:@"</tr>\n"];

    /* close the main table's body */

    [qlHtml appendString: @"</tbody>\n"];

    /* close the table */

    [qlHtml appendString: @"</table>\n"];

    /* close the html */

    endOutputBody(qlHtml);

    hqxReleaseFileHandle(&hqxFile);

    QLPreviewRequestSetDataRepresentation(preview,
                                          (__bridge CFDataRef)[qlHtml dataUsingEncoding:
                                                NSUTF8StringEncoding],
                                          kUTTypeHTML,
                                          (__bridge CFDictionaryRef)qlHtmlProps);

    return (zipErr == 0 ? noErr : zipQLFailed);
}

/* GeneratePreviewForSIT - generate the preview for a stuffit archive */

static OSStatus GeneratePreviewForSIT(void *thisInterface,
                                      QLPreviewRequestRef preview,
                                      CFURLRef url,
                                      CFStringRef contentTypeUTI,
                                      CFDictionaryRef options)
{
    NSMutableDictionary *qlHtmlProps = nil;
    NSMutableString *qlHtml = nil;
    NSString *qlEntryIcon = nil;
    NSMutableString *fileDateStringInZip = nil;
    NSDateFormatter *fileDateFormatterInZip = nil;
    NSDateFormatter *fileLocalDateFormatterInZip = nil;
    NSDate *fileDateInZip = nil;
    int zipErr = 0;
    CFMutableStringRef zipFileName = NULL;
    const char *zipFileNameStr = NULL;
    char zipFileNameCStr[PATH_MAX];
    NSString *fileNameInZipEscaped = nil;
    const char *fileNameInZip;
    sitFileHandle_t sitFile;
    fileSizeSpec_t fileSizeSpecInZip;
    sitEntryHeader_t eHdr;
    size_t totalEntries = 0;
    NSDateComponents *macosRefDateComponents = nil;
    NSCalendar *gregorian = nil;
    NSDate *macosRefDate = nil;
    off_t totalSize = 0;
    off_t totalCompressedSize = 0;
    off_t fileCompressedSize = 0;
    bool isFolder = FALSE;

    if (url == NULL)
    {
        fprintf(stderr, "qlZipInfo: ERROR: url is null\n");
        return zipQLFailed;
    }

    if (CFEqual(contentTypeUTI, gUTISIT1) != true &&
        CFEqual(contentTypeUTI, gUTISIT2) != true)
    {
        fprintf(stderr,
                "qlZipInfo: ERROR: UTI is not SIT = '%s'\n",
                CFStringGetCStringPtr(contentTypeUTI,
                                      kCFStringEncodingMacRoman));
        return zipQLFailed;
    }

    /* get the local file system path for the specified file */

    zipFileName =
        (CFMutableStringRef)CFURLCopyFileSystemPath(url,
                                                    kCFURLPOSIXPathStyle);
    if (zipFileName == NULL)
    {
        fprintf(stderr, "qlZipInfo: ERROR: file name is null\n");
        return zipQLFailed;
    }

    /* normalize the file name */

    CFStringNormalize(zipFileName, kCFStringNormalizationFormC);

    /* covert the file system path to a c string */

    zipFileNameStr =
        CFStringGetCStringPtr(zipFileName, kCFStringEncodingUTF8);

    if (zipFileNameStr == NULL)
    {

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

    if (QLPreviewRequestIsCancelled(preview))
    {
        return noErr;
    }

    if (sitInitFileHandle(zipFileNameStr, &sitFile) != gHqxOkay)
    {
        fprintf(stderr,
                "qlZipInfo: ERROR: could not initialize sit file handle\n");
        return zipQLFailed;
    }

    /*  exit if the user canceled the preview */

    if (QLPreviewRequestIsCancelled(preview))
    {
        sitReleaseFileHandle(&sitFile);
        return noErr;
    }

    /* initialize the HTML output */

    qlHtmlProps = [[NSMutableDictionary alloc] init];
    [qlHtmlProps setObject: @"UTF-8"
                 forKey: (NSString *)kQLPreviewPropertyTextEncodingNameKey];
    [qlHtmlProps setObject: @"text/html"
                 forKey: (NSString*)kQLPreviewPropertyMIMETypeKey];

    qlHtml = [[NSMutableString alloc] init];

    /* create the html header */

    formatOutputHeader(qlHtml);

    /* start the html body */

    startOutputBody(qlHtml);

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

    do
    {
        zipErr = sitGetNextEntry(&sitFile, &eHdr);
        if (zipErr != gSitOkay)
        {
            break;
        }

        if (QLPreviewRequestIsCancelled(preview)) {
            break;
        }

        if (sitIsEntryFolder(&eHdr) == SitEntryFolderEnd)
        {
            continue;
        }

        totalEntries++;

        isFolder = FALSE;
        if (sitIsEntryFolder(&eHdr) == SitEntryFolderStart)
        {
            isFolder = TRUE;
        }

        /* start the table row for this entry */

        [qlHtml appendFormat: @"<tr>"];

        /* add an icon */

        qlEntryIcon = (NSString *)gFileIcon;

        if (isFolder == TRUE)
        {
            qlEntryIcon = (NSString *)gFolderIcon;
        }
        else if (sitIsEntryEncrypted(&eHdr) == 1)
        {
            qlEntryIcon = (NSString *)gFileEncyrptedIcon;
        }
        else if (sitIsEntryApplication(&eHdr) == 1)
        {
            qlEntryIcon = (NSString *)gFileAppIcon;
        }

        [qlHtml appendFormat: @"<td align=\"center\">%@</td>",
                              qlEntryIcon];

        /* output the filename with HTML escaping */

        fileNameInZip = sitEntryGetAsciiName(&eHdr);
        if (fileNameInZip == NULL)
        {
            fileNameInZip = gFileNameUnavilable;
        }

        fileNameInZipEscaped =
            [[NSString stringWithUTF8String: fileNameInZip]
                                             gtm_stringByEscapingForHTML];
        if (fileNameInZipEscaped == nil)
        {
            fileNameInZipEscaped = (NSString *)gFileNameUnavilableStr;
        }

        [qlHtml appendString: @"<td><div style=\"display: block; "];

        [qlHtml appendFormat: @"word-wrap: break-word;\">%@</div></td>",
                              fileNameInZipEscaped];

        if (isFolder == TRUE)
        {
            [qlHtml appendString:
                    @"<td align=\"center\" colspan=\"2\"><pre>--</pre></td>"];
        }
        else
        {
            /* update the total uncompressed size */

            totalSize += sitEntryGetUnCompressedSize(&eHdr);

            /* get this entry's compressed size */

            fileCompressedSize = sitEntryGetCompressedSize(&eHdr);

            /* clear the file size spec */

            memset(&fileSizeSpecInZip, 0, sizeof(fileSizeSpec_t));

            /* get the file's size spec */

            getFileSizeSpec(fileCompressedSize,
                            &fileSizeSpecInZip);

            /* print out the file's size in B, K, M, G, or T */

            [qlHtml appendFormat:
                    @"<td align=\"right\">%-.1f %-1s</td>",
                    fileSizeSpecInZip.size,
                    fileSizeSpecInZip.spec];

            [qlHtml appendString:
                    @"<td align=\"right\">&nbsp;</td>"];
        }

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

        /*
            Create a date for Classic MacOS' reference date of
            midnight Jan 1, 1904
            Based on: https://stackoverflow.com/questions/4154082/
        */

        if (macosRefDate == nil)
        {
            if (macosRefDateComponents == nil)
            {
                macosRefDateComponents =
                    [[NSDateComponents alloc] init];
                [macosRefDateComponents setDay: 1];
                [macosRefDateComponents setMonth: 1];
                [macosRefDateComponents setYear: 1904];
                [macosRefDateComponents setHour: 0];
                [macosRefDateComponents setMinute: 0];
                [macosRefDateComponents setSecond: 0];
            }
            if (gregorian == nil)
            {
                gregorian = [[NSCalendar alloc]
                             initWithCalendarIdentifier:
                             NSCalendarIdentifierGregorian];
            }
            macosRefDate =
                [gregorian dateFromComponents: macosRefDateComponents];
        }

        fileDateInZip =
            [[NSDate alloc] initWithTimeInterval: sitEntryGetModifiedDate(&eHdr)
                                      sinceDate: macosRefDate];

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

    } while (zipErr == gSitOkay);

    totalCompressedSize = sitGetSize(&sitFile);

    /* close the sit file */

    sitReleaseFileHandle(&sitFile);

    /* close the main table's body */

    [qlHtml appendString: @"</tbody>\n"];

    /*
        start the summary row for the sit file -
        [# files] [expanded size / compressed size] [% compression]
     */

    [qlHtml appendString: @"<tbody>\n<tr>\n"];

    /* print out the total number of files in the sit file */

    [qlHtml appendString:
        @"<td align=\"center\" colspan=\"2\" class=\"border-top\">"];

    [qlHtml appendFormat: @"%lu item%s</td>\n",
                          totalEntries,
                          (totalEntries > 1 ? "s" : "")];

    /* clear the file size spec */

    memset(&fileSizeSpecInZip, 0, sizeof(fileSizeSpec_t));

    /* get the file's total uncompressed size spec */

    getFileSizeSpec(totalSize,
                    &fileSizeSpecInZip);

    /* print out the zip file's total size in B, K, M, G, or T */

    [qlHtml appendString:
        @"<td align=\"right\" colspan=\"3\" class=\"border-top\">"];
    [qlHtml appendFormat: @"%-.1f&nbsp;%-1s",
                          fileSizeSpecInZip.size,
                          fileSizeSpecInZip.spec];

    if (totalCompressedSize > 0)
    {
            /* clear the file size spec */

            memset(&fileSizeSpecInZip, 0, sizeof(fileSizeSpec_t));

            /* get the file's total uncompressed size spec */

            getFileSizeSpec(totalCompressedSize,
                            &fileSizeSpecInZip);

            [qlHtml appendFormat: @" / %-.1f&nbsp;%-1s",
                                  fileSizeSpecInZip.size,
                                  fileSizeSpecInZip.spec];
    }

    /* print out the % compression for the whole zip file */

    if (totalSize > 0 && totalCompressedSize > 0)
    {
        [qlHtml appendFormat: @" (%3.0f%%)",
                              getCompression(totalSize,
                                             totalCompressedSize)];
    }

    [qlHtml appendString: @"</td>"];

    [qlHtml appendString:
        @"<td class=\"border-top\"><pre>&nbsp;</pre></td>\n"];

    /* close the summary row */

    [qlHtml appendString:@"</tr>\n"];

    /* close the table body */

    [qlHtml appendString: @"</tbody>\n"];

    /* close the table */

    [qlHtml appendString: @"</table>\n"];

    /* close the html */

    endOutputBody(qlHtml);

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

/* private functions */

/* formatOutputHeader - format the output header */

static bool formatOutputHeader(NSMutableString *qlHtml)
{
    if (qlHtml == nil)
    {
        return false;
    }

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

    [qlHtml appendString: @"@media (prefers-color-scheme: dark) { "];

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

    /*
        add a bottom border for the header row items only, to better
        match the BigSur finder, and make the header fixed.
        based on:
            https://www.w3docs.com/snippets/html/how-to-create-a-table-with-a-fixed-header-and-scrollable-body.html
     */

    [qlHtml appendFormat:
        @"th { border-bottom: %dpx solid %@; ",
        gBorder,
        gDarkModeTableHeaderBorderColor];
    [qlHtml appendString: @" position: sticky; position: -webkit-sticky; "];
    [qlHtml appendFormat: @"top: 0; z-index: 3; background-color: %@ ;}\n",
                          gDarkModeBackground];

    /* disable internal borders for table cells */

    [qlHtml appendString: @"td { border: none; z-index: 1; }\n"];

    /* top border for table cells in the summary row */

    [qlHtml appendFormat:
            @"td.border-top { border-top: %dpx solid %@; }\n",
            gBorder,
            gDarkModeTableHeaderBorderColor];

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

    /* no internal borders */

    [qlHtml appendString: @"td { border: none; z-index: 1; }\n"];

    /* top border for table cells in the summary row */

    [qlHtml appendFormat:
            @"td.border-top { border-top: %dpx solid %@; }\n",
            gBorder,
            gLightModeTableHeaderBorderColor];

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

    return true;
}

/* formatOutputHeader - start the output body */

static bool startOutputBody(NSMutableString *qlHtml)
{
    if (qlHtml == nil) {
        return false;
    }

    [qlHtml appendFormat: @"<body>\n"];
    [qlHtml appendFormat: @"<font face=\"%@\">\n", gFontFace];

    return true;
}

static bool endOutputBody(NSMutableString *qlHtml)
{
    if (qlHtml == nil) {
        return false;
    }

    [qlHtml appendString: @"</font>\n</body>\n</html>\n"];

    return true;
}

/*  getGZExpandedFileSize - get a gzip'ed file's expanded file size */

static off_t getGZExpandedFileSize(const char *zipFileNameStr)
{
    FILE *gzFile = NULL;
    UInt8 gzCompressedSize[4];
    off_t gzExpandedFileSize = 0;

    if (zipFileNameStr == NULL)
    {
        return gzExpandedFileSize;
    }

    /* open the file for reading */

    gzFile = fopen(zipFileNameStr, "r");
    if (gzFile == NULL)
    {
        return gzExpandedFileSize;
    }

    memset(gzCompressedSize, 0, 4);

    /* go to last 4 bytes of the file */

    if (fseek(gzFile, -4, SEEK_END) != 0)
    {
        fclose(gzFile);
        return gzExpandedFileSize;
    }

    /*
        read the last 4 bytes and convert them to the uncompressed
        file size (which might be wrong for files greater than 4GB),
        see:

        http://www.abeel.be/content/determine-uncompressed-size-gzip-file
        https://stackoverflow.com/questions/9209138/uncompressed-file-size-using-zlibs-gzip-file-access-function
     */

    if (fread(gzCompressedSize, 1 , 4, gzFile) == 4)
    {
        gzExpandedFileSize =
            (gzCompressedSize[3] << 24) |
            (gzCompressedSize[2] << 16) |
            (gzCompressedSize[1] <<  8) +
            gzCompressedSize[0];
    }

    fclose(gzFile);

    return gzExpandedFileSize;
}

/* getFileSizeSpec - return a string corresponding to the size of the file */

static int getFileSizeSpec(off_t fileSizeInBytes,
                           fileSizeSpec_t *fileSpec)
{
    Float64 fileSize = 0.0;
    int err = -1;

    if (fileSpec == NULL)
    {
        return err;
    }

    err = 0;

    memset(fileSpec->spec, 0, 3);

    /* print the file size in B, KB, MB, GB, or TB */

    if (fileSizeInBytes < 100)
    {
        snprintf(fileSpec->spec, 3, "%s", gFileSizeBytes);
        fileSpec->size = (Float64)fileSizeInBytes;
        return err;
    }

    fileSize = (Float64)fileSizeInBytes / 1000.0;

    if (fileSize < 1000.0)
    {
        snprintf(fileSpec->spec, 3, "%s", gFileSizeKiloBytes);
        fileSpec->size = fileSize;
        return err;
    }

    fileSize /= 1000.0;

    if (fileSize < 1000.0)
    {
        snprintf(fileSpec->spec, 3, "%s", gFileSizeMegaBytes);
        fileSpec->size = fileSize;
        return err;
    }

    fileSize /= 1000.0;

    if (fileSize < 1000.0)
    {
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
        if (compression >= 1.0)
        {
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

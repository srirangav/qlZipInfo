/*
    GeneratePreviewForURL - generate a preview of a zip file
    $Id: GeneratePreviewForURL.c 1435 2015-08-14 16:48:34Z ranga $
 
    History:
 
    v. 0.1.0 (08/19/2015) - Initial Release
 
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

/* 
    Default error code (MacOS extractErr error code from MacErrors.h)
    See:  https://opensource.apple.com/source/CarbonHeaders/CarbonHeaders-18.1/MacErrors.h
 */

enum {
    zipQLFailed = -3104,
};

/* prototypes */

OSStatus GeneratePreviewForURL(void *thisInterface,
                               QLPreviewRequestRef preview,
                               CFURLRef url,
                               CFStringRef contentTypeUTI,
                               CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface,
                               QLPreviewRequestRef preview,
                               CFURLRef url,
                               CFStringRef contentTypeUTI,
                               CFDictionaryRef options)
{
    NSMutableString *qlHtml = nil;
    NSMutableDictionary *qlHtmlProps = nil;
    CFStringRef zipFileName = NULL;
    const char *zipFileNameStr = NULL;
    unzFile zipFile = NULL;
    unz_global_info zipFileInfo;
    char fileNameInZip[PATH_MAX];
    unz_file_info fileInfoInZip;
    uLong i = 0, totalSize = 0;
    int zipErr = UNZ_OK;
    
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
    
    zipFile = unzOpen(zipFileNameStr);
    if (zipFile == NULL) {
        return zipQLFailed;
    }

    /* get the zip files global info */

    zipErr = unzGetGlobalInfo(zipFile, &zipFileInfo);
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
    
    /* html header */
    
    [qlHtml appendString: @"<!DOCTYPE html>\n"];
    [qlHtml appendString: @"<html xmlns=\"http://www.w3.org/1999/xhtml\">\n"];
    [qlHtml appendString: @"<head>\n"];
    [qlHtml appendString: @"<meta http-equiv=\"Content-Type\" content=\"text/html; "];
    [qlHtml appendString: @"charset=utf-8\" />\n"];
    
    [qlHtml appendString: @"<style>\n"];
    [qlHtml appendString: @"#name_col { width: 340px; word-break: break-all; }\n"];
    [qlHtml appendString: @"tr:nth-child(even) { background: #F0F0F0; }\n"];
    [qlHtml appendString: @"tr:nth-child(odd) { background: #FFFFFF; }\n"];
    [qlHtml appendString: @"</style>\n"];
    
    [qlHtml appendString: @"</head>\n"];

    /* html body */

    [qlHtml appendString: @"<body bgcolor=\"#F6F6F6\">\n"];
    [qlHtml appendString: @"<font size=\"2\" face=\"sans-serif\">\n"];
    
    /* start the table */
    
    [qlHtml appendString: @"<table align=\"center\" frame=\"box\" width=\"608\" cellpadding=\"4\" "];
    [qlHtml appendString: @"rules=\"groups\" style=\"table-layout:fixed\">\n"];
    [qlHtml appendString: @"<colgroup width=\"88\" />\n"];
    [qlHtml appendString: @"<colgroup width=\"74\" />\n"];
    [qlHtml appendString: @"<colgroup width=\"74\" />\n"];
    [qlHtml appendString: @"<colgroup width=\"352\" />\n"];
        
    /* add the table header */
    
    [qlHtml appendString:
        @"<thead><tr><th>Length</th><th>Date</th><th>Time</th><th>Name</th></tr></thead>\n"];
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
        
        zipErr = unzGetCurrentFileInfo(zipFile,
                                       &fileInfoInZip,
                                       fileNameInZip,
                                       sizeof(fileNameInZip),
                                       NULL,0,NULL,0);
        if (zipErr != UNZ_OK) {
            break;
        }
        
        /* generate the table row for this file - [size] [date] [time] [name] */
        
        [qlHtml appendString: @"<tr>"];
        
        [qlHtml appendFormat: @"<td align=\"right\">%lu</td>",
                              fileInfoInZip.uncompressed_size];
        
        [qlHtml appendFormat: @"<td align=\"center\">%2.2lu-%2.2lu-%2.2lu</td>",
                              (uLong)fileInfoInZip.tmu_date.tm_mon + 1,
                              (uLong)fileInfoInZip.tmu_date.tm_mday,
                              (uLong)fileInfoInZip.tmu_date.tm_year % 100];

        [qlHtml appendFormat: @"<td align=\"center\">%2.2lu:%2.2lu</td>",
                              (uLong)fileInfoInZip.tmu_date.tm_hour,
                              (uLong)fileInfoInZip.tmu_date.tm_min];
        
        [qlHtml appendFormat: @"<td><div id=\"name_col\">%s</div></td>",
                              fileNameInZip];
        
        [qlHtml appendString:@"</tr>\n"];

        /* update the total size */
        
        totalSize += fileInfoInZip.uncompressed_size;
    }

    [qlHtml appendString: @"</tbody>\n"];
    
    /* add the summary row for the zip file - [total size] [blank] [ no. of files] */

    [qlHtml appendString: @"<tbody>\n"];
    [qlHtml appendString: @"<tr>"];
    [qlHtml appendFormat: @"<td align=\"right\"><b>%ld</b></td>",
                          totalSize];
    [qlHtml appendString: @"<td colspan=\"2\">&nbsp;</td>"];
    [qlHtml appendFormat: @"<td><b>%lu file%s</b></td>\n",
                          zipFileInfo.number_entry,
                          (zipFileInfo.number_entry > 1 ? "s" : "")];
    [qlHtml appendString:@"</tr>\n"];
    [qlHtml appendString: @"</tbody>\n"];
    
    /* close the table */
    
    [qlHtml appendString: @"</table>\n"];

    /* close the html */
    
    [qlHtml appendString: @"</font>\n</body>\n</html>\n"];
    
    /* close the zip file */
    
    unzClose(zipFile);

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

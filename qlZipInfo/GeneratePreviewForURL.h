/*
    GeneratePreviewForURL.h - constants for qlZipInfo

    History:

    v. 0.1.0 (07/22/2021) - initial release
    v. 0.2.0 (11/13/2021) - add binhex support
    v. 0.3.0 (08/01/2022) - add stuffit support
    v. 0.4.0 (04/16/2024) - Added svg icons from icons8.com. (see LICENSE.txt)
                          - Changed colors to more closely match the Finder.
                          - Contribution by Manuel Brotz
                            https://github.com/mbrotz/qlZipInfo

    Copyright (c) 2015-2024 Sriranga R. Veeraraghavan <ranga@calalum.org>

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

#ifndef generate_preview_for_url_h
#define generate_preview_for_url_h

/* constants */

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
    gColFileMacType  = 58,
    gColFileMacCreator = 58,
    gColFileMacFileName = 356,
};

/* table headings */

static const NSString *gTableHeaderName = @"Name";
static const NSString *gTableHeaderSize = @"Size";
static const NSString *gTableHeaderMode = @"Mode";
static const NSString *gTableHeaderDate = @"Modified";
static const NSString *gTableHeaderType = @"Type";
static const NSString *gTableHeaderCreator = @"Creator";

/* darkmode styles */

static const NSString *gDarkModeBackground = @"#231D2D";
static const NSString *gDarkModeForeground = @"#aba8ad";
static const NSString *gDarkModeFolderColor
                                           = @"#51C5F8";
static const NSString *gDarkModeTableRowEvenBackground
                                           = @"#2F2A39";
static const NSString *gDarkModeTableRowEvenForeground
                                           = @"#aba8ad";
static const NSString *gDarkModeTableBorderColor
                                           = @"#231D2D";
static const NSString *gDarkModeTableHeaderBorderColor
                                           = @"#403B47";
/* light mode styles */

static const NSString *gLightModeBackground = @"white";
static const NSString *gLightModeForeground = @"#6e6b6d";
static const NSString *gLightModeFolderColor
                                            = @"#76D0FB";
static const NSString *gLightModeTableRowEvenBackground
                                            = @"#F4F5F5";
static const NSString *gLightModeTableRowEvenForeground
                                            = @"#6e6b6d";
static const NSString *gLightModeTableBorderColor
                                            = @"white";
static const NSString *gLightModeTableHeaderBorderColor
                                            = @"#DDDDDD";

/* SVG icons from icons8.com, see LICENSE.txt for more information. */

static const NSString *gFolderIcon        = @"<svg alt=\"Folder\" viewBox=\"0,0,256,256\" width=\"16px\" height=\"16px\"><g class=\"folder-icon\" fill-rule=\"nonzero\" stroke=\"none\" stroke-width=\"1\" stroke-linecap=\"butt\" stroke-linejoin=\"miter\" stroke-miterlimit=\"10\" stroke-dasharray=\"\" stroke-dashoffset=\"0\" font-family=\"none\" font-weight=\"none\" font-size=\"none\" text-anchor=\"none\" style=\"mix-blend-mode: normal\"><g transform=\"scale(10.66667,10.66667)\"><path d=\"M20,6h-8l-2,-2h-6c-1.1,0 -2,0.9 -2,2v12c0,1.1 0.9,2 2,2h16c1.1,0 2,-0.9 2,-2v-10c0,-1.1 -0.9,-2 -2,-2z\"></path></g></g></svg>";
static const NSString *gFileIcon          = @"<svg alt=\"Regular File\" viewBox=\"0,0,256,256\" width=\"16px\" height=\"16px\"><g fill-rule=\"nonzero\" stroke=\"none\" stroke-width=\"1\" stroke-linecap=\"butt\" stroke-linejoin=\"miter\" stroke-miterlimit=\"10\" stroke-dasharray=\"\" stroke-dashoffset=\"0\" font-family=\"none\" font-weight=\"none\" font-size=\"none\" text-anchor=\"none\" style=\"mix-blend-mode: normal\"><g transform=\"scale(10.66667,10.66667)\"><path d=\"M13.172,2h-7.172c-1.1,0 -2,0.9 -2,2v16c0,1.1 0.9,2 2,2h12c1.1,0 2,-0.9 2,-2v-11.172c0,-0.53 -0.211,-1.039 -0.586,-1.414l-4.828,-4.828c-0.375,-0.375 -0.884,-0.586 -1.414,-0.586zM18.5,9h-5.5v-5.5z\"></path></g></g></svg>";
static const NSString *gFileEncyrptedIcon = @"<svg alt=\"Encrypted File\" viewBox=\"0,0,256,256\" width=\"16px\" height=\"16px\"><g fill-rule=\"nonzero\" stroke=\"none\" stroke-width=\"1\" stroke-linecap=\"butt\" stroke-linejoin=\"miter\" stroke-miterlimit=\"10\" stroke-dasharray=\"\" stroke-dashoffset=\"0\" font-family=\"none\" font-weight=\"none\" font-size=\"none\" text-anchor=\"none\" style=\"mix-blend-mode: normal\"><g transform=\"scale(10.66667,10.66667)\"><path d=\"M6,2c-1.1,0 -2,0.9 -2,2v16c0,1.1 0.9,2 2,2h8.00586c-0.607,-1.092 -1.00586,-2.419 -1.00586,-4v-2.35742c0,-1.182 0.69348,-2.25428 1.77148,-2.73828l5.22852,-2.3457v-1.73047c0,-0.53 -0.21094,-1.03906 -0.58594,-1.41406l-4.82812,-4.82812c-0.375,-0.375 -0.88406,-0.58594 -1.41406,-0.58594zM13,3.5l5.5,5.5h-4.5c-0.552,0 -1,-0.448 -1,-1zM19.5,13c-0.1245,0.00013 -0.24923,0.02653 -0.36523,0.08203l-3.59961,1.71094c-0.325,0.153 -0.53516,0.49695 -0.53516,0.87695v1.92383c0,4.18 3.219,6.13125 4.5,6.40625c1.281,-0.275 4.5,-2.22625 4.5,-6.40625v-1.92383c0,-0.38 -0.21016,-0.72491 -0.53516,-0.87891l-3.59961,-1.70899c-0.116,-0.055 -0.24073,-0.08216 -0.36523,-0.08203z\"></path></g></g></svg>";
static const NSString *gFileLinkIcon      = @"<svg alt=\"Symbolic Link\" viewBox=\"0,0,256,256\" width=\"16px\" height=\"16px\"><g fill-rule=\"nonzero\" stroke=\"none\" stroke-width=\"1\" stroke-linecap=\"butt\" stroke-linejoin=\"miter\" stroke-miterlimit=\"10\" stroke-dasharray=\"\" stroke-dashoffset=\"0\" font-family=\"none\" font-weight=\"none\" font-size=\"none\" text-anchor=\"none\" style=\"mix-blend-mode: normal\"><g transform=\"scale(10.66667,10.66667)\"><path d=\"M6,2c-1.105,0 -2,0.895 -2,2v16c0,1.105 0.895,2 2,2h10.63086c-0.16,-0.333 -0.28777,-0.667 -0.38477,-1h0.00195c-0.014,-0.049 -0.01825,-0.09748 -0.03125,-0.14648c-0.065,-0.246 -0.11448,-0.49038 -0.14648,-0.73437c-0.235,-1.845 0.42998,-3.61152 1.58398,-4.97852l0.00781,-0.0293c-0.618,-0.814 -0.70516,-1.93337 -0.16016,-2.85937c0.478,-0.809 1.4018,-1.25195 2.3418,-1.25195h0.15625v-2.17187c0,-0.53 -0.21094,-1.03906 -0.58594,-1.41406l-4.82812,-4.82812c-0.375,-0.375 -0.88406,-0.58594 -1.41406,-0.58594zM13,3.45508l5.5,5.54492h-4.5c-0.552,0 -1,-0.448 -1,-1zM19.70703,13c-0.504,0 -0.75544,0.60884 -0.39844,0.96484l1.15625,1.15625l-0.95117,0.95117c-1.223,1.222 -2.7042,3.87783 0.0918,6.67383l0.95703,0.95898c0.39,0.391 1.02306,0.391 1.41406,0c0.391,-0.39 0.391,-1.02306 0,-1.41406l-0.97852,-0.97852c-1.997,-1.996 -0.17327,-3.71327 0.17773,-4.07227l0.70313,-0.70508l1.15625,1.15625c0.356,0.356 0.96484,0.10556 0.96484,-0.39844v-3.29297c0,-0.552 -0.448,-1 -1,-1z\"></path></g></g></svg>";
static const NSString *gFileSpecialIcon   = @"<svg alt=\"Special File\" viewBox=\"0,0,256,256\" width=\"16px\" height=\"16px\"><g fill-rule=\"nonzero\" stroke=\"none\" stroke-width=\"1\" stroke-linecap=\"butt\" stroke-linejoin=\"miter\" stroke-miterlimit=\"10\" stroke-dasharray=\"\" stroke-dashoffset=\"0\" font-family=\"none\" font-weight=\"none\" font-size=\"none\" text-anchor=\"none\" style=\"mix-blend-mode: normal\"><g transform=\"scale(10.66667,10.66667)\"><path d=\"M6,2c-1.1,0 -2,0.9 -2,2v16c0,1.1 0.9,2 2,2h6.68359c-0.433,-0.91 -0.68359,-1.925 -0.68359,-3c0,-3.866 3.134,-7 7,-7c0.34,0 0.673,0.03308 1,0.08008v-3.25195c0,-0.53 -0.21094,-1.03906 -0.58594,-1.41406l-4.82812,-4.82812c-0.375,-0.375 -0.88406,-0.58594 -1.41406,-0.58594zM13,3.5l5.5,5.5h-4.5c-0.552,0 -1,-0.448 -1,-1zM19,14c-2.75,0 -5,2.25 -5,5c0,2.75 2.25,5 5,5c2.75,0 5,-2.25 5,-5c0,-2.75 -2.25,-5 -5,-5zM18.25391,16h1.49414l-0.16602,3.98633h-1.16406zM19,20.73438c0.104,0 0.1992,0.01673 0.2832,0.05273c0.085,0.036 0.1568,0.08548 0.2168,0.14648c0.059,0.061 0.10472,0.1328 0.13672,0.2168c0.032,0.083 0.04883,0.17444 0.04883,0.27344c-0.001,0.096 -0.01583,0.18358 -0.04883,0.26758c-0.032,0.084 -0.07772,0.1558 -0.13672,0.2168c-0.06,0.061 -0.1318,0.11053 -0.2168,0.14453c-0.084,0.034 -0.1792,0.05078 -0.2832,0.05078c-0.105,0 -0.1982,-0.01578 -0.2832,-0.05078c-0.083,-0.033 -0.15584,-0.08353 -0.21484,-0.14453c-0.059,-0.061 -0.10567,-0.1328 -0.13867,-0.2168c-0.033,-0.084 -0.04883,-0.17258 -0.04883,-0.26758c0,-0.099 0.01683,-0.19044 0.04883,-0.27344c0.033,-0.084 0.07967,-0.1558 0.13867,-0.2168c0.059,-0.061 0.13184,-0.11049 0.21484,-0.14648c0.085,-0.036 0.1792,-0.05273 0.2832,-0.05273z\"></path></g></g></svg>";
static const NSString *gFileUnknownIcon   = @"<svg alt=\"Unknown File\" viewBox=\"0,0,256,256\" width=\"16px\" height=\"16px\"><g fill-rule=\"nonzero\" stroke=\"none\" stroke-width=\"1\" stroke-linecap=\"butt\" stroke-linejoin=\"miter\" stroke-miterlimit=\"10\" stroke-dasharray=\"\" stroke-dashoffset=\"0\" font-family=\"none\" font-weight=\"none\" font-size=\"none\" text-anchor=\"none\" style=\"mix-blend-mode: normal\"><g transform=\"scale(10.66667,10.66667)\"><path d=\"M6,2c-1.1,0 -2,0.9 -2,2v16c0,1.1 0.9,2 2,2h6.83203l0.81836,-0.82227l1.12695,-1.13867l0.00586,-0.01758l-0.91016,-0.91797c-1.155,-1.164 -1.155,-3.0567 0,-4.2207c0.567,-0.571 1.32195,-0.88672 2.12695,-0.88672c0.805,0 1.56095,0.31672 2.12695,0.88672l0.88672,0.89258l0.98633,-0.99609v-5.95117c0,-0.53 -0.21094,-1.03906 -0.58594,-1.41406l-4.82812,-4.82812c-0.375,-0.375 -0.88406,-0.58594 -1.41406,-0.58594zM13,3.5l5.5,5.5h-5.5zM16,15.99609c-0.25613,0 -0.51203,0.09842 -0.70703,0.29492c-0.386,0.389 -0.386,1.0163 0,1.4043l2.29883,2.3125l-2.30274,2.29492c-0.386,0.389 -0.386,1.01434 0,1.40234c0.39,0.392 1.02506,0.392 1.41406,0l2.29102,-2.2832l2.26953,2.2832c0.389,0.393 1.02406,0.393 1.41406,0c0.386,-0.389 0.386,-1.01434 0,-1.40234l-2.27148,-2.28711l2.31445,-2.30664c0.386,-0.389 0.386,-1.0163 0,-1.4043c-0.389,-0.393 -1.02406,-0.393 -1.41406,0l-2.30469,2.29687l-2.29687,-2.31055c-0.1945,-0.1965 -0.44895,-0.29492 -0.70508,-0.29492z\"></path></g></g></svg>";

/* Unicode icons */

static const NSString *gFileAppIcon       = @"E&#x270D";
static const NSString *gFilePkgIcon       = @"F&#x1F4E6";

/* unknown file name */

static const char *gFileNameUnavilable = "[Unavailable]";
static const NSString *gFileNameUnavilableStr =
                                         @"[Unavailable]";

/* default font style of the Finder is Lucida Grande. */

static const NSString *gFontFace = @"Lucida Grande";

/* filesize abbreviations */

static const char *gFileSizeBytes     = "B";
static const char *gFileSizeKiloBytes = "K";
static const char *gFileSizeMegaBytes = "M";
static const char *gFileSizeGigaBytes = "G";
static const char *gFileSizeTeraBytes = "T";

static const char *gMacFileTypeApplication = "APPL";
static const char *gMacFileTypeSIT = "SITD";
static const char *gMacFileTypeSIT5 = "SIT5";

/* UTIs for files that may require special handling */

static const CFStringRef gUTIGZip = CFSTR("org.gnu.gnu-zip-archive");
static const CFStringRef gUTIBinHex = CFSTR("com.apple.binhex-archive");
static const CFStringRef gUTISIT1 = CFSTR("com.stuffit.archive.sit");
static const CFStringRef gUTISIT2 = CFSTR("com.allume.stuffit-archive");

/* structs */

typedef struct fileSizeSpec
{
    char spec[3];
    Float64 size;
} fileSizeSpec_t;

/* prototypes */

OSStatus GeneratePreviewForURL(void *thisInterface,
                               QLPreviewRequestRef preview,
                               CFURLRef url,
                               CFStringRef contentTypeUTI,
                               CFDictionaryRef options);
static OSStatus GeneratePreviewForHQX(void *thisInterface,
                                      QLPreviewRequestRef preview,
                                      CFURLRef url,
                                      CFStringRef contentTypeUTI,
                                      CFDictionaryRef options);
static OSStatus GeneratePreviewForSIT(void *thisInterface,
                                      QLPreviewRequestRef preview,
                                      CFURLRef url,
                                      CFStringRef contentTypeUTI,
                                      CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface,
                             QLPreviewRequestRef preview);
static off_t getGZExpandedFileSize(const char *zipFileNameStr);
static int getFileSizeSpec(off_t fileSizeInBytes,
                           fileSizeSpec_t *fileSpec);
static float getCompression(off_t uncompressedSize,
                            off_t compressedSize);
static void getPermissions(mode_t mode, char *buf);
static bool formatOutputHeader(NSMutableString *qlHtml);
static bool startOutputBody(NSMutableString *qlHtml);
static bool endOutputBody(NSMutableString *qlHtml);

#endif /* generate_preview_for_url_h */

/*
    macosroman2ascii.h - convert MacOS Roman encoded strings
                         to ascii

    History:

    v. 0.1.0 (08/01/2022) - initial release

    Based on:

    https://en.m.wikipedia.org/wiki/Mac_OS_Roman

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

#ifndef qlZipInfo_macosroman2ascii_h
#define qlZipInfo_macosroman2ascii_h

int macosroman2ascii(const char *macosromanStr,
                     int macosromanStrLen,
                     char *asciiStr,
                     int asciiStrLen);

#endif /* qlZipInfo_macosroman2ascii_h */

/*
    macosroman2ascii.c - convert MacOS Roman encoded strings
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

#include <string.h>

#include "macosroman2ascii.h"

int macosroman2ascii(const char *macosromanStr,
                     int macosromanStrLen,
                     char *asciiStr,
                     int asciiStrLen)
{
    int i = 0;
    unsigned char curChar = '\0';

    if (macosromanStr == NULL ||
        macosromanStrLen <= 0 ||
        asciiStr == NULL ||
        asciiStrLen <= 0)
    {
        return -1;
    }

    memset(asciiStr, '\0', asciiStrLen);

    for (i = 0; i < macosromanStrLen && i < asciiStrLen; i++)
    {
        curChar = (unsigned char)macosromanStr[i];

        if (curChar == '\0')
        {
            break;
        }

        if (curChar < ' ')
        {
            asciiStr[i] = '_';
            continue;
        }

        if (curChar > '~')
        {
            switch(curChar)
            {
                case 0x80:
                case 0x81:
                case 0xCB:
                case 0xCC:
                case 0XE5:
                case 0XE7:
                    asciiStr[i] = 'A';
                    break;
                case 0x82:
                    asciiStr[i] = 'C';
                    break;
                case 0x83:
                case 0xE6:
                case 0XE8:
                case 0xE9:
                    asciiStr[i] = 'E';
                    break;
                case 0x84:
                    asciiStr[i] = 'N';
                    break;
                case 0x85:
                case 0xCD:
                case 0xEE:
                case 0xEF:
                case 0xF1:
                    asciiStr[i] = 'O';
                    break;
                case 0x86:
                case 0xF2:
                case 0xF3:
                case 0xF4:
                    asciiStr[i] = 'U';
                    break;
                case 0x87:
                case 0x88:
                case 0x89:
                case 0x8A:
                case 0x8B:
                case 0x8C:
                case 0xBB:
                    asciiStr[i] = 'a';
                    break;
                case 0x8D:
                    asciiStr[i] = 'c';
                    break;
                case 0x8E:
                case 0x8F:
                case 0x90:
                case 0x91:
                    asciiStr[i] = 'e';
                    break;
                case 0x92:
                case 0x93:
                case 0x94:
                case 0x95:
                case 0xF5:
                    asciiStr[i] = 'i';
                    break;
                case 0x96:
                    asciiStr[i] = 'n';
                    break;
                case 0x97:
                case 0x98:
                case 0x99:
                case 0x9A:
                case 0x9B:
                case 0xBC:
                    asciiStr[i] = 'o';
                    break;
                case 0x9C:
                case 0x9D:
                case 0x9E:
                case 0x9F:
                case 0xB5:
                    asciiStr[i] = 'u';
                    break;
                case 0xA7:
                    asciiStr[i] = 'B';
                    break;
                case 0xB6:
                    asciiStr[i] = 'd';
                    break;
                case 0xC5:
                    asciiStr[i] = 'f';
                    break;
                case 0xD2:
                case 0xD3:
                case 0xE3:
                case 0xFD:
                    asciiStr[i] = '"';
                    break;
                case 0xAB:
                case 0xD4:
                case 0xD5:
                case 0xE2:
                    asciiStr[i] = '\'';
                    break;
                case 0xCA:
                    asciiStr[i] = ' ';
                    break;
                case 0xD0:
                case 0xD1:
                case 0xF8:
                    asciiStr[i] = '-';
                    break;
                case 0xD8:
                    asciiStr[i] = 'y';
                    break;
                case 0xD9:
                    asciiStr[i] = 'Y';
                    break;
                case 0xDA:
                    asciiStr[i] = '/';
                    break;
                case 0xDC:
                    asciiStr[i] = '<';
                    break;
                case 0xDD:
                    asciiStr[i] = '>';
                    break;
                case 0xEA:
                case 0xEB:
                case 0xEC:
                case 0xED:
                    asciiStr[i] = 'I';
                    break;
                case 0xF6:
                    asciiStr[i] = '^';
                    break;
                case 0xF7:
                    asciiStr[i] = '~';
                    break;
                case 0xE1:
                case 0xFA:
                    asciiStr[i] = '.';
                    break;
                default:
                    asciiStr[i] = '_';
                    break;
            }
            continue;
        }

        asciiStr[i] = curChar;
    }

    return 0;
}

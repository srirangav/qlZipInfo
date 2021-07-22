#!/bin/sh
#    getUTI.sh - get the Uniform Type Identifier (UTI) for a file
#
#    See: https://en.wikipedia.org/wiki/Uniform_Type_Identifier
#
#    Copyright (c) 2020-2021 Sriranga R. Veeraraghavan <ranga@calalum.org>
#
#    Permission is hereby granted, free of charge, to any person obtaining
#    a copy of this software and associated documentation files (the
#    "Software") to deal in the Software without restriction, including
#    without limitation the rights to use, copy, modify, merge, publish,
#    distribute, sublicense, and/or sell copies of the Software, and to
#    permit persons to whom the Software is furnished to do so, subject
#    to the following conditions:
# 
#    The above copyright notice and this permission notice shall be
#    included in all copies or substantial portions of the Software.
# 
#    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
#    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
#    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
#    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

MDLS="/usr/bin/mdls"

# check if at least one file was specified

if [ x"$1" = "x" ] ; then
    echo "Usage: $0 [file1] [file2] ..." >& 2
    exit 1;
fi

# check if mdls is available

if [ ! -x "$MDLS" ] ; then
    echo "ERROR: $MDLS not available" >& 2
    exit 1;
fi

for ARG in "$@" ;
do  
    if [ ! -r "$ARG" ] ; then
        echo "ERROR: $ARG is not readable / does not exist" >& 2
        continue
    fi

    # if more than one file was specified, print out the file name
    
    if [ $# -gt 1 ] ; then
            echo "--- $ARG ---"
    fi

    # print out the UTI using mdls
    
    "$MDLS" -name kMDItemContentType \
                -name kMDItemContentTypeTree \
                -name kMDItemKind "$ARG"

done

exit $?

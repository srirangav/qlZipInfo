#!/bin/sh
# getUTI.sh - get the Uniform Type Identifier (UTI) for a file
# See: https://en.wikipedia.org/wiki/Uniform_Type_Identifier

MDLS="/usr/bin/mdls"
AWK="/usr/bin/awk"

if [ x"$1" = "x" ] ; then
	echo "Usage: $0 [file1] [file2] ..." >&2
	exit 1;
fi

if [ ! -x "$MDLS" ] ; then
	echo "ERROR: $MDLS not available" >& 2
fi
for ARG in "$@" ;
do	
	if [ ! -r "$ARG" ] ; then
		echo "ERROR: $ARG is not readable / does not exist" >&2
		continue
	fi
	if [ $# -gt 1 ] ; then
		if [ -x "$AWK" ] ; then
			FNAME="`echo $ARG | $AWK -F/ '{ print $NF; }'`"
			echo "--- $FNAME ---"
		else
			echo "--- $ARG ---"
		fi
	fi
	"$MDLS" -name kMDItemContentType \
               	-name kMDItemContentTypeTree \
               	-name kMDItemKind "$ARG"
	if [ $# -gt 1 ] ; then
		echo "------------"
	fi
done

exit $?


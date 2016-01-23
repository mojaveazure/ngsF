#!/bin/bash

set -e
set -u
set -o pipefail

#   A function to display a message if we aren't on Mac OS X
function notMac() {
    echo -e "\

"
}
#   A function to download and install the GNU Scientific Library (GSL)
function installGSL() {
    #   Because we want to return a value, we need to write all standard output and error streams to /dev/null when applicable
    local NGSF_DIR="$1" # Where is ngsF?
    cd "${NGSF_DIR}" # Go to ngsF
    curl -sO ftp://ftp.gnu.org/gnu/gsl/gsl-latest.tar.gz # Get the latest version of GSL, silently
    tar -xzf gsl-latest.tar.gz # Unpack the GSL tarball, not verbosely
    rm -f gsl-latest.tar.gz # Get rid of the tarball
    LATEST=$(ls | grep gsl) # Figure out where GSL is located
    cd "${LATEST}" # Change to the GSL directory
    ./configure --prefix=$(pwd) > /dev/null 2> /dev/null # Configure GSL, setting the prefix to be the current directory
    make > /dev/null 2> /dev/null # Make GSL
    make install > /dev/null 2> /dev/null # Install GSL
    make clean > /dev/null 2> /dev/null # Clean up files from make
    make distclean > /dev/null 2> /dev/null # Clean up files from ./configure
    cd include # Go to `include'
    echo $(pwd -P) # Return the full physical path to `include'
    cd "${NGSF_DIR}" # Go back to ngsF
}

#   Flags for clang
CFLAGS='-O3 -Wall' # Specify optimization and pass arguments to linker and assembler
DFLAGS='-D_FILE_OFFSET_BITS=64 -D_LARGEFILE64_SOURCE -D_USE_KNETFILE' # Add `#define' into predefines buffer
LIBFLAGS='-lgsl -lgslcblas -lz -lpthread' # Specify libraries to be used

#   Are we using Mac OS X?
if ! [[ $(uname) == "Darwin" ]]; then notMac; fi

#   Do we already have GSL installed?
if [[ $(ls /usr/local/include | grep 'gsl') ]]
then # If so...
    INCLUDE_DIR='/usr/local/include' # The library is in /usr/local/include
else # If not...
    INCLUDE_DIR=$(installGSL $(pwd -P)) # Install it
fi

#   Export the function
export -f installGSL

#   Install ngsF
make -C bgzf bgzip # Install bgzip
clang ${CFLAGS} ${DFLAGS} -c parse_args.cpp # Compile parse_args
clang ${CFLAGS} ${DFLAGS} -L ${INCLUDE_DIR} -I ${INCLUDE_DIR} ${LIBFLAGS} -c read_data.cpp # Compile read_data
clang ${CFLAGS} ${DFLAGS} -c EM.cpp # Compile EM
clang ${CFLAGS} ${DFLAGS} -c shared.cpp # Compile shared
clang # Compile ngsF

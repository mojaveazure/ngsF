#!/bin/bash

set -e # Make sure all commands run to exit status of 0
set -u # Leave no varialbe unset
set -o pipefail # Make sure all parts for each chain of commands run

#   A function to display a message if we aren't on Mac OS X
function notMac() {
    echo -e "\
This install script is for Mac OS X only. \n\
For Linux and other UNIX-like operating systems, \n\
please use the original ngsF, located at: \n\
https://github.com/fgvieira/ngsF \n\
" >&2
    exit 1
}

#   A function to download and install the GNU Scientific Library (GSL)
function installGSL() {
    #   Because we want to return a value, we need to write all standard output and error streams to /dev/null when applicable
    set -euo pipefail # Make sure all internal commands run and that no variable is left unset
    local NGSF_DIR="$1" # Where is ngsF?
    cd "${NGSF_DIR}" # Go to ngsF
    curl -sO ftp://ftp.gnu.org/gnu/gsl/gsl-latest.tar.gz # Get the latest version of GSL, silently
    tar -xzf gsl-latest.tar.gz # Unpack the GSL tarball, not verbosely
    rm -f gsl-latest.tar.gz # Get rid of the tarball
    LATEST=$(ls | grep gsl) # Figure out where GSL is located
    cd "${LATEST}" # Change to the GSL directory
    ./configure --prefix=$(pwd) \
        CXX="g++ -arch i386 -arch x86_64 -arch ppc -arch ppc64" \
        CPP="gcc -E" CXXCPP="g++ -E" \
        > /dev/null 2> /dev/null # Configure GSL, setting the prefix to be the current directory
    make > /dev/null 2> /dev/null # Make GSL
    make install > /dev/null 2> /dev/null # Install GSL
    make clean > /dev/null 2> /dev/null # Clean up files from make
    make distclean > /dev/null 2> /dev/null # Clean up files from ./configure
    cd include # Go to `include'
    echo $(pwd -P) # Return the full physical path to `include'
    cd "${NGSF_DIR}" # Go back to ngsF
}

#   Flags for clang
CFLAGS='-O3 -Wall -stdlib=libstdc++' # Specify optimization and pass arguments to linker and assembler
DFLAGS='-D_FILE_OFFSET_BITS=64 -D_LARGEFILE64_SOURCE -D_USE_KNETFILE' # Add `#define' into predefines buffer
LIBFLAGS='-lgsl -lgslcblas -lz -lpthread' # Specify libraries to be used

#   Are we using Mac OS X?
if ! [[ $(uname) == "Darwin" ]]; then notMac; fi

#   Check for Clang and G++
if ! $(command -v clang > /dev/null 2> /dev/null) || ! $(command -v g++ > /dev/null 2> /dev/null); then echo "Failed to find Clang or G++; please install Xcode from the App Store and run it to accept user agreements and allow compalition from the command line" >&2; exit 1; fi

#   Check for zlib
if ! [[ $(ls /usr/lib/ | grep libz) ]] && ! [[ $(ls /usr/local/lib | grep libz) ]]; then echo "Failed to find zlib! Exiting..." >&2; exit 1; fi

#   Do we already have GSL installed?
if [[ $(ls /usr/local/include | grep 'gsl') ]]
then # If so...
    INCLUDE_DIR='/usr/local/include' # The library is in /usr/local/include
else # If not...
    echo "Failed to find the GNU Scientific Library, installing..." >&2
    INCLUDE_DIR=$(installGSL $(pwd -P)) # Install it
fi

#   Install ngsF
make -C bgzf bgzip # Install bgzip
clang ${CFLAGS} ${DFLAGS} -c parse_args.cpp # Compile parse_args
clang ${CFLAGS} ${DFLAGS} -I ${INCLUDE_DIR} -c read_data.cpp # Compile read_data
clang ${CFLAGS} ${DFLAGS} -c EM.cpp # Compile EM
clang ${CFLAGS} ${DFLAGS} -c shared.cpp # Compile shared
g++ ${CFLAGS} ${DFLAGS} -L ${INCLUDE_DIR/include/lib} -I ${INCLUDE_DIR} ngsF.cpp parse_args.o read_data.o EM.o shared.o bgzf/bgzf.o bgzf/knetfile.o ${LIBFLAGS} -o ngsF # Compile ngsF

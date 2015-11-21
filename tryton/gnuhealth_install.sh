#!/bin/bash

# GNU Health installer
# Version for 3.0 series

##############################################################################
#
#    GNU Health Installer
#
#    Copyright (C) 2008-2015  Luis Falcon <falcon@gnu.org>
#    Copyright (C) 2008-2015  GNU Solidario <health@gnusolidario.org>
#    Copyright (C) 2014 Bruno M. Villasanti <bvillasanti@thymbra.com>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
##############################################################################

#-----------------------------------------------------------------------------
# Variables declaration
#-----------------------------------------------------------------------------

# Colors constants
NONE="$(tput sgr0)"
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="\n$(tput setaf 3)"
BLUE="\n$(tput setaf 4)"

# Params
INSTDIR="$PWD"
GNUHEALTH_INST_DIR="$PWD"
GNUHEALTH_VERSION=$(cat version)
TRYTON_VERSION="3.8"
TRYTON_BASE_URL="http://downloads.tryton.org"


#-----------------------------------------------------------------------------
# Functions
#-----------------------------------------------------------------------------

message () {
    # $1 : Message
    # $2 : Color
    # return : Message colorized
    local NOW="[$(date +%H:%M:%S)]"

    echo -e "${2}${NOW}${1}${NONE}"
}


check_requirements() {
    # WGET command
    message "[INFO] Checking requirements" ${BLUE}
    echo -n " -> Looking for wget... "

    if ! type wget 2>/dev/null ; then
        message "[ERROR] wget command not found. Please install it or check your PATH variable" ${RED}
        bailout
    fi

    # PYTHON version [2.7.x < 3.x]
    echo -n " -> Looking for the Python Interpreter command... "

    if ! type python 2>/dev/null ; then
        message "[ERROR] Python interpreter not found. Please install it or check your PATH variable." ${RED}
        bailout
    fi

    local PVERSION=$(python -V 2>&1 | grep 2.[7-9].[0-9])

    if test "${PVERSION}" ; then
        message "[INFO] Found ${PVERSION}" ${BLUE}
    else
        python -V
        message "[ERROR] Found an Incompatible Python version." ${RED}
        bailout
    fi

    # PIP command
    echo " -> Looking for PIP command..."

    # Alternative pip names on Debian/ArchLinux/RedHat based distros:
    local PIP_NAMES="pip pip2 pip-python"
    PIP_NAME=""
    for NAME in ${PIP_NAMES}; do
        if [[ $(which ${NAME} 2>/dev/null) ]]; then
            PIP_NAME=${NAME}
            break
        fi
    done

    if [[ ! ${PIP_NAME} ]]; then
        message "[ERROR] PIP command not found. Please install it or check your PATH variable." ${RED}
        bailout
    fi

    # Check main operating system
    case "$OSTYPE" in
        freebsd*)
            message "[INFO] Running on FreeBSD" ${GREEN}
            OS="FREEBSD"
            ;;
        linux*)
            message "[INFO] Running on GNU/LINUX" ${GREEN}
            OS="GNULINUX"
            # Check for GNU/Linux Distros
            GNU_LINUX_DISTRO=$(lsb_release -i -s)
            message "[INFO] GNU / Linux distro: $GNU_LINUX_DISTRO" ${GREEN}
            ;;
        *)
            message "[INFO] Running on Other OS: $OSTYPE" ${YELLOW}
            ;;
    esac

    message "[INFO] OK." ${GREEN}
}


install_directories() {
    #
    # Temporary/staging area.
    #
    message "[INFO] Creating temporary directory..." ${YELLOW}

    # global variable
    TMP_DIR="/tmp/gnuhealth_installer"

    if [[ -e ${TMP_DIR} ]]; then
        message "[ERROR] Directory ${TMP_DIR} exists. You need to delete it." ${RED}
        bailout
    else
        mkdir ${TMP_DIR} || bailout
    fi
    message "[INFO] OK." ${GREEN}

    #
    # Create the destination directories.
    #
    message "[INFO] Creating destination directories..." ${YELLOW}

    # global variables
    BASEDIR="$HOME/gnuhealth"
    TRYTON_BASEDIR="${BASEDIR}/tryton"
    TRYTOND_DIR="${TRYTON_BASEDIR}/server"
    MODULES_DIR="${TRYTOND_DIR}/modules"
    LOG_DIR="${BASEDIR}/logs"
    ATTACH_DIR="${HOME}/attach"
    LOCAL_MODS_DIR="${MODULES_DIR}/local"
    CONFIG_DIR="${TRYTOND_DIR}/config"
    UTIL_DIR="${TRYTOND_DIR}/util"
    DOC_DIR="${BASEDIR}/doc"

    # Create GNU Health directories
    if [[ -e ${BASEDIR} ]]; then
        message "[ERROR] Directory ${BASEDIR} exists. You need to delete it." ${RED}
        bailout
    else
        mkdir -p ${MODULES_DIR} ${LOG_DIR} ${ATTACH_DIR} ${LOCAL_MODS_DIR} ${CONFIG_DIR} ${UTIL_DIR} ${DOC_DIR}||  bailout
    fi
    message "[INFO] OK." ${GREEN}
}


install_python_dependencies() {
    local PIP_CMD=$(which $PIP_NAME)
    local PIP_VERSION="$(${PIP_CMD} --version | awk '{print $2}')"

    local PIP_ARGS="install --upgrade --user"

    # Python packages
    local PIP_LXML="lxml==3.5.0"
    local PIP_RELATORIO="relatorio==0.6.1"
    local PIP_DATEUTIL="python-dateutil==2.4.2"
    local PIP_PSYCOPG2="psycopg2==2.6.1"
    local PIP_PYTZ="pytz==2015.7"
    local PIP_LDAP="python-ldap==2.4.20"
    local PIP_VOBJECT="vobject==0.8.1c"
    local PIP_PYWEBDAV="PyWebDAV==0.9.8"
    local PIP_QRCODE="qrcode==5.1"
    local PIP_SIX="six==1.10.0"
    local PIP_PILLOW="Pillow==3.0.0"
    local PIP_CALDAV="caldav==0.4.0"
    local PIP_POLIB="polib==1.0.7"
    local PIP_SQL="python-sql==0.8"
    local PIP_STDNUM="python-stdnum==1.2"
    local PIP_SIMPLEEVAL="simpleeval==0.8.7"

    # Operating System specific package selection
    # Skip PYTHON-LDAP installation since it tries to install / compile it system-wide
    
    message "[WARNING] Skipping local PYTHON-LDAP installation. Please refer to the Wikibook to install it" ${YELLOW}

    local PIP_PKGS="$PIP_PYTZ $PIP_SIX $PIP_LXML $PIP_RELATORIO $PIP_DATEUTIL $PIP_PSYCOPG2 $PIP_VOBJECT $PIP_PYWEBDAV $PIP_QRCODE $PIP_PILLOW $PIP_CALDAV $PIP_POLIB $PIP_SQL $PIP_STDNUM $PIP_SIMPLEEVAL"
    
    message "[INFO] Installing python dependencies with pip-${PIP_VERSION} ..." ${YELLOW}

    for PKG in ${PIP_PKGS}; do
        message " >> ${PKG}" ${BLUE}
        ${PIP_CMD} ${PIP_ARGS} ${PKG} || bailout
        message " >> OK" ${GREEN}
    done
}


get_url() {
    # $1 : Module name
    # return : URL to download
    echo ${TRYTON_BASE_URL}/${TRYTON_VERSION}/$(wget --quiet -O- ${TRYTON_BASE_URL}/${TRYTON_VERSION} | egrep -o "${1}-${TRYTON_VERSION}.[0-9\.]+.tar.gz" | sort -V | tail -1)
}


install_tryton_modules() {
    #
    # Get the lastest revision number for each Tryton module.
    #
    message "[INFO] Getting list of lastest Tryton packages..." ${YELLOW}

    local TRYTOND_URL=$(get_url trytond)
    local TRYTOND_FILE=$(basename ${TRYTOND_URL})

    local TRYTON_MODULES="account account_invoice account_product calendar company country currency party product stock stock_lot purchase account_invoice_stock stock_supply"

    local TRYTON_MODULES_FILE=""
    local TRYTON_MODULES_URL=""
    local AUX="" MODULE=""
    for MODULE in ${TRYTON_MODULES}
    do
        AUX=$(get_url trytond_${MODULE})
        TRYTON_MODULES_URL="${TRYTON_MODULES_URL} ${AUX}"
        TRYTON_MODULES_FILE="${TRYTON_MODULES_FILE} $(basename ${AUX})"
    done

    message "[INFO] OK." ${GREEN}

    #
    # Download Tryton packages.
    #
    message "[INFO] Changing to temporary directory." ${BLUE}
    cd ${TMP_DIR} || bailout

    message "[INFO] Downloading the Tryton server..." ${YELLOW}
    wget ${TRYTOND_URL} || bailout
    message "[INFO] OK." ${GREEN}

    message "[INFO] Downloading Tryton modules..." ${YELLOW}
    local URL=""
    for URL in ${TRYTON_MODULES_URL}; do
        wget ${URL} || bailout
    done
    message "[INFO] OK." ${GREEN}

    #
    # Uncompress the Tryton packages.
    #
    message "[INFO] Uncompressing the Tryton server..." ${YELLOW}
    cd ${TRYTOND_DIR}
    tar -xzf ${TMP_DIR}/${TRYTOND_FILE} || bailout
    message "[INFO] OK." ${GREEN}

    message "[INFO] Uncompressing the Tryton modules..." ${YELLOW}
    cd ${MODULES_DIR} || bailout
    for MODULE in $(ls ${TMP_DIR}/trytond_*); do
        tar -xzf ${MODULE} || bailout
    done
    message "[INFO] OK." ${GREEN}

    #
    # Links to modules.
    #
    message "[INFO] Changing directory to <../trytond/modules>." ${BLUE}
    local TRYTOND_FOLDER=$(basename ${TRYTOND_FILE} .tar.gz)
    cd "${TRYTOND_DIR}/${TRYTOND_FOLDER}/trytond/modules" || bailout

    message "[INFO] Linking the Tryton modules..." ${YELLOW}
    local LNMOD=""
    for LNMOD in ${TRYTON_MODULES}; do
        ln -si ${MODULES_DIR}/trytond_${LNMOD}-* ${LNMOD} || bailout
    done
    message "[INFO] OK." ${GREEN}

    message "[INFO] Copying GNU Health modules to the Tryton modules directory..." ${YELLOW}
    cp -a ${GNUHEALTH_INST_DIR}/health* ${MODULES_DIR} || bailout

    ln -si ${MODULES_DIR}/health* .

    # Copy LICENSE README and version files
    
    local EXTRA_FILES="COPYING README version"
    for FILE in ${EXTRA_FILES}; do
        cp -a ${GNUHEALTH_INST_DIR}/${FILE} ${BASEDIR} || bailout
    done

    # Copy Tryton configuration files
    
    cp ${GNUHEALTH_INST_DIR}/config/* ${CONFIG_DIR} || bailout

    # Copy serverpass
    
    cp ${GNUHEALTH_INST_DIR}/scripts/security/serverpass.py ${UTIL_DIR} || bailout

    message "[INFO] OK." ${GREEN}

    # Copy gnuhealth-control
    
    cp ${GNUHEALTH_INST_DIR}/gnuhealth-control ${UTIL_DIR} || bailout

    message "[INFO] OK." ${GREEN}

    # Copy documentation directory
    
    cp -a ${GNUHEALTH_INST_DIR}/doc/* ${DOC_DIR} || bailout

    message "[INFO] OK." ${GREEN}

}


bash_profile () {

    message "[INFO] Creating or Updating the BASH profile for GNU Health" ${BLUE}

    cd $INSTDIR

    PROFILE="$HOME/.gnuhealthrc"

    if [[ -e ${PROFILE} ]]; then
        # Make a backup copy of the GNU Health BASH profile if it exists
        message "[INFO] GNU Health BASH Profile exists. Making backup to ${PROFILE}.bak ." ${YELLOW}
        cp ${PROFILE} ${PROFILE}.bak || bailout
    fi

    cp gnuhealthrc ${PROFILE} ||  bailout

    # Load .gnuhealthrc from .bash_profile . If .bash_profile does not exist, create it.
    if [[ -e $HOME/.bash_profile ]]; then
        grep --silent "source ${PROFILE}" $HOME/.bash_profile || echo "[[ -f ${PROFILE} ]] && source ${PROFILE}" >> $HOME/.bash_profile
    else
        echo "[[ -f ${PROFILE} ]] && source ${PROFILE}" >> $HOME/.bash_profile
    fi

    # Include .gnuhealthrc in .bashrc for non-login shells
    if [[ -e $HOME/.bashrc ]]; then
        grep --silent "source ${PROFILE}" $HOME/.bashrc || echo "[[ -f ${PROFILE} ]] && source ${PROFILE}" >> $HOME/.bashrc
    else
        echo "[[ -f ${PROFILE} ]] && source ${PROFILE}" >> $HOME/.bashrc
    fi

}

serverpass () {
 
    message "[INFO] Setting up your GNU Health Tryton master server password" ${BLUE}
    source ${PROFILE}
    /usr/bin/env python ${UTIL_DIR}/serverpass.py || bailout
}
 

cleanup() {
    message "[INFO] Cleaning Up..." ${YELLOW}
    rm -rf ${TMP_DIR} || bailout

    message "[INFO] OK." ${GREEN}
}

bailout() {
    message "[INFO] Bailing out !" ${BLUE}
    message "[INFO] Cleaning up temp directories at ${TMP_DIR}" ${BLUE}
    rm -rf ${TMP_DIR}
    message "[INFO] removind base dir at ${BASEDIR}" ${BLUE}
    rm -rf ${BASEDIR}
 
    exit 1
}
    
#-----------------------------------------------------------------------------
# Main
#-----------------------------------------------------------------------------

main() {
    message "[INFO] Starting GNU Health ${GNUHEALTH_VERSION} installation..." ${BLUE}

    # (1) Check requirements.
    check_requirements

    # (2) Install directories.
    install_directories

    # (3) Install Python dependencies.
    install_python_dependencies

    # (4) Download Tryton modules.
    install_tryton_modules

    # (5) BASH Profile
    bash_profile

    # (5) Server Password
    serverpass
    
    # (7) Clean
    cleanup

    message "[INFO] Installed successfully in ${BASEDIR}." ${BLUE}
}


main "$@"


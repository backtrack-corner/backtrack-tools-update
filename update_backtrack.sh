#!/bin/sh
#
# System update script for BT
# by Fabio "dr4kk4r" Busico & Armando "armax00" Miraglia
# v0.4.0
#
#
# Copyright (c) 2011,  Fabio "dr4kk4r" Busico & Armando "armax00" Miraglia
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the <organization> nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY dr4kk4r & armax00 ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL dr4kk4r & armax00 BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

############
# Includes #
############
. /lib/lsb/init-functions

#############
# Constants #
#############
TMP_FILE_STDOUT=`mktemp`
TMP_FILE_STDERR=`mktemp`
VERSION="0.4.0"

###########
# Globals #
###########
# Log Levels
INFO=1
WARN=2
ERROR=3

# Options
SILENT=0
STOP_ON_ERROR=0

# Status
SUCCESS_WITH_ERRORS=0

#############
# Utilities #
#############
version() {
  echo "$0 v$VERSION"
}
usage() {
 echo "usage: $0 -l file.log [-e] [-s]"
 echo "this script updates the system and several tools."
 echo "OPTIONS:"
 echo "  -e           if set, the script will STOP on errors."
 echo "  -l   LOGFILE log the messages of the script into $LOGFILE (mandatory)."
 echo "  -s           no output will be produced by the script."
 echo "  -u           update SQLMap using svn (development version only)"
 echo "  -h           show this message."
 echo "  -v           prints the script version."
}

must_be_root() {
  echo "error: you must be root to run this script"
}

options_mandatory() {
  echo "error: -l is mandatory"
}

# $1 level of the logging message
# $2 message to be logged
log_to_file() {
  # logging to standard output
  DECORATOR=
  TIME=`date +"%d/%m/%Y %H:%M:%S"`

  if [ $1 -eq $INFO ]; then
    DECORATOR="[INFO] "
  elif [ $1 -eq $WARN ]; then
    DECORATOR="[WARN] "
  elif [ $1 -eq $ERROR ]; then
    DECORATOR="[ERROR] "
  fi

  echo "$2" | while read line; do
    # hard fixed cause of sqlmap update log message
    echo "$DECORATOR $TIME `echo $line | sed -e"s/^.*\(\[INFO\]\|\[CRITICAL\]\|\[WARNING\]\)//"`" >> $LOGGING_FILE
  done
}

exec_command() {
  $1 1> $TMP_FILE_STDOUT 2> $TMP_FILE_STDERR
  RESULT=$?

  # Log the messages
  if [ -s $TMP_FILE_STDOUT ]; then
    log_to_file $INFO "`cat $TMP_FILE_STDOUT`"
  fi

  if [ $RESULT -ne 0 ]; then
    if [ -s $TMP_FILE_STDERR ]; then
      log_to_file $ERROR "`cat $TMP_FILE_STDERR`"
    fi
  else
    if [ -s $TMP_FILE_STDERR ]; then
      log_to_file $WARN "`cat $TMP_FILE_STDERR`"
      SUCCESS_WITH_ERRORS=1
    fi
  fi

  # Clean the temporary files
  rm $TMP_FILE_STDOUT
  rm $TMP_FILE_STDERR

  # If an error was encountered and the user requested such a behavior,
  # stop the script execution
  if [ $RESULT -ne 0 -a $STOP_ON_ERROR -eq 1 ]; then
    log_to_file $ERROR "$1 caused an error."
    log_to_file $ERROR "Stopping the execution."
    if [ $SILENT -e 1 ]; then
      log_failure_msg "$1 caused an error."
    fi
    exit 1
  fi

  return $RESULT
}

########
# MAIN #
########

# Parse parameters
while getopts "ehl:sv" OPTION
do
  case $OPTION in
    e)
      STOP_ON_ERROR=1
      ;;
    h)
      usage
      exit 1
      ;;
    l)
      LOGGING_FILE=$OPTARG
      ;;
    s)
      SILENT=1
      ;;
    v)
      version
      exit 0
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done

# Check user permission
if [ $EUID -ne 0 ]; then
   must_be_root
   exit 1
fi

# Check for mandatory options
if [ -z "$LOGGING_FILE" ]; then
   options_mandatory "-l"
   usage
   exit 1
fi

if [ $SILENT -eq 0 ]; then
  log_daemon_msg "Starting upgrade script"
fi

##################
# Upgrade System #
##################
MSG="upgrading the system"
ENDMSG="finished $MSG"
if [ $SILENT -eq 0 ]; then log_action_begin_msg $MSG; fi

log_to_file $INFO $MSG
exec_command "apt-get update -q -y"
FIRST_RES=$?
exec_command "apt-get dist-upgrade -q -y"
SECOND_RES=$?
log_to_file $INFO $ENDMSG

if [ $SILENT -eq 0 ]; then log_action_end_msg $((FIRST_RES + SECOND_RES)); fi
 
###########################
# Upgrade Tools /pentest/ #
###########################
MSG="upgrading pentest"
ENDMSG="finished $MSG"
if [ $SILENT -eq 0 ]; then log_action_begin_msg $MSG; fi

log_to_file $INFO "Remove pentest lock"
exec_command "find /pentest/ -name lock -exec rm -f {} ;"
FIRST_RES=$?
log_to_file $INFO "Upgrade pentest tools"
exec_command "find /pentest/ -maxdepth 5 -type d -name \".svn\"  \
                            -not -path \"/pentest/database/sqlmap/*\" \
                            -not -path \"/pentest/telephony/warvox/*\" \
                            -not -path \"/pentest/wireless/aircrack-ng/*\" \
                            -not -path \"/pentest/exploits/exploitdb/*\" \
                            -ls -exec svn update {}/.. ;"
SECOND_RES=$?
log_to_file $INFO $ENDMSG

if [ $SILENT -eq 0 ]; then log_action_end_msg $((FIRST_RES + SECOND_RES)); fi

 
##################
# Upgrade Sqlmap #
##################
MSG="upgrading sqlmap"
ENDMSG="finished $MSG"
if [ $SILENT -eq 0 ]; then log_action_begin_msg $MSG; fi

log_to_file $INFO $MSG
exec_command "/pentest/database/sqlmap/sqlmap.py --update"
RES=$?
log_to_file $INFO $ENDMSG

if [ $SILENT -eq 0 ]; then log_action_end_msg $RES; fi
 
############################
# Upgrade del DB exploitdb #
############################
#MSG="upgrading ExploitDB"
#ENDMSG="finished $MSG"
#if [ $SILENT -eq 0 ]; then log_action_begin_msg $MSG; fi
#
#log_to_file $INFO $MSG
#exec_command "wget --no-verbose -c http://www.exploit-db.com/archive.tar.bz2 -P /pentest/exploits/exploitdb/"
#FIRST_RES=$?
#exec_command "tar -mxjf /pentest/exploits/exploitdb/archive.tar.bz2 -C /pentest/exploits/exploitdb/"
#SECOND_RES=$?
#exec_command "rm -rf /pentest/exploits/exploitdb/archive.tar.bz2"
#THIRD_RES=$?
#log_to_file $INFO $ENDMSG
#
#if [ $SILENT -eq 0 ]; then
#  log_action_end_msg $((FIRST_RES + SECOND_RES + THIRD_RES))
#fi

#################################
# Upgrade nessus-update-plugins #
#################################
MSG="upgrading Nessus Plugins"
ENDMSG="finished $MSG"
if [ $SILENT -eq 0 ]; then log_action_begin_msg $MSG; fi

log_to_file $INFO $MSG
exec_command "/opt/nessus/sbin/nessus-update-plugins"
RES=$?
log_to_file $INFO $ENDMSG
 
if [ $SILENT -eq 0 ]; then log_action_end_msg $RES; fi

###############
# Upgrade MSF #
###############
MSG="upgrading Metasploit"
ENDMSG="finished $MSG"
if [ $SILENT -eq 0 ]; then log_action_begin_msg $MSG; fi

log_to_file $INFO $MSG
exec_command "/opt/metasploit/msf3/msfupdate"
RES=$?
log_to_file $INFO $ENDMSG

if [ $SILENT -eq 0 ]; then log_action_end_msg $RES; fi
 
#####################################
# Upgrade nmap-update set user pass #
#####################################
MSG="upgrading NMap Plugins"
ENDMSG="finished $MSG"
if [ $SILENT -eq 0 ]; then log_action_begin_msg $MSG; fi

log_to_file $INFO $MSG
exec_command "svn co --force https://svn.nmap.org/nmap/scripts/ /usr/local/share/nmap/scripts"
RES=$?
log_to_file $INFO $ENDMSG

if [ $SILENT -eq 0 ]; then log_action_end_msg $RES; fi
 
##################################
# Upgrade airodump-ng-oui-update #
##################################
MSG="upgrading AiroDump NG Plugins"
ENDMSG="finished $MSG"
if [ $SILENT -eq 0 ]; then log_action_begin_msg $MSG; fi

log_to_file $INFO "Upgrade Airodump-NG"
exec_command "chmod a+x /pentest/wireless/aircrack-ng/scripts/airodump-ng-oui-update"
FIRST_RES=$?
exec_command "/pentest/wireless/aircrack-ng/scripts/airodump-ng-oui-update"
SECOND_RES=$?
log_to_file $INFO "Upgrade Airodump-NG finished"

if [ $SILENT -eq 0 ]; then log_action_end_msg $((FIRST_RES + SECOND_RES)); fi

################################
# Completing the script output #
################################
if [ $SILENT -eq 0 ]; then
  if [ $SUCCESS_WITH_ERRORS -eq 1 ]; then
    log_warning_msg "The upgrade finished with some problems."
  else
    log_success_msg "The upgrade finished successfully."
  fi
fi

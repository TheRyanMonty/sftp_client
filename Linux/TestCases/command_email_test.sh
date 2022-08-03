#!/bin/bash
################################################################################
##
##      command_email_test.sh
##
################################################################################

source ../funcs/command_email.func

EmailCheckTest () {
    EmailCheck
    if [ "$?" != "0" ]; then
        echo "EmailCheck Function Failed"
        return 1
    fi 
}

#EmailFileTest () {
#    Validate no error is thrown for null values for arguments
#    Validate emails send of reasonable size (up to 10MB)
#    Validate error is thrown for nonsensical use of arguments (i.e. blatherskite for email address, file isn't a file, subject is a string)
#}

echo "Test Completed Successfully"
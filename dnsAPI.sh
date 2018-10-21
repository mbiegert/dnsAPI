#!/bin/bash

# This script is used to make requests to the hosttech DNS API with
# authentication credentials already built in.

set -euo pipefail

# this method looks for an error in the response and if
# it finds something prints it to the screen
# expects the xml to check as first parameter
check_for_error () {
    if grep -q "<SOAP-ENV:Fault>" <<< $1; then
        code=$(grep -oP '(?<=<faultcode>).*(?=</faultcode>)' <<< $1)
        message=$(grep -oP '(?<=<faultstring>).*(?=</faultstring>)' <<< $1)

        echo "An error was returned by the hosttech API endpoint." 1>&2
        echo "Code: $code" 1>&2
        echo "Message: $message" 1>&2
        return 1
    fi
}

# this function authenticates and returns a
# header which is to be used with every request
get_auth_cookie() {
    # read credentials
    if [ ! -f "credentials.sh" ]; then
        echo "Could not find credentials file." 1>&2
        echo "Please make sure there is a file \"credentials.sh\" "\
            "in the current working directory providing the "\
            "variables \$username and \$password." 1>&2
        echo "Exiting..." 1>&2
        exit
    fi
    . ./credentials.sh
    if [ -z "${username+set}" -o -z "${password+set}" ]; then
        echo "\$username or \$password not found. Exiting..." 1>&2
        exit
    fi

    # load the authenticate request
    if [ ! -f "xml/authenticate.xml" ]; then
        echo "Cannot find xml/authenticate.xml" 1>&2
        echo "Exiting..." 1>&2
        exit
    fi
    # fill in username and password
    REQ=$(<"./xml/authenticate.xml")
    REQ=${REQ/"WELLKNOWNUSERNAME"/$username}
    REQ=${REQ/"WELLKNOWNPASSWORD"/$password}

    # call the hosttech endpoint to authenticate
    RESPONSE=$(curl \
        --silent \
        --request POST \
        --header "Content-Type: text/xml;charset=UTF-8" \
        --header "SOAPAction: \"https://ns1.hosttech.eu/soap#authenticate\"" \
        --data "$REQ" \
        "https://ns1.hosttech.eu/soap")

    # RESPONSE="<SOAP-ENV:Envelope SOAP-ENV:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:ns1=\"https://ns1.hosttech.eu/soap\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\">
    # <SOAP-ENV:Body>
    #     <ns1:authenticateResponse>
    #         <return xsi:type=\"xsd:string\">81mscqilum5uep3ri2p6o80e76</return>
    #     </ns1:authenticateResponse>
    # </SOAP-ENV:Body>
    # </SOAP-ENV:Envelope>"

    if ! check_for_error "$RESPONSE"; then
        # information printing is already done by the check_for_error function
        # an auth error is FATAL
        echo "Exiting..." 1>&2
        exit
    fi

    # extract
    TMP=$(echo $RESPONSE | grep -oP '(?<=<return xsi:type="xsd:string">).*(?=</return>)')
    AUTH_HEADER="Cookie: PHPSESSID=$TMP"
}

# this takes the action as parameter one and a variable containing the
# xml as second parameter
api_call() {
    if [ -z "${AUTH_HEADER+set}" ]; then
        echo "No \$AUTH_HEADER not set. Please authenticate first." 1>&2
        echo "Exiting..." 1>&2
        exit
    fi
    if [ $# -ne 2 ]; then
        echo "Wrong argument count to api_call: $#. Expected: 2" 1>&2
        echo "Exiting..." 1>&2
        exit
    fi
    RESPONSE=$(curl \
        --silent \
        --request POST \
        --header "$AUTH_HEADER" \
        --header "Content-Type: text/xml;charset=UTF-8" \
        --header "SOAPAction: \"https://ns1.hosttech.eu/soap#$1\"" \
        --data "$2" \
        "https://ns1.hosttech.eu/soap")
}

# this function requires $AUTH_HEADER to be set and the following parameters
# first: <recordName> - there must be a file update<recordName> in the xml directory
# depending on the record to be updated an IPv4 or IPv6 address or both
updateRecord() {
    if [ -z "${1+set}" ]; then
        echo "No record to update specified. Exiting." 1>&2
        exit
    fi
    printf "Updating $1.mbiegert.ch..."
    
    FILE="xml/update$1.xml"
    shift
    if [ ! -f $FILE ]; then
        echo "Cannot find $FILE. Exiting." 1>&2
        exit
    fi
    REQ=$(<$FILE)

    # replace WELLKNOWNIP1 (and maybe WELLKNOWNIP2)
    while grep -Fq "WELLKNOWN" <<< $REQ
    do
        if [ -z "${1+set}" ]; then
            echo "Too few arguments to updateRecord. Exiting." 1>&2
            exit
        fi
        REQ=${REQ/"WELLKNOWNIP1"/$1}
        shift
    done

    # For safety test if there are arguments left
    if [ -n "${1+set}" ]; then
        echo "Too many arguments to updateRecord. Exiting." 1>&2
        exit
    fi

    # use the generated xml to call the API
    api_call "updateRecords" "$REQ"

    if ! check_for_error "$RESPONSE" || ! grep -q "<return xsi:type=\"xsd:boolean\">true</return>" <<< "$RESPONSE"; then
        echo "Error while calling updateRecords"
        echo "Exiting..." 1>&2
        exit
    fi
    echo " Success"
}

help () {
    echo "I need to build a help function."
}
# after this we have a variable $AUTH_HEADER
get_auth_cookie

# display a help message if there are no arguments
if [ $# -eq 0 ]; then
    help
    exit
fi

# parse options
while true; do
    if [ -z "${1+set}" ]; then
        break;
    fi

    case "$1" in
        # requests
        --updateRecord)
            if [[ -z "${2+set}" || $2 == --* || -z "${3+set}" || $3 == --* ]]; then
                help
                echo "Wrong argument count to --updateRecord."
                exit;
            fi
            if [[ -z "${4+set}" || $4 == --* ]]; then
                updateRecord "$2" "$3"
                shift; shift; shift;
            else
                updateRecord "$2" "$3" "$4"
                shift; shift; shift; shift;
            fi
        ;;
        --help)
            help
            exit;;
        *)
            help
            exit;;
    esac
done

#updateRecord google 1.2.3.5
#api_call 12

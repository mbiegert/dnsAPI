# dnsAPI
This is a shell implementation of parts of the DNS API provided by hosttech.ch (https://ns1.hosttech.eu/wsdl)

## Usage
First rename the file `template.credentials.sh` to `credentials.sh` and adjust the variables to your needs.   
Then you can simply call the script with some action. Every action needs to have a reqeusts file in the xml directory.
See the [xml](xml) directory for information what parameters are required by each action. The following actions are supported:
  - ###### `--updateRecord <recordname> <IP1> [IP2]`
    The record you are trying to update must have a corresponding xml request in the xml directory
    (`xml/update<recordname>`)


### Notes
Some notes about the funcionality and some variables I tend to forget.   
Authentication:
  - first call the authenticate method with username and password, this returns a
    string element which is to be used as a session id.
  - use this string as an additional header:
    `Cookie: PHPSESSID=<string>`

zone id of mbiegert.ch: 184727   
zone id of test.mbiegert2.ch: 203278

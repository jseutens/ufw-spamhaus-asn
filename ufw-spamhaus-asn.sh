#!/usr/bin/env bash

# based off the following script
# https://github.com/cowgill/spamhaus
# https://github.com/dajul/ufw-spamhaus
# https://joshtronic.com/2015/09/06/error-invalid-position-1/

# path to UFW
UFW="/usr/sbin/ufw";
CURL=""
# copy all below this line to combine the script with https://github.com/dajul/ufw-spamhaus
# not recommended , the ASN list is not changing that much  , personally i only run this 1 time a month
# the ufw-spamhaus I personally run once a day
#ASNTRANSLATOR="https://api.hackertarget.com/aslookup/"
# hackertarget need an paid API key if you want to do a lot of ASN queries.
# I leave this in as a referense , possibly the script need changes for hackertarget
ASNTRANSLATOR="https://www.enjen.net/asn-blocklist/index.php?type=iplist&api=1&asn="
# list of known spammers ASN
URL4="https://www.spamhaus.org/drop/asndrop.txt";
# save local copy here
FILE4="/tmp/asndrop.lasso";
# old ASN list 
COMBINEDASN="/tmp/asndrop.combined"
# old ip ASN list (without the number)
COMBINEDASNIP="/tmp/asndropip.combined"
# all IPS , if exists remove these IP from UFW
COMBINEDIPALL="/tmp/asndropipall.txt"
# list for adding the IPV4 ips
COMBINEDIPV4="/tmp/asndropipv4.txt"
# list for adding the IPV6 ips
COMBINEDIPV6="/tmp/asndropipv6.txt"
# get a copy of the spam lists ASN
wget -qc $URL4 -O $FILE4
if [ $? -ne 0 ]; then
    exit 1
fi
# combine files and filter ASN numbers out of it
cat $FILE4 | egrep -v '^;' | awk '{ print $1}' > $COMBINEDASN

# remove the ASN list
unlink $FILE4

# remove all old entries out of UFW
#ipv6 and ipv4 can be in same list the delete command is the same for both
    if [ -f $COMBINEDIPALL ]; then
     for IP in $( cat $COMBINEDIPALL); do
      $UFW delete deny from $IP to any
     done
    fi

# list all ips in a ASN
if [ -f $COMBINEDASN ]; then
for ASN in $( cat $COMBINEDASN ); do
# read the ASN IP list
  # get the new ip list from the ASN
  IPLISTINGASN=$COMBINEDASNIP$ASN
  wget -qc $ASNTRANSLATOR$ASN  -O "$IPLISTINGASN"
done
fi

# merge all ASN list into 1 big list
cat "$COMBINEDASNIP*" > $COMBINEDIPALL

# remove all asn ip lists
unlink "$COMBINEDASNIP*"

# split the list in a ipv4 list and a ipv6 list
  for IP in $( cat $COMBINEDIPALL); do
  # check for ip4 or ip6  (very unclean way , only check for colon , trust enjen lists to have correct writing)
      if [[ $IP =~ .*:.* ]]
      then
        echo $IP >> $COMBINEDIPV6
       else
        echo $IP >> $COMBINEDIPV4
      fi
  done

#insert ipv4 IP
for IP in $( cat $COMBINEDIPV4 ); do
    $UFW insert 1 deny from $IP to any
done

#insert ipv6 IP
for IP in $( cat $COMBINEDIPV6); do
    v6ruleid=$(sudo ufw status numbered | grep "(v6)" | grep -o "\\[[0-9]*\\]" | grep -o "[0-9]*" | head -n 1)
    $UFW insert $v6ruleid deny from $IP to any
done

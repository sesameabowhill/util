#!/usr/bin/python
# $Id:$
# Cribbed from http://github.com/Constellation/crxmake/blob/master/lib/crxmake.rb
# and http://src.chromium.org/viewvc/chrome/trunk/src/chrome/tools/extensions/chromium_extension.py?revision=14872&content-type=text/plain&pathrev=14872

import sys
from array import *
from subprocess import *

arg0,input,key,output = sys.argv

# Sign the zip file with the private key in PEM format
signature = Popen(["openssl", "sha1", "-sign", key, input], stdout=PIPE).stdout.read();

# Convert the PEM key to DER (and extract the public form) for inclusion in the CRX header
derkey = Popen(["openssl", "rsa", "-pubout", "-inform", "PEM", "-outform", "DER", "-in", key], stdout=PIPE).stdout.read();

out=open(output, "wb");
out.write("Cr24")  # Extension file magic number
header = array("l");
header.append(2); # Version 2
header.append(len(derkey));
header.append(len(signature));
header.tofile(out);
out.write(derkey);
out.write(signature);
#zip_content = open(input, "rb").read();
#print len(zip_content)
#out.write(zip_content);
out.write(open(input, "rb").read());
bytes_out = out.tell();

print "save [%s] size [%d] bytes" % (output, bytes_out);
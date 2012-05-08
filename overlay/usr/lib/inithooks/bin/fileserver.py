#!/usr/bin/python
"""Set fileserver (eXtplorer) admin and guest password

Option:
    --pass=     unless provided, will ask interactively

"""

import re
import sys
import getopt
import hashlib

from dialog_wrapper import Dialog

def usage(s=None):
    if s:
        print >> sys.stderr, "Error:", s
    print >> sys.stderr, "Syntax: %s [options]" % sys.argv[0]
    print >> sys.stderr, __doc__
    sys.exit(1)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h", ['help', 'pass=',])
    except getopt.GetoptError, e:
        usage(e)

    password = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val

    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')
        password = d.get_password(
            "eXtplorer Password",
            "Enter password for the eXtplorer 'admin/guest' accounts.")
 
    hashpass = hashlib.md5(password).hexdigest()

    new = []
    htusers = "/var/www/extplorer/config/.htusers.php"
    for s in file(htusers).readlines():
        s = s.rstrip()
        s = re.sub("\"admin\",\"([a-z0-9]*)\"", "\"admin\",\"%s\"" % hashpass, s)
        s = re.sub("\"guest\",\"([a-z0-9]*)\"", "\"guest\",\"%s\"" % hashpass, s)
        new.append(s)

    fh = file(htusers, "w")
    print >> fh, "\n".join(new)
    fh.close()


if __name__ == "__main__":
    main()


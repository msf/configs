#!/usr/bin/env python
# stolen shamelessly from http://github.com/htr/dotfiles/blob/master/install.py

from glob import glob
import os
import shutil

config_files = glob('*')
config_files.extend( glob('.*') )
config_files.remove('install.py') #or should I use __file__ ?
config_files.remove('README')
config_files.remove('.git')

HOME = os.path.expanduser('~/')
CWD = os.path.abspath('.') + '/'

for file in config_files:
    destfile = HOME + file
    if os.path.exists(destfile):
        if os.path.islink(destfile):
            os.unlink(destfile)
        elif os.path.isdir(destfile):
            shutil.rmtree(destfile,True,True)
        else:
            os.remove(destfile)
    sourcefile = CWD + file
    os.symlink(sourcefile,destfile)
    print file,"installed"

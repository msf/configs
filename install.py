#!/usr/bin/env python

from glob import glob
import os
import shutil

HOME = os.path.expanduser('~/')
CWD = os.path.abspath('.') + '/'


def copyFiles():
    config_files = glob('*')
    config_files.extend( glob('.*') )
    dont_symlink = [
        'install.py', #or should I use __file__ ?
        'README',
        '.git',
        'awesome',
        ]
    dont_symlink.extend( glob('.*swp') ) # temp edit files

    for f in dont_symlink:
        config_files.remove(f)

    for file in config_files:
        destfile = HOME + file
        sourcefile = CWD + file
        if os.path.exists(destfile):
            removePath(destfile)
        try:
            os.symlink(sourcefile,destfile)
            print("symlinked %s" % file)
        except OSError:
            print("failed on %s -> %s" % (sourcefile, destfile))

def removePath(destfile):
    # REMOVE if dest exists
    if os.path.islink(destfile):
        os.unlink(destfile)
    elif os.path.isdir(destfile):
        shutil.rmtree(destfile,True,True)
    else:
        os.remove(destfile)

def copyConfigDirs():
    ''' into .config directory stuff '''
    configdirs = [ 'awesome'
        ,
        ]

    destdir = HOME + ".config/"
    if not os.path.exists(destdir):
        os.mkdir(destdir)

    for di in configdirs :
        destpath = destdir + di
        if os.path.exists(destpath):
            removePath(destpath)
        os.symlink( CWD + di, destpath )
        print("symlinked directory %s" % destpath)

copyFiles()
copyConfigDirs()

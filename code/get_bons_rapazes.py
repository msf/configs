#!/usr/bin/env python

import urllib
import sys
import re
import subprocess
import os.path
import time


MPLAYER_CMD = "mplayer -dumpstream -dumpfile";
BONS_RAPAZES_HP = "http://ww1.rtp.pt/icmblogs/rtp/bonsrapazes/"

MMS_URL_RE = re.compile("(mms://.+\.wma)+", re.IGNORECASE | re.UNICODE)
def grep_podcasts(page_source):
    ''' Search in the page_source for the streaming podcast URL '''

    url_list = MMS_URL_RE.findall(page_source)
    return url_list

def fetch_page(url):
    ''' Fetch a url and return the data '''
    return urllib.urlopen(url).read()

def pull_podcasts( url_list, stdout='/dev/null'):
    ''' use popen + mplayer to download the podcast streams. '''

    tmp_args = MPLAYER_CMD.split()
    cmd_list = []
    for url in url_list:
        fname = "bonsrapazes_" + url.split('-')[1]
        if os.path.exists(fname):
            print("%s already exists, skipping.." % (fname))
            continue
        args = []
        args.extend(tmp_args)
        args.append(fname)
        args.append(url)
        proc = subprocess.Popen(args, stdout=stdout, stderr=stdout)
        print("Pid: %d - %r" % ( proc.pid, " ".join(args) ))
        cmd_list.append(proc)

    return cmd_list


def wait_for_completion( ps_list ):
    ''' Wait for all workers to finish '''
    total = len(ps_list)
    print("Waiting for: %d workers" % ( total ))
    running = total
    while( running > 0):
        time.sleep(10)
        print("%d." %(running))
        for p in ps_list:
            if p.poll():
                print("Pid: %d finished with status: %d" % (p.pid, p.returncode) )
                running -= 1
    print("All finished")

def find_morepage_urls(basepage):
    ''' Search in base page for more urls with podcasts.
    '''
    return []


def get_bons_rapazes(homepage_url):

    hpage = fetch_page(homepage_url)
    pods = grep_podcasts(hpage)

    for page_url in find_morepage_urls(hpage):
        data = fetch_page(page_url)
        pods.extends( grep_podcasts(data) )

    dev_null = open('/dev/null', 'w')
    running = pull_podcasts(pods, stdout=dev_null)

    wait_for_completion(running)



try:
    get_bons_rapazes(BONS_RAPAZES_HP)
except KeyboardInterrupt, ki:
    pass



#!/usr/bin/env python

import urlopen
import sys


MPLAYER_CMD = "mplayer -dumpstream -dumpfile";

def fetch_page(url):
    ''' Fetch a url and return the data '''
    pass

def grep_podcasts(page_source):
    ''' Search in the page_source for the streaming podcast URL '''
    pass

def pull_podcasts( url_list):
    ''' use popen + mplayer to download the podcast streams. '''
    pass

def find_morepage_urls(basepage):
    ''' Search in base page for more urls with podcasts.
    '''
    pass


def get_bons_rapazes(homepage_url):

    hpage = fetch_page(homepage_url)
    pods = grep_podcasts(hpage)

    for page_url in find_morepage_urls(hpage):
        data = fetch_page(page_url)
        pods.extends( grep_podcasts(data) )

    pull_podcasts(pods)




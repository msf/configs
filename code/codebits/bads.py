#!/usr/bin/env python

import binascii
import bitstring

s = open('bitstring','r').read().strip("\n")

bstr = bitstring.BitString('0b'+s)

bis = binascii.unhexlify(b.hex[2:])


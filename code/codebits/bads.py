#!/usr/bin/env python

import binascii
import bitstring
from Crypto.Cipher import AES,Blowfish,DES3,DES

s = open('longstring.txt','r').read().strip("\n")
frase = 'A long long long long string ago'
frase2= 'A long long time ago in a galaxy'

out = open('longstring.bin', 'wb')

bstr = bitstring.BitString(bin=s)
cstr = bitstring.BitString()
dstr = bitstring.BitString()

bstr.tofile(out)

stop = len(bstr)/8.0

dist = {}
i = 0
l = ''
s = ''
full = ''
while (i < stop ):
	num = chr(bstr[i:i+1:8].uint)
	dist[num] = dist.setdefault(num, 0) + 1
	i += 1
	l += num
	if len(l) == 78:
		s += l + "\n"
		full += l
		l = ''

for w,c in dist.iteritems():
	print(" %r: %r" % (w, c) )

print "\n\n\n"
print s
print "\n\n\n"

aes1 = AES.new(frase)
aes2 = AES.new(frase2)
blow1 = Blowfish.new(frase)
blow2 = Blowfish.new(frase2)

for i in (aes1, aes2, blow1, blow2):
	print "\n\n\n"
	i.decrypt(full)
	print "\n\n\n"

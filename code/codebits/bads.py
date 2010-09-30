#!/usr/bin/env python

import binascii
import bitstring
import array
import heapq

s = open('longstring.txt','r').read().strip("\n")

out = open('longstring.bin', 'wb')

bstr = bitstring.BitString(bin=s)
bstr.tofile(out)

stop = len(bstr)/8.0

dist = {}
i = 0
l = ''
s = ''
full = ''
byte_array = []
qwin = ''
s4 = [[]]*4
s32 =[[]]*32
s64 =[[]]*64
while (i < stop ):
	num = bstr[i:i+1:8].uint
	s4[ i % 4 ].append(num)
	s32[ i % 32 ].append(num)
	s64[ i % 64 ].append(num)
	dist[num] = dist.setdefault(num, 0) + 1
	i += 1
	l += chr(num)
	byte_array.append(num)
	if num >= 128: qnum = num - 128
	else: qnum = num
	qwin += chr(qnum)



def write_sets_step( sets, step ):
	f = open('freq_set%d.csv'% (step), 'w')
	lst = range(step)
	header = ', '.join( [ str(i) for i in lst] ) + "\n"
	f.write(header)
	for i in xrange( len(sets[0]) ):
		tmp = []
		for row in sets:
			tmp.append(row[i])
		line = ', '.join( [ str(j) for j in tmp ]) + "\n"
		f.write(line)
	f.close()

write_sets_step( s4, 4)
write_sets_step( s32, 32)
write_sets_step( s64, 64)

qwind = {}
for i in qwin:
	qwind[i] = qwind.setdefault(i, 0) + 1

distr = open('freq_qw1.txt', 'w')
top5 = [(0,'')]*5
low5 = [(0,'')]*5
heapq.heapify(top5)
heapq.heapify(low5)
for w,c in qwind.iteritems():
	if c > top5[0][0]:
		heapq.heapreplace(top5, (c, w))
	if -c > low5[0][0]:
		heapq.heapreplace(low5, (-c, w))
	distr.write(" %r, %r, %.5f\n" % (ord(w), c, c/float(len(qwin))) )



distr = open('freq_words.txt', 'w')
heap =  []
for w,c in dist.iteritems():
	heapq.heappush(heap, (c, w))
	distr.write(" %r, %r\n" % (w, c) )

print "\n\n"
print qwin
print "\n\n"
print "top 5 letters: \n"
print top5
print "low 5 letters: \n"
print low5
print "\n\n"
#print s

#qwin = qwin.replace('X',' ')
#qwin = qwin.replace('Y','e')
#qwin = qwin.replace('Q','t')
#qwin = qwin.replace('J','a')

wrd3 = {}
cnt = 0
for i in qwin:
	wrd = qwin[cnt:cnt+2]
	wrd3[wrd] = wrd3.setdefault(wrd, 0) + 1
	cnt +=1

best5 = [(0,'')]*5
heapq.heapify(best5)
for wrd, cnt in wrd3.iteritems():
	if cnt > best5[0][0]:
		heapq.heapreplace(best5, (cnt, wrd))

print "top 5 2letter sequences:"
print best5
print "\n\n"




# in R:
# xpto <- read.csv(file='freq_words.txt', header=F)
# plot(xpto$V1,xpto$V2, type='h')
# its a 4poli-alphabetic 32char-key cipher...
# we gotta find the frequency of each byte in the stream.
keys=[{}] * 8 # 4 keys and 4 sets of nounces..

#freqs in english:
en_freqs = {'a': 8.17, 'c': 2.78, 'b': 1.49, 'e': 12.70, 'd': 4.25, 'g': 2.02, 'f': 2.23, 'i': 6.97, 'h': 6.09, 'k': 0.77, 'j': 0.15, 'm': 2.41, 'l': 4.03, 'o': 7.51, 'n': 6.75, 'q': 0.10, 'p': 1.93, 's': 6.33, 'r': 5.99, 'u': 2.76, 't': 9.06, 'w': 2.36, 'v': 0.98, 'y': 1.97, 'x': 0.15, 'z': 0.07}

# split in 4 keys/dicts according to the range of num (0-64,
while heap:
	(cnt, num) = heapq.heappop(heap)
	keys[ num / 32 ][cnt] = (num, str(cnt/float(stop)) )

#print keys[0]
#for i in xrange(32):
#	print("%r: 1:%r, 2:%r, 3:%r, 4:%r" %
#		( keys[0][i], keys[2][i], keys[4][i], keys[6][i]) )






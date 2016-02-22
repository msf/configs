#!/usr/bin/env python
import sys

numbs = []
sumi = 0
with open(sys.argv[1]) as f:
	for line in f:
		try:
			val = float(line)
			numbs.append(val)
			sumi += val
		except Exception, e:
			pass

numbs.sort(key=float)

print("avg: %.3f" % (sumi/len(numbs)))
for i in range(1, 10):
	pos = len(numbs)/10
	pos *= i
	print("p%d%%: \t%.3f" % (i *10, numbs[pos-1]))


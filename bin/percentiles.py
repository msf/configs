#!/usr/bin/env python
from __future__ import print_function
import sys
import re


PERCENTILES = [10, 50, 90, 95, 99]
NUMBERS_REGEXP = re.compile(r'\d+(?:\.\d+)?')


def read_numbers(inputstream):
    numbs = []
    sumi = 0

    for line in inputstream:
        try:
            val = float(NUMBERS_REGEXP.findall(line)[0])
            numbs.append(val)
            sumi += val
        except Exception:
            pass
    return numbs, sumi


def get_percentile(sorted_numbers, percentile):
    count = len(sorted_numbers)
    if count == 0:
        return -1
    if count == 1:
        return sorted_numbers[0]
    if percentile >= 100:
        return sorted_numbers[-1]
    pos = int((percentile * count)/100)
    return sorted_numbers[pos]


def run(inputstream):
    numbs, sumi = read_numbers(inputstream)
    if len(numbs) == 0:
        print("No data to compute percentiles")
        return
    numbs.sort(key=float)

    print("count: {},    min:{:.3f},    avg:{:.3f},    max:{:.3f}".format(
        len(numbs),
        numbs[0],
        sumi/len(numbs),
        numbs[-1],
    ))
    percentiles_str = ""
    for percen in PERCENTILES:
        value = get_percentile(numbs, percen)
        percentiles_str += "    P{}%: {:.3f}".format(percen, value)
    print(percentiles_str.strip())


def main():
    if sys.argv[1] == '-':
        inputstream = sys.stdin
    else:
        inputstream = open(sys.argv[1])
    run(inputstream)


if __name__ == '__main__':
    main()

#!/usr/bin/env python
# Adaptive Replacement Cache.
# simple cache implementation that outperforms LRU.


def cache_arc(max_size):
    """     Adaptive Replacement Cache
        The self-tuning, low-overhead, scan-resistant adaptive replacement cache
        algorithm outperforms the least-recently-used algorithm by dynamically
        responding to changing access patterns and continually balancing
        between workload recency and frequency features.
    """
    def decorating_function(f):
        L1_len = 0     # accessed once LRU              entries counter
        L2_len = 0     # accessed more than once LRU    entries counter
        top_LRU1 = []           # TOP    of LRU 1  - elements accessed once
        bottom_LRU1 = []    # BOTTOM of LRU 1  - elements accessed once
        top_LRU2 = []       # TOP    of LRU 2  - elements accessed _more than_ once
        bottom_LRU2 = []    # BOTTOM of LRU 2  - elements accessed _more than_ once
        maxsize = max_size
        p = 0
        cache = {}
        
        def replace( id, len):
            if len(top_LRU1) > 1 and (( id in bottom_LRU2 and len(top_LRU1) == len) or len(top_LRU1) > len ):
                key = top_LRU1.pop(0)
                bottom_LRU1.append(key)
            else:
                key = top_LRU2.pop(0)
                bottom_LRU2.append(key)
            cache.remove(key)    # remove item from cache.
            
        
        def wrapper(*args):

            #localize variables.
            _head1 = top_LRU1
            _tail1 = bottom_LRU1
            _head2 = top_LRU2
            _tail2 = bottom_LRU2
            lru1_len = L1_len
            lru2_len = L2_len
            _cache = cache

            
            if (args in _head1) or (args in _head2):
                wrapper.hits += 1
                if args in _head2:
                    _head2.remove(args) # move to "beggining of" _head2
                    _head2.append(args)
                else:
                    _head1.remove(args)
                    _head2.append(args)
                result = _cache[args]
            
            elif (args in _tail1) or (args in _tail2):
                if args in _tail2:
                    p = max(0, p - max( len(_tail1)//len(_tail2), 1))
                else:
                    p = min(maxsize, p + max( len(_tail2)//len(_tail1), 1))

                replace( args, p)
                wrapper.misses += 1
                _head2.append(args)
                result = _cache[args] = f(*args)
            else:
                if lru1_len == maxsize:
                    if len(_head1) < maxsize:
                        _tail1.pop(0)
                        replace(args, p)
                    else:
                        _head1.pop(0)
                        _cache.remove(args)
                elif lru1_len < maxsize and (lru1_len + lru2_len >= maxsize):
                    if lru1_len + lru2_len == maxsize*2:
                        _tail2.pop(0)
                    replace( args,p)

                wrapper.misses += 1
                _head1.append(args)
                result = _cache[args] = f(*args)
                
            # update L1 and L2 LRUs
            lru1_len = len(_tail1) + len(_head1)
            lru2_len = len(_tail2) + len(_head2)
            
            return result
            
        wrapper.__doc__ = f.__doc__
        wrapper.__name__ = f.__name__
        wrapper.hits = wrapper.misses = 0
        return wrapper
    return decorating_function


if __name__ == '__main__':
         
    @cache_arc(max_size=500)
    def f(x, y):
        return 3*x+y

    domain = range(30)
    from random import choice
    for i in range(1000):
        r = f(choice(domain), choice(domain))

    print f.hits, f.misses

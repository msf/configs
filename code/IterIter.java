package github.msf;

import java.util.Collection;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.function.Consumer;

public class IterIter<T> implements Iterator<T> {

    private LinkedList<Iterator<T>> _nextIterators;
    private Policy _policy;

    public enum Policy {
        ROUND_ROBIN,
        SEQUENTIAL,
    }

    public IterIter(Collection<Iterator<T>> allIterators, Policy policy) {
        _policy = policy;
        _nextIterators = new LinkedList<Iterator<T>>();
        for(Iterator<T> iter : allIterators) {
            if(iter.hasNext()) {
                _nextIterators.add(iter);
            }
        }
    }

    private Iterator<T> pop() {
        Iterator current = null;
        while( (current == null || !current.hasNext()) && _nextIterators.size() > 0) {
            current = _nextIterators.removeFirst();
        }
        if(!current.hasNext())
            return null;
        return current;
    }

    private void push(Iterator<T> iter) {
        if(_policy == Policy.ROUND_ROBIN) {
            _nextIterators.addLast(iter);
        } else {
            _nextIterators.addFirst(iter);
        }
    }

    @Override
    public boolean hasNext() {
        Iterator<T> iter = pop();
        if(iter != null) {
            _nextIterators.addFirst(iter);
            return true;
        }
        return false;
    }

    public T next() {
        Iterator<T> current = pop();
        if(current == null) {
            return null;
        }

        T item = current.next();
        push(current);
        return item;
    }

    @Override
    public void remove() {
        pop();
    }

    @Override
    public void forEachRemaining(Consumer<? super T> consumer) {
        while(hasNext()) {
            consumer.accept(next());
        }
    }
}

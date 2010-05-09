using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;

namespace Altitude.Voice.Utils
{
  public class SmartQueue<T>
  {
    private object m_lock = new object();
    private Queue<T> m_qu;
    private ManualResetEvent m_go;
    
    public SmartQueue()
    {
      m_qu = new Queue<T>();
      m_go = new ManualResetEvent(false);
    }

    public void Enqueue(T o)
    {
      lock( m_lock )
      {
        m_qu.Enqueue(o);
        m_go.Set();
      }
    }
   
    public T Dequeue(int timeout_milis, out bool timedout)
    {
      timedout = false;
      bool res = m_go.WaitOne( timeout_milis, false );
      if( !res ) {
        timedout = true;
        return default( T );
      }
      T o;
      lock( m_lock )
      {
        o = m_qu.Dequeue();
        if (m_qu.Count == 0)
          m_go.Reset();
      }
      return o;
    }

    public T Dequeue()
    {
      bool b;
      return Dequeue(-1, out b);
    }
  }
}

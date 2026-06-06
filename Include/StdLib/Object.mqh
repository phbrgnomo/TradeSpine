//+------------------------------------------------------------------+
//|                                                       Object.mqh |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                                     www.mql5.com |
//+------------------------------------------------------------------+
//
// VENDORED — TradeSpine Include/StdLib/ (ADR-06)
// Source: MetaTrader 5 terminal Include/Object.mqh
// Included by: Trade/TerminalInfo.mqh (and future Trade/*.mqh siblings)
// Edits applied: include guard added (not in terminal original); sibling
// relative include "StdLibErr.mqh" unchanged.
//
#ifndef TRADESPINE_VENDOR_OBJECT_MQH
#define TRADESPINE_VENDOR_OBJECT_MQH

#include "StdLibErr.mqh"
//+------------------------------------------------------------------+
//| Class CObject.                                                   |
//| Purpose: Base class for storing elements.                        |
//+------------------------------------------------------------------+
class CObject
  {
private:
   CObject          *m_prev;               // previous item of list
   CObject          *m_next;               // next item of list

public:
                     CObject(void): m_prev(NULL),m_next(NULL)            {                 }
                    ~CObject(void)                                       {                 }
   //--- methods to access protected data
   CObject          *Prev(void)                                    const { return(m_prev); }
   void              Prev(CObject *node)                                 { m_prev=node;    }
   CObject          *Next(void)                                    const { return(m_next); }
   void              Next(CObject *node)                                 { m_next=node;    }
   //--- methods for working with files
   virtual bool      Save(const int file_handle)                         { return(true);   }
   virtual bool      Load(const int file_handle)                         { return(true);   }
   //--- method of identifying the object
   virtual int       Type(void)                                    const { return(0);      }
   //--- method of comparing the objects
   virtual int       Compare(const CObject *node,const int mode=0) const { return(0);      }
  };

#endif // TRADESPINE_VENDOR_OBJECT_MQH
//+------------------------------------------------------------------+

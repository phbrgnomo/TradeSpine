//+------------------------------------------------------------------+
//|                                                 TradeLogger.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Persistence/TradeLogger.mqh                       |
//| @spec: SPEC-05  @tdd: TDD.05.04.229f  @iplan: IPLAN-05           |
//|                                                                  |
//| Paired intent/execution CSV evidence writer (SPEC-05 evidence    |
//| sink contract). Each trade leaves exactly two rows in the same  |
//| daily CSV file, sharing strategy_run_id and order_intent_id.    |
//|                                                                  |
//| Separation guarantee: diagnostic log messages are routed through |
//| the injected ILogSink — they never appear in the trade CSV.     |
//|                                                                  |
//| I/O gate: AllowsHighVolumeEvidence() is checked before every    |
//| write; in optimization mode both methods return true silently.  |
//|                                                                  |
//| CSV file: MQL5/Files/TradeSpine/<filename_prefix>_<YYYYMMDD>.csv |
//| (one file per day, appended; header written once per new file). |
//|                                                                  |
//| CSV columns (16):                                                |
//|   record_type, timestamp_utc, strategy_run_id, order_intent_id, |
//|   symbol, magic, side,                                           |
//|   intended_price, sl_price, tp_price, lots_requested,           |  <- INTENT only
//|   retcode, ticket, fill_price, lots_submitted,                  |  <- EXECUTION only
//|   broker_outcome                                                 |
//| Intent-side and execution-side fields are written as empty for  |
//| the inapplicable row type. side is written on both row types.   |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_PERSISTENCE_TRADELOGGER_MQH
#define TRADESPINE_PERSISTENCE_TRADELOGGER_MQH

#include "PersistenceTypes.mqh"
#include "../../Include/Core/OptContext.mqh"

//+------------------------------------------------------------------+
//| \brief ENUM_TRADE_SIDE - constrains TradeEvidenceRecord.side to   |
//|        a well-defined domain so the evidence CSV cannot pick up  |
//|        accidental casing/typo/localisation variants.            |
//+------------------------------------------------------------------+
enum ENUM_TRADE_SIDE
  {
   TRADE_SIDE_BUY  = 0, //!< Long-side order.
   TRADE_SIDE_SELL = 1  //!< Short-side order.
  };

//+------------------------------------------------------------------+
//| \brief TradeEvidenceRecord - one CSV row in the trade evidence   |
//|        file. Intent and execution rows are paired by sharing the |
//|        same strategy_run_id and order_intent_id.                 |
//|                                                                  |
//| Fields marked [INTENT] are populated on INTENT rows and written  |
//| as empty on EXECUTION rows. Fields marked [EXECUTION] are the   |
//| reverse. [BOTH] fields are populated on every row.              |
//+------------------------------------------------------------------+
struct TradeEvidenceRecord
  {
   ENUM_TRADE_RECORD_TYPE record_type;     //!< [BOTH]      TRADE_RECORD_INTENT or TRADE_RECORD_EXECUTION.
   string                 strategy_run_id; //!< [BOTH]      Correlates all records within one lifecycle.
   string                 order_intent_id; //!< [BOTH]      Pairs exactly one intent and one execution row.
   string                 symbol;          //!< [BOTH]      Instrument symbol.
   ulong                  magic;           //!< [BOTH]      EA magic number.
   ENUM_TRADE_SIDE        side;            //!< [BOTH]      TRADE_SIDE_BUY or TRADE_SIDE_SELL.
   // --- Intent fields: populate before broker submission; leave default on EXECUTION rows. ---
   double                 intended_price;  //!< [INTENT]    EA's calculated entry price.
   double                 sl_price;        //!< [INTENT]    Requested stop loss (0.0 = none).
   double                 tp_price;        //!< [INTENT]    Requested take profit (0.0 = none).
   double                 lots_requested;  //!< [INTENT]    Lot size from position sizer.
   // --- Execution fields: populate after broker result is known; leave default on INTENT rows. ---
   uint                   retcode;         //!< [EXECUTION] Broker return code.
   ulong                  ticket;          //!< [EXECUTION] Order/deal ticket (0 = not created).
   double                 fill_price;      //!< [EXECUTION] Actual fill price (0.0 = rejected).
   double                 lots_submitted;  //!< [EXECUTION] Lots that reached the broker.
   // --- Free-form overflow: rejection messages, retry info, etc. ---
   string                 broker_outcome;  //!< [BOTH]      Free-form overflow; empty is valid.
  };

//+------------------------------------------------------------------+
//| \brief TradeLogger - writes paired intent and execution CSV      |
//|        evidence for every guarded trade submission.             |
//+------------------------------------------------------------------+
class TradeLogger
  {
  private:
   COptContext*   m_ctx;
   ILogSink*      m_sink;
   string         m_prefix;     // e.g. "TradeEvidence_99090_WINM26"
   string         m_active_file; // full relative path for the current open file
   int            m_fh;          // file handle (-1 = not open)
   string         m_today;       // YYYYMMDD of the last opened file

   //--- Open (or reopen after date rollover) the CSV file; write header if new.
   bool           _EnsureFile(void);

   //--- Format and write one evidence row; returns false (with diagnostic) on invalid side or I/O failure.
   bool           _WriteRow(const TradeEvidenceRecord &rec);

   //--- UTC datetime → "YYYYMMDD" for file naming.
   static string  _DateStamp(datetime t);

   //--- UTC datetime → ISO-8601 timestamp for CSV rows.
   static string  _IsoTimestamp(datetime t);

   //--- RFC 4180 quote a CSV field; escapes embedded double-quotes.
   static string  _CsvField(const string v);

   //--- ENUM_TRADE_SIDE → "BUY"/"SELL" for the CSV side column.
   static string  _SideToString(ENUM_TRADE_SIDE s);

  public:
                  TradeLogger(void) : m_ctx(NULL), m_sink(NULL), m_fh(INVALID_HANDLE) {}
                 ~TradeLogger(void) { Close(); }

   //--- \brief Initialize the logger.
   //--- \param filename_prefix  Base name for the CSV file (e.g. "TradeEvidence_99090_WINM26").
   //---                         The date stamp and ".csv" extension are appended automatically.
   //--- \param ctx   Runtime mode gate (non-null; caller owns lifetime).
   //--- \param sink  Diagnostic fallback for error reporting (non-null; caller owns lifetime).
   //--- \return true on success.
   bool           Init(string filename_prefix, COptContext* ctx, ILogSink* sink);

   //--- \brief Write an intent evidence row before order submission.
   //--- \return true on success or when gated (optimization mode); false on I/O failure.
   bool           WriteIntent(const TradeEvidenceRecord &rec);

   //--- \brief Write an execution evidence row after the broker result is known.
   //--- \return true on success or when gated; false on I/O failure (LogFailure).
   bool           WriteExecution(const TradeEvidenceRecord &rec);

   //--- \brief Close the CSV file handle. Safe to call multiple times.
   void           Close(void);
  };

//+------------------------------------------------------------------+
static string TradeLogger::_DateStamp(datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return(StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day));
  }

//+------------------------------------------------------------------+
static string TradeLogger::_IsoTimestamp(datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return(StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ",
                       dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec));
  }

//+------------------------------------------------------------------+
static string TradeLogger::_CsvField(const string v)
  {
   string s = v;
   StringReplace(s, "\"", "\"\"");
   return("\"" + s + "\"");
  }

//+------------------------------------------------------------------+
static string TradeLogger::_SideToString(ENUM_TRADE_SIDE s)
  {
   return(s == TRADE_SIDE_SELL ? "SELL" : "BUY");
  }

//+------------------------------------------------------------------+
bool TradeLogger::_EnsureFile(void)
  {
   string today = _DateStamp(TimeGMT());
   if(m_fh != INVALID_HANDLE && today == m_today)
      return(true); // already open for today

//--- Close previous handle on date rollover.
   if(m_fh != INVALID_HANDLE)
     {
      FileClose(m_fh);
      m_fh = INVALID_HANDLE;
     }

   FolderCreate("TradeSpine");
   string path = "TradeSpine/" + m_prefix + "_" + today + ".csv";
   bool   is_new = !FileIsExist(path);

   m_fh = FileOpen(path, FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(m_fh == INVALID_HANDLE)
      return(false);

//--- Seek to end so new rows are appended.
   FileSeek(m_fh, 0, SEEK_END);

//--- Write CSV header once per new file.
   if(is_new)
     {
      uint written = FileWriteString(m_fh,
                      "record_type,timestamp_utc,strategy_run_id,order_intent_id,"
                      "symbol,magic,side,"
                      "intended_price,sl_price,tp_price,lots_requested,"
                      "retcode,ticket,fill_price,lots_submitted,"
                      "broker_outcome\n");
      if(written == 0)
        {
         FileClose(m_fh);
         m_fh = INVALID_HANDLE;
         return(false);
        }
     }

   m_today       = today;
   m_active_file = path;
   return(true);
  }

//+------------------------------------------------------------------+
bool TradeLogger::_WriteRow(const TradeEvidenceRecord &rec)
  {
   if(!_EnsureFile()) return(false);

//--- Reject out-of-domain side values; coercing them to BUY would silently misrepresent direction.
   if(rec.side != TRADE_SIDE_BUY && rec.side != TRADE_SIDE_SELL)
     {
      m_sink.Write(LOG_ERROR, "TradeLogger", "invalid trade side value; record rejected");
      return(false);
     }

   bool   is_intent = (rec.record_type == TRADE_RECORD_INTENT);
   string type_str  = is_intent ? "INTENT" : "EXECUTION";

//--- Intent-side columns: populated on INTENT rows, empty on EXECUTION rows.
   string col_intended_price = is_intent ? StringFormat("%.5f", rec.intended_price) : "";
   string col_sl_price       = is_intent ? StringFormat("%.5f", rec.sl_price)       : "";
   string col_tp_price       = is_intent ? StringFormat("%.5f", rec.tp_price)       : "";
   string col_lots_requested = is_intent ? StringFormat("%.3f", rec.lots_requested) : "";

//--- Execution-side columns: populated on EXECUTION rows, empty on INTENT rows.
   string col_retcode        = !is_intent ? StringFormat("%u",    rec.retcode)       : "";
   string col_ticket         = !is_intent ? StringFormat("%I64u", rec.ticket)        : "";
   string col_fill_price     = !is_intent ? StringFormat("%.5f", rec.fill_price)    : "";
   string col_lots_submitted = !is_intent ? StringFormat("%.3f", rec.lots_submitted): "";

   string row = type_str + ","
              + _CsvField(_IsoTimestamp(TimeGMT())) + ","
              + _CsvField(rec.strategy_run_id) + ","
              + _CsvField(rec.order_intent_id) + ","
              + _CsvField(rec.symbol) + ","
              + StringFormat("%I64u", rec.magic) + ","
              + _CsvField(_SideToString(rec.side)) + ","
              + col_intended_price + ","
              + col_sl_price + ","
              + col_tp_price + ","
              + col_lots_requested + ","
              + col_retcode + ","
              + col_ticket + ","
              + col_fill_price + ","
              + col_lots_submitted + ","
              + _CsvField(rec.broker_outcome) + "\n";

   uint written = FileWriteString(m_fh, row);
   if(written == 0)
     {
      FileClose(m_fh);
      m_fh    = INVALID_HANDLE;
      m_today = "";
      return(false);
     }

//--- Flush immediately so evidence survives a terminal crash.
   FileFlush(m_fh);
   return(true);
  }

//+------------------------------------------------------------------+
bool TradeLogger::Init(string filename_prefix, COptContext* ctx, ILogSink* sink)
  {
   if(ctx == NULL || sink == NULL)
      return(false);
   m_prefix = filename_prefix;
   m_ctx    = ctx;
   m_sink   = sink;
   m_fh     = INVALID_HANDLE;
   m_today  = "";
   return(true);
  }

//+------------------------------------------------------------------+
bool TradeLogger::WriteIntent(const TradeEvidenceRecord &rec)
  {
   if(m_ctx == NULL) return(false);
   if(!m_ctx.AllowsHighVolumeEvidence()) return(true); // gated in optimization
   TradeEvidenceRecord row = rec;
   row.record_type = TRADE_RECORD_INTENT;
   if(!_WriteRow(row))
     {
      m_sink.Write(LOG_ERROR, "TradeLogger",
                   "Intent write failed for order_intent_id=" + rec.order_intent_id);
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
bool TradeLogger::WriteExecution(const TradeEvidenceRecord &rec)
  {
   if(m_ctx == NULL) return(false);
   if(!m_ctx.AllowsHighVolumeEvidence()) return(true); // gated in optimization
   TradeEvidenceRecord row = rec;
   row.record_type = TRADE_RECORD_EXECUTION;
   if(!_WriteRow(row))
     {
      m_sink.Write(LOG_ERROR, "TradeLogger",
                   "Execution write failed for order_intent_id=" + rec.order_intent_id);
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
void TradeLogger::Close(void)
  {
   if(m_fh != INVALID_HANDLE)
     {
      FileClose(m_fh);
      m_fh = INVALID_HANDLE;
     }
  }

#endif // TRADESPINE_PERSISTENCE_TRADELOGGER_MQH
//+------------------------------------------------------------------+

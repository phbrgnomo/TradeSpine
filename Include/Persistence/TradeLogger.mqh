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
//+------------------------------------------------------------------+
#ifndef TRADESPINE_PERSISTENCE_TRADELOGGER_MQH
#define TRADESPINE_PERSISTENCE_TRADELOGGER_MQH

#include "StateStore.mqh"
#include "../../Include/Core/OptContext.mqh"

//+------------------------------------------------------------------+
//| \brief TradeEvidenceRecord - one CSV row in the trade evidence   |
//|        file. Intent and execution rows are paired by sharing the |
//|        same strategy_run_id and order_intent_id.                 |
//+------------------------------------------------------------------+
struct TradeEvidenceRecord
  {
   ENUM_TRADE_RECORD_TYPE record_type;     //!< TRADE_RECORD_INTENT or TRADE_RECORD_EXECUTION.
   string                 strategy_run_id; //!< Correlates all records within one lifecycle.
   string                 order_intent_id; //!< Pairs exactly one intent and one execution row.
   string                 symbol;          //!< Instrument symbol.
   ulong                  magic;           //!< EA magic number.
   string                 broker_outcome;  //!< Empty for INTENT; retcode/deal for EXECUTION.
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

   //--- Format and write one evidence row.
   bool           _WriteRow(const TradeEvidenceRecord &rec);

   //--- UTC datetime → "YYYYMMDD" for file naming.
   static string  _DateStamp(datetime t);

   //--- UTC datetime → ISO-8601 timestamp for CSV rows.
   static string  _IsoTimestamp(datetime t);

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
      FileWriteString(m_fh,
                      "record_type,timestamp_utc,strategy_run_id,order_intent_id,"
                      "symbol,magic,broker_outcome\n");

   m_today       = today;
   m_active_file = path;
   return(true);
  }

//+------------------------------------------------------------------+
bool TradeLogger::_WriteRow(const TradeEvidenceRecord &rec)
  {
   if(!_EnsureFile()) return(false);

   string type_str = (rec.record_type == TRADE_RECORD_INTENT) ? "INTENT" : "EXECUTION";
   string row = type_str + ","
              + _IsoTimestamp(TimeGMT()) + ","
              + rec.strategy_run_id + ","
              + rec.order_intent_id + ","
              + rec.symbol + ","
              + IntegerToString((long)rec.magic) + ","
              + rec.broker_outcome + "\n";

   uint written = FileWriteString(m_fh, row);
   if(written == 0)
      return(false);

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
   if(!_WriteRow(rec))
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
   if(!_WriteRow(rec))
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

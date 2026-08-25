//+------------------------------------------------------------------+
//|                                                 MarkerLease.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Persistence/MarkerLease.mqh                       |
//| @spec: SPEC-05  @tdd: TDD.05.04.e64a  @iplan: IPLAN-05           |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_PERSISTENCE_MARKERLEASE_MQH
#define TRADESPINE_PERSISTENCE_MARKERLEASE_MQH

#include "PersistenceTypes.mqh"

//+------------------------------------------------------------------+
//| \brief Injectable marker primitive seam for deterministic lease |
//|        interleaving tests. Production uses terminal GVs/files.   |
//+------------------------------------------------------------------+
interface IMarkerBackend
  {
   //--- \brief Test whether a marker slot exists.
   //--- \param key Canonical marker slot key.
   //--- \return true when the slot exists.
   bool Exists(string key);
   //--- \brief Read a marker slot.
   //--- \param key Canonical marker slot key.
   //--- \return Current scalar value; callers first establish existence.
   double Get(string key);
   //--- \brief Create or replace a marker slot.
   //--- \param key Canonical marker slot key.
   //--- \param value Exact-double-safe scalar value.
   //--- \return true when the value is stored.
   bool Set(string key, double value);
   //--- \brief Atomically replace an existing slot when expected matches.
   //--- \param key Canonical owner slot key.
   //--- \param value Replacement value.
   //--- \param expected Required current value.
   //--- \return true only when the compare-and-exchange succeeds.
   bool CompareExchange(string key, double value, double expected);
   //--- \brief Acquire the identity-scoped exclusive publication lock.
   //--- \param lock_name Canonical lock filename.
   //--- \return Valid handle on success; INVALID_HANDLE on contention/error.
   int AcquireExclusive(string lock_name);
   //--- \brief Release an acquired publication lock.
   //--- \param handle Handle returned by AcquireExclusive.
   void ReleaseExclusive(int handle);
  };

//+------------------------------------------------------------------+
//| \brief Terminal implementation of the marker primitive seam.    |
//+------------------------------------------------------------------+
class CTerminalMarkerBackend : public IMarkerBackend
  {
  public:
   bool Exists(string key) override { return(GlobalVariableCheck(key)); }
   double Get(string key) override { return(GlobalVariableGet(key)); }
   bool Set(string key, double value) override { return(GlobalVariableSet(key, value) != 0); }
   bool CompareExchange(string key, double value, double expected) override
     { return(GlobalVariableSetOnCondition(key, value, expected)); }
   int AcquireExclusive(string lock_name) override
     { return(FileOpen(lock_name, FILE_READ | FILE_WRITE | FILE_BIN)); }
   void ReleaseExclusive(int handle) override
     { if(handle != INVALID_HANDLE) FileClose(handle); }
  };

//+------------------------------------------------------------------+
//| \brief Token-fenced marker lease protocol.                       |
//|                                                                  |
//| The exclusive identity lock serializes bootstrap and publication.|
//| Positive owners are live epochs; zero/negative owners are free.  |
//| Heartbeat never publishes a negative owner: failure preserves the|
//| caller's epoch when possible, while release alone negates a token.|
//+------------------------------------------------------------------+
class CMarkerLease
  {
  private:
   string          m_owner_key;
   string          m_heartbeat_key;
   string          m_lock_name;
   IMarkerBackend* m_backend;
   bool            m_initialized;

   bool _Ensure(string key, double default_value)
     {
      if(m_backend == NULL) return(false);
      if(m_backend.Exists(key)) return(true);
      return(m_backend.Set(key, default_value));
     }

   bool _NextToken(double owner, long &token)
     {
      double abs_owner = (owner < 0.0 ? -owner : owner);
      if(abs_owner >= 9007199254740991.0 || MathFloor(abs_owner) != abs_owner)
         return(false);
      token = (long)(abs_owner + 1.0);
      return(token > 0);
     }

  public:
   CMarkerLease(void) : m_owner_key(""), m_heartbeat_key(""), m_lock_name(""),
                        m_backend(NULL), m_initialized(false) {}

   //--- \brief Bind the protocol to its identity-derived keys and backend.
   //--- \param owner_key Canonical marker-owner key.
   //--- \param heartbeat_key Canonical heartbeat timestamp key.
   //--- \param lock_name Identity-scoped exclusive lock filename.
   //--- \param backend Non-null primitive backend owned by the caller.
   //--- \return true when all protocol dependencies are valid.
   bool Init(string owner_key,
             string heartbeat_key,
             string lock_name,
             IMarkerBackend* backend)
     {
      m_initialized = false;
      if(owner_key == "" || heartbeat_key == "" || lock_name == "" || backend == NULL)
         return(false);
      m_owner_key = owner_key;
      m_heartbeat_key = heartbeat_key;
      m_lock_name = lock_name;
      m_backend = backend;
      m_initialized = true;
      return(true);
     }

   //--- \brief Claim a free marker or reclaim an expired positive owner.
   //--- \param now Current lease clock value.
   //--- \param lease_secs Positive stale-owner threshold.
   //--- \param out_token [out] Positive owner token only on successful claim.
   //--- \param status [out] Active, stale-reclaimed, or conflict classification.
   //--- \return true when the claim attempt is handled; inspect status/token.
   bool ClaimOrReclaim(datetime now,
                       int lease_secs,
                       long &out_token,
                       ENUM_DUPLICATE_MARKER_STATUS &status)
     {
      out_token = 0;
      status = DUPLICATE_MARKER_CONFLICT;
      if(!m_initialized || lease_secs <= 0) return(false);

      ResetLastError();
      int lock_handle = m_backend.AcquireExclusive(m_lock_name);
      if(lock_handle == INVALID_HANDLE)
        {
         PrintFormat("[TS_LEASE_CONFLICT] bootstrap mutex busy: error=%d", GetLastError());
         return(true);
        }
      if(!_Ensure(m_owner_key, 0.0) || !_Ensure(m_heartbeat_key, 0.0))
        {
         m_backend.ReleaseExclusive(lock_handle);
         return(false);
        }

      double owner = m_backend.Get(m_owner_key);
      double heartbeat = m_backend.Get(m_heartbeat_key);
      if(MathFloor(owner) != owner || MathFloor(heartbeat) != heartbeat || heartbeat < 0.0)
        {
         m_backend.ReleaseExclusive(lock_handle);
         return(false);
        }
      bool was_free = (owner <= 0.0);
      if(!was_free && heartbeat <= 0.0)
        {
         m_backend.ReleaseExclusive(lock_handle);
         return(true);
        }
      bool stale = (!was_free && now >= (datetime)(long)heartbeat
                    && ((long)now - (long)heartbeat) >= lease_secs);
      if(!was_free && !stale)
        {
         m_backend.ReleaseExclusive(lock_handle);
         return(true);
        }

      long token = 0;
      if(!_NextToken(owner, token))
        {
         m_backend.ReleaseExclusive(lock_handle);
         return(false);
        }
      ResetLastError();
      if(!m_backend.CompareExchange(m_owner_key, (double)token, owner))
        {
         m_backend.ReleaseExclusive(lock_handle);
         return(true);
        }
      if(!m_backend.Set(m_heartbeat_key, (double)now))
        {
         m_backend.CompareExchange(m_owner_key, (double)(-token), (double)token);
         m_backend.ReleaseExclusive(lock_handle);
         return(false);
        }
      double published_owner = m_backend.Get(m_owner_key);
      double published_heartbeat = m_backend.Get(m_heartbeat_key);
      if(published_owner != (double)token || published_heartbeat != (double)now)
        {
         m_backend.CompareExchange(m_owner_key, (double)(-token), (double)token);
         m_backend.ReleaseExclusive(lock_handle);
         return(false);
        }

      out_token = token;
      status = (stale ? DUPLICATE_MARKER_STALE_RECLAIMED : DUPLICATE_MARKER_ACTIVE);
      m_backend.ReleaseExclusive(lock_handle);
      PrintFormat("[TS_LEASE_CLAIM] token=%I64d status=%d", token, (int)status);
      return(true);
     }

   //--- \brief Advance the fence and heartbeat while preserving ownership on verification failure.
   //--- \param token [in,out] Current token; advanced only after verified success.
   //--- \param now Current heartbeat timestamp.
   //--- \return true only when token and heartbeat publication are reread exactly.
   bool Heartbeat(long &token, datetime now)
     {
      if(!m_initialized || token <= 0) return(false);
      int lock_handle = m_backend.AcquireExclusive(m_lock_name);
      if(lock_handle == INVALID_HANDLE) return(false);

      long next_token = token + 1;
      if(next_token <= token || (double)next_token > 9007199254740991.0)
        {
         m_backend.ReleaseExclusive(lock_handle);
         return(false);
        }
      ResetLastError();
      if(!m_backend.CompareExchange(m_owner_key, (double)next_token, (double)token))
        {
         m_backend.ReleaseExclusive(lock_handle);
         return(false);
        }
      if(!m_backend.Set(m_heartbeat_key, (double)now))
        {
         m_backend.CompareExchange(m_owner_key, (double)token, (double)next_token);
         m_backend.ReleaseExclusive(lock_handle);
         return(false);
        }

      double observed_owner = m_backend.Get(m_owner_key);
      double observed_heartbeat = m_backend.Get(m_heartbeat_key);
      if(observed_owner != (double)next_token || observed_heartbeat != (double)now)
        {
         // A failed reread is not a release request. Roll back only while the
         // advanced token is still ours; never overwrite a competing epoch.
         bool preserved = (observed_owner == (double)token);
         if(observed_owner == (double)next_token)
            preserved = m_backend.CompareExchange(m_owner_key,
                                                   (double)token,
                                                   (double)next_token);
         // Backend reads expose no error status. Non-finite values are therefore
         // classified explicitly; every other failed verification is a reread
         // mismatch and includes both identity-derived slot keys for correlation.
         string reason = (!MathIsValidNumber(observed_owner)
                          || !MathIsValidNumber(observed_heartbeat)
                          ? "invalid_backend_value" : "reread_mismatch");
         PrintFormat("[TS_LEASE_HEARTBEAT_VERIFY_FAIL] reason=%s owner_key=%s heartbeat_key=%s token=%I64d owner=%.0f heartbeat=%.0f preserved=%d",
                     reason, m_owner_key, m_heartbeat_key, token,
                     observed_owner, observed_heartbeat, (preserved ? 1 : 0));
         m_backend.ReleaseExclusive(lock_handle);
         return(false);
        }
      token = next_token;
      m_backend.ReleaseExclusive(lock_handle);
      return(true);
     }

   //--- \brief Verify the exact positive owner fence.
   //--- \param token Expected current owner token.
   //--- \return true only when the owner slot exactly matches token.
   bool IsOwner(long token)
     {
      return(m_initialized && token > 0 && m_backend.Exists(m_owner_key)
             && m_backend.Get(m_owner_key) == (double)token);
     }

   //--- \brief Release only the exact current token by negating its epoch.
   //--- \param token Expected current owner token.
   //--- \return true only when the owner slot changes atomically to -token.
   bool Release(long token)
     {
      if(!m_initialized || token <= 0) return(false);
      ResetLastError();
      return(m_backend.CompareExchange(m_owner_key, (double)(-token), (double)token));
     }
  };

#endif // TRADESPINE_PERSISTENCE_MARKERLEASE_MQH
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                             FakeStateStore.mqh   |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Support/FakeStateStore.mqh                 |
//| @spec: SPEC-04,SPEC-05  @tdd: TDD.04.04.8b79  @iplan: IPLAN-04   |
//|                                                                  |
//| In-memory IStateStore fake with IPLAN-04 lease, pending-order,   |
//| HALT set/clear, and scalar/ticket counters.                      |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_TEST_SUPPORT_FAKESTATESTORE_MQH
#define TRADESPINE_TEST_SUPPORT_FAKESTATESTORE_MQH

#include "../../../Include/Persistence/StateStore.mqh"

//+------------------------------------------------------------------+
//| \brief FakeScalarSlot - one in-memory scalar state slot.         |
//+------------------------------------------------------------------+
struct FakeScalarSlot
  {
   string scope;
   double value;
  };

//+------------------------------------------------------------------+
//| \brief FakeStateStore - reusable in-memory IStateStore double.   |
//+------------------------------------------------------------------+
class FakeStateStore : public IStateStore
  {
  private:
   FakeScalarSlot m_scalars[];
   //--- \brief Find scalar slot by scope.
   //--- \param scope Logical state scope.
   //--- \param index [out] Array index, or -1 when absent.
   //--- \return true when the scope exists.
   bool           _FindScalar(string scope, int &index);

  public:
   int            write_scalar_calls;
   int            read_scalar_calls;
   int            set_halt_calls;
   int            append_halt_calls;
   int            clear_halt_calls;
   int            marker_claim_calls;
   int            marker_heartbeat_calls;
   int            marker_release_calls;
   int            pending_write_calls;
   int            pending_clear_calls;
   int            snapshot_write_calls;
   int            snapshot_read_calls;
   bool           halted;
   bool           fail_set_halt;
   bool           fail_clear_halt;
   bool           fail_write_scalar;
   bool           fail_write_snapshot;
   bool           corrupt_snapshot;
   HaltEvidence   last_halt;
   ulong          ticket_value;
   bool           ticket_set;
   ulong          pending_ticket;
   datetime       pending_submitted_ts;
   bool           pending_set;
   long           marker_owner;
   datetime       marker_hb_ts;
   LifecycleSnapshot snapshot_value;
   bool           snapshot_set;
   bool           runtime_isolated;

                  FakeStateStore(void) { Reset(); }

   //--- \brief Reset all fake state and counters.
   void           Reset();
   //--- \brief Commit an in-memory lifecycle aggregate.
   bool           WriteLifecycleSnapshot(const LifecycleSnapshot &snapshot) override;
   //--- \brief Read the in-memory lifecycle aggregate with detailed status.
   ENUM_STORE_READ_RESULT ReadLifecycleSnapshot(LifecycleSnapshot &snapshot) override;
   //--- \brief Return the injected runtime-isolation flag.
   //--- \return true when runtime_isolated is set.
   bool           IsRuntimeIsolated() override { return(runtime_isolated); }
   //--- \brief Store an in-memory scalar and increment write counter.
   //--- \return true.
   bool           WriteScalar(string scope, double value) override;
   //--- \brief Read an in-memory scalar and increment read counter.
   //--- \return true when the scope exists.
   bool           ReadScalar(string scope, double &value) override;
   //--- \brief Mark an intent as duplicate in scalar state.
   //--- \return true.
   bool           SetDuplicate(string intent_id_hash) override { return(WriteScalar("dup_" + intent_id_hash, 1.0)); }
   //--- \brief Return whether a duplicate scalar exists.
   //--- \return true when marked duplicate.
   bool           IsDuplicate(string intent_id_hash) override;
   //--- \brief Capture HALT evidence and optionally fail the write.
   //--- \return false only when fail_set_halt is true.
   bool           SetHalt(const HaltEvidence &ev) override;
   //--- \brief Capture appended HALT evidence without changing the HALT flag.
   //--- \param ev HALT evidence payload.
   //--- \return false only when fail_set_halt is true.
   bool           AppendHaltEvidence(const HaltEvidence &ev) override
                    { append_halt_calls++; last_halt = ev; return(!fail_set_halt); }
   //--- \brief Return fake HALT flag.
   //--- \return true when halted.
   bool           IsHalted() override { return(halted); }
   //--- \brief Clear fake HALT flag and increment counter.
   //--- \return true.
   bool           ClearHalt() override;
   //--- \brief Store fake filled ticket.
   //--- \return true.
   bool           WriteTicket(ulong ticket) override { ticket_value = ticket; ticket_set = true; return(true); }
   //--- \brief Read fake filled ticket.
   //--- \return true when a ticket is set.
   bool           ReadTicket(ulong &ticket) override { if(!ticket_set) return(false); ticket = ticket_value; return(true); }
   //--- \brief Store fake pending-order evidence.
   //--- \return true.
   bool           WritePendingOrder(ulong ticket, datetime submitted_ts) override;
   //--- \brief Read fake pending-order evidence.
   //--- \return true when pending evidence is set.
   bool           ReadPendingOrder(ulong &ticket, datetime &submitted_ts) override;
   //--- \brief Clear fake pending-order evidence.
   //--- \return true.
   bool           ClearPendingOrder() override;
   //--- \brief Claim, conflict, or stale-reclaim fake marker lease.
   //--- \return true for handled claim/conflict; false for invalid lease_secs.
   bool           MarkerClaimOrReclaim(datetime now,
                                       int lease_secs,
                                       long &out_token,
                                       ENUM_DUPLICATE_MARKER_STATUS &status) override;
   //--- \brief Heartbeat fake marker lease when token matches.
   //--- \param token [in,out] Current marker-owner token; advanced on success.
   //--- \param now Current timestamp.
   //--- \return true when token advances.
   bool           MarkerHeartbeat(long &token, datetime now) override;
   //--- \brief Check fake marker ownership.
   bool           MarkerIsOwner(long token) override { return(token > 0 && marker_owner == token); }
   //--- \brief Release fake marker lease when token matches.
   //--- \return true when marker_owner changes to -token.
   bool           MarkerRelease(long token) override;
   //--- \brief Fake integrity check.
   //--- \return true.
   bool           Verify() override { return(true); }
  };

//+------------------------------------------------------------------+
void FakeStateStore::Reset()
  {
   ArrayResize(m_scalars, 0);
   write_scalar_calls = 0;
   read_scalar_calls = 0;
   set_halt_calls = 0;
   append_halt_calls = 0;
   clear_halt_calls = 0;
   marker_claim_calls = 0;
   marker_heartbeat_calls = 0;
   marker_release_calls = 0;
   pending_write_calls = 0;
   pending_clear_calls = 0;
   snapshot_write_calls = 0;
   snapshot_read_calls = 0;
   halted = false;
   fail_set_halt = false;
   fail_clear_halt = false;
   fail_write_scalar = false;
   fail_write_snapshot = false;
   corrupt_snapshot = false;
   ticket_value = 0;
   ticket_set = false;
   pending_ticket = 0;
   pending_submitted_ts = 0;
   pending_set = false;
   marker_owner = 0;
   marker_hb_ts = 0;
   snapshot_set = false;
   runtime_isolated = false;
   snapshot_value.state = POSITION_STATE_UNKNOWN;
   snapshot_value.position_ticket = 0;
   snapshot_value.position_identifier = 0;
   snapshot_value.pending.ticket = 0;
   snapshot_value.pending.submitted_ts = 0;
   snapshot_value.pending.cancel_requested_ts = 0;
   snapshot_value.pending.cancel_origin = CANCEL_ORIGIN_NONE;
   snapshot_value.halted = false;
   snapshot_value.generation = 0;
  }

//+------------------------------------------------------------------+
bool FakeStateStore::WriteLifecycleSnapshot(const LifecycleSnapshot &snapshot)
  {
   snapshot_write_calls++;
   if(fail_write_snapshot)
      return(false);
//--- Mirror CStateStore: UNKNOWN is a migration sentinel and contradictory
//--- HALT aggregates are never published.
   if(snapshot.state < POSITION_STATE_IDLE || snapshot.state > POSITION_STATE_PENDING_CANCEL)
      return(false);
   if(snapshot.halted != (snapshot.state == POSITION_STATE_HALT))
      return(false);
   if(!WriteScalar("pos_state", (double)snapshot.state))
      return(false);
   long next_generation = (snapshot_set ? snapshot_value.generation + 1 : 1);
   snapshot_value = snapshot;
   snapshot_value.generation = next_generation;
   snapshot_set = true;
   ticket_value = snapshot.position_ticket;
   ticket_set = (snapshot.position_ticket != 0);
   pending_ticket = snapshot.pending.ticket;
   pending_submitted_ts = snapshot.pending.submitted_ts;
   pending_set = (snapshot.pending.ticket != 0);
   halted = snapshot.halted;
   return(true);
  }

//+------------------------------------------------------------------+
ENUM_STORE_READ_RESULT FakeStateStore::ReadLifecycleSnapshot(LifecycleSnapshot &snapshot)
  {
   snapshot_read_calls++;
   if(corrupt_snapshot)
      return(STORE_READ_CORRUPT);
   if(!snapshot_set)
      return(STORE_READ_ABSENT);
   snapshot = snapshot_value;
   return(STORE_READ_VALID);
  }

//+------------------------------------------------------------------+
bool FakeStateStore::_FindScalar(string scope, int &index)
  {
   for(int i = 0; i < ArraySize(m_scalars); i++)
     {
      if(m_scalars[i].scope == scope)
        {
         index = i;
         return(true);
        }
     }
   index = -1;
   return(false);
  }

//+------------------------------------------------------------------+
bool FakeStateStore::WriteScalar(string scope, double value)
  {
   write_scalar_calls++;
   if(fail_write_scalar)
      return(false);
   int idx = -1;
   if(!_FindScalar(scope, idx))
     {
      idx = ArraySize(m_scalars);
      ArrayResize(m_scalars, idx + 1);
      m_scalars[idx].scope = scope;
     }
   m_scalars[idx].value = value;
   return(true);
  }

//+------------------------------------------------------------------+
bool FakeStateStore::ReadScalar(string scope, double &value)
  {
   read_scalar_calls++;
   int idx = -1;
   if(!_FindScalar(scope, idx))
      return(false);
   value = m_scalars[idx].value;
   return(true);
  }

//+------------------------------------------------------------------+
bool FakeStateStore::IsDuplicate(string intent_id_hash)
  {
   double v = 0.0;
   return(ReadScalar("dup_" + intent_id_hash, v) && v >= 0.5);
  }

//+------------------------------------------------------------------+
bool FakeStateStore::SetHalt(const HaltEvidence &ev)
  {
   set_halt_calls++;
   last_halt = ev;
   if(fail_set_halt)
      return(false);
   halted = true;
   return(true);
  }

//+------------------------------------------------------------------+
bool FakeStateStore::ClearHalt()
  {
   clear_halt_calls++;
   if(fail_clear_halt)
      return(false);
   halted = false;
   return(true);
  }

//+------------------------------------------------------------------+
bool FakeStateStore::WritePendingOrder(ulong ticket, datetime submitted_ts)
  {
   pending_write_calls++;
   pending_ticket = ticket;
   pending_submitted_ts = submitted_ts;
   pending_set = true;
   return(true);
  }

//+------------------------------------------------------------------+
bool FakeStateStore::ReadPendingOrder(ulong &ticket, datetime &submitted_ts)
  {
   if(!pending_set)
      return(false);
   ticket = pending_ticket;
   submitted_ts = pending_submitted_ts;
   return(true);
  }

//+------------------------------------------------------------------+
bool FakeStateStore::ClearPendingOrder()
  {
   pending_clear_calls++;
   pending_ticket = 0;
   pending_submitted_ts = 0;
   pending_set = false;
   return(true);
  }

//+------------------------------------------------------------------+
bool FakeStateStore::MarkerClaimOrReclaim(datetime now,
                                          int lease_secs,
                                          long &out_token,
                                          ENUM_DUPLICATE_MARKER_STATUS &status)
  {
   marker_claim_calls++;
   out_token = 0;
   status = DUPLICATE_MARKER_CONFLICT;
   if(lease_secs <= 0)
      return(false);

   bool was_free = (marker_owner <= 0);
   bool stale = (!was_free && ((long)now - (long)marker_hb_ts) >= lease_secs);
   if(!was_free && !stale)
      return(true);

   long abs_owner = (marker_owner < 0 ? -marker_owner : marker_owner);
   long next_token = abs_owner + 1;
   marker_owner = next_token;
   marker_hb_ts = now;
   out_token = next_token;
   status = (stale ? DUPLICATE_MARKER_STALE_RECLAIMED : DUPLICATE_MARKER_ACTIVE);
   return(true);
  }

//+------------------------------------------------------------------+
bool FakeStateStore::MarkerHeartbeat(long &token, datetime now)
  {
   marker_heartbeat_calls++;
   if(token <= 0 || marker_owner != token)
      return(false);
   marker_owner = token + 1;
   marker_hb_ts = now;
   token = marker_owner;
   return(true);
  }

//+------------------------------------------------------------------+
bool FakeStateStore::MarkerRelease(long token)
  {
   marker_release_calls++;
   if(token <= 0 || marker_owner != token)
      return(false);
   marker_owner = -token;
   return(true);
  }

#endif // TRADESPINE_TEST_SUPPORT_FAKESTATESTORE_MQH
//+------------------------------------------------------------------+

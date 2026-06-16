//+------------------------------------------------------------------+
//|                                                   KeyBuilder.mqh |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Persistence/KeyBuilder.mqh                        |
//| @spec: SPEC-05  @tdd: TDD.05.04.e64a  @iplan: IPLAN-05           |
//|                                                                  |
//| Canonical identity hashing and terminal Global Variable key      |
//| builder. Raw account, symbol, and magic MUST NOT appear in the  |
//| generated key. All output keys are 19 characters ("ts_" + 16    |
//| uppercase hex digits), well within MT5's 63-char GV name limit. |
//|                                                                  |
//| Hash algorithm: FNV-1a 64-bit over the UTF-16 code units of     |
//|   "<account>|<symbol>|<magic>|<scope>"                           |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_PERSISTENCE_KEYBUILDER_MQH
#define TRADESPINE_PERSISTENCE_KEYBUILDER_MQH

//+------------------------------------------------------------------+
//| \brief CanonicalIdentity - four-field strategy identity used to  |
//|        derive deterministic, scope-tagged terminal GV keys and   |
//|        identity fingerprints.                                    |
//+------------------------------------------------------------------+
struct CanonicalIdentity
  {
   long   account; //!< MT5 account login number.
   string symbol;  //!< Instrument symbol (e.g. "WINM26").
   ulong  magic;   //!< EA magic number.
   string scope;   //!< GV namespace scope tag (e.g. "halt", "fp", "tkt_hi"). Must not contain '|'.
  };

//+------------------------------------------------------------------+
//| \brief CKeyBuilder - builds deterministic 19-char GV keys from   |
//|        a canonical strategy identity via FNV-1a 64-bit hashing.  |
//|        Raw identity fields are NOT recoverable from the key.     |
//+------------------------------------------------------------------+
class CKeyBuilder
  {
  private:
   //--- FNV-1a 64-bit hash constants split into 32-bit halves for portability.
   //--- offset_basis = 0xcbf29ce484222325  prime = 0x100000001b3
   static ulong FNV1a64(const string s);

  public:
   //--- \brief Build a deterministic, bounded GV key from a canonical identity.
   //--- \param id   Identity fields; scope selects the GV slot.
   //---             symbol and scope must not contain '|' (returns false if violated).
   //--- \param key  [out] 19-character GV key ("ts_" + 16 hex chars).
   //--- \return true on success; false if symbol or scope contains '|'.
   bool Build(const CanonicalIdentity &id, string &key);

   //--- \brief Recompute the key from \p expected and compare to \p key byte-for-byte.
   //--- \param key      Previously stored GV key to verify.
   //--- \param expected Identity to recompute the key from.
   //--- \return true if keys match; false on KeyCollision.
   bool Verify(const string key, const CanonicalIdentity &expected);

   //--- \brief Compute a double-safe identity fingerprint (lower 53 bits of
   //---        FNV-1a hash of "<account>|<symbol>|<magic>", excluding scope).
   //--- \param id  Identity fields (scope is ignored).
   //--- \return Exact double value ∈ [0, 2^53-1].
   double Fingerprint(const CanonicalIdentity &id);
  };

//+------------------------------------------------------------------+
ulong CKeyBuilder::FNV1a64(const string s)
  {
//--- FNV-1a 64-bit constants split into 32-bit halves to avoid
//--- potential compiler issues with very large integer literals.
//--- offset_basis = 0xcbf29ce484222325 (14695981039346656037)
//--- prime        = 0x00000100000001b3  (1099511628211)
   const ulong basis_hi = (ulong)0xcbf29ce4;
   const ulong basis_lo = (ulong)0x84222325;
   const ulong prime_hi = (ulong)0x00000100;
   const ulong prime_lo = (ulong)0x000001b3;
   ulong hash  = (basis_hi << 32) | basis_lo;
   ulong prime = (prime_hi << 32) | prime_lo;
   int   len   = StringLen(s);
   for(int i = 0; i < len; i++)
     {
      hash ^= (ulong)StringGetCharacter(s, i);
      hash *= prime;
     }
   return(hash);
  }

//+------------------------------------------------------------------+
bool CKeyBuilder::Build(const CanonicalIdentity &id, string &key)
  {
   if(StringFind(id.symbol, "|") >= 0 || StringFind(id.scope, "|") >= 0)
      return(false);
   string pre_hash = IntegerToString(id.account) + "|"
                   + id.symbol + "|"
                   + StringFormat("%I64u", id.magic) + "|"
                   + id.scope;
   ulong hash = FNV1a64(pre_hash);
   key = "ts_" + StringFormat("%016I64X", hash);
   return(StringLen(key) <= 63);
  }

//+------------------------------------------------------------------+
bool CKeyBuilder::Verify(const string key, const CanonicalIdentity &expected)
  {
   string expected_key;
   if(!Build(expected, expected_key))
      return(false);
   return(key == expected_key);
  }

//+------------------------------------------------------------------+
double CKeyBuilder::Fingerprint(const CanonicalIdentity &id)
  {
//--- Hash the raw identity without scope; mask to 53 bits for exact double storage.
   string raw = IntegerToString(id.account) + "|" + id.symbol + "|"
              + StringFormat("%I64u", id.magic);
   ulong  hash = FNV1a64(raw);
//--- 2^53 - 1 = 0x001FFFFFFFFFFFFF = 9007199254740991 (max exact integer in double)
   const ulong mask = (ulong)0x001FFFFFFFFFFFFF;
   ulong  safe = hash & mask;
   return((double)(long)safe); // long cast is lossless: safe ≤ 2^53-1 < LLONG_MAX
  }

#endif // TRADESPINE_PERSISTENCE_KEYBUILDER_MQH
//+------------------------------------------------------------------+

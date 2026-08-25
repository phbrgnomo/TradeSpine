//+------------------------------------------------------------------+
//| @code: Include/Position/LiveBrokerPositionView.mqh               |
//| @spec: SPEC-04 @tdd: TDD.04.04.c6e1 @iplan: IPLAN-04            |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_POSITION_LIVEBROKERPOSITIONVIEW_MQH
#define TRADESPINE_POSITION_LIVEBROKERPOSITIONVIEW_MQH

#include "Interfaces.mqh"
#include "../StdLib/Trade/PositionInfo.mqh"

//+------------------------------------------------------------------+
//| \brief Read-only terminal-backed current-position provider.      |
//+------------------------------------------------------------------+
class CLiveBrokerPositionView : public IBrokerPositionView
  {
  private:
   CPositionInfo m_position;
  bool          m_selected;
  public:
   //--- \brief Construct a provider with no selected terminal position.
   //--- \return void.
                 CLiveBrokerPositionView(void) : m_selected(false) {}
   //--- \brief Return the terminal's current position count.
   //--- \return Number of terminal positions.
   int           Total() override { return(PositionsTotal()); }
   //--- \brief Select one terminal position by zero-based index.
   //--- \param index Zero-based terminal position index.
   //--- \return true when selected; later accessors return safe fallbacks otherwise.
   bool          SelectByIndex(int index) override
                   { m_selected = m_position.SelectByIndex(index); return(m_selected); }
   //--- \brief Select one terminal position by ticket.
   //--- \param ticket Nonzero terminal position ticket.
   //--- \return true when selected; later accessors return safe fallbacks otherwise.
   bool          SelectByTicket(ulong ticket) override
                   { m_selected = (ticket > 0 && m_position.SelectByTicket(ticket)); return(m_selected); }
   //--- \brief Return the selected position ticket.
   //--- \return Selected ticket, or zero when no position is selected.
   ulong         Ticket() override { return(m_selected ? m_position.Ticket() : 0); }
   //--- \brief Return the selected position's stable identifier.
   //--- \return Selected identifier, or zero when no position is selected.
   ulong         Identifier() override { return(m_selected ? (ulong)m_position.Identifier() : 0); }
   //--- \brief Return the selected position symbol.
   //--- \return Selected symbol, or an empty string when no position is selected.
   string        Symbol() override { return(m_selected ? m_position.Symbol() : ""); }
   //--- \brief Return the selected position magic number.
   //--- \return Selected magic, or zero when no position is selected.
   ulong         Magic() override { return(m_selected ? (ulong)m_position.Magic() : 0); }
   //--- \brief Return the selected position side.
   //--- \return Selected type, or WRONG_VALUE when no position is selected.
   ENUM_POSITION_TYPE PositionType() override
                   { return(m_selected ? m_position.PositionType() : (ENUM_POSITION_TYPE)WRONG_VALUE); }
   //--- \brief Return the selected position volume.
   //--- \return Volume in lots, or zero when no position is selected.
   double        Volume() override { return(m_selected ? m_position.Volume() : 0.0); }
   //--- \brief Return the selected position stop loss.
   //--- \return Stop-loss price, or zero when no position is selected.
   double        StopLoss() override { return(m_selected ? m_position.StopLoss() : 0.0); }
   //--- \brief Return the selected position take profit.
   //--- \return Take-profit price, or zero when no position is selected.
   double        TakeProfit() override { return(m_selected ? m_position.TakeProfit() : 0.0); }
  };

#endif
//+------------------------------------------------------------------+

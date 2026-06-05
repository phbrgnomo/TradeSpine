//+X================================================================X+
//|                                                     IsNewBar.mqh |
//|              MQL5 Code:     Copyright © 2010,   Nikolay Kositsin |
//|                              Khabarovsk,   farria@mail.redcom.ru |
//+X================================================================X+
#property copyright "Copyright © 2010,   Nikolay Kositsin"
#property link "farria@mail.redcom.ru"
//+X================================================================X+
//| IsNewBar() function                                              |
//+X================================================================X+
bool IsNewBar(
    int             Number,     // Number of a call in the IsNewBar function in the program code of the Expert Advisor
    string          symbol,     // Symbol of a chart calculation of data is performed at
    ENUM_TIMEFRAMES timeframe   // Timeframe of a chart calculation of data is performed at
) {
   //----+
   static datetime Told[];
   datetime        Tnew;
   //----+ Declaration of a variable for storing sizes of arrays of variables
   static int Size_ = 0;
   //----+ Changing size of arrays of variables
   if(Number + 1 > Size_) {
      uint size = Number + 1;
      //----
      if(ArrayResize(Told, size) == -1) {
         string word = "";
         StringConcatenate(word, "IsNewBar( ", Number,
                           " ): Error!!! Failed to change sizes of arrays of variables!!!");
         Print(word);
         //----
         int error = GetLastError();
         ResetLastError();
         if(error > 4000) {
            StringConcatenate(word, "IsNewBar( ", Number, " ): Error code ", error);
            Print(word);
         }
         //----
         Size_ = -2;
         return (false);
      }
   }
   Tnew = SeriesInfoInteger(symbol, timeframe, SERIES_LASTBAR_DATE);
   if(Tnew != Told[Number]) {
      Told[Number] = Tnew;
      return (true);
   }
   //----+
   return (false);
}
//+X----------------------+ <<< The End >>> +-----------------------X+

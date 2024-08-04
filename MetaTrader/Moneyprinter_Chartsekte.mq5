//+------------------------------------------------------------------+
//|                                      Moneyprinter_Chartsekte.mq5 |
//|                                                           Tobias |
//|                                                                  |
//+------------------------------------------------------------------+
/*Vermögensverlaufskurve
29 / 30.10 9-17 Uhr ab 500€ CFD Mini Konto
*/

//Strategie:
string sStrategiebezeichnung = "Moneyprinter Chartsekte";

//Include
#include <Tobias_V2.mqh>

//Input Variablen
input int ZigZagAbweichung = 12;
input int OrderDistPoints = 150;
input int TpPoints = 300;
input int SlPoints = 150;
input int TslPoints = 10;
input int TslTriggerPoints = 6;
input int BarsN = 5; //???????
input int ExpirationHours = 50;
ulong MagicNummer = 20; //Magic Nummer
input double maxVerlust = 2; //maximaler Verlust in Prozent der Kontogröße
input double maxEinsatz = 20; //maximaler Einsatz in Prozet der Kontogröße

//Globale Variablen
double Anzahl_Kontrakte;
double Trailing_start_Long;
double Trailing_start_Short;
ENUM_POSITION_TYPE Buy_Sell;
MqlTradeResult result_Order={};

//Indikatoren
int handle_ZigZag;
double ZigZag[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   //Indikatoren
   handle_ZigZag = iCustom(_Symbol,PERIOD_CURRENT,"Examples\\ZigZag",ZigZagAbweichung);


//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   //Indikatoren Kopieren
   CopyBuffer(handle_ZigZag,0,0,1000,ZigZag);    

   ArraySetAsSeries(ZigZag,true);

   //ZigZag auswerten
   for(int i=0; i< ArraySize(ZigZag);i++)
   {
      if(ZigZag[i] == 0)
      {
         ArrayRemove(ZigZag,i,1);
         i--;
      }
   }
   ArrayRemove(ZigZag,3,WHOLE_ARRAY);

   //Long Pending Order
   if(Bid < ZigZag[ArrayMaximum(ZigZag,0,WHOLE_ARRAY)] - OrderDistPoints * Point() && !fcCheckPositionOpen(MagicNummer) && !fcCheckOrderOpen(MagicNummer))
   {
      Anzahl_Kontrakte = fcAnzahlKontrakte(_Symbol,maxVerlust,maxEinsatz,ZigZag[ArrayMaximum(ZigZag,0,WHOLE_ARRAY)],ZigZag[ArrayMaximum(ZigZag,0,WHOLE_ARRAY)]-SlPoints*Point());   
      fcOpenPendingOrder_Ablauf(sStrategiebezeichnung,_Symbol,PERIOD_CURRENT,MagicNummer,Anzahl_Kontrakte,ZigZag[ArrayMaximum(ZigZag,0,WHOLE_ARRAY)],ZigZag[ArrayMaximum(ZigZag,0,WHOLE_ARRAY)]-SlPoints*Point(),ZigZag[ArrayMaximum(ZigZag,0,WHOLE_ARRAY)]+TpPoints*Point(),ORDER_TYPE_BUY_STOP,ExpirationHours,result_Order);
      Trailing_start_Long = ZigZag[ArrayMaximum(ZigZag,0,WHOLE_ARRAY)] + TslTriggerPoints * Point();
   }
   //Short Pending Order
   if(Bid > ZigZag[ArrayMinimum(ZigZag,0,WHOLE_ARRAY)] + OrderDistPoints * Point() && !fcCheckPositionOpen(MagicNummer+1) && !fcCheckOrderOpen(MagicNummer+1))
   {
      Anzahl_Kontrakte = fcAnzahlKontrakte(_Symbol,maxVerlust,maxEinsatz,ZigZag[ArrayMinimum(ZigZag,0,WHOLE_ARRAY)],ZigZag[ArrayMinimum(ZigZag,0,WHOLE_ARRAY)]+SlPoints*Point());   
      fcOpenPendingOrder_Ablauf(sStrategiebezeichnung,_Symbol,PERIOD_CURRENT,MagicNummer+1,Anzahl_Kontrakte,ZigZag[ArrayMinimum(ZigZag,0,WHOLE_ARRAY)],ZigZag[ArrayMinimum(ZigZag,0,WHOLE_ARRAY)]+SlPoints*Point(),ZigZag[ArrayMinimum(ZigZag,0,WHOLE_ARRAY)]-TpPoints*Point(),ORDER_TYPE_SELL_STOP,ExpirationHours,result_Order);
      Trailing_start_Short = ZigZag[ArrayMinimum(ZigZag,0,WHOLE_ARRAY)] - TslTriggerPoints * Point();
   }

   //Trailing-Stop
   if(TslTriggerPoints > 0 && Bid >= Trailing_start_Long && fcCheckPositionOpen(MagicNummer))
   {
      fcTrailingStopLoss(MagicNummer,TslPoints);
   }
   if(TslTriggerPoints > 0 && Bid <= Trailing_start_Short && fcCheckPositionOpen(MagicNummer+1))
   {
      fcTrailingStopLoss(MagicNummer+1,TslPoints);
   }
  
  }
//+------------------------------------------------------------------+




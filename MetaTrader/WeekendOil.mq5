//+------------------------------------------------------------------+
//| 									 Weekend Oil                           |
//|                            Torsten David                         |
//+------------------------------------------------------------------+


// Trade
#include <Mql5Book\TradeHedge.mqh>
CTradeHedge Trade;
CPositions Positions;

// Price
#include <Mql5Book\Price.mqh>
CBars Price;

// Money management
#include <Mql5Book\MoneyManagement.mqh>

// Trailing stops
#include <Mql5Book\TrailingStops.mqh>
CTrailing Trail;

// Timer
#include <Mql5Book\Timer.mqh>
CTimer Timer;
CNewBar NewBar;

// Indicators 
#include <Mql5Book\Indicators.mqh>
CiMA FastMA;


//+------------------------------------------------------------------+
//| Expert information                                               |
//+------------------------------------------------------------------+

#property copyright "Torsten David"
#property version   "1.00"
#property description "Weekend Crude Oil Long EA"



//+------------------------------------------------------------------+
//| Input variables                                                  |
//+------------------------------------------------------------------+

input int symbolPastCommaDigits = 3;
input ulong Slippage = 3;
input ulong MagicNumber = 101;
input bool TradeOnNewBar = false;

sinput string MM; 	// Money Management
input bool UseMoneyManagement = false;
input double RiskPercent = 1;
input double FixedVolume = 1;

sinput string SL; 	// Stop Loss & Take Profit
input int StopLossPercent = 1.35;
input int TakeProfitPercent = 2.00;
//input int StopLoss = 80;
//input int TakeProfit = 1.6;

sinput string FaMA;	// Fast MA
input int FastMAPeriod = 5;
input ENUM_MA_METHOD FastMAMethod = 1;
input int FastMAShift = 0;
input ENUM_APPLIED_PRICE FastMAPrice = PRICE_CLOSE;

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+

ulong glBuyTicket, glSellTicket;
bool timeIsGoodToOpen;
bool timeIsGoodToClose;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
{
	FastMA.Init(_Symbol,_Period,FastMAPeriod,FastMAShift,FastMAMethod,FastMAPrice);
	
	Trade.MagicNumber(MagicNumber);
	Trade.Deviation(Slippage);
   return(0);
}



//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+

void OnTick()
{

	// Check for new bar
	bool newBar = true;
	int barShift = 0;
	
	

	double modifiedStopLoss = 0;
	double modifiedTakeProfit = 0;
	
	if(TradeOnNewBar == true) 
	{
		newBar = NewBar.CheckNewBar(_Symbol,_Period);
		barShift = 1;
	}
	
	
	// Update prices
	Price.Update(_Symbol,_Period);
	
	// Order placement
	if(newBar == true)
	{
		
		// Money management
		double tradeSize;
		if(UseMoneyManagement == true) tradeSize = MoneyManagement(_Symbol,FixedVolume,RiskPercent,modifiedStopLoss);
		else tradeSize = VerifyVolume(_Symbol,FixedVolume);
		
		MqlDateTime timeVar;
      TimeToStruct(TimeCurrent(), timeVar);
      
      
		if (timeVar.day_of_week == 5)
      {
          if(timeVar.hour == 18 && timeVar.min >= 30) {
            timeIsGoodToOpen = true;
          } else {
            timeIsGoodToOpen = false;
          }
      }
      
      if(timeVar.hour == 21 && timeVar.min >= 30) {
            timeIsGoodToClose = true;
       } else {
            timeIsGoodToClose = false;
       }
		
		// Open Buy order
		if(Positions.Buy(MagicNumber) == 0 && timeIsGoodToOpen && glBuyTicket == 0 && FastMA.Main(barShift) < Price.Close(barShift))
		{
			glBuyTicket = Trade.Buy(_Symbol,1);
			
			if(glBuyTicket > 0)
			{
				double openPrice = PositionOpenPrice(glBuyTicket);
				
				double takeProfitFactor = (100.00 + TakeProfitPercent) / 100.00;
				double stopLossFactor = (100.00-StopLossPercent) / 100.00;
				
				Print("Faktor TP");
				Print(takeProfitFactor);
				
				modifiedStopLoss = openPrice * stopLossFactor;
				modifiedTakeProfit = openPrice * takeProfitFactor;
				
				modifiedStopLoss = NormalizeDouble(modifiedStopLoss, symbolPastCommaDigits);
				modifiedTakeProfit = NormalizeDouble(modifiedTakeProfit, symbolPastCommaDigits);
				
				Print("Stopp");
				Print(modifiedStopLoss);
				Print("Profit");
				Print(modifiedTakeProfit);
				
				double buyStop = BuyStopLoss(_Symbol,modifiedStopLoss,openPrice);
				//if(buyStop > 0) AdjustBelowStopLevel(_Symbol,buyStop);
				
				double buyProfit = BuyTakeProfit(_Symbol,modifiedTakeProfit,openPrice);
				//if(buyProfit > 0) AdjustAboveStopLevel(_Symbol,buyProfit);
				
				Print("Stopp");
				Print(buyStop);
				Print("Profit");
				Print(buyProfit);
				
				//if(buyStop > 0 || buyProfit > 0) Trade.ModifyPosition(glBuyTicket,buyStop,buyProfit);
				glSellTicket = 0;
			} 
		}
		
	} // Order placement end
	
	
	// Get position tickets
	ulong tickets[];
	Positions.GetTickets(MagicNumber, tickets);
	int numTickets = ArraySize(tickets);
	
	//Close when 20:30 pm
	for(int i = 0; i < numTickets; i++) {
	   if(timeIsGoodToClose) {
	      Trade.Close(glBuyTicket);
			glBuyTicket = 0;
	   }
	  
	}


}



//+------------------------------------------------------------------+
//| 									 Pound Shorter 2022                    |
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



//+------------------------------------------------------------------+
//| Expert information                                               |
//+------------------------------------------------------------------+

#property copyright "Torsten David"
#property version   "1.00"
#property description "Pound Shorter Strategie inspiriert durch Stagge"



//+------------------------------------------------------------------+
//| Input variables                                                  |
//+------------------------------------------------------------------+

input int symbolDigits = 5;
input ulong Slippage = 3;
input ulong MagicNumber = 101;
input bool TradeOnNewBar = false;

sinput string MM; 	// Money Management
input bool UseMoneyManagement = true;
input double RiskPercent = 1;
input double FixedVolume = 0.1;

sinput string SL; 	// Stop Loss & Take Profit
input int StopLoss = 80;
input int TakeProfit = 0;


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
	
	int pointFactor = 1;
	
	if(symbolDigits == 5) {
	   pointFactor = 10;
	}
	
	int modifiedStopLoss = StopLoss * pointFactor;
	
	if(TradeOnNewBar == true) 
	{
		newBar = NewBar.CheckNewBar(_Symbol,_Period);
		barShift = 1;
	}
	
	
	// Update prices
	Price.Update(_Symbol,_Period);
	
	Print("New Bar:");
	Print(newBar);
	
	// Order placement
	if(newBar == true)
	{
		
		// Money management
		double tradeSize;
		if(UseMoneyManagement == true) tradeSize = MoneyManagement(_Symbol,FixedVolume,RiskPercent,modifiedStopLoss);
		else tradeSize = VerifyVolume(_Symbol,FixedVolume);
		
		MqlDateTime timeVar;
      TimeToStruct(TimeCurrent(), timeVar);
      
      Print("Day:");
      Print(timeVar.day_of_week);
      
      Print("Hour:");
      Print(timeVar.hour);
      
      Print("Minute:");
      Print(timeVar.min);
      
		if ((timeVar.day_of_week == 1) || (timeVar.day_of_week == 2) || (timeVar.day_of_week == 5))
      {
          if(timeVar.hour == 8 && timeVar.min >= 45) {
            timeIsGoodToOpen = true;
          } else {
            timeIsGoodToOpen = false;
          }
      }
      
      if(timeVar.hour == 14 && timeVar.min >= 00) {
            timeIsGoodToClose = true;
       } else {
            timeIsGoodToClose = false;
       }
		
		// Open sell order
		if(Positions.Sell(MagicNumber) == 0 && timeIsGoodToOpen)
		{
			glSellTicket = Trade.Sell(_Symbol,tradeSize);
			
			if(glSellTicket > 0)
			{
				double openPrice = PositionOpenPrice(glSellTicket);
				
				double sellStop = SellStopLoss(_Symbol,modifiedStopLoss,openPrice);
				if(sellStop > 0) sellStop = AdjustAboveStopLevel(_Symbol,sellStop);
				
				double sellProfit = SellTakeProfit(_Symbol,TakeProfit,openPrice);
				if(sellProfit > 0) sellProfit = AdjustBelowStopLevel(_Symbol,sellProfit);
				
				if(sellStop > 0 || sellProfit > 0) Trade.ModifyPosition(glSellTicket,sellStop,sellProfit);
				glBuyTicket = 0;
			} 
		}
		
	} // Order placement end
	
	
	// Get position tickets
	ulong tickets[];
	Positions.GetTickets(MagicNumber, tickets);
	int numTickets = ArraySize(tickets);
	
	//Close when 01:00 pm
	for(int i = 0; i < numTickets; i++) {
	   if(timeIsGoodToClose) {
	      Trade.Close(glSellTicket);
			glSellTicket = 0;
	   }
	  
	}


}



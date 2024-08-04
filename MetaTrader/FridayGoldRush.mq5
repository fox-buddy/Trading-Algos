//+------------------------------------------------------------------+
//| 									 Friday Gold Rush                      |
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
#property description "Friday Gold Rush Strategie"



//+------------------------------------------------------------------+
//| Input variables                                                  |
//+------------------------------------------------------------------+

input int symbolPastCommaDigits = 2;
input ulong Slippage = 3;
input ulong MagicNumber = 104;
input bool TradeOnNewBar = false;

sinput string MM; 	// Money Management
input bool UseMoneyManagement = true;
input double RiskPercent = 1;
input double FixedVolume = 0.1;

sinput string SL; 	// Stop Loss & Take Profit
input int StopLoss = 100;
input int TakeProfit = 200;

sinput string FaMA;	// Fast MA
input int FastMAPeriod = 34;
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
		double modifiedStopLoss = StopLoss * 100.00;
		double modifiedTakeProfit = TakeProfit * 100.00;
		if(UseMoneyManagement == true) tradeSize = MoneyManagement(_Symbol,FixedVolume,RiskPercent,modifiedStopLoss);
		else tradeSize = VerifyVolume(_Symbol,FixedVolume);
		
		MqlDateTime timeVar;
      TimeToStruct(TimeCurrent(), timeVar);
      
      
		if (timeVar.day_of_week == 4)
      {
          if(timeVar.hour == 23 && timeVar.min == 00) {
            timeIsGoodToOpen = true;
          } else {
            timeIsGoodToOpen = false;
          }
      }
      
      if (timeVar.day_of_week == 5)
      {
          if(timeVar.hour == 23 && timeVar.min == 00) {
            timeIsGoodToClose = true;
          } else {
            timeIsGoodToClose = false;
          }
      }
		
		// Open Buy order
		if(Positions.Buy(MagicNumber) == 0 && timeIsGoodToOpen && glBuyTicket == 0 && FastMA.Main(barShift) > Price.Close(barShift))
		{
			glBuyTicket = Trade.Buy(_Symbol,tradeSize);
			
			if(glBuyTicket > 0)
			{
				double openPrice = PositionOpenPrice(glBuyTicket);
				
				double buyStop = BuyStopLoss(_Symbol, modifiedStopLoss, openPrice);
				if(buyStop > 0) AdjustBelowStopLevel(_Symbol,buyStop);
				
				double buyProfit = BuyTakeProfit(_Symbol, modifiedTakeProfit, openPrice);
				if(buyProfit > 0) AdjustAboveStopLevel(_Symbol,buyProfit);
				
				if(buyStop > 0 || buyProfit > 0) Trade.ModifyPosition(glBuyTicket,buyStop,buyProfit);
				glSellTicket = 0;
			} 
		}
		
	} // Order placement end
	
	
	// Get position tickets
	ulong tickets[];
	Positions.GetTickets(MagicNumber, tickets);
	int numTickets = ArraySize(tickets);
	
	//Close when 22:00 pm
	for(int i = 0; i < numTickets; i++) {
	   if(timeIsGoodToClose) {
	      Trade.Close(glBuyTicket);
			glBuyTicket = 0;
	   }
	  
	}


}



//+------------------------------------------------------------------+
//| 									 Expert Advisor HLHB Trend Catcher     |
//|                            Torsten David                         |
//|                            Strategievorlage von Baby Pips        |
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
CiMA SlowMA;
CiRSI RSI;
CiMACD macdFilter;

//+------------------------------------------------------------------+
//| Expert information                                               |
//+------------------------------------------------------------------+

#property copyright "Torsten David"
#property version   "1.00"
#property description "Strategieidee von Baby Pips"




//+------------------------------------------------------------------+
//| Input variables                                                  |
//+------------------------------------------------------------------+

input ulong Slippage = 3;
input ulong MagicNumber = 111;
input bool TradeOnNewBar = true;
input int symbolDigits = 5;

sinput string MM; 	// Money Management
input bool UseMoneyManagement = true;
input double RiskPercent = 1;
input double FixedVolume = 0.1;

sinput string SL; 	// Stop Loss & Take Profit
input int StopLoss = 200;
input int TakeProfit = 0;


sinput string MACD;	// MACD
input int MACDPeriodFast = 12;
input int MACDPeriodSlow = 26;
input ENUM_APPLIED_PRICE MACDPrice = PRICE_CLOSE;


//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+

ulong glBuyTicket, glSellTicket;
bool anotherLongPossible;
bool anotherShortPossible;
bool timeIsGoodToOpen;
bool timeIsGoodToClose;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
{

	macdFilter.Init(_Symbol, _Period, MACDPeriodFast, MACDPeriodSlow, 9, MACDPrice);
	
	Trade.MagicNumber(MagicNumber);
	Trade.Deviation(Slippage);
	
	anotherLongPossible = true;
	anotherShortPossible = true;
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
	int modifiedTakeProfit = TakeProfit * pointFactor;
	
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
		MqlDateTime timeVar;
      TimeToStruct(TimeCurrent(), timeVar);
      
		// Money management
		double tradeSize;
		if(UseMoneyManagement == true) tradeSize = MoneyManagement(_Symbol,FixedVolume,RiskPercent,modifiedStopLoss);
		else tradeSize = VerifyVolume(_Symbol,FixedVolume);
		
		bool longCondition = false;
		bool shortCondition = false;
		
		if (timeVar.hour == 15 && timeVar.min == 00) {
            if(macdFilter.Main(barShift) > 0) {
   		      longCondition = true;
   		      shortCondition = false;
   	      }
		
		      if(macdFilter.Main(barShift) < 0) {
      		   longCondition = false;
      		   shortCondition = true;
            }
       }
      
      if(timeVar.hour == 23 && timeVar.min == 00) {
            timeIsGoodToClose = true;
       } else {
            timeIsGoodToClose = false;
       }
		
		
		
		// Open buy order
		if(Positions.Buy(MagicNumber) == 0 && longCondition && anotherLongPossible)
		{
		   // Close current position
			if(glSellTicket > 0)
			{
			   Trade.Close(glSellTicket);
			   glSellTicket = 0;
			}
			
			glBuyTicket = Trade.Buy(_Symbol,tradeSize);
			anotherShortPossible = true;
			anotherLongPossible = false;
		
			if(glBuyTicket > 0)  
			{
				double openPrice = PositionOpenPrice(glBuyTicket);
				
				double buyStop = BuyStopLoss(_Symbol,modifiedStopLoss,openPrice);
				if(buyStop > 0) AdjustBelowStopLevel(_Symbol,buyStop);
				
				double buyProfit = BuyTakeProfit(_Symbol,modifiedTakeProfit,openPrice);
				if(buyProfit > 0) AdjustAboveStopLevel(_Symbol,buyProfit);
				
				if(buyStop > 0 || buyProfit > 0) Trade.ModifyPosition(glBuyTicket,buyStop,buyProfit);
			} 
		}
		
		
		// Open sell order
		if(Positions.Sell(MagicNumber) == 0 && shortCondition && anotherShortPossible)
		{
		   // Close current position
		   if(glBuyTicket > 0)
			{
			   Trade.Close(glBuyTicket);
			   glBuyTicket = 0;
			}
			
			glSellTicket = Trade.Sell(_Symbol,tradeSize);
			anotherShortPossible = false;
			anotherLongPossible = true;
			
			if(glSellTicket > 0)
			{
				double openPrice = PositionOpenPrice(glSellTicket);
				
				double sellStop = SellStopLoss(_Symbol,modifiedStopLoss,openPrice);
				if(sellStop > 0) sellStop = AdjustAboveStopLevel(_Symbol,sellStop);
				
				double sellProfit = SellTakeProfit(_Symbol,modifiedTakeProfit,openPrice);
				if(sellProfit > 0) sellProfit = AdjustBelowStopLevel(_Symbol,sellProfit);
				
				if(sellStop > 0 || sellProfit > 0) Trade.ModifyPosition(glSellTicket,sellStop,sellProfit);
			} 
		}
		
	} // Order placement end
	
	
	// Get position tickets
	ulong tickets[];
	Positions.GetTickets(MagicNumber, tickets);
	int numTickets = ArraySize(tickets);
	

}



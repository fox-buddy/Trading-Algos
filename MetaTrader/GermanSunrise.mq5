//+------------------------------------------------------------------+
//| 									 German Sunrise                        |
//|                            Torsten David                         |
//|                            Dax Mean Reversion                    |            
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

CiMA SignalMA;
CiMA FastMA;
CiMA MiddleMA;
CiMA SlowMA;
CiRSI RSI;
CiStochastic StoCH;

//+------------------------------------------------------------------+
//| Expert information                                               |
//+------------------------------------------------------------------+

#property copyright "Torsten David"
#property version   "1.00"
#property description "German Sunrise"




//+------------------------------------------------------------------+
//| Input variables                                                  |
//+------------------------------------------------------------------+

input ulong Slippage = 3;
input ulong MagicNumber = 102;
input bool TradeOnNewBar = true;
input int symbolDigits = 5;

sinput string MM; 	// Money Management
input bool UseMoneyManagement = true;
input double RiskPercent = 1;
input double FixedVolume = 0.1;

sinput string SL; 	// Stop Loss & Take Profit
input int StopLoss = 0;
input int TakeProfit = 0;

sinput string SiMA;	// Signal MA
input int SignalMAPeriod = 34;
input ENUM_MA_METHOD SignalMAMethod = 1;
input int SignalMAShift = 0;
input ENUM_APPLIED_PRICE SignalMAPrice = PRICE_CLOSE;

sinput string FaMA;	// Fast MA
input int FastMAPeriod = 34;
input ENUM_MA_METHOD FastMAMethod = 1;
input int FastMAShift = 0;
input ENUM_APPLIED_PRICE FastMAPrice = PRICE_CLOSE;

sinput string MiMa;	// Middle MA
input int MiddleMAPeriod = 50;
input ENUM_MA_METHOD MiddleMAMethod = 1;
input int MiddleMAShift = 0;
input ENUM_APPLIED_PRICE MiddleMAPrice = PRICE_CLOSE;

sinput string SlMA;	// Slow MA
input int SlowMAPeriod = 100;
input ENUM_MA_METHOD SlowMAMethod = 1;
input int SlowMAShift = 0;
input ENUM_APPLIED_PRICE SlowMAPrice = PRICE_CLOSE;

sinput string stochFilter;	// Stochastik
input int stochPeriod = 14;
input int kSmooth = 1;
input int dSmooth = 3;
input int stochShift = 0;
input ENUM_APPLIED_PRICE stochPrice = PRICE_CLOSE;


//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+

ulong glBuyTicket, glSellTicket;
bool anotherLongPossible;
bool anotherShortPossible;
bool stochastikOversold;
bool stochastikOverbought;
bool stochastikNeutral;
bool timeIsGoodToCloseLong;
bool timeIsGoodToCloseShort;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
{
   SignalMA.Init(_Symbol,_Period,SignalMAPeriod,SignalMAShift,SignalMAMethod,SignalMAPrice);
   FastMA.Init(_Symbol,_Period,FastMAPeriod,FastMAShift,FastMAMethod,FastMAPrice);
   MiddleMA.Init(_Symbol,_Period,MiddleMAPeriod,MiddleMAShift,MiddleMAMethod,MiddleMAPrice);
	SlowMA.Init(_Symbol,_Period,SlowMAPeriod,SlowMAShift,SlowMAMethod,SlowMAPrice);
	StoCH.Init(_Symbol, _Period,stochPeriod,dSmooth,kSmooth,MODE_SMA,STO_LOWHIGH);
	
	Trade.MagicNumber(MagicNumber);
	Trade.Deviation(Slippage);
	
	anotherLongPossible = true;
	anotherShortPossible = true;
	
	stochastikNeutral = false;
	stochastikOverbought = false;
	stochastikOversold = false;
	
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
		
		// Money management
		double tradeSize;
		if(UseMoneyManagement == true) tradeSize = MoneyManagement(_Symbol,FixedVolume,RiskPercent,modifiedStopLoss);
		else tradeSize = VerifyVolume(_Symbol,FixedVolume);
		
		bool longCondition = false;
		bool shortCondition = false;
		
		bool signalMaLongCondition = false;
		bool signalMaShortCondition = false;
		
		bool longTrend = false;
		bool shortTrend = false;
		
		if(FastMA.Main(barShift) > MiddleMA.Main(barShift) > SlowMA.Main(barShift)) {
		   longTrend = true;
		   shortTrend = false;
		}
		
		if(FastMA.Main(barShift) < MiddleMA.Main(barShift) < SlowMA.Main(barShift)) {
		   longTrend = false;
		   shortTrend = true;
		}
		
		if(StoCH.Main(barShift) < 20) {
		   stochastikOversold = true;
		   stochastikOverbought = false;
		}
		
		if(StoCH.Main(barShift) > 80) {
		   stochastikOversold = false;
		   stochastikOverbought = true;
		}
		
      if(StoCH.Main(barShift) > 20 && StoCH.Main(barShift) < 80) {
         stochastikNeutral = true;
      }
      
      if(Price.Close(barShift) > SignalMA.Main(barShift)) {
         signalMaLongCondition = true;
         signalMaShortCondition = false;
      }
      
      if(Price.Close(barShift) < SignalMA.Main(barShift)) {
         signalMaLongCondition = false;
         signalMaShortCondition = true;
      }
      
      if (Positions.Buy(MagicNumber) != 0 && Price.Close(barShift) < SignalMA.Main(barShift))
      {
         timeIsGoodToCloseLong = true;
         timeIsGoodToCloseShort = false;
      }
      
      if (Positions.Sell(MagicNumber) != 0 && Price.Close(barShift) > SignalMA.Main(barShift))
      {
         timeIsGoodToCloseLong = false;
         timeIsGoodToCloseShort = true;
      }
      
      if(longTrend && stochastikNeutral && stochastikOversold && signalMaLongCondition) {
         longCondition = true;
         shortCondition = false;
      }
      
      if(shortTrend && stochastikNeutral && stochastikOverbought && signalMaShortCondition) {
         longCondition = false;
         shortCondition = true;
      }
      
      //Print("Stochastik Oversold");
      //Print(stochastikOversold);
      //Print("Stochastik Overbought");
      //Print(stochastikOverbought);
      //Print("Stochastik Neutral");
      //Print(stochastikNeutral);
      
      Print("Fast");
      Print(FastMA.Main(barShift));
      Print("Middle");
      Print(MiddleMA.Main(barShift));
      Print("Slow");
      Print(SlowMA.Main(barShift));
      
      Print("Longtrend");
      Print(longTrend);
      Print("ShortTrend");
      Print(shortTrend);
      
      //Print("signalMaLongCondition");
      //Print(signalMaLongCondition);
      //Print("signalMaShortCondition");
      //Print(signalMaShortCondition);
		
		
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
			
			stochastikNeutral = false;
      	stochastikOverbought = false;
      	stochastikOversold = false;
		
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
			
			stochastikNeutral = false;
      	stochastikOverbought = false;
      	stochastikOversold = false;
			
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
	
	//Close when to Close Buy Orders
	for(int i = 0; i < numTickets; i++) {
	   if(timeIsGoodToCloseLong) {
	      Trade.Close(glBuyTicket);
			glBuyTicket = 0;
	   }
	   
	   if(timeIsGoodToCloseShort) {
	      Trade.Close(glSellTicket);
			glSellTicket = 0;
	   }
	  
	}

}



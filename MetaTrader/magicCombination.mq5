//+------------------------------------------------------------------+
//|                                 Bands/RSI CounterTrend (Hedging) |
//|                                                     Andrew Young |
//|                                 http://www.expertadvisorbook.com |
//+------------------------------------------------------------------+

#property copyright "Andrew Young"
#property link      "http://www.expertadvisorbook.com"
#property description "A counter-trend trading system using Bollinger Bands and RSI for hedging accounts"

/*
 Creative Commons Attribution-NonCommercial 3.0 Unported
 http://creativecommons.org/licenses/by-nc/3.0/

 You may use this file in your own personal projects. You
 may modify it if necessary. You may even share it, provided
 the copyright above is present. No commercial use permitted. 
*/


// Trade
#include <Mql5Book\TradeHedge.mqh>
CTradeHedge Trade;
CPositions Positions;

// Price
#include <Mql5Book\Price.mqh>
CBars Bar;

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
CiBollinger Bands;
CiRSI RSI;
CiMA FastMA;


//+------------------------------------------------------------------+
//| Input variables                                                  |
//+------------------------------------------------------------------+

input ulong Slippage = 3;
input ulong MagicNumber = 43;
input bool TradeOnNewBar = true;

sinput string MM; 	// Money Management
input bool UseMoneyManagement = true;
input double RiskPercent = 1;
input double FixedVolume = 0.1;

sinput string SL; 	// Stop Loss & Take Profit
input int StopLoss = 1000;
input int TakeProfit = 2000;

sinput string TS;		// Trailing Stop
input bool UseTrailingStop = false;
input int TrailingStop = 0;
input int MinimumProfit = 0;
input int Step = 0; 

sinput string BE;		// Break Even
input bool UseBreakEven = false;
input int BreakEvenProfit = 0;
input int LockProfit = 0;

sinput string BB;		// Bollinger Bands
input int BandsPeriod = 20;
input int BandsShift = 0;
input double BandsDeviation = 2;
input ENUM_APPLIED_PRICE BandsPrice = PRICE_CLOSE; 

sinput string RS;	// RSI
input int RSIPeriod = 2;
input ENUM_APPLIED_PRICE RSIPrice = PRICE_CLOSE;

sinput string FaMA;	// Fast MA
input int FastMAPeriod = 50;
input ENUM_MA_METHOD FastMAMethod = 1;
input int FastMAShift = 0;
input ENUM_APPLIED_PRICE FastMAPrice = PRICE_CLOSE;

sinput string TI; 	// Timer
input bool UseTimer = false;
input int StartHour = 0;
input int StartMinute = 0;
input int EndHour = 0;
input int EndMinute = 0;
input bool UseLocalTime = false;



//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+

ulong glBuyTicket, glSellTicket;

enum Signal
{
	SIGNAL_BUY,
	SIGNAL_SELL,
	SIGNAL_NONE,
};

Signal glSignal;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
{
	Bands.Init(_Symbol,_Period,BandsPeriod,BandsShift,BandsDeviation,BandsPrice);
	RSI.Init(_Symbol,_Period,RSIPeriod,RSIPrice);
	
	Trade.Deviation(Slippage);
	Trade.MagicNumber(MagicNumber);
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
	
	
	// Timer
	bool timerOn = true;
	if(UseTimer == true)
	{
		timerOn = Timer.DailyTimer(StartHour,StartMinute,EndHour,EndMinute,UseLocalTime);
	}
	
	
	// Update prices
	Bar.Update(_Symbol,_Period);
	
	
	// Order placement
	if(newBar == true && timerOn == true)
	{
		
		// Money management
		double tradeSize;
		if(UseMoneyManagement == true) tradeSize = MoneyManagement(_Symbol,FixedVolume,RiskPercent,StopLoss);
		else tradeSize = VerifyVolume(_Symbol,FixedVolume);
		
		
		// Open positions
		ulong buyTickets[], sellTickets[];
		Positions.GetBuyTickets(MagicNumber, buyTickets);
		glBuyTicket = buyTickets[0];
		
		Positions.GetSellTickets(MagicNumber, sellTickets);
		glSellTicket = sellTickets[0];
		
		
		// Trade signal
		if(Bar.Close(barShift) <= Bands.Lower(barShift) && RSI.Main(barShift) > 30 && RSI.Main(barShift) < 50) glSignal = SIGNAL_BUY;
		else if(Bar.Close(barShift) >= Bands.Upper(barShift) && RSI.Main(barShift) < 70 && RSI.Main(barShift) > 50) glSignal = SIGNAL_SELL;
		
		
		// Open buy order
		if(glSignal == SIGNAL_BUY && Bar.Close(barShift) > Bands.Lower(barShift) && Bar.Close(barShift+1) <= Bands.Lower(barShift+1) && Positions.Buy(MagicNumber) == 0 && Bar.Close(barShift) >= FastMA.Main(barShift)) 
		{
			if(glSellTicket > 0)
			{
			   Trade.Close(glSellTicket);
			}
			
			glBuyTicket = Trade.Buy(_Symbol,tradeSize);
		
			if(glBuyTicket > 0)  
			{
				double openPrice = PositionOpenPrice(glBuyTicket);
				
				double buyStop = BuyStopLoss(_Symbol,StopLoss,openPrice);
				if(buyStop > 0) AdjustBelowStopLevel(_Symbol,buyStop);
				
				double buyProfit = BuyTakeProfit(_Symbol,TakeProfit,openPrice);
				if(buyProfit > 0) AdjustAboveStopLevel(_Symbol,buyProfit);
				
				if(buyStop > 0 || buyProfit > 0) Trade.ModifyPosition(glBuyTicket,buyStop,buyProfit);
				
				glSignal = SIGNAL_NONE;
			} 
		}
		
		
		// Open sell order
		if(glSignal == SIGNAL_SELL && Bar.Close(barShift) < Bands.Upper(barShift) && Bar.Close(barShift+1) >= Bands.Upper(barShift+1) && Positions.Sell(MagicNumber) == 0 && Bar.Close(barShift) <= FastMA.Main(barShift)) 
		{
			if(glBuyTicket > 0)
			{
			   Trade.Close(glBuyTicket);
			}
			
			glSellTicket = Trade.Sell(_Symbol,tradeSize);
			
			if(glSellTicket > 0)
			{
				double openPrice = PositionOpenPrice(glSellTicket);
				
				double sellStop = SellStopLoss(_Symbol,StopLoss,openPrice);
				if(sellStop > 0) sellStop = AdjustAboveStopLevel(_Symbol,sellStop);
				
				double sellProfit = SellTakeProfit(_Symbol,TakeProfit,openPrice);
				if(sellProfit > 0) sellProfit = AdjustBelowStopLevel(_Symbol,sellProfit);
				
				if(sellStop > 0 || sellProfit > 0) Trade.ModifyPosition(glSellTicket,sellStop,sellProfit);
				
				glSignal = SIGNAL_NONE;
			} 
		}
		
	}	// Order placement end
	
	
	// Get position tickets
	ulong tickets[];
	Positions.GetTickets(MagicNumber, tickets);
	int numTickets = ArraySize(tickets);
	


}



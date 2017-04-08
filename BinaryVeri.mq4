//+------------------------------------------------------------------+
//|                                                   BinaryVeri.mq4 |
//|                           Copyright 2017, Palawan Software, Ltd. |
//|                             https://coconala.com/services/204383 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Palawan Software, Ltd."
#property link      "https://coconala.com/services/204383"
#property description "Author: Kotaro Hashimoto <hasimoto.kotaro@gmail.com>"
#property version   "1.00"
#property strict

input int Band_Period = 20;
input int RSI_Period = 14;
input int Close_TimeOut = 5;

input int Start_Time = 0;
input int End_Time = 24;

input double Entry_Lot = 0.1;
input int Magic_Number = 1;

string thisSymbol;
double minLot;
double maxLot;

int signal() {

  if(iOpen(thisSymbol, PERIOD_CURRENT, 1) < iClose(thisSymbol, PERIOD_CURRENT, 1)) {
    if(iBands(thisSymbol, PERIOD_CURRENT, Band_Period, 2, 0, PRICE_WEIGHTED, 1, 1) < iClose(thisSymbol, PERIOD_CURRENT, 1)) {
      if(iHighest(thisSymbol, PERIOD_CURRENT, MODE_HIGH, 20, 2) < iHigh(thisSymbol, PERIOD_CURRENT, 1)) {
        if(70.0 < iRSI(thisSymbol, PERIOD_CURRENT, RSI_Period, PRICE_WEIGHTED, 1)) {
          return OP_SELL;
        }
      }
    }
  }
  else {
    if(iClose(thisSymbol, PERIOD_CURRENT, 1) < iBands(thisSymbol, PERIOD_CURRENT, Band_Period, 2, 0, PRICE_WEIGHTED, 2, 1)) {
      if(iLow(thisSymbol, PERIOD_CURRENT, 1) < iLowest(thisSymbol, PERIOD_CURRENT, MODE_LOW, 20, 2)) {
        if(iRSI(thisSymbol, PERIOD_CURRENT, RSI_Period, PRICE_WEIGHTED, 1) < 30.0) {
          return OP_BUY;
        }
      }
    }  
  }

  return -1;
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

  thisSymbol = Symbol();
  minLot = MarketInfo(Symbol(), MODE_MINLOT);
  maxLot = MarketInfo(Symbol(), MODE_MAXLOT);

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

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
      
        if(OrderType() == OP_BUY) {
          if(OrderOpenTime() + 60 * Close_TimeOut < TimeCurrent()) {
            bool closed = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Bid, Digits), 0);
          }
        }
        else if(OrderType() == OP_SELL) {
          if(OrderOpenTime() + 60 * Close_TimeOut < TimeCurrent()) {
            bool closed = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Ask, Digits), 0);
          }
        }
        
        return;
      }
    }
  }

  if(Entry_Lot < minLot || maxLot < Entry_Lot) {
    Print("lot size invalid, min = ", minLot, ", max = ", maxLot);
    return;
  }

  if(!(Start_Time <= Hour() && Hour() < End_Time)) {
    return;
  }  

  int s = signal();
  if(s == -1) {
    return;
  }
  else if(s == OP_SELL) {
    int ticket = OrderSend(thisSymbol, OP_SELL, Entry_Lot, NormalizeDouble(Bid, Digits), 3, 0, 0, NULL, Magic_Number);
  }
  else if(s == OP_BUY) {
    int ticket = OrderSend(thisSymbol, OP_BUY, Entry_Lot, NormalizeDouble(Ask, Digits), 3, 0, 0, NULL, Magic_Number);
  }
}
//+------------------------------------------------------------------+

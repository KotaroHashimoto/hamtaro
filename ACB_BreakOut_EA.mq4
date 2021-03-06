//+------------------------------------------------------------------+
//|                                              ACB_BreakOut_EA.mq4 |
//|                           Copyright 2017, Palawan Software, Ltd. |
//|                             https://coconala.com/services/204383 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Palawan Software, Ltd."
#property link      "https://coconala.com/services/204383"
#property description "Author: Kotaro Hashimoto <hasimoto.kotaro@gmail.com>"
#property version   "1.00"
#property strict

enum exitMethod {
   SPLIT = 0,
   QUICK = 1,
   FIRST = 2,
   FINAL = 3
};

input exitMethod Exit_Method = SPLIT;
input double Stop_Loss_Percentage = 1.0;
input int Open_Time = 0;
input int Close_Time = 24;
input bool EMA_Filter = False;
input int EMA_Period = 200;
input int Friday_Close_Time = 23;
input int Magic_Number = 1;

const string symbolSuffix = "-cd";

double stopLoss;
double entryPrice;
double quickProfit;
double firstTarget;
double trailQuick;
double trailFirst;
double finalTarget;
int signal;

string thisSymbol;
double minSL;
double minLot;
double maxLot;
double lotStep;
double lotSize;

int positionCount;

const string indName = "Market/ACB Breakout Arrows";

bool getIndicatorValues() {

  stopLoss = ObjectGetDouble(0, "StopLoss", OBJPROP_PRICE);
  entryPrice = ObjectGetDouble(0, "Entry", OBJPROP_PRICE);
  quickProfit = ObjectGetDouble(0, "FirstTarget", OBJPROP_PRICE);
  firstTarget = ObjectGetDouble(0, "Target1", OBJPROP_PRICE);
  finalTarget = ObjectGetDouble(0, "Target2", OBJPROP_PRICE);
  
  trailQuick = quickProfit;
  trailFirst = firstTarget;
  
  switch(Exit_Method) {
    case QUICK:
      firstTarget = quickProfit;
      finalTarget = quickProfit;
      break;
    case FIRST:
      quickProfit = firstTarget;
      finalTarget = firstTarget;
      break;
    case FINAL:
      quickProfit = finalTarget;
      firstTarget = finalTarget;
      break;
  } 

  if(iCustom(NULL, 0, indName, 0, 1)) {
    signal = OP_BUY;
    stopLoss = iCustom(NULL, 0, indName, 2, 1);
    Print("Buy Signal, entryPrice: ", entryPrice, " quickProfit: ", quickProfit, " firstTarget:", firstTarget, " finalTarget: ", finalTarget);
  }
  else if(iCustom(NULL, 0, indName, 1, 1)) {
    signal = OP_SELL;
    stopLoss = iCustom(NULL, 0, indName, 3, 1);
    Print("Sell Signal, entryPrice: ", entryPrice, " quickProfit: ", quickProfit, " firstTarget:", firstTarget, " finalTarget: ", finalTarget);
  }
  else {
    signal = -1;
  }

  return (signal != -1);
}

bool determineFilter() {

  if(!EMA_Filter) {
    return True;
  }

  double ema = iMA(Symbol(), PERIOD_D1, EMA_Period, 0, MODE_EMA, PRICE_WEIGHTED, 0);
  if(signal == OP_BUY) {
    return ema < Ask;
  }
  else if(signal == OP_SELL) {
    return Bid < ema;
  }
  else {
    return False;
  }
}


void calcLot(double priceDiff, double& quickLot, double& targetLot) {

  double totalLot = (AccountEquity() * Stop_Loss_Percentage / 100.0) / (priceDiff * lotSize);

  string base = StringSubstr(thisSymbol, 3, 3);
  if(StringCompare(base, "JPY") != 0) {
    double basejpy = (MarketInfo(base + "JPY" + symbolSuffix, MODE_ASK) + MarketInfo(base + "JPY" + symbolSuffix, MODE_BID)) / 2.0;
    totalLot /= basejpy;
  }

  targetLot = MathFloor(totalLot / (3.0 * lotStep)) * lotStep;
  quickLot = MathFloor((totalLot - (targetLot * 2.0)) / lotStep) * lotStep;
  
  if(maxLot < targetLot) {
    targetLot = maxLot;
  }
  if(maxLot < quickLot) {
    quickLot = maxLot;
  }
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

  stopLoss = 0.0;
  entryPrice = 0.0;
  quickProfit = 0.0;
  firstTarget = 0.0;
  finalTarget = 0.0;
  signal = -1;

  thisSymbol = Symbol();

  minSL = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
  minLot = MarketInfo(Symbol(), MODE_MINLOT);
  maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
  lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
  lotSize = MarketInfo(Symbol(), MODE_LOTSIZE);
  
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

void trailPosition(int direction) {

  if(direction == OP_BUY) {
    if(trailFirst < Bid && minSL < (Bid - trailQuick) && OrderStopLoss() < trailQuick) {
      bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(trailQuick, Digits), OrderTakeProfit(), 0);
    }
    else if(trailQuick < Bid && minSL < (Bid - OrderOpenPrice()) && OrderStopLoss() < OrderOpenPrice()) {
      bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(OrderOpenPrice(), Digits), OrderTakeProfit(), 0);
    }
  }
  else if(direction == OP_SELL) {
    if(Ask < trailFirst && minSL < (trailQuick - Ask) && trailQuick < OrderStopLoss()) {
      bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(trailQuick, Digits), OrderTakeProfit(), 0);
    }
    else if(Ask < trailQuick && minSL < (OrderOpenPrice() - Ask) && OrderOpenPrice() < OrderStopLoss()) {
      bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(OrderOpenPrice(), Digits), OrderTakeProfit(), 0);
    }
  }
}

bool isFridayNight() {
  return (DayOfWeek() == 5 && Friday_Close_Time <= Hour());
}

void scanPositions() {

  positionCount = 0;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
        int direction = OrderType();

        if(direction == OP_BUY) {
          positionCount ++;
          if(signal == OP_SELL || isFridayNight()) {
            if(OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Bid, Digits), 3)) {
              positionCount --;
              i = -1;
            }
          }
        }
        else if(direction == OP_SELL) {
          positionCount --;
          if(signal == OP_BUY || isFridayNight()) {
            if(OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Ask, Digits), 3)) {
              positionCount ++;
              i = -1;
            }
          }
        }

        trailPosition(direction);
      }
    }
  }
}


bool openPositions() {

  if(signal == -1) {
    return False;
  }
  else if(!determineFilter()) {
    Print("Signal received, but opposite direction to the major trend.");
    return False;
  }

  double quickLot = 0.0;
  double targetLot = 0.0;

  if(signal == OP_BUY) {

    calcLot(Ask - stopLoss, quickLot, targetLot);

    if(Ask - stopLoss < minSL) {
      Print("SL(", stopLoss, ") is too close to entry point(", Ask, ") than minimum stoplevel(", minSL, ")");
      return False;
    }
    else if(quickProfit - Ask < minSL) {
      Print("TP(", quickProfit, ") is too close to entry point(", Ask, ") than minimum stoplevel(", minSL, ")");
      return False;
    }

    if((minLot <= quickLot && quickLot <= maxLot) && positionCount == 0) {
      int quick = OrderSend(thisSymbol, OP_BUY, quickLot, NormalizeDouble(Ask, Digits), 3, NormalizeDouble(stopLoss, Digits), NormalizeDouble(quickProfit, Digits), NULL, Magic_Number);
      if(quick == -1) {
        return False;
      }
      else {
        positionCount ++;
      }
    }
    if((minLot <= targetLot && targetLot <= maxLot) && positionCount == 1) {
      int target = OrderSend(thisSymbol, OP_BUY, targetLot, NormalizeDouble(Ask, Digits), 3, NormalizeDouble(stopLoss, Digits), NormalizeDouble(firstTarget, Digits), NULL, Magic_Number);
      if(target == -1) {
        return False;
      }
      else {
        positionCount ++;
      }
    }      
    if((minLot <= targetLot && targetLot <= maxLot) && positionCount == 2) {
      int target = OrderSend(thisSymbol, OP_BUY, targetLot, NormalizeDouble(Ask, Digits), 3, NormalizeDouble(stopLoss, Digits), NormalizeDouble(finalTarget, Digits), NULL, Magic_Number);
      if(target == -1) {
        return False;
      }
      else {
        positionCount ++;
      }
    }
  }
  else if(signal == OP_SELL) {

    calcLot(stopLoss - Bid, quickLot, targetLot);

    if(stopLoss - Bid < minSL) {
      Print("SL(", stopLoss, ") is too close to entry point(", Bid, ") than minimum stoplevel(", minSL, ")");
      return False;
    }
    else if(stopLoss - Bid < minSL) {
      Print("TP(", quickProfit, ") is too close to entry point(", Bid, ") than minimum stoplevel(", minSL, ")");
      return False;
    }

    if((minLot <= quickLot && quickLot <= maxLot) && positionCount == 0) {
      int quick = OrderSend(thisSymbol, OP_SELL, quickLot, NormalizeDouble(Bid, Digits), 3, NormalizeDouble(stopLoss, Digits), NormalizeDouble(quickProfit, Digits), NULL, Magic_Number);
      if(quick == -1) {
        return False;
      }
      else {
        positionCount --;
      }
    }
    if((minLot <= targetLot && targetLot <= maxLot) && positionCount == -1) {
      int target = OrderSend(thisSymbol, OP_SELL, targetLot, NormalizeDouble(Bid, Digits), 3, NormalizeDouble(stopLoss, Digits), NormalizeDouble(firstTarget, Digits), NULL, Magic_Number);
      if(target == -1) {
        return False;
      }
      else {
        positionCount --;
      }
    }      
    if((minLot <= targetLot && targetLot <= maxLot) && positionCount == -2) {
      int target = OrderSend(thisSymbol, OP_SELL, targetLot, NormalizeDouble(Bid, Digits), 3, NormalizeDouble(stopLoss, Digits), NormalizeDouble(finalTarget, Digits), NULL, Magic_Number);
      if(target == -1) {
        return False;
      }
      else {
        positionCount --;
      }
    }
  }

  return True;
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

  getIndicatorValues();

  if(stopLoss == 0.0 || entryPrice == 0.0 || quickProfit == 0.0 || firstTarget == 0.0 || finalTarget == 0.0) {
    return;
  }
   
  scanPositions();

  if(Open_Time <= Hour() && Hour() < Close_Time && !isFridayNight())
    openPositions();
}
//+------------------------------------------------------------------+

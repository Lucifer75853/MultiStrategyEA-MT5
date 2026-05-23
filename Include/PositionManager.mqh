//+------------------------------------------------------------------+
//| Position Manager - Pozíciókezelés (MT5)                          |
//+------------------------------------------------------------------+
#ifndef POSITION_MANAGER_MQH
#define POSITION_MANAGER_MQH

#include <Trade\Trade.mqh>

class PositionManager
{
private:
    string symbol;
    int    maxPositions;
    int    takeProfit;
    int    stopLoss;
    CTrade trade;

public:
    PositionManager() { symbol = ""; maxPositions = 10; takeProfit = 100; stopLoss = 50; }

    void Init(string sym, int maxPos, int tp, int sl)
    {
        symbol      = sym;
        maxPositions = maxPos;
        takeProfit  = tp;
        stopLoss    = sl;
        trade.SetExpertMagicNumber(9999);
        trade.SetDeviationInPoints(10);
    }

    int GetOpenPositions()
    {
        int count = 0;
        for(int i = 0; i < PositionsTotal(); i++)
            if(PositionGetSymbol(i) == symbol) count++;
        return count;
    }

    double CalculateLot(double riskAmount, int slPoints)
    {
        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

        if(tickValue <= 0 || tickSize <= 0 || slPoints <= 0) return 0.01;

        double slValue = slPoints * _Point * (tickValue / tickSize);
        if(slValue <= 0) return 0.01;

        double lot     = riskAmount / slValue;
        double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

        lot = MathFloor(lot / lotStep) * lotStep;
        lot = MathMax(minLot, MathMin(lot, maxLot));
        return NormalizeDouble(lot, 2);
    }

    void UpdatePositions(double trailingStop, double breakEven)
    {
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != symbol) continue;

            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            int    posType   = (int)PositionGetInteger(POSITION_TYPE);
            double curPrice  = (posType == POSITION_TYPE_BUY)
                               ? SymbolInfoDouble(symbol, SYMBOL_BID)
                               : SymbolInfoDouble(symbol, SYMBOL_ASK);

            if(trailingStop > 0)
            {
                if(posType == POSITION_TYPE_BUY)
                {
                    double newSL = curPrice - trailingStop * _Point;
                    if(newSL > currentSL + _Point)
                        trade.PositionModify(ticket, newSL, currentTP);
                }
                else
                {
                    double newSL = curPrice + trailingStop * _Point;
                    if(currentSL == 0 || newSL < currentSL - _Point)
                        trade.PositionModify(ticket, newSL, currentTP);
                }
            }

            if(breakEven > 0)
            {
                if(posType == POSITION_TYPE_BUY)
                {
                    double beSL = openPrice + _Point;
                    if(curPrice >= openPrice + breakEven * _Point && currentSL < beSL)
                        trade.PositionModify(ticket, beSL, currentTP);
                }
                else
                {
                    double beSL = openPrice - _Point;
                    if(curPrice <= openPrice - breakEven * _Point && (currentSL > beSL || currentSL == 0))
                        trade.PositionModify(ticket, beSL, currentTP);
                }
            }
        }
    }
};

#endif

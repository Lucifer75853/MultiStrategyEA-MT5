//+------------------------------------------------------------------+
//| HFT Strategy - Gyors EMA keresztezés alapú stratégia (MT5)       |
//+------------------------------------------------------------------+
#ifndef HFT_STRATEGY_MQH
#define HFT_STRATEGY_MQH

#include <Strategy.mqh>

class HFTStrategy : public Strategy
{
private:
    int fastEmaPeriod;
    int slowEmaPeriod;
    int rsiPeriod;

    int fastEmaHandle;
    int slowEmaHandle;
    int rsiHandle;

public:
    HFTStrategy(double initialBalance, double leverage)
    {
        balance           = initialBalance;
        leverageMultiplier = leverage;
        fastEmaPeriod     = 5;
        slowEmaPeriod     = 13;
        rsiPeriod         = 7;
        fastEmaHandle     = INVALID_HANDLE;
        slowEmaHandle     = INVALID_HANDLE;
        rsiHandle         = INVALID_HANDLE;
    }

    ~HFTStrategy()
    {
        if(fastEmaHandle != INVALID_HANDLE) IndicatorRelease(fastEmaHandle);
        if(slowEmaHandle != INVALID_HANDLE) IndicatorRelease(slowEmaHandle);
        if(rsiHandle != INVALID_HANDLE)     IndicatorRelease(rsiHandle);
    }

    bool Init()
    {
        fastEmaHandle = iMA(_Symbol, PERIOD_CURRENT, fastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
        slowEmaHandle = iMA(_Symbol, PERIOD_CURRENT, slowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
        rsiHandle     = iRSI(_Symbol, PERIOD_CURRENT, rsiPeriod, PRICE_CLOSE);

        if(fastEmaHandle == INVALID_HANDLE || slowEmaHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE)
        {
            Print("HFTStrategy: Indikátor handle hiba!");
            return false;
        }
        return true;
    }

    string GetName() { return "HFT"; }

    int GetSignal()
    {
        double fastEma[], slowEma[], rsi[];

        if(CopyBuffer(fastEmaHandle, 0, 0, 2, fastEma) < 2) return 0;
        if(CopyBuffer(slowEmaHandle, 0, 0, 2, slowEma) < 2) return 0;
        if(CopyBuffer(rsiHandle,     0, 0, 1, rsi)     < 1) return 0;

        ArraySetAsSeries(fastEma, true);
        ArraySetAsSeries(slowEma, true);
        ArraySetAsSeries(rsi,     true);

        // BUY: Fast EMA átmegy a Slow EMA fölé, RSI nem túlvett
        if(fastEma[1] <= slowEma[1] && fastEma[0] > slowEma[0] && rsi[0] < 65)
        {
            Print("HFT BUY: FastEMA=" + DoubleToString(fastEma[0], 5) +
                  " SlowEMA=" + DoubleToString(slowEma[0], 5) +
                  " RSI=" + DoubleToString(rsi[0], 1));
            return 1;
        }

        // SELL: Fast EMA átmegy a Slow EMA alá, RSI nem túladott
        if(fastEma[1] >= slowEma[1] && fastEma[0] < slowEma[0] && rsi[0] > 35)
        {
            Print("HFT SELL: FastEMA=" + DoubleToString(fastEma[0], 5) +
                  " SlowEMA=" + DoubleToString(slowEma[0], 5) +
                  " RSI=" + DoubleToString(rsi[0], 1));
            return -1;
        }

        return 0;
    }
};

#endif

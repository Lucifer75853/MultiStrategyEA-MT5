//+------------------------------------------------------------------+
//| XBTFX Strategy - Stochastic + MA trend követő stratégia (MT5)   |
//+------------------------------------------------------------------+
#ifndef XBTFX_STRATEGY_MQH
#define XBTFX_STRATEGY_MQH

#include <Strategy.mqh>

class XBTFXStrategy : public Strategy
{
private:
    int stochKPeriod;
    int stochDPeriod;
    int stochSlowing;
    int maPeriod;
    int atrPeriod;

    int stochHandle;
    int maHandle;
    int atrHandle;

public:
    XBTFXStrategy(double initialBalance, double leverage)
    {
        balance           = initialBalance;
        leverageMultiplier = leverage;
        stochKPeriod      = 14;
        stochDPeriod      = 3;
        stochSlowing      = 3;
        maPeriod          = 50;
        atrPeriod         = 14;
        stochHandle       = INVALID_HANDLE;
        maHandle          = INVALID_HANDLE;
        atrHandle         = INVALID_HANDLE;
    }

    ~XBTFXStrategy()
    {
        if(stochHandle != INVALID_HANDLE) IndicatorRelease(stochHandle);
        if(maHandle    != INVALID_HANDLE) IndicatorRelease(maHandle);
        if(atrHandle   != INVALID_HANDLE) IndicatorRelease(atrHandle);
    }

    bool Init()
    {
        stochHandle = iStochastic(_Symbol, PERIOD_CURRENT, stochKPeriod, stochDPeriod, stochSlowing, MODE_SMA, STO_LOWHIGH);
        maHandle    = iMA(_Symbol, PERIOD_CURRENT, maPeriod, 0, MODE_SMA, PRICE_CLOSE);
        atrHandle   = iATR(_Symbol, PERIOD_CURRENT, atrPeriod);

        if(stochHandle == INVALID_HANDLE || maHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
        {
            Print("XBTFXStrategy: Indikátor handle hiba!");
            return false;
        }
        return true;
    }

    string GetName() { return "XBTFX"; }

    int GetSignal()
    {
        double stochK[], stochD[], ma[], atr[];
        double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);

        if(CopyBuffer(stochHandle, 0, 0, 2, stochK) < 2) return 0;
        if(CopyBuffer(stochHandle, 1, 0, 2, stochD) < 2) return 0;
        if(CopyBuffer(maHandle,    0, 0, 1, ma)     < 1) return 0;
        if(CopyBuffer(atrHandle,   0, 0, 1, atr)    < 1) return 0;

        ArraySetAsSeries(stochK, true);
        ArraySetAsSeries(stochD, true);
        ArraySetAsSeries(ma,     true);

        // BUY: Stoch túladott terület elhagyása, ár MA felett
        if(stochK[1] < 20 && stochK[0] > stochD[0] && close0 > ma[0])
        {
            Print("XBTFX BUY: StochK=" + DoubleToString(stochK[0], 1) +
                  " MA=" + DoubleToString(ma[0], 5) +
                  " ATR=" + DoubleToString(atr[0], 5));
            return 1;
        }

        // SELL: Stoch túlvett terület elhagyása, ár MA alatt
        if(stochK[1] > 80 && stochK[0] < stochD[0] && close0 < ma[0])
        {
            Print("XBTFX SELL: StochK=" + DoubleToString(stochK[0], 1) +
                  " MA=" + DoubleToString(ma[0], 5) +
                  " ATR=" + DoubleToString(atr[0], 5));
            return -1;
        }

        return 0;
    }
};

#endif

//+------------------------------------------------------------------+
//| Scalper Strategy - Bollinger Bands + RSI + MACD (MT5)            |
//+------------------------------------------------------------------+
#ifndef SCALPER_STRATEGY_MQH
#define SCALPER_STRATEGY_MQH

#include <Strategy.mqh>

class ScalperStrategy : public Strategy
{
private:
    int    bbPeriod;
    double bbStdDev;
    int    lookbackCandles;
    double volatilityThreshold;
    double profitTargetPips;
    double stopLossPips;
    int    rsiPeriod;
    double rsiOverbought;
    double rsiOversold;
    bool   useTrailingStop;
    int    signalsGenerated;
    int    successfulSignals;

    int bbHandle;
    int rsiHandle;
    int atrHandle;
    int macdHandle;
    int adxHandle;

public:
    ScalperStrategy(double initialBalance, double leverage)
    {
        balance            = initialBalance;
        leverageMultiplier = leverage;
        bbPeriod           = 20;
        bbStdDev           = 2.0;
        lookbackCandles    = 20;
        volatilityThreshold = 0.0015;
        profitTargetPips   = 15;
        stopLossPips       = 10;
        rsiPeriod          = 14;
        rsiOverbought      = 70.0;
        rsiOversold        = 30.0;
        useTrailingStop    = true;
        signalsGenerated   = 0;
        successfulSignals  = 0;

        bbHandle   = INVALID_HANDLE;
        rsiHandle  = INVALID_HANDLE;
        atrHandle  = INVALID_HANDLE;
        macdHandle = INVALID_HANDLE;
        adxHandle  = INVALID_HANDLE;
    }

    ~ScalperStrategy()
    {
        if(bbHandle   != INVALID_HANDLE) IndicatorRelease(bbHandle);
        if(rsiHandle  != INVALID_HANDLE) IndicatorRelease(rsiHandle);
        if(atrHandle  != INVALID_HANDLE) IndicatorRelease(atrHandle);
        if(macdHandle != INVALID_HANDLE) IndicatorRelease(macdHandle);
        if(adxHandle  != INVALID_HANDLE) IndicatorRelease(adxHandle);
    }

    bool Init()
    {
        bbHandle   = iBands(_Symbol, PERIOD_CURRENT, bbPeriod, 0, bbStdDev, PRICE_CLOSE);
        rsiHandle  = iRSI(_Symbol, PERIOD_CURRENT, rsiPeriod, PRICE_CLOSE);
        atrHandle  = iATR(_Symbol, PERIOD_CURRENT, 14);
        macdHandle = iMACD(_Symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
        adxHandle  = iADX(_Symbol, PERIOD_CURRENT, 14);

        if(bbHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE ||
           atrHandle == INVALID_HANDLE || macdHandle == INVALID_HANDLE ||
           adxHandle == INVALID_HANDLE)
        {
            Print("ScalperStrategy: Indikátor handle hiba!");
            return false;
        }
        return true;
    }

    string GetName() { return "Scalper"; }

    int GetSignal()
    {
        double bbUpper[], bbMiddle[], bbLower[];
        double rsiArr[], atrArr[], macdMain[], macdSig[];

        if(CopyBuffer(bbHandle,   1, 0, 1, bbUpper)  < 1) return 0;
        if(CopyBuffer(bbHandle,   0, 0, 1, bbMiddle) < 1) return 0;
        if(CopyBuffer(bbHandle,   2, 0, 1, bbLower)  < 1) return 0;
        if(CopyBuffer(rsiHandle,  0, 0, 1, rsiArr)   < 1) return 0;
        if(CopyBuffer(atrHandle,  0, 0, 1, atrArr)   < 1) return 0;
        if(CopyBuffer(macdHandle, 0, 0, 1, macdMain) < 1) return 0;
        if(CopyBuffer(macdHandle, 1, 0, 1, macdSig)  < 1) return 0;

        ArraySetAsSeries(bbUpper,  true);
        ArraySetAsSeries(bbLower,  true);
        ArraySetAsSeries(rsiArr,   true);
        ArraySetAsSeries(atrArr,   true);
        ArraySetAsSeries(macdMain, true);
        ArraySetAsSeries(macdSig,  true);

        double close0    = iClose(_Symbol, PERIOD_CURRENT, 0);
        double atrPct    = (close0 > 0) ? (atrArr[0] / close0) * 100.0 : 0;
        double rsi       = rsiArr[0];
        double macCurrent = macdMain[0];
        double macSignal  = macdSig[0];

        signalsGenerated++;

        // BUY: ár BB alsó sáv alatt, RSI oversold, MACD felfelé
        if(close0 < bbLower[0] * 1.01 &&
           rsi < rsiOversold &&
           macCurrent > macSignal &&
           atrPct > volatilityThreshold)
        {
            Print("SCALPER BUY: Price=" + DoubleToString(close0, 5) +
                  " RSI=" + DoubleToString(rsi, 2) +
                  " ATR%=" + DoubleToString(atrPct, 4));
            return 1;
        }

        // SELL: ár BB felső sáv felett, RSI overbought, MACD lefelé
        if(close0 > bbUpper[0] * 0.99 &&
           rsi > rsiOverbought &&
           macCurrent < macSignal &&
           atrPct > volatilityThreshold)
        {
            Print("SCALPER SELL: Price=" + DoubleToString(close0, 5) +
                  " RSI=" + DoubleToString(rsi, 2) +
                  " ATR%=" + DoubleToString(atrPct, 4));
            return -1;
        }

        return 0;
    }

    double GetProfitTargetPips()  { return profitTargetPips; }
    double GetStopLossPips()      { return stopLossPips; }
    int    GetBBPeriod()          { return bbPeriod; }
    double GetBBStdDev()          { return bbStdDev; }
    int    GetLookbackCandles()   { return lookbackCandles; }
    double GetVolatilityThreshold() { return volatilityThreshold; }
    int    GetSignalsGenerated()  { return signalsGenerated; }
    int    GetSuccessfulSignals() { return successfulSignals; }

    void SetBBPeriod(int period)           { bbPeriod = MathMax(5, period); }
    void SetBBStdDev(double stdDev)        { bbStdDev = MathMax(0.5, MathMin(stdDev, 5.0)); }
    void SetProfitTargetPips(double pips)  { profitTargetPips = MathMax(5, pips); }
    void SetStopLossPips(double pips)      { stopLossPips = MathMax(1, pips); }
};

#endif

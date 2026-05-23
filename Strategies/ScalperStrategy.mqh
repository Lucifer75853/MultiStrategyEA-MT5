//+------------------------------------------------------------------+
//| Scalper Strategy - Rövidময়দী kereskedési stratégia              |
//| Bollinger Bands alapú gyors belépések és kijáviások              |
//+------------------------------------------------------------------+
#ifndef SCALPER_STRATEGY_MQH
#define SCALPER_STRATEGY_MQH

#include "Strategy.mqh"

class ScalperStrategy : public Strategy
{
private:
    // Bollinger Bands paraméterek
    int bbPeriod;                    // BB periódus (default: 20)
    double bbStdDev;                 // BB szórás (default: 2.0)
    
    // Scalper specifikus paraméterek
    int lookbackCandles;             // Hány gyertyát néz vissza (default: 20)
    double volatilityThreshold;      // Volatilitás küszöb
    double profitTargetPips;         // Profit cél (pips)
    double stopLossPips;             // Stop loss (pips)
    
    // Momentum indikátor
    int rsiPeriod;                   // RSI periódus
    double rsiOverbought;            // RSI overbought szint
    double rsiOversold;              // RSI oversold szint
    
    // Risk management
    double maxRiskPerTrade;          // Max kockázat per trade
    bool useTrailingStop;            // Trailing stop használat
    
    // Stratégia statisztika
    int signalsGenerated;
    int successfulSignals;
    
public:
    ScalperStrategy(double initialBalance, double leverage)
    {
        balance = initialBalance;
        leverageMultiplier = leverage;
        
        // Bollinger Bands inicializálás
        bbPeriod = 20;               // 20 gyertya
        bbStdDev = 2.0;
        lookbackCandles = 20;        // 20 gyertyát figyel
        
        // Scalper paraméterek
        volatilityThreshold = 0.0015;  // 0.15% volatilitás küszöb
        profitTargetPips = 15;         // 15 pips profit cél
        stopLossPips = 10;             // 10 pips stop loss
        
        // RSI indikátor
        rsiPeriod = 14;
        rsiOverbought = 70.0;
        rsiOversold = 30.0;
        
        // Risk management
        maxRiskPerTrade = 2.0;  // 2% kockázat per trade
        useTrailingStop = true;
        
        // Statisztika
        signalsGenerated = 0;
        successfulSignals = 0;
    }
    
    //+------ Stratégia név ------+
    string GetName()
    {
        return "Scalper";
    }
    
    //+------ Fő szignál generálás ------+
    int GetSignal()
    {
        // Bollinger Bands értékek
        double bbUpper = iBands(Symbol(), PERIOD_CURRENT, bbPeriod, bbStdDev, 0, MODE_UPPER, 0);
        double bbMiddle = iBands(Symbol(), PERIOD_CURRENT, bbPeriod, bbStdDev, 0, MODE_MAIN, 0);
        double bbLower = iBands(Symbol(), PERIOD_CURRENT, bbPeriod, bbStdDev, 0, MODE_LOWER, 0);
        
        // RSI érték
        double rsi = iRSI(Symbol(), PERIOD_CURRENT, rsiPeriod, PRICE_CLOSE, 0);
        
        // ATR volatilitás mérés
        double atr = iATR(Symbol(), PERIOD_CURRENT, 14, 0);
        double atrPercent = (atr / Close[0]) * 100;
        
        // Macsellánelem (MACD) momentum
        double macCurrent = iMACD(Symbol(), PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
        double macSignal = iMACD(Symbol(), PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
        
        signalsGenerated++;
        
        //+------ BUY SZIGNÁL ------+
        // 1. Ár az alsó Bollinger Band közelében
        // 2. RSI oversold (< 30)
        // 3. MACD momentum felfelé
        if(Close[0] < bbLower * 1.01 &&     // Ár BB alsó sáv alatt
           rsi < rsiOversold &&              // RSI oversold
           macCurrent > macSignal &&         // MACD momentum felfelé
           atrPercent > volatilityThreshold) // Megfelelő volatilitás
        {
            Print("🟢 SCALPER BUY SZIGNÁL: Price=" + DoubleToStr(Close[0], 4) + 
                  " RSI=" + DoubleToStr(rsi, 2) + " ATR%=" + DoubleToStr(atrPercent, 3));
            return 1;  // BUY
        }
        
        //+------ SELL SZIGNÁL ------+
        // 1. Ár a felső Bollinger Band közelében
        // 2. RSI overbought (> 70)
        // 3. MACD momentum lefelé
        if(Close[0] > bbUpper * 0.99 &&     // Ár BB felső sáv fölött
           rsi > rsiOverbought &&            // RSI overbought
           macCurrent < macSignal &&         // MACD momentum lefelé
           atrPercent > volatilityThreshold) // Megfelelő volatilitás
        {
            Print("🔴 SCALPER SELL SZIGNÁL: Price=" + DoubleToStr(Close[0], 4) + 
                  " RSI=" + DoubleToStr(rsi, 2) + " ATR%=" + DoubleToStr(atrPercent, 3));
            return -1;  // SELL
        }
        
        return 0;  // Nincs szignál
    }
    
    //+------ Bollinger Bands elemzés ------+
    bool AnalyzeBollingerBands(double &upper, double &middle, double &lower)
    {
        upper = iBands(Symbol(), PERIOD_CURRENT, bbPeriod, bbStdDev, 0, MODE_UPPER, 0);
        middle = iBands(Symbol(), PERIOD_CURRENT, bbPeriod, bbStdDev, 0, MODE_MAIN, 0);
        lower = iBands(Symbol(), PERIOD_CURRENT, bbPeriod, bbStdDev, 0, MODE_LOWER, 0);
        
        if(upper > 0 && middle > 0 && lower > 0)
            return true;
        return false;
    }
    
    //+------ Volatilitás elemzés ------+
    double GetVolatility()
    {
        double atr = iATR(Symbol(), PERIOD_CURRENT, 14, 0);
        return (atr / Close[0]) * 100;  // ATR %-ban
    }
    
    //+------ Momentum elemzés (MACD) ------+
    bool GetMomentum(double &mainLine, double &signalLine)
    {
        mainLine = iMACD(Symbol(), PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
        signalLine = iMACD(Symbol(), PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
        
        return (mainLine != 0 && signalLine != 0);
    }
    
    //+------ RSI Momentum ------+
    double GetRSI()
    {
        return iRSI(Symbol(), PERIOD_CURRENT, rsiPeriod, PRICE_CLOSE, 0);
    }
    
    //+------ Trend erőssége (ADX) ------+
    double GetTrendStrength()
    {
        return iADX(Symbol(), PERIOD_CURRENT, 14, MODE_MAIN, 0);
    }
    
    //+------ Lezárás feltétele ------+
    bool ShouldClose()
    {
        // Ha az utolsó 3 gyertyában nincs mozgás, zárjuk
        double range = MathAbs(Close[0] - Close[3]);
        double averageRange = (High[1] - Low[1] + High[2] - Low[2] + High[3] - Low[3]) / 3.0;
        
        if(range < averageRange * 0.3)
        {
            return true;  // Zárjuk a pozíciót - nincs mozgás
        }
        
        return false;
    }
    
    //+------ Profit Target ------+
    double GetProfitTargetPips()
    {
        return profitTargetPips;
    }
    
    //+------ Stop Loss ------+
    double GetStopLossPips()
    {
        return stopLossPips;
    }
    
    //+------ Setter függvények ------+
    void SetBBPeriod(int period)
    {
        bbPeriod = MathMax(5, period);
    }
    
    void SetBBStdDev(double stdDev)
    {
        bbStdDev = MathMax(0.5, MathMin(stdDev, 5.0));
    }
    
    void SetLookbackCandles(int candles)
    {
        lookbackCandles = MathMax(10, candles);
    }
    
    void SetProfitTargetPips(double pips)
    {
        profitTargetPips = MathMax(5, pips);
    }
    
    void SetStopLossPips(double pips)
    {
        stopLossPips = MathMax(1, pips);
    }
    
    void SetVolatilityThreshold(double threshold)
    {
        volatilityThreshold = MathMax(0.0005, MathMin(threshold, 0.01));
    }
    
    //+------ Getter függvények ------+
    int GetBBPeriod() { return bbPeriod; }
    double GetBBStdDev() { return bbStdDev; }
    int GetLookbackCandles() { return lookbackCandles; }
    double GetVolatilityThreshold() { return volatilityThreshold; }
    int GetSignalsGenerated() { return signalsGenerated; }
    int GetSuccessfulSignals() { return successfulSignals; }
    
    //+------ Statisztika ------+
    void PrintStatistics()
    {
        Print("\n╔════════════════════════════════════════╗");
        Print("║     SCALPER STRATÉGIA STATISZTIKA      ║");
        Print("╠════════════════════════════════════════╣");
        Print("║ Stratégia: " + GetName());
        Print("║ Egyenleg: " + DoubleToStr(balance, 2));
        Print("║ Leverage: 1:" + IntegerToString((int)leverageMultiplier));
        Print("║─────────────────────────────────────────");
        Print("║ Bollinger Bands Periódus: " + IntegerToString(bbPeriod));
        Print("║ Szórás (Std Dev): " + DoubleToStr(bbStdDev, 2));
        Print("║ Lookback Gyertyák: " + IntegerToString(lookbackCandles));
        Print("║─────────────────────────────────────────");
        Print("║ Profit Target: " + DoubleToStr(profitTargetPips, 0) + " pips");
        Print("║ Stop Loss: " + DoubleToStr(stopLossPips, 0) + " pips");
        Print("║ Volatilitás Küszöb: " + DoubleToStr(volatilityThreshold * 100, 3) + "%");
        Print("║─────────────────────────────────────────");
        Print("║ Szignálok (Összesen): " + IntegerToString(signalsGenerated));
        Print("║ Sikeres Szignálok: " + IntegerToString(successfulSignals));
        double successRate = (signalsGenerated > 0) ? (((double)successfulSignals / signalsGenerated) * 100) : 0;
        Print("║ Siker %-a: " + DoubleToStr(successRate, 1) + "%");
        Print("╚════════════════════════════════════════╝\n");
    }
};

#endif

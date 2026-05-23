//+------------------------------------------------------------------+
//| Trade Settings Manager - Kereskedési paraméterek kezelése         |
//+------------------------------------------------------------------+
#ifndef TRADE_SETTINGS_MQH
#define TRADE_SETTINGS_MQH

class TradeSettings
{
private:
    // Pozíció méret paraméterek
    double fixedLotSize;              // Fix lot méret
    double riskPercentage;            // Kockázat % per trade
    double maxPositionSize;           // Maximum pozíció méret
    double minPositionSize;           // Minimum pozíció méret
    
    // Tőkeáttétel (Leverage)
    int leverage;                      // Tőkeáttétel szintje (1:X)
    double maxAccountLeverage;        // Maximum megengedett leverage
    
    // Take Profit / Stop Loss
    double takeProfitPips;            // TP távolság (pips-ben)
    double stopLossPips;              // SL távolság (pips-ben)
    double trailingStopPips;          // Trailing stop (pips-ben)
    bool useTrailingStop;             // Trailing stop engedélyezve?
    
    // Bollinger Bands paraméterek
    int bbPeriod;                      // BB periódus
    double bbStdDev;                   // BB szórás (width)
    double bbUpperMultiplier;         // Felső szorzó
    double bbLowerMultiplier;         // Alsó szorzó
    
    // Pozíció kezelés
    bool breakEvenAfterProfit;        // Break-even SL a profit után?
    double breakEvenPips;             // Break-even távolság
    double partialTakeProfitAt;       // Részleges TP hol?
    double partialTakeProfitPercent;  // Részleges TP mekkora %?
    
    // Korlátozások
    int maxOpenTrades;                // Max nyitott pozíció
    double maxDailyLossPercent;       // Max napi veszteség %
    bool tradingEnabled;              // Trading engedélyezve?
    
public:
    TradeSettings()
    {
        // Alapértelmezett értékek
        fixedLotSize = 0.10;
        riskPercentage = 2.0;
        maxPositionSize = 1.0;
        minPositionSize = 0.01;
        
        leverage = 1;
        maxAccountLeverage = 50;
        
        takeProfitPips = 100;
        stopLossPips = 50;
        trailingStopPips = 30;
        useTrailingStop = false;
        
        bbPeriod = 20;
        bbStdDev = 2.0;
        bbUpperMultiplier = 1.0;
        bbLowerMultiplier = 1.0;
        
        breakEvenAfterProfit = true;
        breakEvenPips = 10;
        partialTakeProfitAt = 50;
        partialTakeProfitPercent = 50;
        
        maxOpenTrades = 3;
        maxDailyLossPercent = 5.0;
        tradingEnabled = true;
    }
    
    //+------ Lot Size Kalkuláció ------+
    double CalculateLotSize(double accountEquity, double riskAmount)
    {
        // Kockázat alapú lot méret
        if(riskPercentage > 0)
        {
            double riskInCurrency = (accountEquity * riskPercentage) / 100.0;
            double lotSize = riskInCurrency / (stopLossPips * 10);
            
            // Korlátozások alkalmazása
            if(lotSize > maxPositionSize)
                lotSize = maxPositionSize;
            if(lotSize < minPositionSize)
                lotSize = minPositionSize;
            
            return NormalizeDouble(lotSize, 2);
        }
        
        return fixedLotSize;
    }
    
    //+------ Leverage Validáció ------+
    bool ValidateLeverage(double accountLeverage)
    {
        if(accountLeverage > maxAccountLeverage)
        {
            Print("⚠️ FIGYELEM: Leverage túl magas! Max: " + 
                  IntegerToString(maxAccountLeverage) + ", Aktuális: " + 
                  DoubleToStr(accountLeverage, 1));
            return false;
        }
        return true;
    }
    
    //+------ Setter függvények ------+
    void SetFixedLotSize(double lots) 
    { 
        fixedLotSize = MathMax(minPositionSize, MathMin(lots, maxPositionSize)); 
    }
    
    void SetRiskPercentage(double percent) 
    { 
        riskPercentage = MathMax(0.1, MathMin(percent, 10.0)); 
    }
    
    void SetTakeProfitPips(double pips) 
    { 
        takeProfitPips = MathMax(1, pips); 
    }
    
    void SetStopLossPips(double pips) 
    { 
        stopLossPips = MathMax(1, pips); 
    }
    
    void SetLeverage(int lev) 
    { 
        leverage = MathMax(1, MathMin(lev, maxAccountLeverage)); 
    }
    
    void SetBBPeriod(int period) 
    { 
        bbPeriod = MathMax(5, period); 
    }
    
    void SetBBStdDev(double stdDev) 
    { 
        bbStdDev = MathMax(0.5, MathMin(stdDev, 5.0)); 
    }
    
    void SetMaxOpenTrades(int maxTrades) 
    { 
        maxOpenTrades = MathMax(1, maxTrades); 
    }
    
    void SetMaxDailyLossPercent(double percent) 
    { 
        maxDailyLossPercent = MathMax(0.5, percent); 
    }
    
    //+------ Getter függvények ------+
    double GetFixedLotSize() { return fixedLotSize; }
    double GetRiskPercentage() { return riskPercentage; }
    double GetMaxPositionSize() { return maxPositionSize; }
    double GetMinPositionSize() { return minPositionSize; }
    
    int GetLeverage() { return leverage; }
    double GetMaxAccountLeverage() { return maxAccountLeverage; }
    
    double GetTakeProfitPips() { return takeProfitPips; }
    double GetStopLossPips() { return stopLossPips; }
    double GetTrailingStopPips() { return trailingStopPips; }
    bool GetUseTrailingStop() { return useTrailingStop; }
    
    int GetBBPeriod() { return bbPeriod; }
    double GetBBStdDev() { return bbStdDev; }
    double GetBBUpperMultiplier() { return bbUpperMultiplier; }
    double GetBBLowerMultiplier() { return bbLowerMultiplier; }
    
    int GetMaxOpenTrades() { return maxOpenTrades; }
    double GetMaxDailyLossPercent() { return maxDailyLossPercent; }
    bool IsTradingEnabled() { return tradingEnabled; }
    
    void SetTradingEnabled(bool enabled) { tradingEnabled = enabled; }
    
    //+------ Beállítások megjelenítése ------+
    void PrintSettings()
    {
        Print("\n╔════════════════════════════════════════╗");
        Print("║     KERESKEDÉSI BEÁLLÍTÁSOK            ║");
        Print("╠════════════════════════════════════════╣");
        Print("║ LOT MÉRET");
        Print("║   Fix Lot: " + DoubleToStr(fixedLotSize, 2));
        Print("║   Kockázat %: " + DoubleToStr(riskPercentage, 1) + "%");
        Print("║   Max Pozíció: " + DoubleToStr(maxPositionSize, 2));
        Print("║─────────────────────────────────────────");
        Print("║ TŐKEÁTTÉTEL");
        Print("║   Leverage: 1:" + IntegerToString(leverage));
        Print("║   Max Leverage: 1:" + IntegerToString((int)maxAccountLeverage));
        Print("║─────────────────────────────────────────");
        Print("║ PROFIT / LOSS");
        Print("║   Take Profit: " + DoubleToStr(takeProfitPips, 0) + " pips");
        Print("║   Stop Loss: " + DoubleToStr(stopLossPips, 0) + " pips");
        Print("║   Trailing Stop: " + (useTrailingStop ? "IGEN" : "NEM"));
        Print("║─────────────────────────────────────────");
        Print("║ BOLLINGER BANDS");
        Print("║   Periódus: " + IntegerToString(bbPeriod));
        Print("║   Szórás (Std Dev): " + DoubleToStr(bbStdDev, 2));
        Print("║─────────────────────────────────────────");
        Print("║ KORLÁTOZÁSOK");
        Print("║   Max Nyitott Pozíció: " + IntegerToString(maxOpenTrades));
        Print("║   Max Napi Veszteség: " + DoubleToStr(maxDailyLossPercent, 1) + "%");
        Print("║   Trading Engedélyezve: " + (tradingEnabled ? "IGEN ✓" : "NEM ✗"));
        Print("╚════════════════════════════════════════╝\n");
    }
};

#endif

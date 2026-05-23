//+------------------------------------------------------------------+
//| Dashboard Manager - UI vezérlőpanel kereskedési beállításokhoz    |
//+------------------------------------------------------------------+
#ifndef DASHBOARD_MANAGER_MQH
#define DASHBOARD_MANAGER_MQH

#include "TradeSettings.mqh"
#include "PositionSynchronizer.mqh"

class DashboardManager
{
private:
    TradeSettings &settings;
    PositionSynchronizer &posSync;
    
    // UI Poziciók
    int dashboardX;
    int dashboardY;
    int dashboardWidth;
    int dashboardHeight;
    
    // Frissítési intervallum
    datetime lastUpdateTime;
    int updateIntervalMs;
    
public:
    DashboardManager(TradeSettings &_settings, PositionSynchronizer &_posSync) 
        : settings(_settings), posSync(_posSync)
    {
        dashboardX = 10;
        dashboardY = 20;
        dashboardWidth = 400;
        dashboardHeight = 600;
        lastUpdateTime = 0;
        updateIntervalMs = 1000;  // 1 másodperc
    }
    
    //+------ Dashboard Frissítése ------+
    void UpdateDashboard()
    {
        // Frissítési intervallum ellenőrzése
        if((TimeCurrent() * 1000 - lastUpdateTime * 1000) < updateIntervalMs)
            return;
        
        // Pozíciók szinkronizálása
        posSync.SyncPositions();
        
        // Dashboard megrajzolása
        DrawDashboard();
        
        lastUpdateTime = TimeCurrent();
    }
    
    //+------ Dashboard Megrajzolása ------+
    void DrawDashboard()
    {
        Print("\n╔════════════════════════════════════════════════╗");
        Print("║      🤖 MULTISTRATEGY EA - VEZÉRLŐPANEL");
        Print("╠════════════════════════════════════════════════╣");
        
        // Kereskedési beállítások
        Print("║ 📊 KERESKEDÉSI BEÁLLÍTÁSOK");
        Print("║   Lot Méret: " + DoubleToString(settings.GetFixedLotSize(), 2));
        Print("║   Kockázat: " + DoubleToString(settings.GetRiskPercentage(), 1) + "%");
        Print("║   Leverage: 1:" + IntegerToString(settings.GetLeverage()));
        Print("║   Take Profit: " + DoubleToString(settings.GetTakeProfitPips(), 0) + " pips");
        Print("║   Stop Loss: " + DoubleToString(settings.GetStopLossPips(), 0) + " pips");
        Print("║   Trailing Stop: " + (settings.GetUseTrailingStop() ? "✓ AKTÍV" : "✗ INAKTÍV"));
        
        // Bollinger Bands
        Print("║─────────────────────────────────────────────────");
        Print("║ 📈 BOLLINGER BANDS");
        Print("║   Periódus: " + IntegerToString(settings.GetBBPeriod()));
        Print("║   Szórás (Std Dev): " + DoubleToString(settings.GetBBStdDev(), 2));
        
        // Pozíció kezelés
        Print("║─────────────────────────────────────────────────");
        Print("║ 💰 POZÍCIÓ KEZELÉS");
        Print("║   Nyitott Pozíciók: " + IntegerToString(posSync.GetPositionCount()));
        
        double totalProfit = posSync.GetTotalProfit();
        string profitStr = (totalProfit >= 0) ? "✅ +" : "❌ ";
        Print("║   Teljes P/L: " + profitStr + DoubleToString(MathAbs(totalProfit), 2) + " USD");
        
        // Account Info
        Print("║─────────────────────────────────────────────────");
        Print("║ 💼 ACCOUNT INFORMÁCIÓ");
        Print("║   Egyenleg: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " USD");
        Print("║   Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + " USD");
        Print("║   Szabad Margó: " + DoubleToString(AccountInfoDouble(ACCOUNT_FREEMARGIN), 2) + " USD");
        Print("║   Trading: " + (settings.IsTradingEnabled() ? "✓ ENGEDÉLYEZETT" : "✗ LETILTVA"));
        
        Print("╚════════════════════════════════════════════════╝\n");
    }
};

#endif
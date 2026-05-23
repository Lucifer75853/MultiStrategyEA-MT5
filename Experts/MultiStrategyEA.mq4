//+------------------------------------------------------------------+
//| Multi-Strategy Forex Bot with Settings Menu                      |
//| Supports: HFT, Scalper, XBTFX                                    |
//| Advanced Position & Risk Management                               |
//+------------------------------------------------------------------+
#property strict
#property description "Advanced Multi-Strategy EA with Position Management"

// Stratégia interfészek és megvalósítások
#include <Strategy.mqh>
#include <PositionManager.mqh>
#include <RiskManager.mqh>
#include <Strategies/HFTStrategy.mqh>
#include <Strategies/ScalperStrategy.mqh>
#include <Strategies/XBTFXStrategy.mqh>

//+==============================================+
//|     TRADING SETTINGS - KERESKEDÉSI BEÁLLÍTÁSOK
//+==============================================+
extern string Strategy1Name = "HFT";           // Stratégia 1
extern string Strategy2Name = "Scalper";       // Stratégia 2
extern double Strategy1Capital = 50.0;         // Stratégia 1 - % (0-100)
extern double Strategy2Capital = 50.0;         // Stratégia 2 - % (0-100)
extern double Leverage = 1.0;                  // Tőkeáttét (1.0-50.0)
extern double RiskPerTrade = 2.0;              // Kockázat % per trade

//+==============================================+
//|     POSITION MANAGEMENT - POZÍCIÓKEZELÉS
//+==============================================+
extern int MaxOpenPositions = 10;              // Max nyitott pozíciók
extern int TakeProfit = 100;                   // TP pontban
extern int StopLoss = 50;                      // SL pontban
extern double TrailingStop = 20;               // Trailing stop pontban (0=off)
extern double BreakEven = 30;                  // Break even pontban (0=off)

//+==============================================+
//|     GENERAL SETTINGS - ÁLTALÁNOS BEÁLLÍTÁSOK
//+==============================================+
extern bool UseAutoTimeframe = true;           // Automatikus timeframe
extern int ManualTimeframe = 15;               // Manuális timeframe (ha OFF)
extern bool ShowMenu = true;                   // Menü megjelenítése
extern string SessionStart = "00:00";          // Trading session kezdete
extern string SessionEnd = "23:59";            // Trading session vége
extern bool TradeMonday = true;
extern bool TradeFriday = true;
extern double MaxDailyLoss = 5.0;              // Max napi veszteség %

//+==============================================+
//|     INTERNAL VARIABLES - BELSŐ VÁLTOZÓK
//+==============================================+
Strategy* strategies[2];
PositionManager posManager;
RiskManager riskManager;
double accountBalance;
double strategyBalance[2];
int initialized = 0;
datetime lastSessionReset = 0;

//+------------------------------------------------------------------+
void OnInit()
{
    Print("=== MultiStrategyEA Inicializálás ===");
    
    // Validációk
    if(!ValidateSettings())
    {
        Print("HIBA: Beállítások validációja sikertelen!");
        return;
    }
    
    // Balance inicializálás
    accountBalance = AccountBalance();
    strategyBalance[0] = (accountBalance * Strategy1Capital) / 100.0;
    strategyBalance[1] = (accountBalance * Strategy2Capital) / 100.0;
    
    Print("Stratégia 1 (" + Strategy1Name + ") tőkéje: " + DoubleToStr(strategyBalance[0], 2));
    Print("Stratégia 2 (" + Strategy2Name + ") tőkéje: " + DoubleToStr(strategyBalance[1], 2));
    
    // Stratégiák inicializálása
    if(!InitializeStrategies())
    {
        Print("HIBA: Stratégiák inicializálása sikertelen!");
        return;
    }
    
    // Position Manager inicializálása
    posManager.Init(Symbol(), MaxOpenPositions, TakeProfit, StopLoss);
    
    // Risk Manager inicializálása
    riskManager.Init(accountBalance, RiskPerTrade, Leverage, MaxDailyLoss);
    
    initialized = 1;
    lastSessionReset = TimeCurrent();
    Print("=== MultiStrategyEA Kész ===");
}

//+------------------------------------------------------------------+
int OnStart()
{
    if(!initialized) return(INIT_FAILED);
    
    // Session ellenőrzése
    if(!IsInTradingSession())
    {
        return(0);
    }
    
    // Heti nap ellenőrzése
    if(!IsTradableDay())
    {
        return(0);
    }
    
    // Session reset (24 óra után)
    if(TimeCurrent() - lastSessionReset >= 86400)  // 24 óra
    {
        riskManager.ResetSessionEquity();
        lastSessionReset = TimeCurrent();
        Print("📊 Session Reset: Új napi limit indítva");
    }
    
    // Pozíciók frissítése
    posManager.UpdatePositions(TrailingStop, BreakEven);
    
    // Kockázat ellenőrzése
    if(!riskManager.CanOpenPosition())
    {
        Print("⚠️ Trading szüneteltetve: Max napi veszteség elérve!");
        return(0);
    }
    
    // Stratégia 1 jelzések
    int signal1 = strategies[0].GetSignal();
    
    // Stratégia 2 jelzések
    int signal2 = strategies[1].GetSignal();
    
    // Pozíciókezelés
    HandleSignals(signal1, signal2);
    
    // Menü kirajzolása
    if(ShowMenu) DrawSettingsMenu();
    
    return(0);
}

//+------------------------------------------------------------------+
bool ValidateSettings()
{
    // Tőke felosztás ellenőrzése
    if(Strategy1Capital + Strategy2Capital != 100.0)
    {
        Print("HIBA: Stratégiák tőkéje összesen 100% kell legyen!");
        Print("Jelenlegi: " + DoubleToStr(Strategy1Capital, 1) + "% + " + 
              DoubleToStr(Strategy2Capital, 1) + "%");
        return false;
    }
    
    // Minimum 2 stratégia
    if(Strategy1Name == Strategy2Name)
    {
        Print("⚠️ FIGYELMEZTETÉS: Ugyanaz a stratégia 2x. Javasolt: Mix stratégiák!");
    }
    
    // Tőkeáttét validáció
    if(Leverage < 1.0 || Leverage > 50.0)
    {
        Print("HIBA: Leverage 1.0-50.0 között kell legyen!");
        return false;
    }
    
    // Kockázat validáció
    if(RiskPerTrade < 0.1 || RiskPerTrade > 10.0)
    {
        Print("HIBA: RiskPerTrade 0.1-10.0% között kell legyen!");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
bool InitializeStrategies()
{
    // Stratégia 1 inicializálása
    if(Strategy1Name == "HFT")
        strategies[0] = new HFTStrategy(strategyBalance[0], Leverage);
    else if(Strategy1Name == "Scalper")
        strategies[0] = new ScalperStrategy(strategyBalance[0], Leverage);
    else if(Strategy1Name == "XBTFX")
        strategies[0] = new XBTFXStrategy(strategyBalance[0], Leverage);
    else
    {
        Print("HIBA: Ismeretlen stratégia: " + Strategy1Name);
        return false;
    }
    
    // Stratégia 2 inicializálása
    if(Strategy2Name == "HFT")
        strategies[1] = new HFTStrategy(strategyBalance[1], Leverage);
    else if(Strategy2Name == "Scalper")
        strategies[1] = new ScalperStrategy(strategyBalance[1], Leverage);
    else if(Strategy2Name == "XBTFX")
        strategies[1] = new XBTFXStrategy(strategyBalance[1], Leverage);
    else
    {
        Print("HIBA: Ismeretlen stratégia: " + Strategy2Name);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
void HandleSignals(int sig1, int sig2)
{
    // sig1/sig2: -1 (Sell), 0 (No signal), 1 (Buy)
    
    // Max pozíciók ellenőrzése
    if(posManager.GetOpenPositions() >= MaxOpenPositions)
        return;
    
    // Kockázat ellenőrzése
    double riskAmount = riskManager.CalculateRiskAmount();
    if(riskAmount <= 0) return;
    
    double lot = posManager.CalculateLot(riskAmount, StopLoss);
    
    //+------ STRATÉGIA 1 - BUY ------+
    if(sig1 == 1 && posManager.GetOpenPositions() < MaxOpenPositions)
    {
        if(OrderSend(Symbol(), OP_BUY, lot, Ask, 3, Bid - StopLoss * Point, 
                     Ask + TakeProfit * Point, "Strat1-BUY-" + strategies[0].GetName(), 1001, 0, clrGreen))
        {
            Print("✅ Order nyitva: " + strategies[0].GetName() + " - BUY");
        }
    }
    
    //+------ STRATÉGIA 1 - SELL ------+
    if(sig1 == -1 && posManager.GetOpenPositions() < MaxOpenPositions)
    {
        if(OrderSend(Symbol(), OP_SELL, lot, Bid, 3, Ask + StopLoss * Point, 
                     Bid - TakeProfit * Point, "Strat1-SELL-" + strategies[0].GetName(), 1002, 0, clrRed))
        {
            Print("✅ Order nyitva: " + strategies[0].GetName() + " - SELL");
        }
    }
    
    //+------ STRATÉGIA 2 - BUY ------+
    if(sig2 == 1 && posManager.GetOpenPositions() < MaxOpenPositions)
    {
        if(OrderSend(Symbol(), OP_BUY, lot, Ask, 3, Bid - StopLoss * Point, 
                     Ask + TakeProfit * Point, "Strat2-BUY-" + strategies[1].GetName(), 1003, 0, clrGreen))
        {
            Print("✅ Order nyitva: " + strategies[1].GetName() + " - BUY");
        }
    }
    
    //+------ STRATÉGIA 2 - SELL ------+
    if(sig2 == -1 && posManager.GetOpenPositions() < MaxOpenPositions)
    {
        if(OrderSend(Symbol(), OP_SELL, lot, Bid, 3, Ask + StopLoss * Point, 
                     Bid - TakeProfit * Point, "Strat2-SELL-" + strategies[1].GetName(), 1004, 0, clrRed))
        {
            Print("✅ Order nyitva: " + strategies[1].GetName() + " - SELL");
        }
    }
}

//+------------------------------------------------------------------+
bool IsInTradingSession()
{
    // Session időpontok feldolgozása
    string hour_str = StringSubstr(SessionStart, 0, 2);
    string min_str = StringSubstr(SessionStart, 3, 2);
    int start_time = StrToInteger(hour_str) * 60 + StrToInteger(min_str);
    
    hour_str = StringSubstr(SessionEnd, 0, 2);
    min_str = StringSubstr(SessionEnd, 3, 2);
    int end_time = StrToInteger(hour_str) * 60 + StrToInteger(min_str);
    
    int current_time = Hour() * 60 + Minute();
    
    return (current_time >= start_time && current_time <= end_time);
}

//+------------------------------------------------------------------+
bool IsTradableDay()
{
    int day = DayOfWeek();
    if(day == 1 && !TradeMonday) return false;    // Hétfő
    if(day == 5 && !TradeFriday) return false;    // Péntek
    return true;
}

//+------------------------------------------------------------------+
void DrawSettingsMenu()
{
    // Menü információk a chart-ra rajzolása
    int xPos = 10;
    int yPos = 20;
    int lineHeight = 16;
    
    // Háttér cikk
    Comment("╔════════════════════════════════════════╗\n",
            "║     MultiStrategyEA - Beállítások      ║\n",
            "╠════════════════════════════════════════╣\n",
            "║ Stratégia 1: " + StringSubstr(Strategy1Name, 0, 15) + "\n",
            "║ Tőke: " + DoubleToStr(Strategy1Capital, 1) + "%\n",
            "║ Stratégia 2: " + StringSubstr(Strategy2Name, 0, 15) + "\n",
            "║ Tőke: " + DoubleToStr(Strategy2Capital, 1) + "%\n",
            "╠════════════════════════════════════════╣\n",
            "║ Nyitott pozíciók: " + IntegerToString(posManager.GetOpenPositions()) + "/" + IntegerToString(MaxOpenPositions) + "\n",
            "║ Napi veszteség: " + DoubleToStr(riskManager.GetDailyLossPercent(), 2) + "%\n",
            "║ Equity: " + DoubleToStr(riskManager.GetCurrentEquity(), 2) + "\n",
            "║ Max napi limit: " + DoubleToStr(MaxDailyLoss, 1) + "%\n",
            "╚════════════════════════════════════════╝");
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(strategies[0] != NULL) delete strategies[0];
    if(strategies[1] != NULL) delete strategies[1];
    
    string reasonText;
    switch(reason)
    {
        case REASON_ACCOUNT: reasonText = "Számla módosítása"; break;
        case REASON_CHARTCHANGE: reasonText = "Chart módosítása"; break;
        case REASON_CHARTCLOSE: reasonText = "Chart bezárása"; break;
        case REASON_PARAMETERS: reasonText = "Paraméterek módosítása"; break;
        case REASON_RECOMPILE: reasonText = "Újrafordítás"; break;
        case REASON_REMOVE: reasonText = "EA eltávolítása"; break;
        default: reasonText = "Ismeretlen"; break;
    }
    
    Print("═══════════════════════════════════════════");
    Print("🛑 MultiStrategyEA Leállítva");
    Print("Oka: " + reasonText);
    Print("═══════════════════════════════════════════");
}

//+------------------------------------------------------------------+
// Helper függvények
//+------------------------------------------------------------------+

int StrToInteger(string str)
{
    return (int)StringToInteger(str);
}

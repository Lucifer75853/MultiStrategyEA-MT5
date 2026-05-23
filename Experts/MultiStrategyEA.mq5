//+------------------------------------------------------------------+
//| Multi-Strategy Forex Bot for MT5                                 |
//| Supports: HFT, Scalper, XBTFX                                   |
//| Advanced Position & Risk Management                              |
//+------------------------------------------------------------------+
#property description "Advanced Multi-Strategy EA with Position Management (MT5)"

#include <Trade\Trade.mqh>
#include <Strategy.mqh>
#include <PositionManager.mqh>
#include <RiskManager.mqh>
#include <Strategies/HFTStrategy.mqh>
#include <Strategies/ScalperStrategy.mqh>
#include <Strategies/XBTFXStrategy.mqh>

//+==============================================+
//|     TRADING SETTINGS - KERESKEDÉSI BEÁLLÍTÁSOK
//+==============================================+
input string Strategy1Name   = "HFT";     // Stratégia 1 (HFT/Scalper/XBTFX)
input string Strategy2Name   = "Scalper"; // Stratégia 2 (HFT/Scalper/XBTFX)
input double Strategy1Capital = 50.0;     // Stratégia 1 - % (0-100)
input double Strategy2Capital = 50.0;     // Stratégia 2 - % (0-100)
input double Leverage        = 1.0;       // Tőkeáttét (1.0-50.0)
input double RiskPerTrade    = 2.0;       // Kockázat % per trade

//+==============================================+
//|     POSITION MANAGEMENT - POZÍCIÓKEZELÉS
//+==============================================+
input int    MaxOpenPositions = 10;  // Max nyitott pozíciók
input int    TakeProfit       = 100; // TP pontban
input int    StopLoss         = 50;  // SL pontban
input double TrailingStop     = 20;  // Trailing stop pontban (0=ki)
input double BreakEven        = 30;  // Break even pontban (0=ki)

//+==============================================+
//|     GENERAL SETTINGS - ÁLTALÁNOS BEÁLLÍTÁSOK
//+==============================================+
input bool   UseAutoTimeframe = true;    // Automatikus timeframe
input int    ManualTimeframe  = 15;      // Manuális timeframe (ha ki)
input bool   ShowMenu         = true;    // Menü megjelenítése
input string SessionStart     = "00:00"; // Trading session kezdete
input string SessionEnd       = "23:59"; // Trading session vége
input bool   TradeMonday      = true;    // Hétfőn kereskedés
input bool   TradeFriday      = true;    // Pénteken kereskedés
input double MaxDailyLoss     = 5.0;     // Max napi veszteség %

//+==============================================+
//|     INTERNAL VARIABLES - BELSŐ VÁLTOZÓK
//+==============================================+
Strategy*       strategies[2];
PositionManager posManager;
RiskManager     riskManager;
CTrade          trade;
double          accountBalance;
double          strategyBalance[2];
datetime        lastSessionReset = 0;

//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== MultiStrategyEA MT5 Inicializálás ===");

    if(!ValidateSettings())
    {
        Print("HIBA: Beállítások validációja sikertelen!");
        return INIT_FAILED;
    }

    accountBalance    = AccountInfoDouble(ACCOUNT_BALANCE);
    strategyBalance[0] = (accountBalance * Strategy1Capital) / 100.0;
    strategyBalance[1] = (accountBalance * Strategy2Capital) / 100.0;

    Print("Stratégia 1 (" + Strategy1Name + ") tőkéje: " + DoubleToString(strategyBalance[0], 2));
    Print("Stratégia 2 (" + Strategy2Name + ") tőkéje: " + DoubleToString(strategyBalance[1], 2));

    if(!InitializeStrategies())
    {
        Print("HIBA: Stratégiák inicializálása sikertelen!");
        return INIT_FAILED;
    }

    posManager.Init(_Symbol, MaxOpenPositions, TakeProfit, StopLoss);
    riskManager.Init(accountBalance, RiskPerTrade, Leverage, MaxDailyLoss);

    trade.SetExpertMagicNumber(9001);
    trade.SetDeviationInPoints(10);

    lastSessionReset = TimeCurrent();
    Print("=== MultiStrategyEA MT5 Kész ===");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
    if(!IsInTradingSession()) return;
    if(!IsTradableDay())      return;

    // Napi reset (24 óra után)
    if(TimeCurrent() - lastSessionReset >= 86400)
    {
        riskManager.ResetSessionEquity();
        lastSessionReset = TimeCurrent();
        Print("Session Reset: Új napi limit indítva");
    }

    posManager.UpdatePositions(TrailingStop, BreakEven);

    if(!riskManager.CanOpenPosition())
    {
        if(ShowMenu) DrawSettingsMenu();
        return;
    }

    int signal1 = strategies[0].GetSignal();
    int signal2 = strategies[1].GetSignal();

    HandleSignals(signal1, signal2);

    if(ShowMenu) DrawSettingsMenu();
}

//+------------------------------------------------------------------+
bool ValidateSettings()
{
    if(MathAbs(Strategy1Capital + Strategy2Capital - 100.0) > 0.01)
    {
        Print("HIBA: Stratégiák tőkéje összesen 100% kell legyen! (" +
              DoubleToString(Strategy1Capital, 1) + "% + " +
              DoubleToString(Strategy2Capital, 1) + "%)");
        return false;
    }

    if(Strategy1Name == Strategy2Name)
        Print("FIGYELMEZTETÉS: Ugyanaz a stratégia 2x. Javasolt: Mix stratégiák!");

    if(Leverage < 1.0 || Leverage > 50.0)
    {
        Print("HIBA: Leverage 1.0-50.0 között kell legyen!");
        return false;
    }

    if(RiskPerTrade < 0.1 || RiskPerTrade > 10.0)
    {
        Print("HIBA: RiskPerTrade 0.1-10.0% között kell legyen!");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
Strategy* CreateStrategy(string name, double capital)
{
    if(name == "HFT")     return new HFTStrategy(capital, Leverage);
    if(name == "Scalper") return new ScalperStrategy(capital, Leverage);
    if(name == "XBTFX")   return new XBTFXStrategy(capital, Leverage);
    Print("HIBA: Ismeretlen stratégia: " + name);
    return NULL;
}

bool InitializeStrategies()
{
    strategies[0] = CreateStrategy(Strategy1Name, strategyBalance[0]);
    strategies[1] = CreateStrategy(Strategy2Name, strategyBalance[1]);

    if(strategies[0] == NULL || strategies[1] == NULL) return false;
    if(!strategies[0].Init())                          return false;
    if(!strategies[1].Init())                          return false;

    return true;
}

//+------------------------------------------------------------------+
void HandleSignals(int sig1, int sig2)
{
    if(posManager.GetOpenPositions() >= MaxOpenPositions) return;

    double riskAmount = riskManager.CalculateRiskAmount();
    if(riskAmount <= 0) return;

    double lot = posManager.CalculateLot(riskAmount, StopLoss);
    if(lot <= 0) return;

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    if(sig1 == 1 && posManager.GetOpenPositions() < MaxOpenPositions)
    {
        if(trade.Buy(lot, _Symbol, ask,
                     bid - StopLoss * _Point,
                     ask + TakeProfit * _Point,
                     "Strat1-BUY-" + strategies[0].GetName()))
            Print("Order nyitva: " + strategies[0].GetName() + " - BUY");
    }

    if(sig1 == -1 && posManager.GetOpenPositions() < MaxOpenPositions)
    {
        if(trade.Sell(lot, _Symbol, bid,
                      ask + StopLoss * _Point,
                      bid - TakeProfit * _Point,
                      "Strat1-SELL-" + strategies[0].GetName()))
            Print("Order nyitva: " + strategies[0].GetName() + " - SELL");
    }

    if(sig2 == 1 && posManager.GetOpenPositions() < MaxOpenPositions)
    {
        if(trade.Buy(lot, _Symbol, ask,
                     bid - StopLoss * _Point,
                     ask + TakeProfit * _Point,
                     "Strat2-BUY-" + strategies[1].GetName()))
            Print("Order nyitva: " + strategies[1].GetName() + " - BUY");
    }

    if(sig2 == -1 && posManager.GetOpenPositions() < MaxOpenPositions)
    {
        if(trade.Sell(lot, _Symbol, bid,
                      ask + StopLoss * _Point,
                      bid - TakeProfit * _Point,
                      "Strat2-SELL-" + strategies[1].GetName()))
            Print("Order nyitva: " + strategies[1].GetName() + " - SELL");
    }
}

//+------------------------------------------------------------------+
bool IsInTradingSession()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int currentMin = dt.hour * 60 + dt.min;

    int startMin = (int)StringToInteger(StringSubstr(SessionStart, 0, 2)) * 60 +
                   (int)StringToInteger(StringSubstr(SessionStart, 3, 2));
    int endMin   = (int)StringToInteger(StringSubstr(SessionEnd, 0, 2)) * 60 +
                   (int)StringToInteger(StringSubstr(SessionEnd, 3, 2));

    return (currentMin >= startMin && currentMin <= endMin);
}

bool IsTradableDay()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    if(dt.day_of_week == 1 && !TradeMonday) return false;
    if(dt.day_of_week == 5 && !TradeFriday) return false;
    return true;
}

//+------------------------------------------------------------------+
void DrawSettingsMenu()
{
    Comment(
        "╔════════════════════════════════════════╗\n",
        "║   MultiStrategyEA MT5 - Beállítások    ║\n",
        "╠════════════════════════════════════════╣\n",
        "║ Stratégia 1: ", StringSubstr(Strategy1Name, 0, 15), "\n",
        "║ Tőke: ",        DoubleToString(Strategy1Capital, 1), "%\n",
        "║ Stratégia 2: ", StringSubstr(Strategy2Name, 0, 15), "\n",
        "║ Tőke: ",        DoubleToString(Strategy2Capital, 1), "%\n",
        "╠════════════════════════════════════════╣\n",
        "║ Nyitott pozíciók: ",
            IntegerToString(posManager.GetOpenPositions()), "/",
            IntegerToString(MaxOpenPositions), "\n",
        "║ Napi veszteség: ", DoubleToString(riskManager.GetDailyLossPercent(), 2), "%\n",
        "║ Equity: ",         DoubleToString(riskManager.GetCurrentEquity(), 2), "\n",
        "║ Max napi limit: ", DoubleToString(MaxDailyLoss, 1), "%\n",
        "╚════════════════════════════════════════╝"
    );
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Comment("");
    if(strategies[0] != NULL) { delete strategies[0]; strategies[0] = NULL; }
    if(strategies[1] != NULL) { delete strategies[1]; strategies[1] = NULL; }

    string reasonText;
    switch(reason)
    {
        case REASON_ACCOUNT:     reasonText = "Számla módosítása";    break;
        case REASON_CHARTCHANGE: reasonText = "Chart módosítása";     break;
        case REASON_CHARTCLOSE:  reasonText = "Chart bezárása";       break;
        case REASON_PARAMETERS:  reasonText = "Paraméterek módosítása"; break;
        case REASON_RECOMPILE:   reasonText = "Újrafordítás";         break;
        case REASON_REMOVE:      reasonText = "EA eltávolítása";      break;
        default:                 reasonText = "Ismeretlen";           break;
    }

    Print("MultiStrategyEA MT5 Leállítva - Oka: " + reasonText);
}

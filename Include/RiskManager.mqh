//+------------------------------------------------------------------+
//| Risk Manager - Kockázatkezelés (MT5)                             |
//+------------------------------------------------------------------+
#ifndef RISK_MANAGER_MQH
#define RISK_MANAGER_MQH

class RiskManager
{
private:
    double riskPerTrade;
    double maxDailyLoss;
    double sessionStartEquity;

public:
    RiskManager() { riskPerTrade = 2.0; maxDailyLoss = 5.0; sessionStartEquity = 0; }

    void Init(double balance, double risk, double leverage, double maxLoss)
    {
        riskPerTrade = risk;
        maxDailyLoss = maxLoss;
        sessionStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        Print("RiskManager: Session equity = " + DoubleToString(sessionStartEquity, 2));
    }

    void ResetSessionEquity()
    {
        sessionStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    }

    bool CanOpenPosition()
    {
        if(sessionStartEquity <= 0) return true;
        double eq = AccountInfoDouble(ACCOUNT_EQUITY);
        double lossPercent = ((sessionStartEquity - eq) / sessionStartEquity) * 100.0;
        return lossPercent < maxDailyLoss;
    }

    double CalculateRiskAmount()
    {
        return (AccountInfoDouble(ACCOUNT_EQUITY) * riskPerTrade) / 100.0;
    }

    double GetDailyLossPercent()
    {
        if(sessionStartEquity <= 0) return 0;
        double eq = AccountInfoDouble(ACCOUNT_EQUITY);
        return ((sessionStartEquity - eq) / sessionStartEquity) * 100.0;
    }

    double GetCurrentEquity() { return AccountInfoDouble(ACCOUNT_EQUITY); }
};

#endif

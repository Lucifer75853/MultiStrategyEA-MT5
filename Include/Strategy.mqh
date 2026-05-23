//+------------------------------------------------------------------+
//| Strategy - Alap stratégia osztály (MT5)                          |
//+------------------------------------------------------------------+
#ifndef STRATEGY_MQH
#define STRATEGY_MQH

class Strategy
{
protected:
    double balance;
    double leverageMultiplier;

public:
    Strategy() { balance = 0; leverageMultiplier = 1.0; }
    virtual ~Strategy() {}

    virtual bool   Init()      { return true; }
    virtual int    GetSignal() { return 0; }
    virtual string GetName()   { return ""; }

    double GetBalance()            { return balance; }
    void   SetBalance(double b)    { balance = b; }
    double GetLeverage()           { return leverageMultiplier; }
};

#endif

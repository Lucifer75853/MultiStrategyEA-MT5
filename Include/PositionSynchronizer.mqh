//+------------------------------------------------------------------+
//| Position Synchronizer - Pozíció szinkronizálás API-ból            |
//+------------------------------------------------------------------+
#ifndef POSITION_SYNCHRONIZER_MQH
#define POSITION_SYNCHRONIZER_MQH

#include <Trade\Trade.mqh>

struct OpenPosition
{
    int ticket;
    int type;                    // POSITION_TYPE_BUY vagy POSITION_TYPE_SELL
    double lots;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double currentProfit;
    datetime openTime;
    string comment;
    double marginUsed;
};

class PositionSynchronizer
{
private:
    OpenPosition positions[];
    int positionCount;
    datetime lastSyncTime;
    int syncIntervalSeconds;
    
    CTrade trade;
    
public:
    PositionSynchronizer()
    {
        positionCount = 0;
        lastSyncTime = 0;
        syncIntervalSeconds = 60;  // Szinkronizálás percenként
        ArrayResize(positions, 10);
    }
    
    //+------ Inicializálás ------+
    bool Init()
    {
        // Trade módosítók beállítása
        trade.SetExpertMagicNumber(12345);
        trade.SetDeviationInPoints(10);
        trade.SetAsyncMode(false);
        
        Print("✅ Pozíció Szinkronizáló inicializálva");
        return true;
    }
    
    //+------ Pozíciók Szinkronizálása ------+
    bool SyncPositions()
    {
        // Szinkronizálás csak intervallum után
        if(TimeCurrent() - lastSyncTime < syncIntervalSeconds)
            return false;
        
        // Régi pozíciók törlése
        positionCount = 0;
        
        // Összes pozíció lekérdezése
        int totalPositions = PositionsTotal();
        
        if(totalPositions == 0)
        {
            Print("ℹ️ Nincsenek nyitott pozíciók");
            lastSyncTime = TimeCurrent();
            return true;
        }
        
        // Array átméretezése ha szükséges
        if(totalPositions > ArraySize(positions))
        {
            ArrayResize(positions, totalPositions + 5);
        }
        
        // Pozíciók olvasása
        for(int i = 0; i < totalPositions; i++)
        {
            if(PositionGetTicket(i) == 0)
                continue;
            
            // Adatok kiolvasása a szimbolum alapján
            ulong positionTicket = PositionGetTicket(i);
            
            if(PositionSelectByTicket(positionTicket))
            {
                OpenPosition &pos = positions[positionCount];
                
                pos.ticket = (int)PositionGetInteger(POSITION_TICKET);
                pos.type = (int)PositionGetInteger(POSITION_TYPE);
                pos.lots = PositionGetDouble(POSITION_VOLUME);
                pos.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                pos.stopLoss = PositionGetDouble(POSITION_SL);
                pos.takeProfit = PositionGetDouble(POSITION_TP);
                pos.currentProfit = PositionGetDouble(POSITION_PROFIT);
                pos.openTime = (datetime)PositionGetInteger(POSITION_TIME);
                pos.comment = PositionGetString(POSITION_COMMENT);
                pos.marginUsed = PositionGetDouble(POSITION_MARGIN);
                
                positionCount++;
            }
        }
        
        lastSyncTime = TimeCurrent();
        
        if(positionCount > 0)
        {
            Print("✅ Szinkronizálva: " + IntegerToString(positionCount) + " pozíció");
            PrintPositions();
        }
        
        return true;
    }
    
    //+------ Pozíciók Megjelenítése ------+
    void PrintPositions()
    {
        if(positionCount == 0)
        {
            Print("ℹ️ Nincsenek nyitott pozíciók");
            return;
        }
        
        Print("\n╔═══════════════════════════════════════════════════╗");
        Print("║          NYITOTT POZÍCIÓK (" + IntegerToString(positionCount) + ")");
        Print("╠═══════════════════════════════════════════════════╣");
        
        for(int i = 0; i < positionCount; i++)
        {
            string type = (positions[i].type == POSITION_TYPE_BUY) ? "🟢 BUY" : "🔴 SELL";
            string profitStr = (positions[i].currentProfit >= 0) ? "✅ +" : "❌ ";
            
            Print("║ #" + IntegerToString(positions[i].ticket) + " | " + type);
            Print("║   Lot: " + DoubleToStr(positions[i].lots, 2));
            Print("║   Entry: " + DoubleToStr(positions[i].entryPrice, 4));
            Print("║   SL: " + DoubleToStr(positions[i].stopLoss, 4) + 
                  " | TP: " + DoubleToStr(positions[i].takeProfit, 4));
            Print("║   P/L: " + profitStr + DoubleToStr(MathAbs(positions[i].currentProfit), 2) + " USD");
            Print("║───────────────────────────────────────────────────");
        }
        
        Print("╚═══════════════════════════════════════════════════╝\n");
    }
    
    //+------ Pozíció Lezárása ------+
    bool ClosePosition(int ticket)
    {
        if(!PositionSelectByTicket(ticket))
        {
            Print("❌ Hiba: Pozíció nem található - Ticket: " + IntegerToString(ticket));
            return false;
        }
        
        if(!trade.PositionClose(ticket))
        {
            Print("❌ Hiba: Nem sikerült lezárni a pozíciót!");
            Print("   Error: " + IntegerToString(GetLastError()));
            return false;
        }
        
        Print("✅ Pozíció lezárva - Ticket: " + IntegerToString(ticket));
        return true;
    }
    
    //+------ Stop Loss Módosítása ------+
    bool ModifyStopLoss(int ticket, double newSL)
    {
        if(!PositionSelectByTicket(ticket))
        {
            Print("❌ Hiba: Pozíció nem található - Ticket: " + IntegerToString(ticket));
            return false;
        }
        
        double currentTP = PositionGetDouble(POSITION_TP);
        
        if(!trade.PositionModify(ticket, newSL, currentTP))
        {
            Print("❌ Hiba: Nem sikerült módosítani az SL-t!");
            return false;
        }
        
        Print("✅ Stop Loss módosítva - Új SL: " + DoubleToStr(newSL, 4));
        return true;
    }
    
    //+------ Take Profit Módosítása ------+
    bool ModifyTakeProfit(int ticket, double newTP)
    {
        if(!PositionSelectByTicket(ticket))
        {
            Print("❌ Hiba: Pozíció nem található - Ticket: " + IntegerToString(ticket));
            return false;
        }
        
        double currentSL = PositionGetDouble(POSITION_SL);
        
        if(!trade.PositionModify(ticket, currentSL, newTP))
        {
            Print("❌ Hiba: Nem sikerült módosítani a TP-t!");
            return false;
        }
        
        Print("✅ Take Profit módosítva - Új TP: " + DoubleToStr(newTP, 4));
        return true;
    }
    
    //+------ Getter függvények ------+
    int GetPositionCount() { return positionCount; }
    
    int GetPositionTicket(int index)
    {
        if(index >= 0 && index < positionCount)
            return positions[index].ticket;
        return -1;
    }
    
    double GetPositionProfit(int index)
    {
        if(index >= 0 && index < positionCount)
            return positions[index].currentProfit;
        return 0;
    }
    
    double GetTotalProfit()
    {
        double totalProfit = 0;
        for(int i = 0; i < positionCount; i++)
            totalProfit += positions[i].currentProfit;
        return totalProfit;
    }
    
    OpenPosition* GetPosition(int index)
    {
        if(index >= 0 && index < positionCount)
            return &positions[index];
        return NULL;
    }
    
    int GetSyncIntervalSeconds() { return syncIntervalSeconds; }
    void SetSyncIntervalSeconds(int seconds) { syncIntervalSeconds = MathMax(30, seconds); }
};

#endif
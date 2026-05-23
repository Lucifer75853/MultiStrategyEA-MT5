//+------------------------------------------------------------------+
//| Data Manager - Adatok mentése és helyreállítása                   |
//+------------------------------------------------------------------+
#ifndef DATA_MANAGER_MQH
#define DATA_MANAGER_MQH

class DataManager
{
private:
    string dataFolder;
    string dataFile;
    string backupFile;
    int lastSaveTime;
    int saveInterval;  // másodperc

public:
    DataManager(string folder = "MultiStrategyEA")
    {
        dataFolder = folder;
        dataFile = dataFolder + "/session_data.dat";
        backupFile = dataFolder + "/session_data.bak";
        lastSaveTime = 0;
        saveInterval = 300;  // 5 percenként mentés
        
        // Mappa létrehozása
        if(!FileIsExist(dataFolder)) CreateDirectory(dataFolder);
    }
    
    //+------ Sessionn adatok mentése ------+
    bool SaveSessionData(
        double accountBalance,
        double equity,
        double profit,
        double profitPercent,
        int totalTrades,
        int winTrades,
        int lossTrades,
        double drawdown,
        string strategy1Name,
        double strategy1Balance,
        string strategy2Name,
        double strategy2Balance)
    {
        if(GetTickCount() - lastSaveTime < saveInterval * 1000)
            return true;  // Még nem itt az ideje mentésnek
        
        int handle = FileOpen(dataFile, FILE_WRITE | FILE_TXT);
        if(handle == INVALID_HANDLE)
        {
            Print("HIBA: Nem tudom megnyitni az adatfájlt: ", dataFile);
            return false;
        }
        
        // Jelenlegi mentés biztonsági mentésé (backup)
        if(FileIsExist(dataFile))
            FileCopy(dataFile, backupFile, FILE_COMMON);
        
        // Új adatok írása
        FileWrite(handle, "===== MultiStrategyEA Session Data =====");
        FileWrite(handle, "DateTime|" + TimeToString(TimeCurrent()));
        FileWrite(handle, "AccountBalance|" + DoubleToString(accountBalance, 2));
        FileWrite(handle, "Equity|" + DoubleToString(equity, 2));
        FileWrite(handle, "Profit|" + DoubleToString(profit, 2));
        FileWrite(handle, "ProfitPercent|" + DoubleToString(profitPercent, 2));
        FileWrite(handle, "TotalTrades|" + IntegerToString(totalTrades));
        FileWrite(handle, "WinTrades|" + IntegerToString(winTrades));
        FileWrite(handle, "LossTrades|" + IntegerToString(lossTrades));
        FileWrite(handle, "Drawdown|" + DoubleToString(drawdown, 2));
        FileWrite(handle, "Strategy1|" + strategy1Name + "|" + DoubleToString(strategy1Balance, 2));
        FileWrite(handle, "Strategy2|" + strategy2Name + "|" + DoubleToString(strategy2Balance, 2));
        FileWrite(handle, "=====================================");
        
        FileClose(handle);
        lastSaveTime = GetTickCount();
        
        Print("✓ Adatok mentve: ", dataFile);
        return true;
    }
    
    //+------ Sessionn adatok helyreállítása ------+
    bool RestoreSessionData()
    {
        if(!FileIsExist(dataFile))
        {
            Print("! Nincs mentett session adat. Új session indul.");
            return false;
        }
        
        int handle = FileOpen(dataFile, FILE_READ | FILE_TXT);
        if(handle == INVALID_HANDLE)
        {
            Print("HIBA: Session adat helyreállítása sikertelen!");
            
            // Backup visszaállítása
            if(FileIsExist(backupFile))
            {
                FileCopy(backupFile, dataFile, FILE_COMMON);
                Print("✓ Backup fájl visszaállítva!");
                return true;
            }
            return false;
        }
        
        Print("✓ Session adatok betöltve!");
        FileClose(handle);
        return true;
    }
    
    //+------ Adatok kiolvasása ------+
    double GetLastBalance()
    {
        if(!FileIsExist(dataFile)) return -1;
        
        int handle = FileOpen(dataFile, FILE_READ | FILE_TXT);
        if(handle == INVALID_HANDLE) return -1;
        
        string line;
        while(!FileIsEnding(handle))
        {
            line = FileReadString(handle);
            if(StringFind(line, "AccountBalance|") != -1)
            {
                string value = StringSubstr(line, 15);
                FileClose(handle);
                return StringToDouble(value);
            }
        }
        
        FileClose(handle);
        return -1;
    }
    
    //+------ Emergency backup ------+
    bool CreateEmergencyBackup()
    {
        string emergencyFile = dataFolder + "/emergency_backup_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + ".dat";
        
        if(FileIsExist(dataFile))
        {
            FileCopy(dataFile, emergencyFile, FILE_COMMON);
            Print("⚠ Emergency backup készítve: ", emergencyFile);
            return true;
        }
        return false;
    }
    
    //+------ Hibás szakadás helyreállítása ------+
    bool RecoverFromCrash()
    {
        if(FileIsExist(backupFile))
        {
            FileCopy(backupFile, dataFile, FILE_COMMON);
            Print("🔄 Helyreállítva crashból (backup)");
            return true;
        }
        return false;
    }
};

#endif

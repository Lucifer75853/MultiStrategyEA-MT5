//+------------------------------------------------------------------+
//| Data Manager - Adatok mentése és helyreállítása (MT5)            |
//+------------------------------------------------------------------+
#ifndef DATA_MANAGER_MQH
#define DATA_MANAGER_MQH

class DataManager
{
private:
    string dataFolder;
    string dataFile;
    string backupFile;
    uint   lastSaveTime;
    int    saveInterval;

public:
    DataManager(string folder = "MultiStrategyEA")
    {
        dataFolder   = folder;
        dataFile     = dataFolder + "/session_data.dat";
        backupFile   = dataFolder + "/session_data.bak";
        lastSaveTime = 0;
        saveInterval = 300;
        FolderCreate(dataFolder, FILE_COMMON);
    }

    bool SaveSessionData(
        double accountBalance,
        double equity,
        double profit,
        double profitPercent,
        int    totalTrades,
        int    winTrades,
        int    lossTrades,
        double drawdown,
        string strategy1Name,
        double strategy1Balance,
        string strategy2Name,
        double strategy2Balance)
    {
        if(GetTickCount() - lastSaveTime < (uint)(saveInterval * 1000))
            return true;

        // Biztonsági mentés
        if(FileIsExist(dataFile, FILE_COMMON))
            FileCopy(dataFile, FILE_COMMON, backupFile, FILE_COMMON);

        int handle = FileOpen(dataFile, FILE_WRITE | FILE_TXT | FILE_COMMON);
        if(handle == INVALID_HANDLE)
        {
            Print("HIBA: Nem tudom megnyitni: ", dataFile);
            return false;
        }

        FileWrite(handle, "===== MultiStrategyEA Session Data =====");
        FileWrite(handle, "DateTime|" + TimeToString(TimeCurrent()));
        FileWrite(handle, "AccountBalance|"  + DoubleToString(accountBalance, 2));
        FileWrite(handle, "Equity|"          + DoubleToString(equity, 2));
        FileWrite(handle, "Profit|"          + DoubleToString(profit, 2));
        FileWrite(handle, "ProfitPercent|"   + DoubleToString(profitPercent, 2));
        FileWrite(handle, "TotalTrades|"     + IntegerToString(totalTrades));
        FileWrite(handle, "WinTrades|"       + IntegerToString(winTrades));
        FileWrite(handle, "LossTrades|"      + IntegerToString(lossTrades));
        FileWrite(handle, "Drawdown|"        + DoubleToString(drawdown, 2));
        FileWrite(handle, "Strategy1|" + strategy1Name + "|" + DoubleToString(strategy1Balance, 2));
        FileWrite(handle, "Strategy2|" + strategy2Name + "|" + DoubleToString(strategy2Balance, 2));
        FileWrite(handle, "=====================================");

        FileClose(handle);
        lastSaveTime = GetTickCount();
        Print("Adatok mentve: ", dataFile);
        return true;
    }

    bool RestoreSessionData()
    {
        if(!FileIsExist(dataFile, FILE_COMMON))
        {
            Print("Nincs mentett session adat. Új session indul.");
            return false;
        }

        int handle = FileOpen(dataFile, FILE_READ | FILE_TXT | FILE_COMMON);
        if(handle == INVALID_HANDLE)
        {
            Print("HIBA: Session adat helyreállítása sikertelen!");
            if(FileIsExist(backupFile, FILE_COMMON))
            {
                FileCopy(backupFile, FILE_COMMON, dataFile, FILE_COMMON);
                Print("Backup fájl visszaállítva!");
                return true;
            }
            return false;
        }

        Print("Session adatok betöltve!");
        FileClose(handle);
        return true;
    }

    double GetLastBalance()
    {
        if(!FileIsExist(dataFile, FILE_COMMON)) return -1;
        int handle = FileOpen(dataFile, FILE_READ | FILE_TXT | FILE_COMMON);
        if(handle == INVALID_HANDLE) return -1;

        while(!FileIsEnding(handle))
        {
            string line = FileReadString(handle);
            if(StringFind(line, "AccountBalance|") != -1)
            {
                FileClose(handle);
                return StringToDouble(StringSubstr(line, 15));
            }
        }
        FileClose(handle);
        return -1;
    }

    bool CreateEmergencyBackup()
    {
        if(!FileIsExist(dataFile, FILE_COMMON)) return false;
        string emergencyFile = dataFolder + "/emergency_" +
                               TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES) + ".dat";
        FileCopy(dataFile, FILE_COMMON, emergencyFile, FILE_COMMON);
        Print("Emergency backup: ", emergencyFile);
        return true;
    }

    bool RecoverFromCrash()
    {
        if(!FileIsExist(backupFile, FILE_COMMON)) return false;
        FileCopy(backupFile, FILE_COMMON, dataFile, FILE_COMMON);
        Print("Helyreállítva crashból (backup)");
        return true;
    }
};

#endif

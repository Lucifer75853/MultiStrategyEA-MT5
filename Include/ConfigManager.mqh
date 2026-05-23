//+------------------------------------------------------------------+
//| Configuration Manager - JSON alapú konfiguráció kezelés (MT5)    |
//+------------------------------------------------------------------+
#ifndef CONFIG_MANAGER_MQH
#define CONFIG_MANAGER_MQH

class ConfigManager
{
private:
    string configPath;
    string configFileName;
    bool   isLoaded;

    string telegramToken;
    string telegramChatID;
    string whatsappAccountSID;
    string whatsappAuthToken;
    string whatsappFromNumber;
    string whatsappToNumber;

    int  telegramRateLimit;
    int  retryAttempts;
    int  retryDelayMs;
    int  requestTimeoutMs;
    bool telegramEnabled;
    bool whatsappEnabled;

public:
    ConfigManager()
    {
        configPath      = "Config/";
        configFileName  = "NotificationConfig.json";
        isLoaded        = false;
        telegramRateLimit = 30;
        retryAttempts   = 3;
        retryDelayMs    = 1000;
        requestTimeoutMs = 5000;
        telegramEnabled = false;
        whatsappEnabled = false;
    }

    bool LoadConfig()
    {
        string fullPath = configPath + configFileName;

        if(!FileIsExist(fullPath, FILE_COMMON))
        {
            Alert("Hiba: Konfigurációs fájl nem található: " + fullPath);
            return false;
        }

        int fileHandle = FileOpen(fullPath, FILE_READ | FILE_COMMON | FILE_ANSI);
        if(fileHandle == INVALID_HANDLE)
        {
            Print("Hiba: Nem lehet megnyitni: " + fullPath);
            return false;
        }

        string jsonContent = "";
        while(!FileIsEnding(fileHandle))
            jsonContent += FileReadString(fileHandle);
        FileClose(fileHandle);

        if(!ParseJSON(jsonContent))
        {
            Print("Hiba: Érvénytelen JSON formátum");
            return false;
        }

        isLoaded = true;
        Print("Konfigurációs fájl betöltve!");
        return true;
    }

    bool ParseJSON(string json)
    {
        if(!ExtractJsonString(json, "\"token\"",       telegramToken))       telegramToken = "";
        if(!ExtractJsonString(json, "\"chat_id\"",     telegramChatID))      telegramChatID = "";
        if(!ExtractJsonBool(json,   "\"enabled\"",     telegramEnabled, 0))  telegramEnabled = false;

        if(!ExtractJsonString(json, "\"account_sid\"", whatsappAccountSID)) whatsappAccountSID = "";
        if(!ExtractJsonString(json, "\"auth_token\"",  whatsappAuthToken))  whatsappAuthToken = "";
        if(!ExtractJsonString(json, "\"from_number\"", whatsappFromNumber)) whatsappFromNumber = "";
        if(!ExtractJsonString(json, "\"to_number\"",   whatsappToNumber))   whatsappToNumber = "";

        if(!ExtractJsonInt(json, "\"telegram_rate_limit\"", telegramRateLimit)) telegramRateLimit = 30;
        if(!ExtractJsonInt(json, "\"retry_attempts\"",      retryAttempts))     retryAttempts = 3;
        if(!ExtractJsonInt(json, "\"retry_delay_ms\"",      retryDelayMs))      retryDelayMs = 1000;
        if(!ExtractJsonInt(json, "\"request_timeout\"",     requestTimeoutMs))  requestTimeoutMs = 5000;

        return true;
    }

    bool ExtractJsonString(string json, string key, string &value)
    {
        int pos = StringFind(json, key);
        if(pos == -1) return false;
        int colonPos = StringFind(json, ":", pos);
        if(colonPos == -1) return false;
        int startQ = StringFind(json, "\"", colonPos);
        if(startQ == -1) return false;
        int endQ = StringFind(json, "\"", startQ + 1);
        if(endQ == -1) return false;
        value = StringSubstr(json, startQ + 1, endQ - startQ - 1);
        return (value != "");
    }

    bool ExtractJsonInt(string json, string key, int &value)
    {
        int pos = StringFind(json, key);
        if(pos == -1) return false;
        int colonPos = StringFind(json, ":", pos);
        if(colonPos == -1) return false;

        string numStr = "";
        int i = colonPos + 1;
        while(i < StringLen(json))
        {
            ushort c = StringGetCharacter(json, i);
            if(c >= '0' && c <= '9') { numStr += CharToString((uchar)c); i++; }
            else if(numStr != "") break;
            else i++;
        }
        if(numStr == "") return false;
        value = (int)StringToInteger(numStr);
        return true;
    }

    bool ExtractJsonBool(string json, string key, bool &value, int index = 0)
    {
        int pos = -1;
        for(int i = 0; i <= index; i++)
        {
            pos = StringFind(json, key, pos + 1);
            if(pos == -1) return false;
        }
        int colonPos = StringFind(json, ":", pos);
        if(colonPos == -1) return false;
        string checkStr = StringSubstr(json, colonPos + 1, 10);
        if(StringFind(checkStr, "true")  != -1) { value = true;  return true; }
        if(StringFind(checkStr, "false") != -1) { value = false; return true; }
        return false;
    }

    bool ValidateConfig()
    {
        if(!isLoaded) return false;
        if(telegramEnabled && StringFind(telegramToken, "PASTE_YOUR") != -1)
        {
            Alert("FIGYELEM: Telegram token nincs beállítva!");
            return false;
        }
        if(telegramEnabled && StringLen(telegramChatID) < 5)
        {
            Alert("FIGYELEM: Telegram Chat ID érvénytelen!");
            return false;
        }
        return true;
    }

    string GetTelegramToken()      { return isLoaded ? telegramToken       : ""; }
    string GetTelegramChatID()     { return isLoaded ? telegramChatID      : ""; }
    string GetWhatsAppAccountSID() { return isLoaded ? whatsappAccountSID  : ""; }
    string GetWhatsAppAuthToken()  { return isLoaded ? whatsappAuthToken   : ""; }
    string GetWhatsAppFromNumber() { return isLoaded ? whatsappFromNumber  : ""; }
    string GetWhatsAppToNumber()   { return isLoaded ? whatsappToNumber    : ""; }

    int  GetTelegramRateLimit()   { return telegramRateLimit; }
    int  GetRetryAttempts()       { return retryAttempts; }
    int  GetRetryDelayMs()        { return retryDelayMs; }
    int  GetRequestTimeoutMs()    { return requestTimeoutMs; }
    bool IsTelegramEnabled()      { return isLoaded && telegramEnabled; }
    bool IsWhatsAppEnabled()      { return isLoaded && whatsappEnabled; }
    bool IsLoaded()               { return isLoaded; }
};

#endif

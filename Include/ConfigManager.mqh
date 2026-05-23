//+------------------------------------------------------------------+
//| Configuration Manager - Biztonságos konfiguráció kezelés          |
//| JSON alapú konfigurációs fájl kezelő                             |
//+------------------------------------------------------------------+
#ifndef CONFIG_MANAGER_MQH
#define CONFIG_MANAGER_MQH

#include <Files\FileTxt.mqh>
#include <Files\Json.mqh>

class ConfigManager
{
private:
    string configPath;
    string configFileName;
    bool isLoaded;
    
    // Cached értékek
    string telegramToken;
    string telegramChatID;
    string whatsappAccountSID;
    string whatsappAuthToken;
    string whatsappFromNumber;
    string whatsappToNumber;
    
    int telegramRateLimit;
    int retryAttempts;
    int retryDelayMs;
    int requestTimeoutMs;
    bool telegramEnabled;
    bool whatsappEnabled;
    
public:
    ConfigManager()
    {
        configPath = "Config/";
        configFileName = "NotificationConfig.json";
        isLoaded = false;
        
        // Alapértelmezett értékek
        telegramRateLimit = 30;
        retryAttempts = 3;
        retryDelayMs = 1000;
        requestTimeoutMs = 5000;
    }
    
    //+------ Konfiguráció Betöltése ------+
    bool LoadConfig()
    {
        string fullPath = configPath + configFileName;
        
        // Fájl létezésének ellenőrzése
        if(!FileExists(fullPath, FILE_COMMON))
        {
            Alert("❌ Hiba: Konfigurációs fájl nem található: " + fullPath);
            Print("Hozd létre az ezt a fájlt: " + fullPath);
            return false;
        }
        
        // Fájl olvasása
        int fileHandle = FileOpen(fullPath, FILE_READ | FILE_COMMON | FILE_ANSI);
        
        if(fileHandle == INVALID_HANDLE)
        {
            Print("❌ Hiba: Nem lehet megnyitni a config fájlt: " + fullPath);
            return false;
        }
        
        string jsonContent = "";
        while(!FileIsEnding(fileHandle))
        {
            jsonContent += FileReadString(fileHandle);
        }
        FileClose(fileHandle);
        
        // JSON Parse
        if(!ParseJSON(jsonContent))
        {
            Print("❌ Hiba: Érvénytelen JSON formátum");
            return false;
        }
        
        isLoaded = true;
        Print("✅ Konfigurációs fájl sikeresen betöltve!");
        
        return true;
    }
    
    //+------ JSON Parse (Egyszerű String-alapú parser) ------+
    bool ParseJSON(string jsonContent)
    {
        // Telegram szekció
        if(!ExtractJsonString(jsonContent, "\"token\"", telegramToken))
            telegramToken = "";
        
        if(!ExtractJsonString(jsonContent, "\"chat_id\"", telegramChatID))
            telegramChatID = "";
        
        if(!ExtractJsonBool(jsonContent, "\"enabled\"", telegramEnabled, 0))
            telegramEnabled = false;
        
        // WhatsApp szekció
        if(!ExtractJsonString(jsonContent, "\"account_sid\"", whatsappAccountSID))
            whatsappAccountSID = "";
        
        if(!ExtractJsonString(jsonContent, "\"auth_token\"", whatsappAuthToken))
            whatsappAuthToken = "";
        
        if(!ExtractJsonString(jsonContent, "\"from_number\"", whatsappFromNumber))
            whatsappFromNumber = "";
        
        if(!ExtractJsonString(jsonContent, "\"to_number\"", whatsappToNumber))
            whatsappToNumber = "";
        
        // API Settings
        if(!ExtractJsonInt(jsonContent, "\"telegram_rate_limit\"", telegramRateLimit))
            telegramRateLimit = 30;
        
        if(!ExtractJsonInt(jsonContent, "\"retry_attempts\"", retryAttempts))
            retryAttempts = 3;
        
        if(!ExtractJsonInt(jsonContent, "\"retry_delay_ms\"", retryDelayMs))
            retryDelayMs = 1000;
        
        if(!ExtractJsonInt(jsonContent, "\"request_timeout\"", requestTimeoutMs))
            requestTimeoutMs = 5000;
        
        return true;
    }
    
    //+------ String Érték Kinyerése JSON-ből ------+
    bool ExtractJsonString(string json, string key, string &value)
    {
        int pos = StringFind(json, key);
        if(pos == -1)
            return false;
        
        // Pozíció a ":" után
        int colonPos = StringFind(json, ":", pos);
        if(colonPos == -1)
            return false;
        
        // Idézőjelek közötti tartalom
        int startQuote = StringFind(json, "\"", colonPos);
        if(startQuote == -1)
            return false;
        
        int endQuote = StringFind(json, "\"", startQuote + 1);
        if(endQuote == -1)
            return false;
        
        value = StringSubstr(json, startQuote + 1, endQuote - startQuote - 1);
        
        return (value != "");
    }
    
    //+------ Integer Érték Kinyerése JSON-ből ------+
    bool ExtractJsonInt(string json, string key, int &value)
    {
        int pos = StringFind(json, key);
        if(pos == -1)
            return false;
        
        int colonPos = StringFind(json, ":", pos);
        if(colonPos == -1)
            return false;
        
        // Szám keresése a ":" után
        string numStr = "";
        int i = colonPos + 1;
        
        while(i < StringLen(json))
        {
            char c = StringGetChar(json, i);
            if(c >= '0' && c <= '9')
            {
                numStr += CharToString(c);
                i++;
            }
            else if(numStr != "")
                break;
            else
                i++;
        }
        
        if(numStr == "")
            return false;
        
        value = (int)StringToInteger(numStr);
        return true;
    }
    
    //+------ Boolean Érték Kinyerése JSON-ből ------+
    bool ExtractJsonBool(string json, string key, bool &value, int index = 0)
    {
        int pos = -1;
        
        // n-edik előfordulást keresni
        for(int i = 0; i <= index; i++)
        {
            pos = StringFind(json, key, pos + 1);
            if(pos == -1)
                return false;
        }
        
        int colonPos = StringFind(json, ":", pos);
        if(colonPos == -1)
            return false;
        
        // "true" vagy "false" keresése
        string checkStr = StringSubstr(json, colonPos + 1, 10);
        
        if(StringFind(checkStr, "true") != -1)
        {
            value = true;
            return true;
        }
        else if(StringFind(checkStr, "false") != -1)
        {
            value = false;
            return true;
        }
        
        return false;
    }
    
    //+------ Getter függvények ------+
    string GetTelegramToken() { return (isLoaded) ? telegramToken : ""; }
    string GetTelegramChatID() { return (isLoaded) ? telegramChatID : ""; }
    string GetWhatsAppAccountSID() { return (isLoaded) ? whatsappAccountSID : ""; }
    string GetWhatsAppAuthToken() { return (isLoaded) ? whatsappAuthToken : ""; }
    string GetWhatsAppFromNumber() { return (isLoaded) ? whatsappFromNumber : ""; }
    string GetWhatsAppToNumber() { return (isLoaded) ? whatsappToNumber : ""; }
    
    int GetTelegramRateLimit() { return telegramRateLimit; }
    int GetRetryAttempts() { return retryAttempts; }
    int GetRetryDelayMs() { return retryDelayMs; }
    int GetRequestTimeoutMs() { return requestTimeoutMs; }
    
    bool IsTelegramEnabled() { return (isLoaded && telegramEnabled); }
    bool IsWhatsAppEnabled() { return (isLoaded && whatsappEnabled); }
    bool IsLoaded() { return isLoaded; }
    
    //+------ Biztonsági ellenőrzés ------+
    bool ValidateConfig()
    {
        if(!isLoaded)
            return false;
        
        // Telegram token nincs a placeholder értéken
        if(telegramEnabled && StringFind(telegramToken, "PASTE_YOUR") != -1)
        {
            Alert("⚠️ FIGYELEM: Telegram token nincs beállítva!");
            Print("Szerkeszd a Config/NotificationConfig.json fájlt!");
            return false;
        }
        
        // Chat ID ellenőrzése
        if(telegramEnabled && StringLen(telegramChatID) < 5)
        {
            Alert("⚠️ FIGYELEM: Telegram Chat ID érvénytelen!");
            return false;
        }
        
        return true;
    }
    
    //+------ Megjelenítés (Teszteléshez) ------+
    void PrintConfig()
    {
        Print("\n=== KONFIGURÁCIÓS BEÁLLÍTÁSOK ===");
        Print("Telegram Token: " + (StringLen(telegramToken) > 0 ? "*** (beállítva)" : "NEM BEÁLLÍTVA"));
        Print("Telegram Chat ID: " + telegramChatID);
        Print("Telegram Enabled: " + (telegramEnabled ? "IGEN" : "NEM"));
        Print("WhatsApp Enabled: " + (whatsappEnabled ? "IGEN" : "NEM"));
        Print("Rate Limit: " + IntegerToString(telegramRateLimit) + " msg/perc");
        Print("Retry Attempts: " + IntegerToString(retryAttempts));
        Print("Retry Delay: " + IntegerToString(retryDelayMs) + "ms");
        Print("Request Timeout: " + IntegerToString(requestTimeoutMs) + "ms");
        Print("=================================\n");
    }
};

#endif

//+------------------------------------------------------------------+
//| Notification Manager - Telegram/WhatsApp üzenetküldés             |
//| Javított verzió: Valódi HTTP, Rate Limiting, Retry logika         |
//+------------------------------------------------------------------+
#ifndef NOTIFICATION_MANAGER_MQH
#define NOTIFICATION_MANAGER_MQH

#include "Base64.mqh"

// Rate Limiter struktura
struct RateLimitTracker
{
    datetime lastRequestTime;
    int requestCount;
    int requestsPerMinute;
};

class NotificationManager
{
private:
    // Telegram Settings
    string telegramToken;
    string telegramChatID;
    bool telegramEnabled;
    
    // WhatsApp Settings (Twilio)
    string whatsappAccountSID;
    string whatsappAuthToken;
    string whatsappFromNumber;
    string whatsappToNumber;
    bool whatsappEnabled;
    
    // Notification Frequency
    int notificationsPerDay;
    datetime lastNotificationTime;
    int notificationInterval;
    
    // Statistics
    int tradesOpened;
    int tradesClosed;
    double sessionStartEquity;
    double sessionProfit;
    
    // Rate Limiting
    RateLimitTracker telegramRateLimit;
    RateLimitTracker whatsappRateLimit;
    
    // Retry paraméterek
    int maxRetries;
    int retryDelayMs;
    int requestTimeoutMs;
    
public:
    NotificationManager()
    {
        telegramEnabled = false;
        whatsappEnabled = false;
        tradesOpened = 0;
        tradesClosed = 0;
        lastNotificationTime = 0;
        notificationsPerDay = 3;
        sessionStartEquity = AccountEquity();
        sessionProfit = 0;
        
        // Rate Limiting inicializálás
        telegramRateLimit.lastRequestTime = 0;
        telegramRateLimit.requestCount = 0;
        telegramRateLimit.requestsPerMinute = 30;  // Telegram limit
        
        whatsappRateLimit.lastRequestTime = 0;
        whatsappRateLimit.requestCount = 0;
        whatsappRateLimit.requestsPerMinute = 60;  // Twilio limit
        
        // Retry paraméterek
        maxRetries = 3;
        retryDelayMs = 1000;
        requestTimeoutMs = 5000;
    }
    
    //+------ Telegram Inicializálás ------+
    void InitTelegram(string token, string chatID)
    {
        telegramToken = token;
        telegramChatID = Trim(chatID);  // Szóközök eltávolítása
        telegramEnabled = true;
        
        Print("✅ Telegram inicializálva - Chat ID: " + telegramChatID);
        SendTelegram("🤖 MultiStrategyEA - Telegram Notifikáció Aktív!");
    }
    
    //+------ WhatsApp Inicializálás (Twilio) ------+
    void InitWhatsApp(string accountSID, string authToken, string fromNumber, string toNumber)
    {
        whatsappAccountSID = accountSID;
        whatsappAuthToken = authToken;
        whatsappFromNumber = fromNumber;
        whatsappToNumber = toNumber;
        whatsappEnabled = true;
        
        Print("✅ WhatsApp inicializálva - Szám: " + whatsappToNumber);
        SendWhatsApp("🤖 MultiStrategyEA - WhatsApp Notifikáció Aktív!");
    }
    
    //+------ Telegram Üzenet Küldése (Retry logikával) ------+
    bool SendTelegram(string message)
    {
        if(!telegramEnabled || telegramToken == "" || telegramChatID == "")
        {
            Print("⚠️ Telegram nincs inicializálva!");
            return false;
        }
        
        // Rate Limit ellenőrzése
        if(!CheckRateLimit(telegramRateLimit))
        {
            Print("⚠️ Telegram Rate Limit elérve! Próbálkozás később.");
            return false;
        }
        
        // API URL
        string url = "https://api.telegram.org/bot" + telegramToken + "/sendMessage";
        
        // Üzenet adatok - chat_id is be van kódolva most
        string postData = "chat_id=" + Trim(telegramChatID) + "&text=" + UrlEncode(message);
        
        Print("📤 ========== TELEGRAM KÜLDÉS ==========");
        Print("📤 URL: " + url);
        Print("📤 Chat ID: " + Trim(telegramChatID));
        Print("📤 Üzenet: " + message);
        Print("📤 Post Data: " + postData);
        
        // HTTP Request retry logikával
        string result = SendHTTPRequestWithRetry(url, postData, "", false);
        
        Print("📥 ========== TELEGRAM VÁLASZ ==========");
        Print("📥 Nyers válasz: " + result);
        Print("📥 Válasz hossza: " + IntegerToString(StringLen(result)) + " karakter");
        
        // Ellenőrzés
        bool hasOk = StringFind(result, "ok") != -1;
        bool hasTrue = StringFind(result, "true") != -1;
        
        Print("📥 'ok' megtalálva: " + (hasOk ? "IGEN" : "NEM"));
        Print("📥 'true' megtalálva: " + (hasTrue ? "IGEN" : "NEM"));
        
        if(hasOk && hasTrue)
        {
            Print("✅ Telegram üzenet ELKÜLDVE!");
            UpdateRateLimit(telegramRateLimit);
            return true;
        }
        else
        {
            Print("❌ Telegram HIBA!");
            Print("❌ Hibaüzenet: " + result);
            return false;
        }
    }
    
    //+------ WhatsApp Üzenet Küldése (Retry logikával) ------+
    bool SendWhatsApp(string message)
    {
        if(!whatsappEnabled || whatsappAccountSID == "")
        {
            Print("⚠️ WhatsApp nincs inicializálva!");
            return false;
        }
        
        // Rate Limit ellenőrzése
        if(!CheckRateLimit(whatsappRateLimit))
        {
            Print("⚠️ WhatsApp Rate Limit elérve! Próbálkozás később.");
            return false;
        }
        
        // Twilio API URL
        string url = "https://api.twilio.com/2010-04-01/Accounts/" + whatsappAccountSID + "/Messages.json";
        
        // Üzenet adatok
        string postData = "From=" + UrlEncode(whatsappFromNumber) + 
                         "&To=" + UrlEncode(whatsappToNumber) + 
                         "&Body=" + UrlEncode(message);
        
        // Basic Auth Header létrehozása
        string credentials = whatsappAccountSID + ":" + whatsappAuthToken;
        string auth = "Basic " + Base64::Encode(credentials);
        
        // HTTP Request retry logikával
        string result = SendHTTPRequestWithRetry(url, postData, auth, true);
        
        if(StringFind(result, "sid") != -1)
        {
            Print("✅ WhatsApp üzenet elküldve!");
            UpdateRateLimit(whatsappRateLimit);
            return true;
        }
        else
        {
            Print("❌ WhatsApp hiba: " + result);
            return false;
        }
    }
    
    //+------ HTTP Request Retry logikával ------+
    string SendHTTPRequestWithRetry(string url, string postData, string authHeader, bool useAuth)
    {
        int attempt = 0;
        string result = "";
        
        while(attempt < maxRetries)
        {
            result = SendHTTPRequest(url, postData, authHeader, useAuth);
            
            Print("⏳ Attempt " + IntegerToString(attempt) + ": " + result);
            
            // Sikeres válasz
            if(StringFind(result, "ok") != -1 || StringFind(result, "sid") != -1)
                return result;
            
            // Timeout vagy hálózati hiba - retry
            if(StringFind(result, "timeout") != -1 || StringFind(result, "connection") != -1)
            {
                attempt++;
                if(attempt < maxRetries)
                {
                    Print("⚠️ Retry " + IntegerToString(attempt) + "/" + IntegerToString(maxRetries));
                    Sleep(retryDelayMs);
                }
            }
            else
            {
                // Nem retry-ozható hiba
                break;
            }
        }
        
        return result;
    }
    
    //+------ HTTP Request (Valódi WebRequest) ------+
    string SendHTTPRequest(string url, string postData, string authHeader, bool useAuth)
    {
        char dataArray[];
        char resultArray[];
        string headers = "";
        
        // Data konvertálása
        StringToCharArray(postData, dataArray, 0, WHOLE_ARRAY, CP_ACP);
        
        // Headers összeállítása
        if(useAuth)
            headers = "Authorization: " + authHeader + "\r\nContent-Type: application/x-www-form-urlencoded\r\n";
        else
            headers = "Content-Type: application/x-www-form-urlencoded\r\n";
        
        // WebRequest hívás
        int timeout = requestTimeoutMs;
        int response = WebRequest("POST", url, headers, timeout, dataArray, resultArray);
        
        Print("🔧 WebRequest HTTP response code: " + IntegerToString(response));
        
        // Válasz feldolgozása
        if(response == 200)
        {
            string result = CharArrayToString(resultArray);
            Print("🔧 Sikeres válasz (200): " + result);
            return result;
        }
        else if(response == -1)
        {
            Print("🔧 Timeout hiba (-1)");
            return "timeout";
        }
        else
        {
            string errMsg = "error_" + IntegerToString(response);
            Print("🔧 HTTP hiba: " + errMsg);
            return errMsg;
        }
    }
    
    //+------ Rate Limit Ellenőrzése ------+
    bool CheckRateLimit(RateLimitTracker &tracker)
    {
        datetime now = TimeCurrent();
        
        // Egy perc múlva reset
        if(now - tracker.lastRequestTime >= 60)
        {
            tracker.requestCount = 0;
            tracker.lastRequestTime = now;
            return true;
        }
        
        // Limit elérve
        if(tracker.requestCount >= tracker.requestsPerMinute)
            return false;
        
        return true;
    }
    
    //+------ Rate Limit Frissítése ------+
    void UpdateRateLimit(RateLimitTracker &tracker)
    {
        tracker.requestCount++;
        if(tracker.lastRequestTime == 0)
            tracker.lastRequestTime = TimeCurrent();
    }
    
    //+------ Szóközök Eltávolítása (Trim) ------+
    string Trim(string text)
    {
        int start = 0;
        int end = StringLen(text) - 1;
        
        // Elöl
        while(start <= end && (StringGetChar(text, start) == ' ' || StringGetChar(text, start) == '\t'))
            start++;
        
        // Hátul
        while(end >= start && (StringGetChar(text, end) == ' ' || StringGetChar(text, end) == '\t'))
            end--;
        
        if(start > end)
            return "";
        
        return StringSubstr(text, start, end - start + 1);
    }
    
    //+------ URL Encoding (Teljes) ------+
    string UrlEncode(string text)
    {
        string result = "";
        int len = StringLen(text);
        
        for(int i = 0; i < len; i++)
        {
            char c = StringGetChar(text, i);
            
            // Alfanumerikus és biztonságos karakterek
            if((c >= 'A' && c <= 'Z') || 
               (c >= 'a' && c <= 'z') || 
               (c >= '0' && c <= '9') ||
               c == '-' || c == '_' || c == '.' || c == '~')
            {
                result += CharToString(c);
            }
            // Szóköz -> +
            else if(c == ' ')
            {
                result += "+";
            }
            // Egyéb karakterek -> %HEX
            else
            {
                result += PercentEncode(c);
            }
        }
        
        return result;
    }
    
    //+------ Percent Encoding ------+
    string PercentEncode(char c)
    {
        string hex = "0123456789ABCDEF";
        int code = (int)(unsigned char)c;
        string result = "%";
        result += StringSubstr(hex, code / 16, 1);
        result += StringSubstr(hex, code % 16, 1);
        return result;
    }
    
    //+------ Pozíció Nyitási Notifikáció ------+
    void NotifyPositionOpen(int orderTicket, int orderType, double lots, double openPrice, 
                           double stopLoss, double takeProfit, string strategy)
    {
        tradesOpened++;
        
        string typeStr = (orderType == OP_BUY) ? "🟢 BUY" : "🔴 SELL";
        string msg = "═══════════════════════════════════\n";
        msg += "📊 POZÍCIÓ NYITVA\n";
        msg += "═══════════════════════════════════\n";
        msg += "Stratégia: " + strategy + "\n";
        msg += "Típus: " + typeStr + "\n";
        msg += "Ticket: " + IntegerToString(orderTicket) + "\n";
        msg += "Lot: " + DoubleToStr(lots, 2) + "\n";
        msg += "Entry: " + DoubleToStr(openPrice, 4) + "\n";
        msg += "SL: " + DoubleToStr(stopLoss, 4) + "\n";
        msg += "TP: " + DoubleToStr(takeProfit, 4) + "\n";
        msg += "═══════════════════════════════════\n";
        
        SendTelegram(msg);
        SendWhatsApp(msg);
        
        Print(msg);
    }
    
    //+------ Pozíció Zárási Notifikáció ------+
    void NotifyPositionClose(int orderTicket, int orderType, double closePrice, double profit)
    {
        tradesClosed++;
        
        string typeStr = (orderType == OP_BUY) ? "🟢 BUY" : "🔴 SELL";
        string profitStr = (profit >= 0) ? "✅ PROFIT: +" : "❌ LOSS: ";
        
        string msg = "═══════════════════════════════════\n";
        msg += "📊 POZÍCIÓ ZÁRVA\n";
        msg += "═══════════════════════════════════\n";
        msg += "Típus: " + typeStr + "\n";
        msg += "Ticket: " + IntegerToString(orderTicket) + "\n";
        msg += "Exit: " + DoubleToStr(closePrice, 4) + "\n";
        msg += profitStr + DoubleToStr(MathAbs(profit), 2) + " USD\n";
        msg += "═══════════════════════════════════\n";
        
        SendTelegram(msg);
        SendWhatsApp(msg);
        
        Print(msg);
    }
    
    //+------ Napi Egyenleg Notifikáció ------+
    void NotifyDailyBalance(double currentBalance, double dayProfit, double dayProfitPercent)
    {
        // Notifikáció frekvencia ellenőrzése
        if(!ShouldSendNotification())
            return;
        
        string profitStr = (dayProfit >= 0) ? "✅ PROFIT: +" : "❌ LOSS: ";
        
        string msg = "═══════════════════════════════════\n";
        msg += "💰 NAPI ÖSSZEFOGLALÓ\n";
        msg += "═══════════════════════════════════\n";
        msg += "Idő: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n";
        msg += "Egyenleg: " + DoubleToStr(currentBalance, 2) + " USD\n";
        msg += profitStr + DoubleToStr(MathAbs(dayProfit), 2) + " USD\n";
        msg += "Nyereség %: " + DoubleToStr(dayProfitPercent, 2) + "%\n";
        msg += "\n";
        msg += "📈 Kereskedések:\n";
        msg += "Nyitott: " + IntegerToString(tradesOpened) + "\n";
        msg += "Zárva: " + IntegerToString(tradesClosed) + "\n";
        msg += "═══════════════════════════════════\n";
        
        SendTelegram(msg);
        SendWhatsApp(msg);
        
        lastNotificationTime = TimeCurrent();
        
        Print(msg);
    }
    
    //+------ Riasztás: Max Napi Veszteség ------+
    void AlertMaxDailyLossReached(double maxLossPercent)
    {
        string msg = "⚠️ FIGYELMEZTETÉS\n";
        msg += "═══════════════════════════════════\n";
        msg += "Maximum napi veszteség ELÉRVE!\n";
        msg += "Limit: " + DoubleToStr(maxLossPercent, 2) + "%\n";
        msg += "Trading szüneteltetve.\n";
        msg += "═══════════════════════════════════\n";
        
        SendTelegram(msg);
        SendWhatsApp(msg);
        
        Print(msg);
    }
    
    //+------ Riasztás: Magas Volatilitás ------+
    void AlertHighVolatility(double vixValue, double atr)
    {
        string msg = "⚠️ MAGAS VOLATILITÁS\n";
        msg += "═══════════════════════════════════\n";
        msg += "VIX: " + DoubleToStr(vixValue, 2) + "\n";
        msg += "ATR(20): " + DoubleToStr(atr, 4) + "\n";
        msg += "Pozícióméret csökkentve 30%-ra.\n";
        msg += "═══════════════════════════════════\n";
        
        SendTelegram(msg);
        SendWhatsApp(msg);
        
        Print(msg);
    }
    
    //+------ Riasztás: Gazdasági Adat ------+
    void AlertEconomicEvent(string eventName, string impact, datetime eventTime)
    {
        string msg = "📰 GAZDASÁGI ADAT\n";
        msg += "═══════════════════════════════════\n";
        msg += "Esemény: " + eventName + "\n";
        msg += "Impact: " + impact + "\n";
        msg += "Idő: " + TimeToString(eventTime, TIME_DATE|TIME_MINUTES) + "\n";
        msg += "➡️ Trading pauzálva 30 percre.\n";
        msg += "═══════════════════════════════════\n";
        
        SendTelegram(msg);
        SendWhatsApp(msg);
        
        Print(msg);
    }
    
    //+------ Notifikáció Frekvencia Ellenőrzése ------+
    bool ShouldSendNotification()
    {
        if(notificationsPerDay <= 0) return false;
        
        int secondsPerNotification = 86400 / notificationsPerDay;  // 24 óra / naponta X
        
        if(TimeCurrent() - lastNotificationTime >= secondsPerNotification)
            return true;
        
        return false;
    }
    
    //+------ Getter függvények ------+
    int GetNotificationsPerDay() { return notificationsPerDay; }
    void SetNotificationsPerDay(int freq) { notificationsPerDay = freq; }
    
    int GetMaxRetries() { return maxRetries; }
    void SetMaxRetries(int retries) { maxRetries = MathMax(1, retries); }
    
    int GetRetryDelayMs() { return retryDelayMs; }
    void SetRetryDelayMs(int delay) { retryDelayMs = MathMax(100, delay); }
    
    int GetRequestTimeoutMs() { return requestTimeoutMs; }
    void SetRequestTimeoutMs(int timeout) { requestTimeoutMs = MathMax(1000, timeout); }
    
    void SetTelegramRateLimit(int requestsPerMinute) 
    { 
        telegramRateLimit.requestsPerMinute = MathMax(1, requestsPerMinute); 
    }
    
    void SetWhatsAppRateLimit(int requestsPerMinute) 
    { 
        whatsappRateLimit.requestsPerMinute = MathMax(1, requestsPerMinute); 
    }
};

// Segédfüggvény: char array -> string
string CharArrayToString(char &arr[])
{
    string result = "";
    int size = ArraySize(arr);
    
    for(int i = 0; i < size; i++)
    {
        if(arr[i] == 0)
            break;
        result += CharToString(arr[i]);
    }
    
    return result;
}

#endif

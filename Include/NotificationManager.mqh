//+------------------------------------------------------------------+
//| Notification Manager - Telegram/WhatsApp üzenetküldés (MT5)      |
//+------------------------------------------------------------------+
#ifndef NOTIFICATION_MANAGER_MQH
#define NOTIFICATION_MANAGER_MQH

#include "Base64.mqh"

struct RateLimitTracker
{
    datetime lastRequestTime;
    int      requestCount;
    int      requestsPerMinute;
};

class NotificationManager
{
private:
    string telegramToken;
    string telegramChatID;
    bool   telegramEnabled;

    string whatsappAccountSID;
    string whatsappAuthToken;
    string whatsappFromNumber;
    string whatsappToNumber;
    bool   whatsappEnabled;

    int      notificationsPerDay;
    datetime lastNotificationTime;

    int tradesOpened;
    int tradesClosed;
    double sessionStartEquity;

    RateLimitTracker telegramRateLimit;
    RateLimitTracker whatsappRateLimit;

    int maxRetries;
    int retryDelayMs;
    int requestTimeoutMs;

public:
    NotificationManager()
    {
        telegramEnabled  = false;
        whatsappEnabled  = false;
        tradesOpened     = 0;
        tradesClosed     = 0;
        lastNotificationTime = 0;
        notificationsPerDay  = 3;
        sessionStartEquity   = AccountInfoDouble(ACCOUNT_EQUITY);

        telegramRateLimit.lastRequestTime    = 0;
        telegramRateLimit.requestCount       = 0;
        telegramRateLimit.requestsPerMinute  = 30;

        whatsappRateLimit.lastRequestTime    = 0;
        whatsappRateLimit.requestCount       = 0;
        whatsappRateLimit.requestsPerMinute  = 60;

        maxRetries      = 3;
        retryDelayMs    = 1000;
        requestTimeoutMs = 5000;
    }

    void InitTelegram(string token, string chatID)
    {
        telegramToken   = token;
        telegramChatID  = Trim(chatID);
        telegramEnabled = true;
        Print("Telegram inicializálva - Chat ID: " + telegramChatID);
        SendTelegram("MultiStrategyEA MT5 - Telegram Notifikáció Aktív!");
    }

    void InitWhatsApp(string accountSID, string authToken, string fromNumber, string toNumber)
    {
        whatsappAccountSID = accountSID;
        whatsappAuthToken  = authToken;
        whatsappFromNumber = fromNumber;
        whatsappToNumber   = toNumber;
        whatsappEnabled    = true;
        Print("WhatsApp inicializálva - Szám: " + whatsappToNumber);
        SendWhatsApp("MultiStrategyEA MT5 - WhatsApp Notifikáció Aktív!");
    }

    bool SendTelegram(string message)
    {
        if(!telegramEnabled || telegramToken == "" || telegramChatID == "")
            return false;

        if(!CheckRateLimit(telegramRateLimit))
        {
            Print("Telegram Rate Limit elérve!");
            return false;
        }

        string url      = "https://api.telegram.org/bot" + telegramToken + "/sendMessage";
        string postData = "chat_id=" + Trim(telegramChatID) + "&text=" + UrlEncode(message);
        string result   = SendHTTPRequestWithRetry(url, postData, "", false);

        if(StringFind(result, "\"ok\":true") != -1)
        {
            Print("Telegram üzenet elküldve!");
            UpdateRateLimit(telegramRateLimit);
            return true;
        }

        Print("Telegram hiba: " + result);
        return false;
    }

    bool SendWhatsApp(string message)
    {
        if(!whatsappEnabled || whatsappAccountSID == "")
            return false;

        if(!CheckRateLimit(whatsappRateLimit))
        {
            Print("WhatsApp Rate Limit elérve!");
            return false;
        }

        string url      = "https://api.twilio.com/2010-04-01/Accounts/" + whatsappAccountSID + "/Messages.json";
        string postData = "From=" + UrlEncode(whatsappFromNumber) +
                          "&To=" + UrlEncode(whatsappToNumber) +
                          "&Body=" + UrlEncode(message);
        string credentials = whatsappAccountSID + ":" + whatsappAuthToken;
        string auth        = "Basic " + Base64::Encode(credentials);
        string result      = SendHTTPRequestWithRetry(url, postData, auth, true);

        if(StringFind(result, "\"sid\"") != -1)
        {
            Print("WhatsApp üzenet elküldve!");
            UpdateRateLimit(whatsappRateLimit);
            return true;
        }

        Print("WhatsApp hiba: " + result);
        return false;
    }

    string SendHTTPRequestWithRetry(string url, string postData, string authHeader, bool useAuth)
    {
        string result = "";
        for(int attempt = 0; attempt < maxRetries; attempt++)
        {
            result = SendHTTPRequest(url, postData, authHeader, useAuth);

            if(StringFind(result, "\"ok\"") != -1 || StringFind(result, "\"sid\"") != -1)
                return result;

            if(StringFind(result, "timeout") != -1 || StringFind(result, "connection") != -1)
            {
                Print("Retry " + IntegerToString(attempt + 1) + "/" + IntegerToString(maxRetries));
                Sleep(retryDelayMs);
            }
            else
                break;
        }
        return result;
    }

    string SendHTTPRequest(string url, string postData, string authHeader, bool useAuth)
    {
        char   dataArray[];
        char   resultArray[];
        string resultHeaders;
        string headers;

        StringToCharArray(postData, dataArray, 0, StringLen(postData), CP_UTF8);

        if(useAuth)
            headers = "Authorization: " + authHeader + "\r\nContent-Type: application/x-www-form-urlencoded\r\n";
        else
            headers = "Content-Type: application/x-www-form-urlencoded\r\n";

        int response = WebRequest("POST", url, headers, requestTimeoutMs, dataArray, resultArray, resultHeaders);

        if(response == 200)
            return CharArrayToString(resultArray, 0, WHOLE_ARRAY, CP_UTF8);
        else if(response == -1)
            return "timeout";
        else
            return "error_" + IntegerToString(response);
    }

    bool CheckRateLimit(RateLimitTracker &tracker)
    {
        datetime now = TimeCurrent();
        if(now - tracker.lastRequestTime >= 60)
        {
            tracker.requestCount     = 0;
            tracker.lastRequestTime  = now;
            return true;
        }
        return tracker.requestCount < tracker.requestsPerMinute;
    }

    void UpdateRateLimit(RateLimitTracker &tracker)
    {
        tracker.requestCount++;
        if(tracker.lastRequestTime == 0)
            tracker.lastRequestTime = TimeCurrent();
    }

    string Trim(string text)
    {
        int start = 0;
        int end   = StringLen(text) - 1;
        while(start <= end && (StringGetCharacter(text, start) == ' ' || StringGetCharacter(text, start) == '\t'))
            start++;
        while(end >= start && (StringGetCharacter(text, end) == ' '   || StringGetCharacter(text, end)   == '\t'))
            end--;
        if(start > end) return "";
        return StringSubstr(text, start, end - start + 1);
    }

    string UrlEncode(string text)
    {
        string result = "";
        int    len    = StringLen(text);
        for(int i = 0; i < len; i++)
        {
            ushort c = StringGetCharacter(text, i);
            if((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
               (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~')
                result += CharToString((uchar)c);
            else if(c == ' ')
                result += "+";
            else
                result += PercentEncode(c);
        }
        return result;
    }

    string PercentEncode(ushort c)
    {
        string hex  = "0123456789ABCDEF";
        int    code = (int)c;
        return "%" + StringSubstr(hex, code / 16, 1) + StringSubstr(hex, code % 16, 1);
    }

    void NotifyPositionOpen(ulong ticket, int posType, double lots, double openPrice,
                            double sl, double tp, string strategy)
    {
        tradesOpened++;
        string typeStr = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
        string msg = "POZICIO NYITVA\nStratégia: " + strategy +
                     "\nTípus: " + typeStr +
                     "\nTicket: " + IntegerToString((int)ticket) +
                     "\nLot: " + DoubleToString(lots, 2) +
                     "\nEntry: " + DoubleToString(openPrice, 5) +
                     "\nSL: " + DoubleToString(sl, 5) +
                     "\nTP: " + DoubleToString(tp, 5);
        SendTelegram(msg);
        SendWhatsApp(msg);
        Print(msg);
    }

    void NotifyPositionClose(ulong ticket, int posType, double closePrice, double profit)
    {
        tradesClosed++;
        string typeStr   = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
        string profitStr = (profit >= 0) ? "PROFIT: +" : "LOSS: ";
        string msg = "POZICIO ZARVA\nTípus: " + typeStr +
                     "\nTicket: " + IntegerToString((int)ticket) +
                     "\nExit: " + DoubleToString(closePrice, 5) +
                     "\n" + profitStr + DoubleToString(MathAbs(profit), 2) + " USD";
        SendTelegram(msg);
        SendWhatsApp(msg);
        Print(msg);
    }

    void NotifyDailyBalance(double currentBalance, double dayProfit, double dayProfitPercent)
    {
        if(!ShouldSendNotification()) return;
        string profitStr = (dayProfit >= 0) ? "PROFIT: +" : "LOSS: ";
        string msg = "NAPI OSSZEFOGLALO\n" +
                     TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES) + "\n" +
                     "Egyenleg: " + DoubleToString(currentBalance, 2) + " USD\n" +
                     profitStr + DoubleToString(MathAbs(dayProfit), 2) + " USD\n" +
                     "Nyereség: " + DoubleToString(dayProfitPercent, 2) + "%\n" +
                     "Kereskedések: " + IntegerToString(tradesOpened) + " nyitott / " +
                     IntegerToString(tradesClosed) + " zárva";
        SendTelegram(msg);
        SendWhatsApp(msg);
        lastNotificationTime = TimeCurrent();
    }

    bool ShouldSendNotification()
    {
        if(notificationsPerDay <= 0) return false;
        int secPerNotif = 86400 / notificationsPerDay;
        return (TimeCurrent() - lastNotificationTime >= secPerNotif);
    }

    int  GetNotificationsPerDay()           { return notificationsPerDay; }
    void SetNotificationsPerDay(int freq)   { notificationsPerDay = freq; }
    int  GetMaxRetries()                    { return maxRetries; }
    void SetMaxRetries(int r)               { maxRetries = MathMax(1, r); }
    int  GetRetryDelayMs()                  { return retryDelayMs; }
    void SetRetryDelayMs(int d)             { retryDelayMs = MathMax(100, d); }
    int  GetRequestTimeoutMs()              { return requestTimeoutMs; }
    void SetRequestTimeoutMs(int t)         { requestTimeoutMs = MathMax(1000, t); }
    void SetTelegramRateLimit(int rpm)      { telegramRateLimit.requestsPerMinute = MathMax(1, rpm); }
    void SetWhatsAppRateLimit(int rpm)      { whatsappRateLimit.requestsPerMinute = MathMax(1, rpm); }
};

#endif

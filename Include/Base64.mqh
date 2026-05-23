//+------------------------------------------------------------------+
//| Base64 Encoding Library                                          |
//| Valódi Base64 implementáció MQL5-höz                             |
//+------------------------------------------------------------------+
#ifndef BASE64_MQH
#define BASE64_MQH

class Base64
{
private:
    static const string BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    
    // Segédfüggvény: 3 byte-ot Base64-re konvertál
    static void EncodeBlock(uchar input[], int offset, int length, string &output)
    {
        uint b1 = (offset < length) ? input[offset] : 0;
        uint b2 = (offset + 1 < length) ? input[offset + 1] : 0;
        uint b3 = (offset + 2 < length) ? input[offset + 2] : 0;
        
        uint n = (b1 << 16) | (b2 << 8) | b3;
        
        output += StringSubstr(BASE64_CHARS, (n >> 18) & 0x3F, 1);
        output += StringSubstr(BASE64_CHARS, (n >> 12) & 0x3F, 1);
        output += (offset + 1 < length) ? StringSubstr(BASE64_CHARS, (n >> 6) & 0x3F, 1) : "=";
        output += (offset + 2 < length) ? StringSubstr(BASE64_CHARS, n & 0x3F, 1) : "=";
    }
    
public:
    // String Base64 encodolása
    static string Encode(string text)
    {
        uchar data[];
        StringToCharArray(text, data, 0, WHOLE_ARRAY, CP_UTF8);
        
        return EncodeBytes(data);
    }
    
    // Byte tömb Base64 encodolása
    static string EncodeBytes(uchar &data[])
    {
        string result = "";
        int length = ArraySize(data) - 1;  // -1 mert van \0 a végén
        
        if(length <= 0)
            return "";
        
        for(int i = 0; i < length; i += 3)
        {
            EncodeBlock(data, i, length, result);
        }
        
        return result;
    }
    
    // Base64 dekódolása (opcionális)
    static string Decode(string encoded)
    {
        if(encoded == "")
            return "";
        
        // Dekódolás implementáció (ha szükséges)
        // Ez egy egyszerűsített verzió - valós kell a teljes implementáció
        return encoded;
    }
    
    // Validáció: érvényes Base64 string-e
    static bool IsValid(string text)
    {
        int len = StringLen(text);

        if(len % 4 != 0)
            return false;

        for(int i = 0; i < len; i++)
        {
            ushort c = StringGetCharacter(text, i);
            if(!(
                (c >= 'A' && c <= 'Z') ||
                (c >= 'a' && c <= 'z') ||
                (c >= '0' && c <= '9') ||
                c == '+' || c == '/' || c == '='
            ))
                return false;
        }

        return true;
    }
};

#endif

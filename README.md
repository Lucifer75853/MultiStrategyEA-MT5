# MultiStrategyEA

Advanced Multi-Strategy Forex EA for MT4 - Supports HFT, Scalper, XBTFX with Position & Risk Management

## Stratégiák

| Stratégia | Leírás |
|-----------|--------|
| **HFT** | Nagy frekvenciájú kereskedés, rövid tartási idő |
| **Scalper** | Kis pip-célú, gyors be- és kilépés |
| **XBTFX** | Egyedi XBTFX alapú logika |

## Főbb funkciók

- Két stratégia egyidejű futtatása, konfigurálható tőkeelosztással
- Pozíciókezelés: Trailing Stop, Break Even, Max nyitott pozíciók
- Kockázatkezelés: max napi veszteség limit, lot méret számítás
- Trading session időkorlát (nap és óra szerint)
- Vizuális menü a chart-on

## Beállítások

| Paraméter | Alapértelmezett | Leírás |
|-----------|----------------|--------|
| Strategy1Name | HFT | Első stratégia neve |
| Strategy2Name | Scalper | Második stratégia neve |
| Strategy1Capital | 50% | Első stratégia tőkéje |
| Strategy2Capital | 50% | Második stratégia tőkéje |
| RiskPerTrade | 2.0% | Kockázat per kereskedés |
| MaxOpenPositions | 10 | Max egyidejű pozíciók |
| TakeProfit | 100 | Take profit pontban |
| StopLoss | 50 | Stop loss pontban |
| MaxDailyLoss | 5.0% | Max napi veszteség |

## Telepítés

1. Másold a fájlokat az MT4 `MQL4` mappájába
2. Fordítsd le a MetaEditor-ban
3. Húzd az EA-t egy chart-ra
4. Állítsd be a paramétereket

## Státusz

Fejlesztés alatt — hiányos, nem éles kereskedésre szánt.

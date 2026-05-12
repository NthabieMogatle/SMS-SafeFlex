//+------------------------------------------------------------------+
//|                    JojosSMC_Deriv_EA.mq5                        |
//|         Smart Money Concepts EA - Deriv Volatility Indices       |
//|    Based on Phineas SMC Book - Setup 1 & Setup 2                |
//|    Instruments: V10, V10(1s), V25, V25(1s), V50, V50(1s),       |
//|                 V75, V75(1s), V100, V100(1s)                     |
//+------------------------------------------------------------------+
#property copyright "Jojos SMC EA - Deriv"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

CTrade        trade;
CPositionInfo posInfo;
COrderInfo    orderInfo;

//+------------------------------------------------------------------+
//|  DERIV VOLATILITY INDEX DEFINITIONS                               |
//+------------------------------------------------------------------+
// All 10 instruments with confirmed real price ranges (April 2026)
struct DerivIndex
{
   string symbol;     // MT5 symbol name
   string shortName;  // Display name
   int    vol;        // Volatility %
   bool   is1s;       // true = 1-second tick variant
   double priceRef;   // Reference/typical price
   double pipSize;    // Typical pip size for this index
};

// -- SYMBOL NAMES ON DERIV MT5 (adjust if your broker uses different names)
// Common Deriv MT5 symbol names - update these to match your broker exactly
#define SYM_V10      "Volatility 10 Index"
#define SYM_V10_1S   "Volatility 10 (1s) Index"
#define SYM_V25      "Volatility 25 Index"
#define SYM_V25_1S   "Volatility 25 (1s) Index"
#define SYM_V50      "Volatility 50 Index"
#define SYM_V50_1S   "Volatility 50 (1s) Index"
#define SYM_V75      "Volatility 75 Index"
#define SYM_V75_1S   "Volatility 75 (1s) Index"
#define SYM_V100     "Volatility 100 Index"
#define SYM_V100_1S  "Volatility 100 (1s) Index"

//+------------------------------------------------------------------+
//|  INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+

// -- INSTRUMENTS TO SCAN
input group "=== DERIV INSTRUMENTS ==="
input bool   Scan_V10      = true;   // Volatility 10 Index (~4,980)
input bool   Scan_V10_1s   = true;   // Volatility 10 (1s) Index (~10,160)
input bool   Scan_V25      = true;   // Volatility 25 Index (~3,345)
input bool   Scan_V25_1s   = true;   // Volatility 25 (1s) Index (~841,811)
input bool   Scan_V50      = true;   // Volatility 50 Index (~81.49)
input bool   Scan_V50_1s   = true;   // Volatility 50 (1s) Index (~317,998)
input bool   Scan_V75      = true;   // Volatility 75 Index (~35,451)
input bool   Scan_V75_1s   = true;   // Volatility 75 (1s) Index (~4,837)
input bool   Scan_V100     = true;   // Volatility 100 Index (~780)
input bool   Scan_V100_1s  = true;   // Volatility 100 (1s) Index (~780)

// -- TRADE MODE
input group "=== TRADE MODE ==="
input bool   AlertOnly        = false;  // TRUE = alerts only, no orders placed ever
input bool   ExecuteTrades    = true;   // MAIN switch: TRUE = execute trades, FALSE = alerts/confirm only
                                        // FALSE = show confirmation popup, press Y to trade
// NOTE: If AlertOnly=true, no orders placed regardless of ExecuteTrades
// NOTE: If ExecuteTrades=true, orders fire instantly - no popup needed
// NOTE: If ExecuteTrades=false, press Y on popup to confirm each trade
input bool   ShowTradeConfirm = true;   // Show confirmation popup (only when ExecuteTrades=false)
input int    AlertCooldownSeconds = 900; // Block repeated same-direction alerts on same symbol for N seconds
input bool   EnableScalp      = false;  // Enable Scalp trades (M15->M5->M1)
input bool   EnableDayTrade   = true;   // Enable Day trades (H4->H1->M15->M5)
input bool   EnableSwing      = true;   // Enable Swing trades (Daily->H4->H1->M15)
input bool   EnableContinuation = false; // Enable Continuation trades (FVG/OB pullback on open trade)

// -- SETUP SELECTION
input group "=== PHINEAS SETUPS ==="
input bool   UseSetup1        = true;   // Setup 1: Stop Hunt + BOS + RTO
input bool   UseSetup2        = true;   // Setup 2: SMS + BMS + RTO
input bool   UseConfluence3D  = true;   // 3-Drive (3rd trendline touch inside OB)
input bool   UseInducement    = true;   // Inducement trap before OB
input bool   UseQML           = true;   // QML (Quasimodo Level) kill zone
input bool   UseFVG           = true;   // Fair Value Gap / Imbalance
input bool   UseBreakerBlock  = true;   // Breaker Block (failed OB)
input bool   UseCHoCH         = true;   // Change of Character confirmation

// -- STRICT ENTRY FILTERS
input group "=== STRICT SMC ENTRY RULES ==="
input bool   SniperOnlyMode          = true;   // TRUE = only trade full strict SMC sequence
input bool   RequireStrictOBTouch    = true;   // Price/candle must actually tap OB, not just be near it
input bool   RequireFVGConfluence    = false;  // FALSE = FVG counts as confirmation, but is not mandatory
input bool   RequireRejectionCandle  = true;   // Require closed rejection candle after OB/FVG tap
input bool   RequireCHoCHStrict      = false;  // FALSE = CHoCH counts as confirmation, but is not mandatory
input int    MinSMCConfirmations     = 3;      // Minimum strict confirmations after base setup: OB touch/rejection/FVG/CHoCH/inducement/3D/QML/breaker
input int    MaxReEntriesPerSymbol   = 1;      // Max continuation/re-entry trades per symbol
input double MaxSpreadPoints         = 0;      // 0 = disabled; otherwise skip if spread too high

input int    MinConfidence    = 80;     // Hard minimum confidence score to take signal

// -- DASHBOARD
input group "=== DASHBOARD ==="
input bool   ShowDashboard    = true;   // Show on-chart dashboard
input int    Dashboard_X      = 20;     // Dashboard X position
input int    Dashboard_Y      = 30;     // Dashboard Y position
input int    ConfirmTimeout   = 30;     // Seconds before confirmation popup times out

// -- RISK MANAGEMENT
input group "=== RISK MANAGEMENT ==="
input bool   UseManualLot          = false;  // TRUE = use fixed lot size below
input double ManualLotSize         = 0.01;   // Fixed lot size
input double RiskPercent           = 1.0;    // Auto risk % per trade
input double MaxDailyLossPct       = 3.0;    // Max daily loss % before EA stops
input int    MaxOpenTrades         = 5;      // Max simultaneous open trades
input double MinRR                 = 2.0;    // Minimum Risk:Reward ratio

// -- SMART TRADING RULES
input group "=== SMART TRADING RULES ==="
input int    MaxTradesPerDay       = 3;      // Max trades per day (then alerts only)
input int    MaxConsecutiveLosses  = 2;      // After X losses in a row - pause auto trade
input int    LossCooldownMinutes   = 30;     // Auto resume after X minutes (0 = manual reset only)
input int    PositionsPerSignal    = 1;      // Positions to open per signal (all same entry/SL/TP)
// NOTE: 5 positions x 0.001 lot = 0.005 total exposure per signal
// Set LossCooldownMinutes = 0 if you want to manually decide when to resume
input double DailyProfitLockPct   = 3.0;    // Lock profits when up X% for the day - stop trading
// BREAKEVEN RULE - move SL to breakeven only after REAL confirmation
input bool   MoveToBreakeven       = true;   // Enable breakeven management
input double BreakevenConfirmPct   = 50.0;   // % of TP1 distance price must move to confirm (50% = halfway to TP1)
// GUIDE: 50% = conservative (halfway to TP1 before moving SL)
//        30% = aggressive (30% of way to TP1)
//        70% = very conservative (70% of way to TP1)
// GUIDE: For $100 account suggested lots:
// V10/V25  -> 0.001-0.01 | V50 -> 0.001-0.01 | V75/V100 -> 0.001

// -- SCALP SETTINGS ? Stronger chain: M15->M5->M1
input group "=== SCALP (M15->M5->M1) ==="
input double Scalp_SL_Pct    = 0.8;   // SL % of entry
input double Scalp_TP1_Pct   = 2.0;   // TP1 % fallback
input double Scalp_TP2_Pct   = 3.2;   // TP2 % fallback
// NOTE: TP uses M5 swing high/low ? fallback % only if no swing found

// -- DAY TRADE SETTINGS
input group "=== DAY TRADE (H4->H1->M15->M5) ==="
input double Day_SL_Pct      = 1.5;   // SL % of entry
input double Day_TP1_Pct     = 3.8;   // TP1 % of entry
input double Day_TP2_Pct     = 6.0;   // TP2 % of entry

// -- SWING SETTINGS (V10, V25 favour swing)
input group "=== SWING (Daily->H4->H1->M15) ==="
input double Swing_SL_Pct    = 3.0;   // SL % of entry
input double Swing_TP1_Pct   = 7.5;   // TP1 % of entry
input double Swing_TP2_Pct   = 13.0;  // TP2 % of entry

// -- SMC DETECTION
input group "=== SMC DETECTION ==="
input int    SwingLookback   = 20;    // Bars for swing highs/lows
input int    OBLookback      = 10;    // Bars for Order Block
input bool   PreferMajorStructureOB = true;  // TRUE = prefer deeper major OB, not tiny continuation OB near current price
input int    MajorOBLookback       = 60;    // Bars to search for the major OB/origin zone
input double OBEntryPercent        = 50.0;  // BUY entry % from OB bottom, SELL entry % from OB top (50 = midpoint mitigation)
input double SLBufferOBPercent     = 25.0;  // SL buffer as % of OB height beyond OB
input double EntryExecutionTolerancePct = 15.0; // Market price must be within this % of OB risk distance from planned OB entry
input bool   UseDiscountPremiumFilter = true; // BUY only from discount, SELL only from premium
input double BuyMaxRangePercent    = 50.0;  // BUY OB must be below this % of recent range (50 = discount)
input double SellMinRangePercent   = 50.0;  // SELL OB must be above this % of recent range (50 = premium)
input bool   UseEquilibriumEntryFilter = true; // Final safety: BUY entry below equilibrium, SELL entry above equilibrium
input int    PremiumDiscountLookback   = 80;   // Bars used to calculate dealing range/equilibrium
input double LiqSweepPct     = 0.1;  // Min % spike for liquidity sweep
input int    BOSBars         = 3;    // Bars confirming BOS
input double FVG_MinPct      = 0.05; // Min % gap for FVG
input int    CHoCH_Lookback  = 15;   // Bars for CHoCH
input int    Drive3_Lookback = 40;   // Bars for 3-Drive
input double Drive3_Tolerance= 0.3;  // % tolerance for 3-Drive touches
input int    QML_Lookback    = 30;   // Bars for QML
input double QML_Tolerance   = 0.2;  // % tolerance for QML

// -- ALERTS
input group "=== ALERTS ==="
input bool   SoundAlert      = true;  // Play sound on signal
input bool   PushNotification= true;  // Send push notification to phone
input bool   EmailAlert      = false; // Send email alert
input bool   TelegramAlert   = false; // Send signal/trade alerts to Telegram
input string TelegramBotToken= "";    // Telegram Bot Token from BotFather
input string TelegramChatID  = "";    // Telegram Chat ID
input string AlertSound      = "alert.wav";

// -- MAGIC
input int    MagicNumber     = 202600; // Unique EA identifier (different from Forex EA)

// -- DIAGNOSTICS
input group "=== DIAGNOSTICS ==="
input bool   DebugMode       = false;  // FIX v2: log first failed check per scan (helps when EA seems "silent")
input bool   DebugSymbolSearch = true; // Print every name tried when resolving broker symbols

//+------------------------------------------------------------------+
//|  STRUCTURES                                                       |
//+------------------------------------------------------------------+
struct SMCSignal
{
   string symbol;
   string shortName;
   string setup;
   string tradeType;
   int    direction;
   double entry;
   double sl;
   double tp1;
   double tp2;
   double rr;
   int    confidence;
   bool   isSniper;    // true = 90%+ = ENTER NOW at market price
   string details;
   bool   hasLiq, hasBOS, hasOB, hasFVG, hasCHoCH, hasInd, has3D, hasQML, hasBB;
};

struct OrderBlock
{
   double top, bottom;
   int    type;   // 1=Bull, -1=Bear
   bool   valid;
};

struct MarketStructure
{
   string trend;
   double lastHH, lastHL, lastLH, lastLL;
   double swingHighs[], swingLows[];
   bool   valid;
};

//+------------------------------------------------------------------+
//|  GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
datetime lastBarTime    = 0;
double   startBalance   = 0;
int      signalCount    = 0;
int      totalTrades    = 0;
int      winTrades      = 0;
int      lossTrades     = 0;
int      breakevenTrades= 0;
double   totalProfit    = 0;
double   totalLoss      = 0;
double   largestWin     = 0;
double   largestLoss    = 0;
double   peakEquity     = 0;
double   maxDrawdown    = 0;
string   lastSignalStr  = "Waiting for signal...";
datetime lastSignalTime = 0;
SMCSignal pendingSignal;
bool      hasPendingSignal = false;
datetime  pendingTime      = 0;
string    DB_PREFIX        = "DERIV_DB_";
int       DB_CW            = 175;

// Smart trading rule trackers
int      dailyTradeCount       = 0;
int      consecutiveLosses     = 0;
bool     smartRulesBlocked     = false;
string   smartBlockReason      = "";
datetime lastTradeDay          = 0;
double   dayStartBalance       = 0;
datetime lossBlockedSince      = 0;     // when the loss cooldown started

// Per-instrument bar and signal tracking
datetime lastBarPerSymbol[];
datetime lastSignalPerSymbol[];
datetime lastAlertBarPerSymbol[];
int      lastAlertDirPerSymbol[];
datetime lastAlertTimePerSymbol[];

// Scan timer per instrument (stagger to avoid overload)
datetime lastScanTime[];
string   activeInstruments[];
int      activeCount = 0;

// Smart-state persistence (Batch A #1): keys scoped by MagicNumber so Deriv
// and Forex EAs do not stomp each other's cooldown state across restarts.
string GV_KEY(string name) { return "JSMC_DERIV_" + IntegerToString(MagicNumber) + "_" + name; }

void LoadSmartState()
{
   if(GlobalVariableCheck(GV_KEY("consecutiveLosses"))) consecutiveLosses = (int)GlobalVariableGet(GV_KEY("consecutiveLosses"));
   if(GlobalVariableCheck(GV_KEY("lossBlockedSince"))) lossBlockedSince   = (datetime)(long)GlobalVariableGet(GV_KEY("lossBlockedSince"));
   if(GlobalVariableCheck(GV_KEY("lastTradeDay")))     lastTradeDay       = (datetime)(long)GlobalVariableGet(GV_KEY("lastTradeDay"));
   if(GlobalVariableCheck(GV_KEY("dayStartBalance"))) dayStartBalance     = GlobalVariableGet(GV_KEY("dayStartBalance"));
   if(GlobalVariableCheck(GV_KEY("dailyTradeCount"))) dailyTradeCount     = (int)GlobalVariableGet(GV_KEY("dailyTradeCount"));
}

void SaveSmartState()
{
   GlobalVariableSet(GV_KEY("consecutiveLosses"), (double)consecutiveLosses);
   GlobalVariableSet(GV_KEY("lossBlockedSince"),  (double)(long)lossBlockedSince);
   GlobalVariableSet(GV_KEY("lastTradeDay"),      (double)(long)lastTradeDay);
   GlobalVariableSet(GV_KEY("dayStartBalance"),   dayStartBalance);
   GlobalVariableSet(GV_KEY("dailyTradeCount"),   (double)dailyTradeCount);
}

// Timeframes
// Scalp chain: M15(bias) -> M5(liq/SMS) -> M1(BOS+OB+entry) | TP on M5
ENUM_TIMEFRAMES scalp_bias_tf  = PERIOD_M15;
ENUM_TIMEFRAMES scalp_liq_tf   = PERIOD_M5;
ENUM_TIMEFRAMES scalp_bos_tf   = PERIOD_M1;
ENUM_TIMEFRAMES scalp_entry_tf = PERIOD_M1;
// Day chain: H4(bias) -> H1(liq) -> M15(BOS) -> M5(entry) | TP on H1
ENUM_TIMEFRAMES day_bias_tf    = PERIOD_H4;
ENUM_TIMEFRAMES day_liq_tf     = PERIOD_H1;
ENUM_TIMEFRAMES day_bos_tf     = PERIOD_M15;
ENUM_TIMEFRAMES day_entry_tf   = PERIOD_M5;
// Swing chain: Daily(bias) -> H4(liq) -> H1(BOS) -> M15(entry) | TP on H4
ENUM_TIMEFRAMES swing_bias_tf  = PERIOD_D1;
ENUM_TIMEFRAMES swing_liq_tf   = PERIOD_H4;
ENUM_TIMEFRAMES swing_bos_tf   = PERIOD_H1;
ENUM_TIMEFRAMES swing_entry_tf = PERIOD_M15;

//+------------------------------------------------------------------+
//|  INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(50); // Higher deviation for volatile indices
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   startBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   // FIX v2: dayStartBalance must be initialised, otherwise daily profit-lock + loss-lock can't anchor.
   dayStartBalance = startBalance;
   peakEquity      = startBalance;
   lastTradeDay    = TimeCurrent();

   // Batch A #1: restore persisted smart-rules state (cooldown timer, streak,
   // daily-trade count, day-anchor balance). Then run CheckDailyReset so a stale
   // day rolls over and dayStartBalance is re-anchored to today's open balance.
   LoadSmartState();
   CheckDailyReset();
   SaveSmartState();   // Persist defaults on brand-new install so restart is deterministic from OnInit.

   // Build active instruments list
   BuildInstrumentList();

   Print("+==========================================+");
   Print("|   JOJOS SMC EA - DERIV VOLATILITY        |");
   Print("+==========================================+");
   Print("|  Scanning: ", activeCount, " instruments              |");
   Print("|  Setup 1:  ", UseSetup1 ? "? ON" : "? OFF", "                         |");
   Print("|  Setup 2:  ", UseSetup2 ? "? ON" : "? OFF", "                         |");
   Print("|  Mode:     ", AlertOnly  ? "Alert Only" : (ExecuteTrades ? "Execute Trades" : "Confirm Y/N"), "             |");
   Print("|  Min Conf: ", MinConfidence, "%                           |");
   Print("+==========================================+");

   for(int i = 0; i < activeCount; i++)
      Print("  ? ", activeInstruments[i]);

   if(ShowDashboard) DrawDashboard();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//|  RESOLVE BROKER SYMBOL NAME (FIX v2)                              |
//|  Different Deriv whitelabels use different names for the same    |
//|  instrument. Try a list of common variants and return whichever  |
//|  this broker actually offers. Empty string = not available here. |
//+------------------------------------------------------------------+
string ResolveDerivSymbol(int volIdx, bool is1s)
{
   string suffix1s = is1s ? " (1s)" : "";
   string variants[12];
   int n = 0;
   variants[n++] = "Volatility " + IntegerToString(volIdx) + suffix1s + " Index";
   variants[n++] = "Volatility " + IntegerToString(volIdx) + " Index" + suffix1s;
   variants[n++] = "Volatility " + IntegerToString(volIdx) + suffix1s;
   variants[n++] = "Volatility_" + IntegerToString(volIdx) + (is1s ? "_1s" : "");
   variants[n++] = "VOL_" + IntegerToString(volIdx) + (is1s ? "_1S" : "");
   variants[n++] = "V" + IntegerToString(volIdx) + (is1s ? "(1s)" : "");
   variants[n++] = "V" + IntegerToString(volIdx) + (is1s ? "_1s" : "");
   variants[n++] = "V" + IntegerToString(volIdx) + (is1s ? " 1s" : "");
   variants[n++] = "Volatility " + IntegerToString(volIdx) + (is1s ? "(1s)" : "") + " Index";
   variants[n++] = "Volatility " + IntegerToString(volIdx) + (is1s ? "(1s)" : "");

   for(int i = 0; i < n; i++)
   {
      // SymbolSelect returns true if the symbol exists in MarketWatch or is selectable
      if(SymbolSelect(variants[i], true))
      {
         // Confirm broker actually quotes a price for it (avoids ghost listings)
         double bid = SymbolInfoDouble(variants[i], SYMBOL_BID);
         if(bid > 0 || SymbolInfoInteger(variants[i], SYMBOL_VISIBLE))
         {
            if(DebugSymbolSearch)
               Print("[SYMBOL] V", volIdx, is1s?"(1s)":"", " resolved -> ", variants[i]);
            return variants[i];
         }
      }
      if(DebugSymbolSearch) Print("[SYMBOL]  tried: ", variants[i], " -> not available");
   }
   return "";
}

//+------------------------------------------------------------------+
//|  BUILD LIST OF INSTRUMENTS TO SCAN                                |
//+------------------------------------------------------------------+
void BuildInstrumentList()
{
   activeCount = 0;
   ArrayResize(activeInstruments, 10);
   ArrayResize(lastScanTime, 10);
   ArrayResize(lastBarPerSymbol, 10);
   ArrayResize(lastSignalPerSymbol, 10);
   ArrayResize(lastAlertBarPerSymbol, 10);
   ArrayResize(lastAlertDirPerSymbol, 10);
   ArrayResize(lastAlertTimePerSymbol, 10);

   // FIX v2: was hardcoded to one specific naming convention. Now resolved per broker.
   int    vols[10] = { 10, 10, 25, 25, 50, 50, 75, 75, 100, 100 };
   bool   is1s[10] = { false, true, false, true, false, true, false, true, false, true };
   bool   ena[10]  = {
      Scan_V10, Scan_V10_1s, Scan_V25, Scan_V25_1s, Scan_V50,
      Scan_V50_1s, Scan_V75, Scan_V75_1s, Scan_V100, Scan_V100_1s
   };

   for(int i = 0; i < 10; i++)
   {
      if(!ena[i]) continue;
      string resolved = ResolveDerivSymbol(vols[i], is1s[i]);
      if(StringLen(resolved) == 0)
      {
         Print("[!] V", vols[i], is1s[i]?"(1s)":"", " not available on this broker - skipping");
         continue;
      }
      activeInstruments[activeCount]      = resolved;
      lastScanTime[activeCount]           = 0;
      lastBarPerSymbol[activeCount]       = 0;
      lastSignalPerSymbol[activeCount]    = 0;
      lastAlertBarPerSymbol[activeCount]  = 0;
      lastAlertDirPerSymbol[activeCount]  = 0;
      lastAlertTimePerSymbol[activeCount] = 0;
      activeCount++;
   }

   if(activeCount == 0)
   {
      Print("[!!!] No Deriv volatility instruments resolved on this broker.");
      Print("       Check Market Watch - none of the common symbol naming");
      Print("       conventions matched. The EA will run but find nothing to scan.");
   }
}

//+------------------------------------------------------------------+
//|  GET SHORT NAME FOR DISPLAY                                       |
//+------------------------------------------------------------------+
// FIX v2: parse the resolved symbol instead of comparing to hardcoded #defines.
// Works regardless of broker naming convention.
string GetShortName(string symbol)
{
   bool is1s = (StringFind(symbol, "1s") >= 0 || StringFind(symbol, "1S") >= 0);
   string s = symbol;
   StringToUpper(s);
   // pull the volatility number out of whatever variant the broker uses
   int volIdx = 0;
   int vols[5] = { 10, 25, 50, 75, 100 };
   // search highest first so "100" doesn't match "10"
   for(int i = ArraySize(vols) - 1; i >= 0; i--)
   {
      if(StringFind(s, IntegerToString(vols[i])) >= 0) { volIdx = vols[i]; break; }
   }
   if(volIdx == 0) return symbol; // unknown - fall back to full name
   return "V" + IntegerToString(volIdx) + (is1s ? "(1s)" : "");
}

//+------------------------------------------------------------------+
//|  GET PREFERRED TRADE TYPES PER INDEX                              |
//+------------------------------------------------------------------+
// V75, V75(1s), V100, V100(1s) -> prefer Scalp and Day
// V50, V50(1s)                 -> prefer Day and Swing
// V10, V10(1s), V25, V25(1s)  -> prefer Day and Swing
bool IndexSupportsType(string symbol, string tradeType)
{
   // All indices support all trade types on Deriv
   // (V75/V100 especially active for scalp due to high volatility)
   if(tradeType == "Scalp") return true;
   if(tradeType == "Day")   return true;
   if(tradeType == "Swing")
   {
      // Lower vol indices favour swing
      string sn = GetShortName(symbol);
      return (sn == "V10" || sn == "V10(1s)" || sn == "V25" || sn == "V25(1s)" ||
              sn == "V50" || sn == "V50(1s)");
   }
   return true;
}

//+------------------------------------------------------------------+
//|  MAIN TICK                                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   // FIX v2: ensure day rollover happens even on quiet days (no trade in 24h).
   CheckDailyReset();

   if(ShowDashboard) DrawDashboard();

   // Confirmation timeout
   if(hasPendingSignal && ShowTradeConfirm && ConfirmTimeout > 0)
   {
      if((int)(TimeCurrent() - pendingTime) >= ConfirmTimeout)
      {
         Print("[TIME] Confirmation timed out: ", pendingSignal.shortName, " - skipped");
         hasPendingSignal = false;
         ObjectsDeleteAll(0, DB_PREFIX + "CB_");
      }
   }

   // FIX v2: previous gate used the chart symbol's M1 bar, which delayed scans
   // of OTHER symbols when the chart symbol was idle. Replace with a small
   // time-based throttle so each symbol is scanned at most once per ~5s.
   static datetime lastScanThrottle = 0;
   if(TimeCurrent() - lastScanThrottle < 5) return;
   lastScanThrottle = TimeCurrent();

   bool dailyLimitHit = IsDailyLossExceeded();
   if(hasPendingSignal) return;

   if(!dailyLimitHit) ManageOpenTrades();

   bool tradingFull = dailyLimitHit;

   // Scan each instrument with its OWN bar check to prevent duplicate signals
   for(int i = 0; i < activeCount; i++)
   {
      string sym = activeInstruments[i];

      // Per-instrument M1 bar check - one scan per new M1 bar per symbol
      datetime symBar = iTime(sym, PERIOD_M1, 0);
      if(symBar == 0) continue; // bars not loaded yet
      if(symBar == lastBarPerSymbol[i]) continue;
      lastBarPerSymbol[i] = symBar;

      // Per-instrument signal cooldown: 5 minutes (300s) between signals on the same symbol.
      // FIX v2: previous comment said "60 seconds" but the code was 300s. Comment now matches.
      if(TimeCurrent() - lastSignalPerSymbol[i] < 300) continue;

      ScanInstrument(sym, i, tradingFull);
   }
}

//+------------------------------------------------------------------+
//|  SCAN ONE INSTRUMENT                                              |
//+------------------------------------------------------------------+
void ScanInstrument(string symbol, int symIndex, bool tradingFull)
{
   SMCSignal sig;
   string sn = GetShortName(symbol);

   // -- SCALP (M15->M5->M1)
   if(EnableScalp && IndexSupportsType(symbol, "Scalp"))
   {
      if(UseSetup1 && DetectSetup1(symbol, sn, "Scalp", sig))
         if(ValidateSignal(sig)) { lastSignalPerSymbol[symIndex]=TimeCurrent(); ProcessSignal(sig, tradingFull); return; }
      if(UseSetup2 && DetectSetup2(symbol, sn, "Scalp", sig))
         if(ValidateSignal(sig)) { lastSignalPerSymbol[symIndex]=TimeCurrent(); ProcessSignal(sig, tradingFull); return; }
   }

   // -- DAY TRADE (H4->H1->M15->M5)
   if(EnableDayTrade && IndexSupportsType(symbol, "Day"))
   {
      if(UseSetup1 && DetectSetup1(symbol, sn, "Day", sig))
         if(ValidateSignal(sig)) { lastSignalPerSymbol[symIndex]=TimeCurrent(); ProcessSignal(sig, tradingFull); return; }
      if(UseSetup2 && DetectSetup2(symbol, sn, "Day", sig))
         if(ValidateSignal(sig)) { lastSignalPerSymbol[symIndex]=TimeCurrent(); ProcessSignal(sig, tradingFull); return; }
   }

   // -- SWING (Daily->H4->H1->M15)
   if(EnableSwing && IndexSupportsType(symbol, "Swing"))
   {
      if(UseSetup1 && DetectSetup1(symbol, sn, "Swing", sig))
         if(ValidateSignal(sig)) { lastSignalPerSymbol[symIndex]=TimeCurrent(); ProcessSignal(sig, tradingFull); return; }
      if(UseSetup2 && DetectSetup2(symbol, sn, "Swing", sig))
         if(ValidateSignal(sig)) { lastSignalPerSymbol[symIndex]=TimeCurrent(); ProcessSignal(sig, tradingFull); return; }
   }

   // -- CONTINUATION ? FVG/OB pullback on existing open trade (all types)
   if(EnableContinuation)
   {
      string types[3] = {"Scalp","Day","Swing"};
      for(int t = 0; t < 3; t++)
      {
         if(types[t]=="Scalp" && !EnableScalp)    continue;
         if(types[t]=="Day"   && !EnableDayTrade) continue;
         if(types[t]=="Swing" && !EnableSwing)    continue;
         if(DetectContinuation(symbol, sn, types[t], sig))
            if(ValidateSignal(sig)) { lastSignalPerSymbol[symIndex]=TimeCurrent(); ProcessSignal(sig, tradingFull); return; }
      }
   }
}

//+------------------------------------------------------------------+
//|  SETUP 1: Stop Hunt + BOS + Return to OB                         |
//+------------------------------------------------------------------+
bool DetectSetup1(string symbol, string sn, string tradeType, SMCSignal &sig)
{
   ENUM_TIMEFRAMES biasTF, liqTF, bosTF, entryTF;
   GetTimeframes(tradeType, biasTF, liqTF, bosTF, entryTF);

   MarketStructure ms = GetMarketStructure(symbol, biasTF);
   if(!ms.valid || ms.trend == "ranging") return false;

   bool sslSwept = false, bslSwept = false;
   double sweepLevel = 0;
   if(!DetectLiquiditySweep(symbol, liqTF, sslSwept, bslSwept, sweepLevel)) return false;

   if(ms.trend == "bullish" && !sslSwept) return false;
   if(ms.trend == "bearish" && !bslSwept) return false;

   int direction = (sslSwept && ms.trend == "bullish") ? 1 : -1;

   if(!DetectBOS(symbol, bosTF, direction)) return false;

   OrderBlock ob;
   if(!FindOrderBlock(symbol, entryTF, direction, ob)) return false;

   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(!IsPriceNearOB(currentPrice, ob, direction)) return false;

   // -- CONFLUENCE
   bool hasFVG = UseFVG         ? DetectFVG(symbol, entryTF, direction)          : false;
   bool hasCH  = UseCHoCH       ? DetectCHoCH(symbol, bosTF, direction)          : false;
   bool hasInd = UseInducement  ? DetectInducement(symbol, entryTF, direction)   : false;
   bool has3D  = UseConfluence3D? Detect3Drive(symbol, entryTF, direction, ob)   : false;
   double qmlLevel = 0;
   bool hasQML = UseQML         ? DetectQML(symbol, entryTF, direction, ob, qmlLevel) : false;
   OrderBlock brkOB;
   bool hasBB  = UseBreakerBlock? DetectBreakerBlock(symbol, entryTF, direction, brkOB) : false;

   string strictRejectReason = "";
   if(SniperOnlyMode && !StrictEntryRulesPass(symbol, entryTF, bosTF, direction, ob, hasFVG, hasCH, hasInd, has3D, hasQML, hasBB, strictRejectReason))
   {
      Print("[STRICT SKIP] ", symbol, " Setup1: ", strictRejectReason);
      return false;
   }

   // SAFEFLEX FIX: entry must be inside the selected OB mitigation zone, not above it.
   // QML is now confluence only; it cannot pull the entry away from the OB.
   double entry = GetOBMitigationEntry(symbol, ob, direction);
   double sl    = GetOBStopLoss(symbol, ob, direction);
   double slD   = MathAbs(entry - sl);
   if(slD <= 0) return false;

   // Reject unrealistically tiny SL (noise OB filter)
   double minSLDist = entry * 0.0005;
   if(slD < minSLDist) return false;

   // TP = Previous swing HIGH (BUY) or swing LOW (SELL) per Phineas book
   double tp1 = GetSwingTP(symbol, getTpTF(tradeType), direction, entry, 1);
   double tp2 = GetSwingTP(symbol, getTpTF(tradeType), direction, entry, 2);
   if(tp1 == 0) tp1 = direction == 1 ? entry + slD * 2.5 : entry - slD * 2.5;
   if(tp2 == 0) tp2 = direction == 1 ? entry + slD * 4.0 : entry - slD * 4.0;

   double rr = MathAbs(tp1 - entry) / slD;
   // Cap R:R at 20 ? anything above signals a bad SL calculation
   if(rr < MinRR || rr > 20.0) return false;

   int confidence = 50;
   if(hasFVG)  confidence += 8;
   if(hasCH)   confidence += 8;
   if(hasInd)  confidence += 6;
   if(has3D)   confidence += 12;
   if(hasQML)  confidence += 15;
   if(hasBB)   confidence += 7;
   confidence = MathMin(confidence, 100);
   if(confidence < MinConfidence) return false;

   string entryType = (hasQML || hasCH) ? "CONFIRMATION ENTRY" : "RISK ENTRY";
   string details   = BuildDetails1(sn, tradeType, entryType, biasTF, liqTF, bosTF, entryTF,
                                    direction, sslSwept, hasFVG, hasCH, hasInd, has3D, hasQML,
                                    qmlLevel, hasBB, entry, rr);

   FillSignal(sig, symbol, sn, "Setup 1 - SH+BOS+RTO", tradeType, direction,
              entry, sl, tp1, tp2, rr, confidence, details,
              true, true, true, hasFVG, hasCH, hasInd, has3D, hasQML, hasBB);
   return true;
}

//+------------------------------------------------------------------+
//|  SETUP 2: SMS + BMS + Return to OB                               |
//+------------------------------------------------------------------+
bool DetectSetup2(string symbol, string sn, string tradeType, SMCSignal &sig)
{
   ENUM_TIMEFRAMES biasTF, liqTF, bosTF, entryTF;
   GetTimeframes(tradeType, biasTF, liqTF, bosTF, entryTF);

   MarketStructure ms = GetMarketStructure(symbol, biasTF);
   if(!ms.valid) return false;

   int smsDir = 0;
   string smsDetail = "";
   if(!DetectSMS(symbol, liqTF, smsDir, smsDetail)) return false;
   if(!DetectBOS(symbol, bosTF, smsDir)) return false;

   OrderBlock ob;
   if(!FindOrderBlock(symbol, entryTF, smsDir, ob)) return false;

   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(!IsPriceNearOB(currentPrice, ob, smsDir)) return false;

   bool hasFVG = UseFVG         ? DetectFVG(symbol, entryTF, smsDir)          : false;
   bool hasCH  = UseCHoCH       ? DetectCHoCH(symbol, bosTF, smsDir)          : false;
   bool hasInd = UseInducement  ? DetectInducement(symbol, entryTF, smsDir)   : false;
   bool has3D  = UseConfluence3D? Detect3Drive(symbol, entryTF, smsDir, ob)   : false;
   double qmlLevel = 0;
   bool hasQML = UseQML         ? DetectQML(symbol, entryTF, smsDir, ob, qmlLevel) : false;
   OrderBlock brkOB;
   bool hasBB  = UseBreakerBlock? DetectBreakerBlock(symbol, entryTF, smsDir, brkOB) : false;

   string strictRejectReason = "";
   if(SniperOnlyMode && !StrictEntryRulesPass(symbol, entryTF, bosTF, smsDir, ob, hasFVG, hasCH, hasInd, has3D, hasQML, hasBB, strictRejectReason))
   {
      Print("[STRICT SKIP] ", symbol, " Setup2: ", strictRejectReason);
      return false;
   }

   // SAFEFLEX FIX: entry must be inside the selected OB mitigation zone, not above it.
   // QML is now confluence only; it cannot pull the entry away from the OB.
   double entry = GetOBMitigationEntry(symbol, ob, smsDir);
   double sl    = GetOBStopLoss(symbol, ob, smsDir);
   double slD   = MathAbs(entry - sl);
   if(slD <= 0) return false;

   // Reject if SL is unrealistically tiny (less than 0.05% of price)
   // This filters out noise OBs that produce 0.79 point SLs
   double minSLDist = entry * 0.0005;  // 0.05% of price
   if(slD < minSLDist) return false;

   // TP = Previous swing HIGH (BUY) or swing LOW (SELL) per Phineas book
   double tp1 = GetSwingTP(symbol, getTpTF(tradeType), smsDir, entry, 1);
   double tp2 = GetSwingTP(symbol, getTpTF(tradeType), smsDir, entry, 2);
   if(tp1 == 0) tp1 = smsDir == 1 ? entry + slD * 2.5 : entry - slD * 2.5;
   if(tp2 == 0) tp2 = smsDir == 1 ? entry + slD * 4.0 : entry - slD * 4.0;

   double rr = MathAbs(tp1 - entry) / slD;
   // Cap R:R at 20 ? anything above is a sign of bad SL calculation
   if(rr < MinRR || rr > 20.0) return false;

   int confidence = 45;
   if(hasFVG)  confidence += 8;
   if(hasCH)   confidence += 10;
   if(hasInd)  confidence += 6;
   if(has3D)   confidence += 12;
   if(hasQML)  confidence += 15;
   if(hasBB)   confidence += 7;
   confidence = MathMin(confidence, 100);
   if(confidence < MinConfidence) return false;

   string entryType = (hasQML || hasCH) ? "CONFIRMATION ENTRY" : "RISK ENTRY";
   string details   = BuildDetails2(sn, tradeType, entryType, biasTF, liqTF, bosTF, entryTF,
                                    smsDir, smsDetail, hasFVG, hasCH, hasInd, has3D, hasQML,
                                    qmlLevel, hasBB, entry, rr);

   FillSignal(sig, symbol, sn, "Setup 2 - SMS+BMS+RTO", tradeType, smsDir,
              entry, sl, tp1, tp2, rr, confidence, details,
              false, true, true, hasFVG, hasCH, hasInd, has3D, hasQML, hasBB);
   return true;
}

//+------------------------------------------------------------------+
//|  SMC DETECTION FUNCTIONS                                          |
//+------------------------------------------------------------------+
MarketStructure GetMarketStructure(string symbol, ENUM_TIMEFRAMES tf)
{
   MarketStructure ms;
   ms.valid = false; ms.trend = "ranging";
   int bars = SwingLookback * 2;
   double highs[], lows[];
   ArraySetAsSeries(highs, true); ArraySetAsSeries(lows, true);
   if(CopyHigh(symbol, tf, 0, bars, highs) < bars) return ms;
   if(CopyLow(symbol,  tf, 0, bars, lows)  < bars) return ms;
   double swH[20], swL[20]; int nH=0, nL=0;
   for(int i=2; i<bars-2 && (nH<20||nL<20); i++)
   {
      if(nH<20 && highs[i]>highs[i+1]&&highs[i]>highs[i-1]&&highs[i]>highs[i+2]&&highs[i]>highs[i-2])
         swH[nH++]=highs[i];
      if(nL<20 && lows[i]<lows[i+1]&&lows[i]<lows[i-1]&&lows[i]<lows[i+2]&&lows[i]<lows[i-2])
         swL[nL++]=lows[i];
   }
   if(nH<2||nL<2) return ms;
   bool isHH=swH[0]>swH[1], isHL=swL[0]>swL[1], isLH=swH[0]<swH[1], isLL=swL[0]<swL[1];
   if(isHH&&isHL) ms.trend="bullish";
   else if(isLH&&isLL) ms.trend="bearish";
   ms.valid=true;
   return ms;
}

bool DetectLiquiditySweep(string symbol, ENUM_TIMEFRAMES tf, bool &ssl, bool &bsl, double &level)
{
   ssl=false; bsl=false;
   int bars=SwingLookback+10;
   double highs[], lows[], closes[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true); ArraySetAsSeries(closes,true);
   if(CopyHigh(symbol,tf,0,bars,highs)<bars) return false;
   if(CopyLow(symbol,tf,0,bars,lows)<bars)   return false;
   if(CopyClose(symbol,tf,0,bars,closes)<bars)return false;
   double prevH=0, prevL=DBL_MAX;
   for(int i=3;i<bars-3;i++) { if(highs[i]>prevH)prevH=highs[i]; if(lows[i]<prevL)prevL=lows[i]; }
   double recL=MathMin(MathMin(lows[0],lows[1]),lows[2]);
   double recH=MathMax(MathMax(highs[0],highs[1]),highs[2]);
   if(recL<prevL&&closes[0]>prevL&&(prevL-recL)/prevL*100>=LiqSweepPct){ssl=true;level=prevL;return true;}
   if(recH>prevH&&closes[0]<prevH&&(recH-prevH)/prevH*100>=LiqSweepPct){bsl=true;level=prevH;return true;}
   return false;
}

//+------------------------------------------------------------------+
//|  GET TP FROM PREVIOUS SWING HIGH OR LOW (Per Phineas Book)       |
//|  BUY  -> TP = previous swing HIGH on the bias/BOS timeframe      |
//|  SELL -> TP = previous swing LOW  on the bias/BOS timeframe      |
//|  TP2  = next swing high/low beyond TP1 (extended target)         |
//+------------------------------------------------------------------+
double GetSwingTP(string symbol, ENUM_TIMEFRAMES tf, int direction, double entry, int swingNumber)
{
   // swingNumber: 1 = first swing (TP1), 2 = second swing (TP2)
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);
   int bars = 100;
   if(CopyHigh(symbol, tf, 0, bars, highs) < bars) return 0;
   if(CopyLow(symbol,  tf, 0, bars, lows)  < bars) return 0;

   int found = 0;
   if(direction == 1) // BUY -> find previous swing HIGHS above entry
   {
      for(int i = 2; i < bars - 2; i++)
      {
         // Swing high: higher than neighbours
         if(highs[i] > highs[i+1] && highs[i] > highs[i-1] &&
            highs[i] > highs[i+2] && highs[i] > highs[i-2])
         {
            if(highs[i] > entry) // Must be above entry
            {
               found++;
               if(found == swingNumber) return highs[i];
            }
         }
      }
      // Fallback if not enough swings found ? use R:R multiplier
      double slDist = 0; // will use entry-based fallback below
   }
   else // SELL -> find previous swing LOWS below entry
   {
      for(int i = 2; i < bars - 2; i++)
      {
         if(lows[i] < lows[i+1] && lows[i] < lows[i-1] &&
            lows[i] < lows[i+2] && lows[i] < lows[i-2])
         {
            if(lows[i] < entry) // Must be below entry
            {
               found++;
               if(found == swingNumber) return lows[i];
            }
         }
      }
   }
   return 0; // 0 means not found ? caller uses fallback
}

// TP timeframe per trade type ? per Phineas book
// Scalp = M15, Day = H1, Swing = H4
// TP timeframe: Scalp=M5, Day=H1, Swing=H4
ENUM_TIMEFRAMES getTpTF(string tradeType)
{
   if(tradeType == "Scalp") return PERIOD_M5;  // Scalp TP on M5 swing high/low
   if(tradeType == "Day")   return PERIOD_H1;  // Day TP on H1
   return PERIOD_H4;                           // Swing TP on H4
}

bool DetectBOS(string symbol, ENUM_TIMEFRAMES tf, int direction)
{
   int bars=SwingLookback+5;
   double highs[], lows[], closes[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true); ArraySetAsSeries(closes,true);
   if(CopyHigh(symbol,tf,0,bars,highs)<bars)  return false;
   if(CopyLow(symbol,tf,0,bars,lows)<bars)    return false;
   if(CopyClose(symbol,tf,0,bars,closes)<bars) return false;
   double prevH=0, prevL=DBL_MAX;
   for(int i=BOSBars;i<bars-2;i++)
   {
      if(highs[i]>highs[i+1]&&highs[i]>highs[i-1]&&highs[i]>prevH) prevH=highs[i];
      if(lows[i]<lows[i+1]&&lows[i]<lows[i-1]&&lows[i]<prevL) prevL=lows[i];
   }
   if(direction==1&&prevH>0)  { for(int i=0;i<BOSBars;i++) if(closes[i]>prevH) return true; }
   if(direction==-1&&prevL<DBL_MAX) { for(int i=0;i<BOSBars;i++) if(closes[i]<prevL) return true; }
   return false;
}

bool DetectSMS(string symbol, ENUM_TIMEFRAMES tf, int &dir, string &detail)
{
   MarketStructure ms=GetMarketStructure(symbol,tf);
   if(!ms.valid) return false;
   int bars=SwingLookback*2;
   double highs[], lows[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   if(CopyHigh(symbol,tf,0,bars,highs)<bars) return false;
   if(CopyLow(symbol,tf,0,bars,lows)<bars)   return false;
   double swH[20],swL[20]; int nH=0,nL=0;
   for(int i=2;i<bars-2&&(nH<20||nL<20);i++)
   {
      if(nL<20&&lows[i]<lows[i+1]&&lows[i]<lows[i-1]) swL[nL++]=lows[i];
      if(nH<20&&highs[i]>highs[i+1]&&highs[i]>highs[i-1]) swH[nH++]=highs[i];
   }
   if(nL>=3&&swL[0]>swL[1]&&swL[1]<=swL[2]){dir=1;detail="SMS: Failed LL - printed HL (bullish shift)";return true;}
   if(nH>=3&&swH[0]<swH[1]&&swH[1]>=swH[2]){dir=-1;detail="SMS: Failed HH - printed LH (bearish shift)";return true;}
   return false;
}

bool FindOrderBlock(string symbol, ENUM_TIMEFRAMES tf, int direction, OrderBlock &ob)
{
   ob.valid = false;
   int bars = (PreferMajorStructureOB ? MajorOBLookback : OBLookback) + 5;
   if(bars < OBLookback + 5) bars = OBLookback + 5;

   double opens[], highs[], lows[], closes[];
   ArraySetAsSeries(opens,true); ArraySetAsSeries(highs,true);
   ArraySetAsSeries(lows,true);  ArraySetAsSeries(closes,true);
   if(CopyOpen(symbol,tf,0,bars,opens)<bars)  return false;
   if(CopyHigh(symbol,tf,0,bars,highs)<bars)  return false;
   if(CopyLow(symbol,tf,0,bars,lows)<bars)    return false;
   if(CopyClose(symbol,tf,0,bars,closes)<bars) return false;

   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minOBSize = currentPrice * 0.00015; // stricter than before to avoid tiny/noise OBs

   double rangeHigh = highs[ArrayMaximum(highs, 1, bars-1)];
   double rangeLow  = lows[ArrayMinimum(lows, 1, bars-1)];
   double recentRange = rangeHigh - rangeLow;
   if(recentRange <= 0) return false;
   double buyMaxLevel  = rangeLow + recentRange * (BuyMaxRangePercent / 100.0);
   double sellMinLevel = rangeLow + recentRange * (SellMinRangePercent / 100.0);

   OrderBlock bestOB; bestOB.valid = false;
   double bestScore = -1.0;

   for(int i=1; i<bars-1; i++)
   {
      double body = MathAbs(closes[i] - opens[i]);
      double impulseBody = MathAbs(closes[i-1] - opens[i-1]);
      if(impulseBody < body * 1.5) continue;
      if(body < minOBSize) continue;

      if(direction == 1 && closes[i] < opens[i] && closes[i-1] > opens[i-1])
      {
         // Bullish demand OB: bearish candle before bullish displacement.
         double obTop    = opens[i];
         double obBottom = lows[i];
         double obRange  = obTop - obBottom;
         if(obRange < minOBSize) continue;
         if(obTop >= currentPrice) continue;

         // SAFETY: skip premium/continuation OBs when waiting for a true discount RTO.
         if(UseDiscountPremiumFilter && obTop > buyMaxLevel) continue;

         // Prefer major/deeper origin OBs over small continuation OBs near current price.
         double distFromPrice = currentPrice - obTop;
         double depthScore = (obTop <= buyMaxLevel ? (buyMaxLevel - obTop) : 0.0);
         double score = PreferMajorStructureOB ? (body * 3.0 + obRange * 2.0 + depthScore + distFromPrice * 0.15) : body;

         if(score > bestScore)
         {
            bestScore = score;
            bestOB.top = obTop; bestOB.bottom = obBottom;
            bestOB.type = 1; bestOB.valid = true;
         }
      }
      else if(direction == -1 && closes[i] > opens[i] && closes[i-1] < opens[i-1])
      {
         // Bearish supply OB: bullish candle before bearish displacement.
         double obTop    = highs[i];
         double obBottom = opens[i];
         double obRange  = obTop - obBottom;
         if(obRange < minOBSize) continue;
         if(obBottom <= currentPrice) continue;

         // SAFETY: skip discount/continuation OBs when waiting for a true premium RTO.
         if(UseDiscountPremiumFilter && obBottom < sellMinLevel) continue;

         double distFromPrice = obBottom - currentPrice;
         double depthScore = (obBottom >= sellMinLevel ? (obBottom - sellMinLevel) : 0.0);
         double score = PreferMajorStructureOB ? (body * 3.0 + obRange * 2.0 + depthScore + distFromPrice * 0.15) : body;

         if(score > bestScore)
         {
            bestScore = score;
            bestOB.top = obTop; bestOB.bottom = obBottom;
            bestOB.type = -1; bestOB.valid = true;
         }
      }
   }

   if(bestOB.valid) { ob = bestOB; return true; }
   return false;
}

double GetOBMitigationEntry(string symbol, OrderBlock &ob, int direction)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double range = MathMax(ob.top - ob.bottom, point * 10);
   double pct = MathMax(0.0, MathMin(100.0, OBEntryPercent)) / 100.0;

   if(direction == 1)
      return NormalizeDouble(ob.bottom + range * pct, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   else
      return NormalizeDouble(ob.top - range * pct, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
}

double GetOBStopLoss(string symbol, OrderBlock &ob, int direction)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double range = MathMax(ob.top - ob.bottom, point * 10);
   double buffer = MathMax(point * 10, range * (SLBufferOBPercent / 100.0));

   if(direction == 1)
      return NormalizeDouble(ob.bottom - buffer, digits);
   else
      return NormalizeDouble(ob.top + buffer, digits);
}



bool GetPremiumDiscountRange(string symbol, ENUM_TIMEFRAMES tf, double &rangeHigh, double &rangeLow, double &equilibrium)
{
   int bars = MathMax(PremiumDiscountLookback, 20);
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   if(CopyHigh(symbol, tf, 1, bars, highs) < bars) return false;
   if(CopyLow(symbol,  tf, 1, bars, lows)  < bars) return false;

   rangeHigh = highs[ArrayMaximum(highs, 0, bars)];
   rangeLow  = lows[ArrayMinimum(lows, 0, bars)];
   if(rangeHigh <= rangeLow) return false;
   equilibrium = (rangeHigh + rangeLow) / 2.0;
   return true;
}

bool IsPremiumDiscountEntryOK(string symbol, ENUM_TIMEFRAMES tf, int direction, double entryPrice, OrderBlock &ob, string &reason)
{
   reason = "";
   if(!UseDiscountPremiumFilter && !UseEquilibriumEntryFilter) return true;

   double hi=0, lo=0, eq=0;
   if(!GetPremiumDiscountRange(symbol, tf, hi, lo, eq))
   {
      reason = "could not calculate premium/discount range";
      return false;
   }

   double range = hi - lo;
   double buyMax  = lo + range * (BuyMaxRangePercent / 100.0);
   double sellMin = lo + range * (SellMinRangePercent / 100.0);

   if(direction == 1)
   {
      // Buy only from discount: the OB and planned entry must be below equilibrium.
      if(ob.top > buyMax || entryPrice > buyMax)
      {
         reason = "BUY rejected: entry/OB is above discount zone (premium buy)";
         return false;
      }
   }
   else if(direction == -1)
   {
      // Sell only from premium: the OB and planned entry must be above equilibrium.
      if(ob.bottom < sellMin || entryPrice < sellMin)
      {
         reason = "SELL rejected: entry/OB is below premium zone (discount sell)";
         return false;
      }
   }

   return true;
}


//+------------------------------------------------------------------+
//|  STRICT SMC ENTRY HELPERS                                         |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable(string symbol)
{
   if(MaxSpreadPoints <= 0) return true;
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0) return true;
   double spreadPts = (ask - bid) / point;
   return (spreadPts <= MaxSpreadPoints);
}

bool IsStrictOBTouch(string symbol, ENUM_TIMEFRAMES tf, OrderBlock &ob, int direction)
{
   if(!ob.valid) return false;
   double price = SymbolInfoDouble(symbol, direction == 1 ? SYMBOL_BID : SYMBOL_ASK);
   double highs[], lows[], closes[];
   ArraySetAsSeries(highs, true); ArraySetAsSeries(lows, true); ArraySetAsSeries(closes, true);
   if(CopyHigh(symbol, tf, 0, 3, highs) < 3) return false;
   if(CopyLow(symbol,  tf, 0, 3, lows)  < 3) return false;
   if(CopyClose(symbol,tf, 0, 3, closes)< 3) return false;

   bool priceInside = (price >= ob.bottom && price <= ob.top);
   bool lastTapped  = (lows[1] <= ob.top && highs[1] >= ob.bottom);
   bool closedAway  = (direction == 1) ? (closes[1] >= ob.bottom) : (closes[1] <= ob.top);
   return (priceInside || (lastTapped && closedAway));
}

bool HasRejectionCandle(string symbol, ENUM_TIMEFRAMES tf, OrderBlock &ob, int direction)
{
   double opens[], highs[], lows[], closes[];
   ArraySetAsSeries(opens, true); ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);  ArraySetAsSeries(closes, true);
   if(CopyOpen(symbol, tf, 0, 4, opens)  < 4) return false;
   if(CopyHigh(symbol, tf, 0, 4, highs)  < 4) return false;
   if(CopyLow(symbol,  tf, 0, 4, lows)   < 4) return false;
   if(CopyClose(symbol,tf, 0, 4, closes) < 4) return false;

   double range = highs[1] - lows[1];
   if(range <= 0) return false;
   double body = MathAbs(closes[1] - opens[1]);
   if(body < range * 0.20) return false; // reject weak/doji candles

   bool tappedOB = (lows[1] <= ob.top && highs[1] >= ob.bottom);
   if(!tappedOB) return false;

   if(direction == 1)
   {
      double lowerWick = MathMin(opens[1], closes[1]) - lows[1];
      return (closes[1] > opens[1] && closes[1] > ob.bottom && lowerWick >= body * 0.50);
   }
   else
   {
      double upperWick = highs[1] - MathMax(opens[1], closes[1]);
      return (closes[1] < opens[1] && closes[1] < ob.top && upperWick >= body * 0.50);
   }
}

bool HasFVGConfluenceAtZone(string symbol, ENUM_TIMEFRAMES tf, int direction, OrderBlock &ob)
{
   double fvgTop = 0, fvgBot = 0;
   if(!GetFVGLevels(symbol, tf, direction, fvgTop, fvgBot)) return false;

   double price = SymbolInfoDouble(symbol, direction == 1 ? SYMBOL_BID : SYMBOL_ASK);
   bool overlapsOB = (fvgBot <= ob.top && fvgTop >= ob.bottom);
   bool priceInFVG = (price >= fvgBot && price <= fvgTop);

   double highs[], lows[];
   ArraySetAsSeries(highs, true); ArraySetAsSeries(lows, true);
   if(CopyHigh(symbol, tf, 0, 3, highs) < 3) return (overlapsOB || priceInFVG);
   if(CopyLow(symbol,  tf, 0, 3, lows)  < 3) return (overlapsOB || priceInFVG);
   bool candleTappedFVG = (lows[1] <= fvgTop && highs[1] >= fvgBot);
   return (overlapsOB || priceInFVG || candleTappedFVG);
}

int CountStrictConfirmations(string symbol, ENUM_TIMEFRAMES entryTF, int direction, OrderBlock &ob, bool hasFVG, bool hasCHoCH, bool hasInd, bool has3D, bool hasQML, bool hasBB, string &summary)
{
   int count = 0;
   summary = "";

   bool obTouch = IsStrictOBTouch(symbol, entryTF, ob, direction);
   bool reject  = HasRejectionCandle(symbol, entryTF, ob, direction);
   bool fvgZone = hasFVG && HasFVGConfluenceAtZone(symbol, entryTF, direction, ob);

   if(obTouch) { count++; summary += "OB touch, "; }
   if(reject)  { count++; summary += "rejection, "; }
   if(fvgZone) { count++; summary += "FVG, "; }
   if(hasCHoCH){ count++; summary += "CHoCH, "; }
   if(hasInd)  { count++; summary += "inducement, "; }
   if(has3D)   { count++; summary += "3-drive, "; }
   if(hasQML)  { count++; summary += "QML, "; }
   if(hasBB)   { count++; summary += "breaker, "; }

   return count;
}

bool StrictEntryRulesPass(string symbol, ENUM_TIMEFRAMES entryTF, ENUM_TIMEFRAMES bosTF, int direction, OrderBlock &ob, bool hasFVG, bool hasCHoCH, bool hasInd, bool has3D, bool hasQML, bool hasBB, string &reason)
{
   reason = "";
   if(!IsSpreadAcceptable(symbol)) { reason = "spread too high"; return false; }

   double plannedEntry = GetOBMitigationEntry(symbol, ob, direction);
   string pdReason = "";
   if(!IsPremiumDiscountEntryOK(symbol, entryTF, direction, plannedEntry, ob, pdReason))
   {
      reason = pdReason;
      return false;
   }

   bool obTouch = IsStrictOBTouch(symbol, entryTF, ob, direction);
   bool reject  = HasRejectionCandle(symbol, entryTF, ob, direction);
   bool fvgZone = hasFVG && HasFVGConfluenceAtZone(symbol, entryTF, direction, ob);

   // Core safety: price must actually return to the zone and reject from a CLOSED candle.
   if(RequireStrictOBTouch && !obTouch)
      { reason = "OB not actually tapped"; return false; }
   if(RequireRejectionCandle && !reject)
      { reason = "no closed rejection candle from zone"; return false; }

   // Optional hard requirements remain available, but defaults are flexible so the EA does not miss every trade.
   if(RequireFVGConfluence && !fvgZone)
      { reason = "no valid FVG confluence at OB"; return false; }
   if(RequireCHoCHStrict && !hasCHoCH)
      { reason = "CHoCH missing"; return false; }

   string confSummary = "";
   int confirms = CountStrictConfirmations(symbol, entryTF, direction, ob, hasFVG, hasCHoCH, hasInd, has3D, hasQML, hasBB, confSummary);
   if(confirms < MinSMCConfirmations)
   {
      reason = "only " + IntegerToString(confirms) + "/" + IntegerToString(MinSMCConfirmations) + " confirmations: " + confSummary;
      return false;
   }

   return true;
}

bool IsPriceNearOB(double price, OrderBlock &ob, int direction)
{
   if(!ob.valid) return false;
   double obRange = ob.top - ob.bottom;

   // Reject tiny OBs ? minimum size = 0.01% of price (filters noise candles)
   double minOBSize = price * 0.0001;
   if(obRange < minOBSize) return false;

   // Allow wick through OB by up to 100% of OB range (stop hunt wick)
   // BUT price must not be more than 3x OB range ABOVE the OB (not approaching)
   double wickAllow = obRange * 1.0;

   if(direction == 1) // BUY ? price must be AT or approaching OB from above
   {
      // Price must be within 3x OB range above OB top (approaching)
      // OR inside OB, OR wicked below (stop hunt)
      return (price >= ob.bottom - wickAllow && price <= ob.top + obRange * 3.0);
   }
   else // SELL ? price must be AT or approaching OB from below
   {
      return (price >= ob.bottom - obRange * 3.0 && price <= ob.top + wickAllow);
   }
}

bool DetectFVG(string symbol, ENUM_TIMEFRAMES tf, int direction)
{
   double highs[], lows[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   if(CopyHigh(symbol,tf,0,20,highs)<20) return false;
   if(CopyLow(symbol,tf,0,20,lows)<20)   return false;
   double price=SymbolInfoDouble(symbol,SYMBOL_BID);
   for(int i=1;i<18;i++)
   {
      if(direction==1&&(lows[i-1]-highs[i+1])>0&&(lows[i-1]-highs[i+1])/price*100>=FVG_MinPct) return true;
      if(direction==-1&&(lows[i+1]-highs[i-1])>0&&(lows[i+1]-highs[i-1])/price*100>=FVG_MinPct) return true;
   }
   return false;
}

// Returns FVG top and bottom price levels (for continuation entry calculation)
bool GetFVGLevels(string symbol, ENUM_TIMEFRAMES tf, int direction, double &fvgTop, double &fvgBot)
{
   double highs[], lows[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   if(CopyHigh(symbol,tf,0,20,highs)<20) return false;
   if(CopyLow(symbol,tf,0,20,lows)<20)   return false;
   double price = SymbolInfoDouble(symbol,SYMBOL_BID);
   for(int i=1;i<18;i++)
   {
      if(direction==1)
      {
         double gap = lows[i-1] - highs[i+1];
         if(gap > 0 && gap/price*100 >= FVG_MinPct)
         {
            fvgTop = lows[i-1];   // top of bullish FVG
            fvgBot = highs[i+1];  // bottom of bullish FVG
            return true;
         }
      }
      else
      {
         double gap = lows[i+1] - highs[i-1];
         if(gap > 0 && gap/price*100 >= FVG_MinPct)
         {
            fvgTop = lows[i+1];   // top of bearish FVG
            fvgBot = highs[i-1];  // bottom of bearish FVG
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//|  DETECT CONTINUATION ? FVG/OB pullback in direction of open trade |
//+------------------------------------------------------------------+
// Fires when: there is an open trade in direction X AND price has
// pulled back to an FVG or OB in the same direction = continuation entry
bool DetectContinuation(string symbol, string sn, string tradeType, SMCSignal &sig)
{
   // Step 1 ? Check if there is already an open trade on this symbol in any direction
   int openDir = 0;
   double openTP = 0;
   for(int p = PositionsTotal()-1; p >= 0; p--)
   {
      if(!posInfo.SelectByIndex(p)) continue;
      if(posInfo.Symbol() != symbol) continue;
      if(posInfo.Magic() != MagicNumber) continue;
      openDir = posInfo.PositionType() == POSITION_TYPE_BUY ? 1 : -1;
      openTP  = posInfo.TakeProfit();
      break;
   }
   if(openDir == 0) return false; // No open trade on this symbol ? skip
   if(GetDirectionalBasketProfit(symbol, openDir) <= 0.0) return false; // continuation only when basket is in profit

   // Step 2 ? Get timeframes for this trade type
   ENUM_TIMEFRAMES biasTF, liqTF, bosTF, entryTF;
   GetTimeframes(tradeType, biasTF, liqTF, bosTF, entryTF);

   // Step 3 ? Confirm market structure still agrees with open trade direction
   MarketStructure ms = GetMarketStructure(symbol, biasTF);
   if(openDir == 1  && ms.trend != "bullish") return false;
   if(openDir == -1 && ms.trend != "bearish") return false;

   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   int    digits       = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point        = SymbolInfoDouble(symbol, SYMBOL_POINT);

   // Step 4 ? Look for FVG at entry TF first (preferred), then OB as fallback
   double entryPrice = 0, slPrice = 0;
   string contType  = "";
   double fvgTop = 0, fvgBot = 0;

   if(GetFVGLevels(symbol, entryTF, openDir, fvgTop, fvgBot))
   {
      double fvgRange = fvgTop - fvgBot;
      // FIX v2: BUY pullback should enter inside the FVG (price falling into demand),
      // not at its outer edge. Same logic for SELL.
      bool priceAtFVG = (openDir == 1)
         ? (currentPrice <= fvgTop + fvgRange * 0.25 && currentPrice >= fvgBot - fvgRange * 0.5)
         : (currentPrice >= fvgBot - fvgRange * 0.25 && currentPrice <= fvgTop + fvgRange * 0.5);
      if(!priceAtFVG) return false;
      OrderBlock fvgZone; fvgZone.top = fvgTop; fvgZone.bottom = fvgBot; fvgZone.type = openDir; fvgZone.valid = true;
      if(RequireRejectionCandle && !HasRejectionCandle(symbol, entryTF, fvgZone, openDir)) return false;

      // Enter at the FVG midpoint, SL beyond the far edge with a percentage buffer.
      double mid = (fvgTop + fvgBot) / 2.0;
      double slBuffer = MathMax(currentPrice * 0.0005, point * 20);
      entryPrice = mid;
      slPrice    = openDir == 1 ? fvgBot - slBuffer : fvgTop + slBuffer;
      contType   = "FVG";
   }
   else
   {
      // Fallback ? look for OB continuation
      OrderBlock ob;
      if(!FindOrderBlock(symbol, entryTF, openDir, ob)) return false;
      if(RequireStrictOBTouch && !IsStrictOBTouch(symbol, entryTF, ob, openDir)) return false;
      if(!RequireStrictOBTouch && !IsPriceNearOB(currentPrice, ob, openDir))    return false;
      if(RequireRejectionCandle && !HasRejectionCandle(symbol, entryTF, ob, openDir)) return false;

      // FIX v2: previous code entered ABOVE the OB top for BUY (chasing breakout),
      // not from inside the demand zone. Use the OB midpoint as the entry instead.
      double obMid = (ob.top + ob.bottom) / 2.0;
      double slBuffer = MathMax(currentPrice * 0.0005, point * 20);
      entryPrice = obMid;
      slPrice    = openDir == 1 ? ob.bottom - slBuffer : ob.top + slBuffer;
      contType   = "OB";
   }

   // Step 5 ? Validate SL distance
   double slDist = MathAbs(entryPrice - slPrice);
   if(slDist < entryPrice * 0.0005) return false;

   // Step 6 ? TP = use the open trade's TP (same target) or swing high/low
   double tp1 = openTP > 0 ? openTP : GetSwingTP(symbol, getTpTF(tradeType), openDir, entryPrice, 1);
   if(tp1 == 0 || (openDir==1 && tp1 <= entryPrice) || (openDir==-1 && tp1 >= entryPrice))
      tp1 = openDir == 1 ? entryPrice + slDist * 2.5 : entryPrice - slDist * 2.5;
   double tp2 = openDir == 1 ? tp1 + slDist : tp1 - slDist;

   // Step 7 ? Validate R:R
   double rr = MathAbs(tp1 - entryPrice) / slDist;
   if(rr < MinRR || rr > 20.0) return false;

   // Step 8 ? Confidence (continuation is already confirmed by open trade)
   int confidence = 60; // Base ? open trade in same direction is strong confluence
   if(contType == "FVG") confidence += 15;  // FVG is premium continuation level
   if(contType == "OB")  confidence += 10;
   bool hasCH = UseCHoCH ? DetectCHoCH(symbol, bosTF, openDir) : false;
   if(hasCH) confidence += 8;
   confidence = MathMin(confidence, 100);

   // Step 9 ? Fill signal
   sig.symbol     = symbol;
   sig.shortName  = sn;
   sig.setup      = "Continuation - "+contType+" pullback";
   sig.tradeType  = tradeType;
   sig.direction  = openDir;
   sig.entry      = NormalizeDouble(entryPrice, digits);
   sig.sl         = NormalizeDouble(slPrice,    digits);
   sig.tp1        = NormalizeDouble(tp1,        digits);
   sig.tp2        = NormalizeDouble(tp2,        digits);
   sig.rr         = NormalizeDouble(rr,         1);
   sig.confidence = confidence;
   sig.isSniper   = (confidence >= 90);
   sig.hasFVG     = (contType == "FVG");
   sig.hasOB      = (contType == "OB");
   sig.hasCHoCH   = hasCH;

   string dirStr = openDir == 1 ? "[BUY]" : "[SELL]";
   sig.details =
      "[OK] Open trade in same direction confirmed\n"
      "[OK] "+contType+" continuation level at entry\n"+
      (hasCH ? "[OK] CHoCH confirmed on "+EnumToString(bosTF)+"\n" : "")+
      "R:R = 1:"+DoubleToString(rr,1);

   return true;
}

bool DetectCHoCH(string symbol, ENUM_TIMEFRAMES tf, int direction)
{
   int bars=CHoCH_Lookback;
   double highs[], lows[], closes[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true); ArraySetAsSeries(closes,true);
   if(CopyHigh(symbol,tf,0,bars,highs)<bars)   return false;
   if(CopyLow(symbol,tf,0,bars,lows)<bars)     return false;
   if(CopyClose(symbol,tf,0,bars,closes)<bars)  return false;
   double rH=0,pH=0,rL=DBL_MAX,pL=DBL_MAX; bool f=false;
   for(int i=1;i<bars-1;i++)
   {
      if(highs[i]>highs[i+1]&&highs[i]>highs[i-1]){if(!f){rH=highs[i];f=true;}else if(pH==0){pH=highs[i];}}
   }
   f=false;
   for(int i=1;i<bars-1;i++)
   {
      if(lows[i]<lows[i+1]&&lows[i]<lows[i-1]){if(!f){rL=lows[i];f=true;}else if(pL==DBL_MAX){pL=lows[i];}}
   }
   if(direction==1&&rL<DBL_MAX&&pL<DBL_MAX&&rL>pL&&closes[0]>rH) return true;
   if(direction==-1&&rH>0&&pH>0&&rH<pH&&closes[0]<rL) return true;
   return false;
}

// FIX v2: previously the `direction` parameter was accepted but ignored, so
// inducement passed for any consolidation in either direction. Now we require
// that the consolidation include a directional stop-grab (long lower wick for
// BUY bias, long upper wick for SELL bias) consistent with the trade.
bool DetectInducement(string symbol, ENUM_TIMEFRAMES tf, int direction)
{
   double opens[], highs[], lows[], closes[];
   ArraySetAsSeries(opens,true); ArraySetAsSeries(highs,true);
   ArraySetAsSeries(lows,true);  ArraySetAsSeries(closes,true);
   if(CopyOpen(symbol,tf,0,10,opens)<10)   return false;
   if(CopyHigh(symbol,tf,0,10,highs)<10)   return false;
   if(CopyLow(symbol,tf,0,10,lows)<10)     return false;
   if(CopyClose(symbol,tf,0,10,closes)<10) return false;

   int smallBars = 0;
   bool sawDirectionalWick = false;
   for(int i=1;i<8;i++)
   {
      double p=MathAbs(closes[i+1]-opens[i+1]);
      double c=MathAbs(closes[i]-opens[i]);
      double x=MathAbs(closes[i-1]-opens[i-1]);
      if(p>0 && x>0 && c<p*0.35 && c<x*0.35) smallBars++;

      double rng = highs[i] - lows[i];
      if(rng <= 0) continue;
      if(direction == 1)
      {
         // BUY inducement = stop-hunt below (long lower wick)
         double lowerWick = MathMin(opens[i], closes[i]) - lows[i];
         if(lowerWick >= rng * 0.55) sawDirectionalWick = true;
      }
      else
      {
         double upperWick = highs[i] - MathMax(opens[i], closes[i]);
         if(upperWick >= rng * 0.55) sawDirectionalWick = true;
      }
   }
   return (smallBars >= 2 && sawDirectionalWick);
}

bool Detect3Drive(string symbol, ENUM_TIMEFRAMES tf, int direction, OrderBlock &ob)
{
   if(!ob.valid||!UseConfluence3D) return false;
   int bars=Drive3_Lookback;
   double highs[], lows[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   if(CopyHigh(symbol,tf,0,bars,highs)<bars) return false;
   if(CopyLow(symbol,tf,0,bars,lows)<bars)   return false;
   double obR=ob.top-ob.bottom;
   // FIX v2: previous formula `obR*(Drive3_Tolerance/100.0*100.0+1.0)` reduced to
   // obR*(Drive3_Tolerance + 1.0) = ~130% of OB range, making 3-Drive trivial to satisfy.
   // Intent was a small percentage of OB range as wiggle room around each touch.
   double tol = obR * (Drive3_Tolerance / 100.0);
   if(tol <= 0) tol = obR * 0.05; // safety floor: 5% of OB range
   double tPx[10]; int tB[10], nT=0;
   for(int i=2;i<bars-2&&nT<10;i++)
   {
      if(direction==1)
      {
         bool isSwL=(lows[i]<lows[i+1]&&lows[i]<lows[i-1]&&lows[i]<lows[i+2]&&lows[i]<lows[i-2]);
         bool inOB=(lows[i]>=ob.bottom-tol&&lows[i]<=ob.top+tol);
         if(isSwL&&inOB){tPx[nT]=lows[i];tB[nT]=i;nT++;}
      }
      else
      {
         bool isSwH=(highs[i]>highs[i+1]&&highs[i]>highs[i-1]&&highs[i]>highs[i+2]&&highs[i]>highs[i-2]);
         bool inOB=(highs[i]>=ob.bottom-tol&&highs[i]<=ob.top+tol);
         if(isSwH&&inOB){tPx[nT]=highs[i];tB[nT]=i;nT++;}
      }
   }
   if(nT<3) return false;
   double p1=tPx[nT-1],p2=tPx[nT-2],p3=tPx[0];
   int b1=tB[nT-1],b2=tB[nT-2],b3=tB[0];
   if(b1!=b3){double slope=(p3-p1)/(b3-b1),exp=p1+slope*(b2-b1);if(MathAbs(p2-exp)/obR>0.5)return false;}
   if(direction==1&&p3>=p1) return false;
   if(direction==-1&&p3<=p1) return false;
   return true;
}

bool DetectQML(string symbol, ENUM_TIMEFRAMES tf, int direction, OrderBlock &ob, double &qmlLevel)
{
   if(!ob.valid||!UseQML) return false;
   qmlLevel=0;
   int bars=QML_Lookback;
   double highs[], lows[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   if(CopyHigh(symbol,tf,0,bars,highs)<bars) return false;
   if(CopyLow(symbol,tf,0,bars,lows)<bars)   return false;
   double swH[10],swL[10]; int nH=0,nL=0;
   for(int i=2;i<bars-2&&(nH<10||nL<10);i++)
   {
      if(nH<10&&highs[i]>highs[i+1]&&highs[i]>highs[i-1]&&highs[i]>highs[i+2]&&highs[i]>highs[i-2]) swH[nH++]=highs[i];
      if(nL<10&&lows[i]<lows[i+1]&&lows[i]<lows[i-1]&&lows[i]<lows[i+2]&&lows[i]<lows[i-2])         swL[nL++]=lows[i];
   }
   // FIX v2: same tolerance bug as 3-Drive. Was effectively 120% of OB range.
   double tol = (ob.top - ob.bottom) * (QML_Tolerance / 100.0);
   if(tol <= 0) tol = (ob.top - ob.bottom) * 0.05;
   if(direction==1&&nH>=3)
   {
      for(int i=0;i<nH-2;i++)
      {
         if(swH[i]<swH[i+2]){qmlLevel=swH[i];if(qmlLevel>=ob.bottom-tol&&qmlLevel<=ob.top+tol)return true;}
      }
   }
   if(direction==-1&&nL>=3)
   {
      for(int i=0;i<nL-2;i++)
      {
         if(swL[i]>swL[i+2]){qmlLevel=swL[i];if(qmlLevel>=ob.bottom-tol&&qmlLevel<=ob.top+tol)return true;}
      }
   }
   return false;
}

bool DetectBreakerBlock(string symbol, ENUM_TIMEFRAMES tf, int direction, OrderBlock &brkOB)
{
   if(!UseBreakerBlock) return false;
   double closes[], price=SymbolInfoDouble(symbol,SYMBOL_BID);
   ArraySetAsSeries(closes,true);
   if(CopyClose(symbol,tf,0,15,closes)<15) return false;
   OrderBlock oldOB;
   if(direction==-1&&FindOrderBlock(symbol,tf,1,oldOB))
   {
      bool violated=false;
      for(int i=0;i<10;i++) if(closes[i]<oldOB.bottom){violated=true;break;}
      if(violated&&price>=oldOB.bottom*0.998&&price<=oldOB.top*1.002){brkOB=oldOB;brkOB.type=-1;return true;}
   }
   if(direction==1&&FindOrderBlock(symbol,tf,-1,oldOB))
   {
      bool violated=false;
      for(int i=0;i<10;i++) if(closes[i]>oldOB.top){violated=true;break;}
      if(violated&&price>=oldOB.bottom*0.998&&price<=oldOB.top*1.002){brkOB=oldOB;brkOB.type=1;return true;}
   }
   return false;
}

//+------------------------------------------------------------------+
//|  BUILD SIGNAL DETAILS STRINGS                                     |
//+------------------------------------------------------------------+
string BuildDetails1(string sn, string tt, string et,
                     ENUM_TIMEFRAMES bTF, ENUM_TIMEFRAMES lTF,
                     ENUM_TIMEFRAMES boTF, ENUM_TIMEFRAMES enTF,
                     int dir, bool ssl,
                     bool fvg, bool ch, bool ind, bool d3,
                     bool qml, double qmlLvl, bool bb,
                     double entry, double rr)
{
   string d="-----------------------------\n";
   d+="SETUP 1 - Stop Hunt + BOS + RTO\n";
   d+=sn+" | "+tt+" | "+et+"\n";
   d+="-----------------------------\n";
   d+="BIAS:    "+TFToStr(bTF)+" (market structure)\n";
   d+="HUNT:    "+TFToStr(lTF)+" (stop hunt / liquidity)\n";
   d+="BOS:     "+TFToStr(boTF)+" (break of structure)\n";
   d+="TRIGGER: "+TFToStr(enTF)+" (OB + entry + confluence)\n";
   d+="TP REF:  "+TFToStr(getTpTF(tt))+" (swing high/low target)\n";
   d+="-----------------------------\n";
   d+="[OK] "+(ssl?"SSL Swept":"BSL Swept")+" on "+TFToStr(lTF)+"\n";
   d+="[OK] BOS confirmed on "+TFToStr(boTF)+"\n";
   d+="[OK] "+(dir==1?"Bullish":"Bearish")+" OB on "+TFToStr(enTF)+" << ENTRY ZONE\n";
   if(fvg) d+="[OK] FVG/Imbalance near OB on "+TFToStr(enTF)+"\n";
   if(ind) d+="[OK] Inducement trap before OB\n";
   if(ch)  d+="[OK] CHoCH confirmed on "+TFToStr(enTF)+"\n";
   if(bb)  d+="[OK] Breaker Block on "+TFToStr(enTF)+"\n";
   if(d3)  d+="[OK] 3-DRIVE: 3rd touch inside OB on "+TFToStr(enTF)+"\n";
   if(qml) d+="[OK] QML KILL ZONE at "+DoubleToString(qmlLvl,2)+" on "+TFToStr(enTF)+"\n";
   d+="-----------------------------\n";
   d+="R:R = 1:"+DoubleToString(rr,1);
   return d;
}

string BuildDetails2(string sn, string tt, string et,
                     ENUM_TIMEFRAMES bTF, ENUM_TIMEFRAMES lTF,
                     ENUM_TIMEFRAMES boTF, ENUM_TIMEFRAMES enTF,
                     int dir, string smsDetail,
                     bool fvg, bool ch, bool ind, bool d3,
                     bool qml, double qmlLvl, bool bb,
                     double entry, double rr)
{
   string d="-----------------------------\n";
   d+="SETUP 2 - SMS + BMS + RTO\n";
   d+=sn+" | "+tt+" | "+et+"\n";
   d+="-----------------------------\n";
   d+="BIAS:    "+TFToStr(bTF)+" (market structure)\n";
   d+="SMS:     "+TFToStr(lTF)+" (shift of market structure)\n";
   d+="BMS:     "+TFToStr(boTF)+" (break of market structure)\n";
   d+="TRIGGER: "+TFToStr(enTF)+" (OB + entry + confluence)\n";
   d+="TP REF:  "+TFToStr(getTpTF(tt))+" (swing high/low target)\n";
   d+="-----------------------------\n";
   d+="[OK] "+smsDetail+"\n";
   d+="[OK] BMS confirmed on "+TFToStr(boTF)+"\n";
   d+="[OK] "+(dir==1?"Bullish":"Bearish")+" OB on "+TFToStr(enTF)+" << ENTRY ZONE\n";
   if(fvg) d+="[OK] FVG/Imbalance near OB on "+TFToStr(enTF)+"\n";
   if(ind) d+="[OK] Inducement trap before OB\n";
   if(ch)  d+="[OK] CHoCH confirmed on "+TFToStr(enTF)+"\n";
   if(bb)  d+="[OK] Breaker Block on "+TFToStr(enTF)+"\n";
   if(d3)  d+="[OK] 3-DRIVE: 3rd touch inside OB on "+TFToStr(enTF)+"\n";
   if(qml) d+="[OK] QML KILL ZONE at "+DoubleToString(qmlLvl,2)+" on "+TFToStr(enTF)+"\n";
   d+="-----------------------------\n";
   d+="R:R = 1:"+DoubleToString(rr,1);
   return d;
}

//+------------------------------------------------------------------+
//|  FILL SIGNAL STRUCT                                               |
//+------------------------------------------------------------------+
void FillSignal(SMCSignal &sig, string sym, string sn, string setup,
                string tt, int dir, double entry, double sl,
                double tp1, double tp2, double rr, int conf,
                string details, bool liq, bool bos, bool ob,
                bool fvg, bool ch, bool ind, bool d3, bool qml, bool bb)
{
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   
   // Sniper mode now means high-quality OB entry ONLY.
   // Do NOT convert to market entry; this prevents early/premium entries like the 4533 signal.
   bool isSniper = (conf >= 90);
   double finalEntry = entry;
   
   sig.symbol     = sym;
   sig.shortName  = sn;
   sig.setup      = setup;
   sig.tradeType  = tt;
   sig.direction  = dir;
   sig.entry      = NormalizeDouble(finalEntry, digits);
   sig.sl         = NormalizeDouble(sl,    digits);
   sig.tp1        = NormalizeDouble(tp1,   digits);
   sig.tp2        = NormalizeDouble(tp2,   digits);
   sig.rr         = rr;
   sig.confidence = conf;
   sig.isSniper   = isSniper;
   sig.details    = details + (isSniper ? "\n[SNIPER] High-confidence OB entry - wait for planned OB price" : "");
   sig.hasLiq     = liq; sig.hasBOS=bos; sig.hasOB=ob;
   sig.hasFVG     = fvg; sig.hasCHoCH=ch; sig.hasInd=ind;
   sig.has3D      = d3;  sig.hasQML=qml; sig.hasBB=bb;
}

//+------------------------------------------------------------------+
//|  VALIDATE SIGNAL                                                  |
//+------------------------------------------------------------------+
bool ValidateSignal(SMCSignal &sig)
{
   if(sig.rr < MinRR) return false;
   if(sig.confidence < MinConfidence) return false;

   int sameDirCount = 0;
   int oppDirCount  = 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != sig.symbol || posInfo.Magic() != MagicNumber) continue;

      int pd = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
      if(pd == sig.direction) sameDirCount++;
      else                    oppDirCount++;
   }

   if(oppDirCount > 0) return false;

   bool isContinuation = (StringFind(sig.setup, "Continuation - ") == 0);

   if(!isContinuation && sameDirCount > 0) return false;

   if(isContinuation)
   {
      if(sameDirCount <= 0) return false;
      if(sameDirCount > MaxReEntriesPerSymbol) return false;
      if(GetDirectionalBasketProfit(sig.symbol, sig.direction) <= 0.0) return false;
   }

   return true;
}


//+------------------------------------------------------------------+
//|  TELEGRAM ALERTS                                                  |
//+------------------------------------------------------------------+
// FIX v2: previous version missed several chars (?, :, /, <, >, etc.) which
// can cause Telegram to reject or truncate messages. Encode all the punctuation
// that matters for Telegram body text.
string UrlEncodeBasic(string text)
{
   string r = text;
   StringReplace(r, "%", "%25");
   StringReplace(r, "\r\n", "%0A");
   StringReplace(r, "\n", "%0A");
   StringReplace(r, " ", "%20");
   StringReplace(r, "#", "%23");
   StringReplace(r, "&", "%26");
   StringReplace(r, "+", "%2B");
   StringReplace(r, "=", "%3D");
   StringReplace(r, "?", "%3F");
   StringReplace(r, "/", "%2F");
   StringReplace(r, "<", "%3C");
   StringReplace(r, ">", "%3E");
   StringReplace(r, "\"", "%22");
   StringReplace(r, "{", "%7B");
   StringReplace(r, "}", "%7D");
   return r;
}

bool SendTelegramMessage(string text)
{
   if(!TelegramAlert) return true;
   if(StringLen(TelegramBotToken) < 10 || StringLen(TelegramChatID) < 1)
   {
      Print("[TELEGRAM] Missing TelegramBotToken or TelegramChatID");
      return false;
   }

   string url = "https://api.telegram.org/bot" + TelegramBotToken
              + "/sendMessage?chat_id=" + TelegramChatID
              + "&text=" + UrlEncodeBasic(text);

   char data[];
   char result[];
   string result_headers;
   ResetLastError();
   int code = WebRequest("GET", url, "", 10000, data, result, result_headers);

   if(code == -1)
   {
      Print("[TELEGRAM] WebRequest failed. Add https://api.telegram.org in MT5: Tools > Options > Expert Advisors > Allow WebRequest. Error: ", GetLastError());
      return false;
   }
   if(code != 200)
   {
      Print("[TELEGRAM] HTTP code: ", code, " response: ", CharArrayToString(result));
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//|  PROCESS SIGNAL                                                   |
//+------------------------------------------------------------------+
void ProcessSignal(SMCSignal &sig, bool tradingFull=false)
{
   int symIndex = FindInstrumentIndex(sig.symbol);
   datetime signalBar = iTime(sig.symbol, PERIOD_M1, 0);
   if(symIndex >= 0)
   {
      if(lastAlertBarPerSymbol[symIndex] == signalBar && lastAlertDirPerSymbol[symIndex] == sig.direction)
      {
         Print("[SKIP] Duplicate signal suppressed on same candle: ", sig.shortName, " ", sig.direction==1?"BUY":"SELL");
         return;
      }
      if(lastAlertDirPerSymbol[symIndex] == sig.direction
         && lastAlertTimePerSymbol[symIndex] > 0
         && (TimeCurrent() - lastAlertTimePerSymbol[symIndex]) < AlertCooldownSeconds)
      {
         Print("[SKIP] Duplicate signal suppressed by cooldown: ", sig.shortName, " ", sig.direction==1?"BUY":"SELL");
         return;
      }
   }
   string dirStr  = sig.direction==1 ? "BUY"  : "SELL";
   string arrow   = sig.direction==1 ? "[BUY]"    : "[SELL]";
   string typeBadge="", typeIcon="";
   if(sig.tradeType=="Scalp")      {typeBadge="[!] SCALP (M15->M5->M1)";              typeIcon="[!]";}
   else if(sig.tradeType=="Day")   {typeBadge="[D] DAY TRADE (H4->H1->M15->M5)";      typeIcon="[D]";}
   else if(sig.tradeType=="Swing") {typeBadge="[S] SWING TRADE (Daily->H4->H1->M15)"; typeIcon="[S]";}
   // Continuation badge ? shows which type it continued from
   if(sig.setup=="Continuation - FVG pullback" || sig.setup=="Continuation - OB pullback")
   {
      string contSrc = sig.hasFVG ? "FVG" : "OB";
      typeBadge = "[CONT] CONTINUATION - "+contSrc+" pullback ("+sig.tradeType+")";
      typeIcon  = "[C]";
   }

   string sniperTag  = sig.isSniper ? " [SNIPER OB]" : "";
   string fullStatus = tradingFull  ? " [!]? MAX TRADES - ALERT ONLY" : "";

   int digs = (int)SymbolInfoInteger(sig.symbol, SYMBOL_DIGITS);
   string msgTitle = "SMC SafeFlex - " + dirStr + " SETUP DETECTED (" + sig.shortName + ")";

   string msgBody = "SMC SafeFlex\n"
                  + "================================\n"
                  + dirStr + " SETUP DETECTED (" + sig.shortName + ")\n"
                  + "Status: WAITING FOR OB MITIGATION\n"
                  + "Symbol: " + sig.shortName + " | TF: " + TFToStr(_Period) + "\n"
                  + "Setup: " + sig.setup + "\n"
                  + "Confidence: " + IntegerToString(sig.confidence) + "%\n"
                  + "================================\n"
                  + "Entry Zone: " + DoubleToString(sig.entry, digs) + "\n"
                  + "SL: " + DoubleToString(sig.sl, digs) + "\n"
                  + "TP1: " + DoubleToString(sig.tp1, digs) + "\n"
                  + "TP2: " + DoubleToString(sig.tp2, digs) + "\n"
                  + "R:R 1:" + DoubleToString(sig.rr, 1) + "\n"
                  + "================================\n"
                  + "Confirmations:\n"
                  // FIX v2: previously these lines hardcoded [OK] regardless of actual flags.
                  + (sig.hasCHoCH ? "[OK] CHoCH confirmed\n" : "[--] CHoCH not present\n")
                  + (sig.hasBOS   ? "[OK] BOS / BMS confirmed\n" : "[--] BOS not confirmed\n")
                  + "[PENDING] OB Touch + Rejection (validated at execution)\n"
                  + (sig.hasInd   ? "[OK] Inducement / liquidity trap\n" : "[--] No inducement\n")
                  + (sig.hasFVG   ? "[OK] FVG confluence\n" : "[OPTIONAL] FVG not detected\n")
                  + (sig.hasQML   ? "[OK] QML kill zone\n" : "")
                  + (sig.has3D    ? "[OK] 3-Drive completed in OB\n" : "")
                  + (sig.hasBB    ? "[OK] Breaker block alignment\n" : "")
                  + "================================\n"
                  + "Rule: No OB touch = No trade.\n"
                  + "Re-entry: Only after TP1 hit + new OB.\n"
                  + "TP2: Final cycle target.\n\n"
                  + sig.details;

   if(tradingFull)
   {
      bool dailyHit = IsDailyLossExceeded();
      if(dailyHit)
      {
         // Daily limit hit ? signal fires but NO notification sent
         // Status is visible on dashboard only
         lastSignalStr  = (sig.isSniper ? "[SNIPER] " : "") + arrow + " " + dirStr
                        + " " + sig.shortName + " | " + typeIcon + " " + sig.tradeType
                        + " | " + IntegerToString(sig.confidence) + "% [DAILY LIMIT]";
         lastSignalTime = TimeCurrent();
         if(ShowDashboard) DrawDashboard();
         return;
      }
      else
         msgBody += "\n\n[!] MAX TRADES (" + IntegerToString(MaxOpenTrades) + "/" + IntegerToString(MaxOpenTrades) + ")\n"
                 +  "Alert only - close a trade first.";
   }

   // Send alerts (only reaches here if NOT daily limit hit)
   // Batch A #2: SendNotification body limit on MT5 is 255 chars; the long
   // msgBody (~500-700 chars) gets silently truncated or dropped. Build a
   // compact body for push, keep the long form for email/Telegram.
   string pushBody = StringFormat("%s%s %s %s | %d%% | E:%s SL:%s TP:%s R:1:%.1f",
                                  sig.isSniper ? "[SNIPER] " : "",
                                  dirStr,
                                  sig.shortName,
                                  sig.tradeType,
                                  sig.confidence,
                                  DoubleToString(sig.entry, digs),
                                  DoubleToString(sig.sl,    digs),
                                  DoubleToString(sig.tp1,   digs),
                                  sig.rr);
   if(StringLen(pushBody) > 250) pushBody = StringSubstr(pushBody, 0, 250);

   if(SoundAlert)        PlaySound(sig.isSniper ? "alert2.wav" : AlertSound);
   if(PushNotification)  SendNotification(pushBody);
   if(EmailAlert)        SendMail(msgTitle, msgBody);
   if(TelegramAlert)     SendTelegramMessage(msgTitle+"\n"+msgBody);
   if(symIndex >= 0)
   {
      lastAlertBarPerSymbol[symIndex]  = signalBar;
      lastAlertDirPerSymbol[symIndex]  = sig.direction;
      lastAlertTimePerSymbol[symIndex] = TimeCurrent();
   }

   lastSignalStr  = (sig.isSniper ? "[SNIPER] " : "") + arrow + " " + dirStr
                  + " " + sig.shortName
                  + " | " + typeIcon + " " + sig.tradeType
                  + " | " + IntegerToString(sig.confidence) + "%"
                  + (sig.isSniper ? " SNIPER OB" : "")
                  + (tradingFull ? " (FULL)" : "");
   lastSignalTime = TimeCurrent();

   Print("===============================");
   if(sig.isSniper) Print("[SNIPER OB] High-confidence OB setup - no market override");
   Print("DERIV SIGNAL: ", msgTitle);
   if(tradingFull) Print("[!]? MAX TRADES - alert only");
   Print("===============================");

   if(tradingFull) { if(ShowDashboard) DrawDashboard(); return; }
   if(AlertOnly)   return;

   // -- SMART RULES CHECK: daily trade limit, consecutive losses, profit lock
   if(!IsSmartRulesAllowed())
   {
      // Smart rules blocking ? still sent signal/alert, just not trading
      Print("[SMART] Auto trade blocked: ", smartBlockReason);
      lastSignalStr = smartBlockReason;
      if(ShowDashboard) DrawDashboard();
      return;
   }

   // Sniper/high-confidence no longer bypasses settings or jumps into market early.

   // -- AUTO EXECUTE: place order immediately, no Y/N needed
   if(ExecuteTrades)
   {
      Print("[AUTO] Auto executing: ", sig.direction==1?"BUY":"SELL", " ",
            sig.shortName, " | Confidence:", sig.confidence, "%");
      dailyTradeCount++;
      SaveSmartState();   // Batch A #1
      ExecuteSignal(sig);
      if(ShowDashboard) DrawDashboard();
      return;
   }

   // -- CONFIRMATION POPUP: show popup, wait for Y/N
   if(ShowTradeConfirm)
   {
      pendingSignal=sig; hasPendingSignal=true; pendingTime=TimeCurrent();
      Print("[WAIT] Awaiting confirmation for ",sig.shortName," - Press Y or N");
      if(ShowDashboard) DrawDashboard();
      return;
   }

   // -- FALLBACK: execute directly
   dailyTradeCount++;
   SaveSmartState();   // Batch A #1
   ExecuteSignal(sig);
}

//+------------------------------------------------------------------+
//|  EXECUTE SIGNAL                                                   |
//+------------------------------------------------------------------+
void ExecuteSignal(SMCSignal &sig)
{
   // FIX v2: dirStr was used below but never declared in this scope (compile error).
   string dirStr = sig.direction == 1 ? "BUY" : "SELL";

   int sameDirOpen = CountDirectionalOpenTrades(sig.symbol, sig.direction);
   int oppDirOpen  = CountDirectionalOpenTrades(sig.symbol, -sig.direction);

   if(oppDirOpen > 0)
   {
      Print("[SKIP] Opposite direction basket already open on ", sig.shortName);
      return;
   }

   double lotSize = CalculateLotSize(sig.symbol, sig.entry, sig.sl);
   if(lotSize <= 0) { Print("[X] Invalid lot size for ", sig.shortName); return; }

   int    digits  = (int)SymbolInfoInteger(sig.symbol, SYMBOL_DIGITS);
   double ask     = SymbolInfoDouble(sig.symbol, SYMBOL_ASK);
   double bid     = SymbolInfoDouble(sig.symbol, SYMBOL_BID);
   double marketEntry = (sig.direction == 1 ? ask : bid);
   double slDist  = MathAbs(sig.entry - sig.sl);
   if(slDist <= 0) return;

   // Safety: do not execute if price has moved away from the planned OB mitigation entry.
   // This keeps execution near the red-line OB style entry instead of chasing continuation/premium price.
   double tolerance = MathMax(SymbolInfoDouble(sig.symbol, SYMBOL_POINT) * 10, slDist * (EntryExecutionTolerancePct / 100.0));
   if(MathAbs(marketEntry - sig.entry) > tolerance)
   {
      Print("[SKIP] Market price too far from planned OB entry: ", sig.shortName,
            " market=", marketEntry, " planned=", sig.entry, " tolerance=", tolerance);
      return;
   }

   // Keep the OB-based SL/TP levels from the signal. Do not move SL/TP up to the current market price.
   double useSL = NormalizeDouble(sig.sl, digits);
   double useTP = NormalizeDouble(sig.tp1, digits);

   // FIX v2: respect broker's minimum stop distance. On many Deriv whitelabels
   // this is non-zero on synthetic indices and trades get rejected silently
   // (retcode 10016) when SL or TP is too tight to current price.
   long stopsLvl = SymbolInfoInteger(sig.symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stopsLvl > 0)
   {
      double point  = SymbolInfoDouble(sig.symbol, SYMBOL_POINT);
      double minDist = stopsLvl * point;
      if(sig.direction == 1)
      {
         if((marketEntry - useSL) < minDist) useSL = NormalizeDouble(marketEntry - minDist, digits);
         if((useTP - marketEntry) < minDist) useTP = NormalizeDouble(marketEntry + minDist, digits);
      }
      else
      {
         if((useSL - marketEntry) < minDist) useSL = NormalizeDouble(marketEntry + minDist, digits);
         if((marketEntry - useTP) < minDist) useTP = NormalizeDouble(marketEntry - minDist, digits);
      }
   }

   // FIX v2: pick a filling mode the broker actually supports for this symbol.
   // Default IOC fails on some Deriv whitelabels; FOK or RETURN may be required.
   long modes = SymbolInfoInteger(sig.symbol, SYMBOL_FILLING_MODE);
   if((modes & SYMBOL_FILLING_FOK) != 0)       trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((modes & SYMBOL_FILLING_IOC) != 0)  trade.SetTypeFilling(ORDER_FILLING_IOC);
   else                                         trade.SetTypeFilling(ORDER_FILLING_RETURN);

   if((sig.direction == 1 && (useSL >= marketEntry || useTP <= marketEntry)) ||
      (sig.direction == -1 && (useSL <= marketEntry || useTP >= marketEntry)))
   {
      Print("[SKIP] Invalid planned OB SL/TP around market price: ", sig.shortName);
      return;
   }

   // QUALITY FIX: never open more positions than MaxOpenTrades allows.
   int availableSlots = MaxOpenTrades - CountOpenTrades();
   if(availableSlots <= 0) { Print("[SKIP] MaxOpenTrades reached"); return; }
   int toPlace = MathMin(PositionsPerSignal, availableSlots);
   if(StringFind(sig.setup, "Continuation - ") == 0 && sameDirOpen <= 0)
   {
      Print("[SKIP] Continuation needs an existing basket in the same direction: ", sig.shortName);
      return;
   }

   int placed = 0;
   for(int p = 0; p < toPlace; p++)
   {
      bool result = false;
      string comment = "ELITE SMC SYSTEM [" + IntegerToString(p+1) + "/" + IntegerToString(toPlace) + "]";

      if(sig.direction == 1)
         result = trade.Buy(lotSize, sig.symbol, 0, useSL, useTP, comment);
      else
         result = trade.Sell(lotSize, sig.symbol, 0, useSL, useTP, comment);

      if(result) placed++;
      else Print("[X] Position ", p+1, " failed: ", trade.ResultRetcodeDescription());
   }

   if(placed > 0)
   {
      signalCount++;
      Print("[OK] ", placed, "/", toPlace, " market positions placed: ",
            sig.direction==1?"BUY":"SELL", " ", sig.shortName,
            " @ ", marketEntry, " SL:", useSL, " TP:", useTP, " Lot:", lotSize);
      if(TelegramAlert)
      {
         string execMsg = "SMC SafeFlex\n"
                        + "================================\n"
                        + dirStr + " EXECUTED (" + sig.shortName + ")\n"
                        + "Status: TRADE LIVE\n"
                        + "Entry: " + DoubleToString(marketEntry, digits) + "\n"
                        + "SL: " + DoubleToString(useSL, digits) + "\n"
                        + "TP1: " + DoubleToString(sig.tp1, digits) + "\n"
                        + "TP2: " + DoubleToString(sig.tp2, digits) + "\n"
                        + "Lot: " + DoubleToString(lotSize, 2) + "\n"
                        + "Confidence: " + IntegerToString(sig.confidence) + "%\n"
                        + "================================\n"
                        + "Reason: OB mitigation + rejection confirmed.\n"
                        + "Re-entry unlocks only after TP1 is hit.";
         SendTelegramMessage(execMsg);
      }
   }
}

//+------------------------------------------------------------------+
//|  LOT SIZE CALCULATION                                             |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double entry, double sl)
{
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0) lotStep = 0.01;

   // Batch A #3: step-aware digit count. Hardcoding 2 digits broke instruments
   // with 0.001 step (NormalizeDouble(0.001, 2) -> 0.00 -> broker reject).
   int stepDigits = (lotStep >= 1.0) ? 0 : (int)MathCeil(-MathLog10(lotStep));
   if(stepDigits < 0) stepDigits = 0;
   if(stepDigits > 8) stepDigits = 8;

   // -- HARD CAP: never allow more than 1.0 lot regardless of settings
   // This protects against runaway lot calculations on volatile indices
   double hardCap = MathMin(maxLot, 1.0);

   // -- MANUAL LOT MODE
   if(UseManualLot)
   {
      double lot = MathFloor(ManualLotSize / lotStep) * lotStep;
      lot = MathMax(minLot, MathMin(hardCap, lot));
      return NormalizeDouble(lot, stepDigits);
   }

   // -- AUTO RISK MODE
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt = balance * RiskPercent / 100.0;
   double point   = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double slPips  = MathAbs(entry - sl) / point;
   if(slPips <= 0) return minLot;
   double tickVal = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0 || tickSz <= 0) return minLot;
   double pipVal  = tickVal / tickSz * point;
   double lot     = MathFloor(riskAmt / (slPips * pipVal) / lotStep) * lotStep;

   // Apply hard cap ? never exceed 1.0 lot on auto mode
   lot = MathMax(minLot, MathMin(hardCap, lot));
   return NormalizeDouble(lot, stepDigits);
}

//+------------------------------------------------------------------+
//|  MANAGE OPEN TRADES (Breakeven)                                   |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   if(!MoveToBreakeven) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic()!=MagicNumber) continue;
      double entry  = posInfo.PriceOpen();
      double sl     = posInfo.StopLoss();
      double tp     = posInfo.TakeProfit();
      double price  = posInfo.PriceCurrent();
      string sym    = posInfo.Symbol();
      double sym_pt = SymbolInfoDouble(sym, SYMBOL_POINT);

      // Move to breakeven only after price moves BreakevenConfirmPct% of the way to TP1
      // This confirms real movement ? not just a random wick
      double confirmDist = MathAbs(tp - entry) * (BreakevenConfirmPct / 100.0);

      // FIX v2: previous lock was `entry + sym_pt * 5` which is way too tight on
      // V50 (~$81 price) and absurdly tight on V25(1s) (~800k price). Use a
      // small percentage of the TP distance instead so it scales across all
      // volatility indices. Floored to 5 points for sanity on micro instruments.
      double beLock = MathMax(MathAbs(tp - entry) * 0.02, sym_pt * 5);
      // Also respect the broker's minimum stop distance
      long stopsLvl = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
      if(stopsLvl > 0) beLock = MathMax(beLock, stopsLvl * sym_pt);

      if(posInfo.PositionType()==POSITION_TYPE_BUY)
      {
         if(price >= entry + confirmDist && sl < entry)
         {
            int sym_digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
            trade.PositionModify(posInfo.Ticket(), NormalizeDouble(entry + beLock, sym_digits), tp);
            Print("[BE] BUY breakeven moved: ", sym, " entry:", entry, " confirmed at:", price);
         }
      }
      else if(posInfo.PositionType()==POSITION_TYPE_SELL)
      {
         if(price <= entry - confirmDist && sl > entry)
         {
            int sym_digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
            trade.PositionModify(posInfo.Ticket(), NormalizeDouble(entry - beLock, sym_digits), tp);
            Print("[BE] SELL breakeven moved: ", sym, " entry:", entry, " confirmed at:", price);
         }
      }
   }
}

//+------------------------------------------------------------------+
//|  TRADE STATS UPDATE                                               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   ulong ticket=trans.deal;
   if(!HistoryDealSelect(ticket)) return;
   if(HistoryDealGetInteger(ticket,DEAL_MAGIC)!=MagicNumber) return;
   if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket,DEAL_ENTRY)!=DEAL_ENTRY_OUT) return;
   double profit=HistoryDealGetDouble(ticket,DEAL_PROFIT)+HistoryDealGetDouble(ticket,DEAL_SWAP)+HistoryDealGetDouble(ticket,DEAL_COMMISSION);
   totalTrades++;
   if(profit>0.01)
   {
      winTrades++;totalProfit+=profit;
      if(profit>largestWin)largestWin=profit;
      consecutiveLosses=0; // reset losing streak on a win
   }
   else if(profit<-0.01)
   {
      lossTrades++;totalLoss+=profit;
      if(profit<largestLoss)largestLoss=profit;
      consecutiveLosses++;
      if(consecutiveLosses>=MaxConsecutiveLosses)
      {
         smartRulesBlocked = true;
         lossBlockedSince  = TimeCurrent();
         string cooldownMsg = LossCooldownMinutes > 0
            ? "Auto resumes in " + IntegerToString(LossCooldownMinutes) + " minutes."
            : "Manual reset required.";
         smartBlockReason="[X] "+IntegerToString(consecutiveLosses)+" losses in a row - "+cooldownMsg;
         if(PushNotification) SendNotification("[!] JOJOS SMC DERIV - "+IntegerToString(consecutiveLosses)+" losses in a row!\n"+cooldownMsg+"\nSignals continue.");
         Print("[SMART] ",smartBlockReason);
      }
   }
   else breakevenTrades++;
   SaveSmartState();   // Batch A #1: persist streak/cooldown after every closed deal.
   string sym=HistoryDealGetString(ticket,DEAL_SYMBOL);
   string sn=GetShortName(sym);
   string r2=profit>0?"WIN [OK] +":(profit<0?"LOSS [X] ":"BE [-] ");
   lastSignalStr=r2+DoubleToString(MathAbs(profit),2)+" | "+sn;
   lastSignalTime=TimeCurrent();
   if(ShowDashboard) DrawDashboard();
   Print("Deriv trade closed: ",r2,"$",DoubleToString(profit,2)," | W:",winTrades," L:",lossTrades," | WR:",DoubleToString(totalTrades>0?(double)winTrades/totalTrades*100:0,1),"%");
}

//+------------------------------------------------------------------+
//|  DASHBOARD                                                        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|  DRAW DASHBOARD - HORIZONTAL (6 columns across bottom of chart)  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|  DASHBOARD - "PRO TERMINAL" (FIX v2 redesign)                    |
//|  Top status ribbon + 4 KPI tiles + 3 detail panels.              |
//|  Warm amber primary, green/red P&L accents, near-black canvas.   |
//+------------------------------------------------------------------+
void DrawDashboard()
{
   ObjectsDeleteAll(0, DB_PREFIX);

   // ---- Stats ------------------------------------------------------
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double profit   = equity - balance;
   double winRate  = totalTrades > 0 ? (double)winTrades/totalTrades*100.0 : 0;
   double pf       = totalLoss < 0 ? totalProfit/MathAbs(totalLoss) : (totalProfit > 0 ? 999 : 0);
   double dayAnch  = dayStartBalance > 0 ? dayStartBalance : startBalance;
   double dailyPnL = balance - dayAnch;
   double dailyPct = dayAnch > 0 ? dailyPnL / dayAnch * 100.0 : 0;
   if(equity > peakEquity) peakEquity = equity;
   double dd       = peakEquity > 0 ? (peakEquity - equity) / peakEquity * 100.0 : 0;
   if(dd > maxDrawdown) maxDrawdown = dd;

   // ---- Layout -----------------------------------------------------
   int DX = Dashboard_X, DY = Dashboard_Y;
   int W = 1080, H = 290;
   int RH1 = 28;   // top ribbon
   int RH2 = 90;   // KPI tiles row
   int RH3 = H - RH1 - RH2; // detail panels row

   // ---- Palette (Pro Terminal) ------------------------------------
   color BG_DARK    = C'8,10,14';      // outer canvas
   color BG_PANEL   = C'14,18,26';     // detail panels
   color BG_KPI     = C'12,14,20';     // KPI tile
   color BG_RIBBON  = C'22,16,8';      // amber-tinted top ribbon
   color BORDER     = C'40,50,72';     // subtle dividers
   color AMBER      = C'255,176,0';    // primary headers / values
   color AMBER_DIM  = C'180,124,0';
   color GOLD       = C'255,215,80';   // highlights / warnings
   color GREEN      = C'80,220,140';   // wins / positive
   color RED        = C'255,90,100';   // losses / breach
   color CYAN_INFO  = C'80,170,220';   // info accent (sparing)
   color WHITE_HOT  = clrWhite;        // primary data
   color TEXT_MUTE  = C'140,150,170';  // secondary
   color TEXT_DIM   = C'80,90,110';    // tertiary

   // Outer frame
   DB_Rect("FRAME",  DX-1, DY-1, W+2, H+2, BG_DARK, BORDER, 1);

   // ---- TOP RIBBON ------------------------------------------------
   DB_Rect("RIBBON",     DX,       DY,         W, RH1, BG_RIBBON, AMBER_DIM, 0);
   DB_Rect("RIBBONLINE", DX,       DY+RH1-1,   W, 1,   AMBER_DIM, AMBER_DIM, 0);

   // Brand
   DB_Label("BRAND_X", DX+12,  DY+9, "ELITE SMC",        AMBER,     10, true);
   DB_Label("BRAND_V", DX+92,  DY+9, "v2.0",             TEXT_DIM,   8, false);
   DB_Label("BRAND_S", DX+118, DY+9, "// FIELD COMMAND", AMBER_DIM,  8, false);

   // Center status
   string scanStatus; color scanColor;
   if(smartRulesBlocked)          { scanStatus = "[ PAUSED ]";       scanColor = GOLD;  }
   else if(IsDailyLossExceeded()) { scanStatus = "[ STOP / LIMIT ]"; scanColor = RED;   }
   else if(activeCount == 0)      { scanStatus = "[ NO SYMBOLS ]";   scanColor = RED;   }
   else                           { scanStatus = "[ SCANNING ]";     scanColor = GREEN; }
   DB_Label("STATUS", DX+W/2-150, DY+9, scanStatus, scanColor, 9, true);

   string modeStr = AlertOnly ? "ALERT" : (ExecuteTrades ? "EXEC" : "CONFIRM Y/N");
   color  modeC   = AlertOnly ? GOLD : (ExecuteTrades ? GREEN : CYAN_INFO);
   DB_Label("MODE_L", DX+W/2,    DY+9, "MODE",  TEXT_MUTE, 8, false);
   DB_Label("MODE_V", DX+W/2+38, DY+9, modeStr, modeC,     9, true);

   // Right side: open trades + min confidence
   int ot = CountOpenTrades();
   color otC = ot >= MaxOpenTrades ? GOLD : AMBER;
   DB_Label("TRD_L", DX+W-220, DY+9, "OPEN",     TEXT_MUTE, 8, false);
   DB_Label("TRD_V", DX+W-185, DY+9, IntegerToString(ot)+"/"+IntegerToString(MaxOpenTrades), otC, 9, true);
   DB_Label("CNF_L", DX+W-130, DY+9, "MIN CONF", TEXT_MUTE, 8, false);
   DB_Label("CNF_V", DX+W-65,  DY+9, IntegerToString(MinConfidence)+"%", AMBER, 9, true);

   // ---- KPI ROW (4 tiles) -----------------------------------------
   int kpiY = DY + RH1;
   int kpiW = W / 4;

   for(int k = 0; k < 4; k++)
      DB_Rect("KPI"+IntegerToString(k), DX + k*kpiW, kpiY, kpiW, RH2, BG_KPI, BG_KPI, 0);
   for(int k = 1; k < 4; k++)
      DB_Rect("KDV"+IntegerToString(k), DX + k*kpiW, kpiY+8, 1, RH2-16, BORDER, BORDER, 0);

   // Tile 1 - BALANCE
   int t1x = DX + 12;
   DB_Label("KPI1L", t1x, kpiY+8,  "BALANCE", TEXT_MUTE, 8, false);
   DB_Label("KPI1V", t1x, kpiY+24, "$"+DoubleToString(balance, 2), WHITE_HOT, 14, true);
   double balPct = startBalance > 0 ? (balance - startBalance) / startBalance * 100.0 : 0;
   color  balC   = balPct >= 0 ? GREEN : RED;
   DB_Label("KPI1S", t1x, kpiY+50, "Start  $"+DoubleToString(startBalance, 2), TEXT_DIM, 7, false);
   DB_Label("KPI1P", t1x, kpiY+64, (balPct >= 0 ? "+" : "")+DoubleToString(balPct, 2)+"% all-time", balC, 8, true);

   // Tile 2 - EQUITY (with open P&L)
   int t2x = DX + kpiW + 12;
   DB_Label("KPI2L", t2x, kpiY+8,  "EQUITY", TEXT_MUTE, 8, false);
   DB_Label("KPI2V", t2x, kpiY+24, "$"+DoubleToString(equity, 2), WHITE_HOT, 14, true);
   color  pC   = profit >= 0 ? GREEN : RED;
   string opl  = (profit >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(profit), 2);
   DB_Label("KPI2S", t2x, kpiY+50, "OPEN P/L", TEXT_DIM, 7, false);
   DB_Label("KPI2P", t2x, kpiY+64, opl, pC, 9, true);

   // Tile 3 - DAILY P/L (with progress bar to whichever limit is closer)
   int t3x = DX + kpiW*2 + 12;
   DB_Label("KPI3L", t3x, kpiY+8,  "DAILY P/L", TEXT_MUTE, 8, false);
   color  dC   = dailyPnL >= 0 ? GREEN : RED;
   string dTx  = (dailyPnL >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(dailyPnL), 2);
   DB_Label("KPI3V", t3x, kpiY+24, dTx, dC, 14, true);
   string dPct = (dailyPct >= 0 ? "+" : "") + DoubleToString(dailyPct, 2) + "%";
   DB_Label("KPI3P", t3x, kpiY+44, dPct, dC, 9, true);

   int barW = kpiW - 24, barX = t3x, barY = kpiY+62;
   DB_Rect("KPI3BG", barX, barY, barW, 4, C'25,30,42', C'25,30,42', 0);
   double pct = dailyPnL >= 0
      ? (DailyProfitLockPct > 0 ? MathMin(dailyPct / DailyProfitLockPct, 1.0) : 0)
      : (MaxDailyLossPct  > 0 ? MathMin(MathAbs(dailyPct) / MaxDailyLossPct, 1.0) : 0);
   int fillW = (int)(barW * pct);
   if(fillW > 0) DB_Rect("KPI3BF", barX, barY, fillW, 4, dC, dC, 0);
   string lim  = dailyPnL >= 0
      ? "-> +" + DoubleToString(DailyProfitLockPct, 0) + "% lock"
      : "-> -" + DoubleToString(MaxDailyLossPct, 0) + "% stop";
   DB_Label("KPI3T", t3x, kpiY+72, lim, TEXT_DIM, 7, false);

   // Tile 4 - WIN RATE
   int t4x = DX + kpiW*3 + 12;
   DB_Label("KPI4L", t4x, kpiY+8,  "WIN RATE", TEXT_MUTE, 8, false);
   color  wrC = winRate >= 60 ? GREEN : winRate >= 45 ? GOLD : (totalTrades == 0 ? AMBER_DIM : RED);
   string wrT = totalTrades == 0 ? "--" : DoubleToString(winRate, 1) + "%";
   DB_Label("KPI4V", t4x, kpiY+24, wrT, wrC, 14, true);
   string wrSub = "W " + IntegerToString(winTrades) + "  L " + IntegerToString(lossTrades) + "  BE " + IntegerToString(breakevenTrades);
   DB_Label("KPI4S", t4x, kpiY+44, wrSub, TEXT_MUTE, 8, false);

   int wbW = kpiW - 24, wbX = t4x;
   DB_Rect("KPI4BG", wbX, kpiY+62, wbW, 4, C'25,30,42', C'25,30,42', 0);
   if(totalTrades > 0)
   {
      int wbF = (int)(wbW * winRate / 100.0);
      if(wbF > 0) DB_Rect("KPI4BF", wbX, kpiY+62, wbF, 4, wrC, wrC, 0);
   }
   string pfStr = "PF " + (pf >= 999 ? "inf" : DoubleToString(pf, 2));
   DB_Label("KPI4T", t4x, kpiY+72, pfStr + "  |  DD " + DoubleToString(maxDrawdown, 1) + "%", TEXT_DIM, 7, false);

   // ---- DETAIL ROW (3 panels) -------------------------------------
   int detY    = DY + RH1 + RH2;
   int panelW  = W / 3;

   for(int p = 0; p < 3; p++)
      DB_Rect("DET"+IntegerToString(p), DX + p*panelW, detY, panelW, RH3, BG_PANEL, BG_PANEL, 0);
   for(int p = 1; p < 3; p++)
      DB_Rect("DDV"+IntegerToString(p), DX + p*panelW, detY+10, 1, RH3-20, BORDER, BORDER, 0);
   DB_Rect("DETDIV", DX, detY, W, 1, BORDER, BORDER, 0);

   // Panel 1 - SMART RULES + RISK
   int p1x = DX + 14;
   int p1y = detY + 10;
   DB_Label("P1H", p1x, p1y, "[ SMART RULES ]", AMBER, 9, true); p1y += 18;

   DB_Label("P1A", p1x, p1y, "Today",        TEXT_MUTE, 8, false);
   DB_Label("P1AV", p1x+95, p1y,
            IntegerToString(dailyTradeCount)+"/"+IntegerToString(MaxTradesPerDay)+" trades",
            dailyTradeCount >= MaxTradesPerDay ? GOLD : WHITE_HOT, 8, true); p1y += 16;

   DB_Label("P1B", p1x, p1y, "Streak",       TEXT_MUTE, 8, false);
   color streakC = consecutiveLosses >= MaxConsecutiveLosses ? RED : (consecutiveLosses > 0 ? GOLD : GREEN);
   string streakTxt = consecutiveLosses == 0 ? "clean" : IntegerToString(consecutiveLosses) + " loss" + (consecutiveLosses > 1 ? "es" : "");
   DB_Label("P1BV", p1x+95, p1y, streakTxt, streakC, 8, true); p1y += 16;

   DB_Label("P1C", p1x, p1y, "Profit lock",  TEXT_MUTE, 8, false);
   DB_Label("P1CV", p1x+95, p1y, "+"+DoubleToString(DailyProfitLockPct, 0)+"%", GOLD, 8, true); p1y += 16;

   DB_Label("P1D", p1x, p1y, "Loss stop",    TEXT_MUTE, 8, false);
   DB_Label("P1DV", p1x+95, p1y, "-"+DoubleToString(MaxDailyLossPct, 0)+"%", RED, 8, true); p1y += 16;

   DB_Label("P1E", p1x, p1y, "Lot",          TEXT_MUTE, 8, false);
   string lotTxt = UseManualLot ? DoubleToString(ManualLotSize, 3) : "auto " + DoubleToString(RiskPercent, 1) + "%";
   DB_Label("P1EV", p1x+95, p1y, lotTxt, AMBER, 8, true); p1y += 16;

   DB_Label("P1F", p1x, p1y, "Pos / signal", TEXT_MUTE, 8, false);
   DB_Label("P1FV", p1x+95, p1y, IntegerToString(PositionsPerSignal), AMBER, 8, true); p1y += 16;

   if(smartRulesBlocked && smartBlockReason != "")
      DB_Label("P1G", p1x, p1y, smartBlockReason, GOLD, 7, false);

   // Panel 2 - SCANNING GRID (10 indices, 2 columns)
   int p2x = DX + panelW + 14;
   int p2y = detY + 10;
   DB_Label("P2H", p2x, p2y, "[ SCANNING ]", AMBER, 9, true); p2y += 18;

   string ins[10] = {"V10","V10(1s)","V25","V25(1s)","V50","V50(1s)","V75","V75(1s)","V100","V100(1s)"};
   bool   ena[10] = {Scan_V10,Scan_V10_1s,Scan_V25,Scan_V25_1s,Scan_V50,Scan_V50_1s,Scan_V75,Scan_V75_1s,Scan_V100,Scan_V100_1s};
   for(int i = 0; i < 10; i += 2)
   {
      string p1mark = ena[i]   ? "[+]" : "[ ]";
      string p2mark = (i+1 < 10 && ena[i+1]) ? "[+]" : "[ ]";
      color  c1m    = ena[i]   ? GREEN : TEXT_DIM;
      color  c2m    = (i+1 < 10 && ena[i+1]) ? GREEN : TEXT_DIM;
      DB_Label("P2P"+IntegerToString(i),   p2x,     p2y, p1mark, c1m, 8, true);
      DB_Label("P2N"+IntegerToString(i),   p2x+25,  p2y, ins[i], ena[i] ? WHITE_HOT : TEXT_DIM, 8, false);
      if(i+1 < 10)
      {
         DB_Label("P2P"+IntegerToString(i+1), p2x+170, p2y, p2mark, c2m, 8, true);
         DB_Label("P2N"+IntegerToString(i+1), p2x+195, p2y, ins[i+1], ena[i+1] ? WHITE_HOT : TEXT_DIM, 8, false);
      }
      p2y += 14;
   }
   p2y += 6;
   color resolvedC = activeCount >= 1 ? GREEN : RED;
   DB_Label("P2T", p2x, p2y, "Resolved on broker:", TEXT_MUTE, 8, false);
   DB_Label("P2TV", p2x+135, p2y, IntegerToString(activeCount)+"/10", resolvedC, 8, true);

   // Panel 3 - RECENT TRADES + STATS
   int p3x = DX + panelW*2 + 14;
   int p3y = detY + 10;
   DB_Label("P3H", p3x, p3y, "[ RECENT TRADES ]", AMBER, 9, true); p3y += 18;

   HistorySelect(0, TimeCurrent());
   int dc = 0;
   for(int d = HistoryDealsTotal()-1; d >= 0 && dc < 6; d--)
   {
      ulong dt = HistoryDealGetTicket(d);
      if(HistoryDealGetInteger(dt, DEAL_MAGIC) != MagicNumber) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(dt, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      double dp   = HistoryDealGetDouble(dt, DEAL_PROFIT) + HistoryDealGetDouble(dt, DEAL_SWAP) + HistoryDealGetDouble(dt, DEAL_COMMISSION);
      string dsym = GetShortName(HistoryDealGetString(dt, DEAL_SYMBOL));
      string ddr  = HistoryDealGetInteger(dt, DEAL_TYPE) == DEAL_TYPE_BUY ? "B" : "S";
      string ic   = dp > 0.01 ? "+" : (dp < -0.01 ? "-" : "=");
      color  rc   = dp > 0.01 ? GREEN : (dp < -0.01 ? RED : GOLD);
      string pStr = (dp >= 0 ? "+" : "") + DoubleToString(dp, 2);
      DB_Label("P3I"+IntegerToString(dc), p3x,           p3y, ic,           rc,        9,  true);
      DB_Label("P3D"+IntegerToString(dc), p3x+18,        p3y, ddr+"  "+dsym, WHITE_HOT, 8, false);
      DB_Label("P3P"+IntegerToString(dc), p3x+panelW-110,p3y, pStr,         rc,        8,  true);
      p3y += 14;
      dc++;
   }
   if(dc == 0) DB_Label("P3X", p3x, p3y, "No closed trades yet", TEXT_DIM, 8, false);
   p3y += 8;
   string statsLine = "Total " + IntegerToString(totalTrades)
                    + "  |  Best +$" + DoubleToString(largestWin, 2)
                    + "  |  Worst -$" + DoubleToString(MathAbs(largestLoss), 2);
   DB_Label("P3T", p3x, p3y, statsLine, TEXT_MUTE, 7, false);

   // ---- Footer line under dashboard --------------------------------
   string lsTxt  = lastSignalStr;
   string ageTxt = lastSignalTime > 0 ? "  |  " + TimeAgoStr(lastSignalTime) : "";
   DB_Label("FOOT", DX+10, DY+H+8, ">> " + lsTxt + ageTxt, GOLD, 8, false);

   if(hasPendingSignal && ShowTradeConfirm) DrawConfirmBox();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//|  CONFIRMATION BOX - PRO TERMINAL STYLE                           |
//+------------------------------------------------------------------+
void DrawConfirmBox()
{
   int cw=300, cx=Dashboard_X+(1080)/2-cw/2, cy=Dashboard_Y-310;
   if(cy<10) cy=10;
   string arrow=pendingSignal.direction==1?"[BUY]":"[SELL]";
   color aC=pendingSignal.direction==1?C'80,220,140':C'255,90,100';
   string typeLbl="",typeTF="";
   if(pendingSignal.tradeType=="Scalp")      {typeLbl="SCALP";       typeTF="M15->M1";}
   else if(pendingSignal.tradeType=="Day")   {typeLbl="DAY TRADE";   typeTF="H4->M5";}
   else if(pendingSignal.tradeType=="Swing") {typeLbl="SWING TRADE"; typeTF="Daily->M15";}
   int tl=ConfirmTimeout>0?ConfirmTimeout-(int)(TimeCurrent()-pendingTime):-1;
   string ts=tl>0?" ("+IntegerToString(tl)+"s)":"";
   int digs=(int)SymbolInfoInteger(pendingSignal.symbol,SYMBOL_DIGITS);

   // Pro Terminal palette
   color BG_BOX = C'12,14,20';
   color BG_HDR = C'22,16,8';
   color BORDER = C'180,124,0';   // amber border
   color AMBER  = C'255,176,0';
   color GOLD   = C'255,215,80';
   color MUTE   = C'140,150,170';
   color DIM    = C'80,90,110';

   DB_Rect("CB_BG", cx, cy,    cw, 320, BG_BOX, BORDER, 2);
   DB_Rect("CB_HD", cx, cy,    cw, 32,  BG_HDR, BORDER, 0);
   DB_Rect("CB_ACL",cx, cy+32, cw, 1,   BORDER, BORDER, 0);
   DB_Label("CB_TI", cx+12, cy+9,
            pendingSignal.isSniper ? "[ SNIPER ENTRY ]"+ts : "[ TRADE SIGNAL ]"+ts,
            pendingSignal.isSniper ? GOLD : AMBER, 10, true);
   int y2=cy+44;
   DB_Label("CB_DR", cx+12, y2, arrow+"  "+pendingSignal.shortName, aC, 14, true); y2+=22;
   DB_Label("CB_TY", cx+12, y2, typeLbl, GOLD, 10, true); y2+=14;
   DB_Label("CB_TF", cx+12, y2, "TF chain: "+typeTF, MUTE, 8, false); y2+=12;
   DB_Label("CB_ST", cx+12, y2, pendingSignal.setup, AMBER, 8, false); y2+=14;
   color cC = pendingSignal.confidence>=90 ? GOLD : pendingSignal.confidence>=80 ? C'80,220,140' : AMBER;
   DB_Label("CB_CF", cx+12, y2,
            "Confidence  "+IntegerToString(pendingSignal.confidence)+"%"
            +(pendingSignal.isSniper?"  [SNIPER]":""), cC, 9, true); y2+=18;
   DB_Label("CB_EL", cx+12, y2, "Entry",   MUTE, 9, false); DB_Label("CB_EV",  cx+95, y2, DoubleToString(pendingSignal.entry,digs), clrWhite, 9, true);   y2+=14;
   DB_Label("CB_SL", cx+12, y2, "Stop",    MUTE, 9, false); DB_Label("CB_SV",  cx+95, y2, DoubleToString(pendingSignal.sl,digs),    C'255,90,100', 9, true); y2+=14;
   DB_Label("CB_T1", cx+12, y2, "TP1",     MUTE, 9, false); DB_Label("CB_T1V", cx+95, y2, DoubleToString(pendingSignal.tp1,digs),   C'80,220,140', 9, true);  y2+=14;
   DB_Label("CB_T2", cx+12, y2, "TP2",     MUTE, 9, false); DB_Label("CB_T2V", cx+95, y2, DoubleToString(pendingSignal.tp2,digs),   C'80,220,140', 9, true);  y2+=14;
   DB_Label("CB_RL", cx+12, y2, "R:R",     MUTE, 9, false); DB_Label("CB_RV",  cx+95, y2, "1:"+DoubleToString(pendingSignal.rr,1), AMBER, 9, true); y2+=18;
   DB_Label("CB_PS", cx+12, y2, "Positions  "+IntegerToString(PositionsPerSignal)+" x "+DoubleToString(ManualLotSize,3)+" lot", AMBER, 8, true); y2+=18;

   // Buttons
   DB_Rect("CB_YES",cx+12,  y2, 132, 28, C'10,40,16', C'80,220,140', 1);
   DB_Rect("CB_NO", cx+156, y2, 132, 28, C'40,12,14', C'255,90,100', 1);
   DB_Label("CB_YL",cx+30,  y2+8, "[Y] CONFIRM", clrWhite, 9, true);
   DB_Label("CB_NL",cx+178, y2+8, "[N] SKIP",    clrWhite, 9, true); y2+=34;
   DB_Label("CB_HT",cx+12,  y2,   "Press Y to fire  -  N to skip  -  auto-skip on timeout", DIM, 7, false);
}

void DB_Rect(string n,int x,int y,int w,int h,color bg,color br,int bw)
{
   string o=DB_PREFIX+n;
   if(ObjectFind(0,o)<0) ObjectCreate(0,o,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,o,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,o,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,o,OBJPROP_XSIZE,w);     ObjectSetInteger(0,o,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,o,OBJPROP_BGCOLOR,bg);  ObjectSetInteger(0,o,OBJPROP_BORDER_COLOR,br);
   ObjectSetInteger(0,o,OBJPROP_BORDER_TYPE,BORDER_FLAT); ObjectSetInteger(0,o,OBJPROP_WIDTH,bw);
   ObjectSetInteger(0,o,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,o,OBJPROP_BACK,true);
   ObjectSetInteger(0,o,OBJPROP_SELECTABLE,false);
}
void DB_Label(string n,int x,int y,string txt,color c,int sz,bool bold)
{
   string o=DB_PREFIX+n;
   if(ObjectFind(0,o)<0) ObjectCreate(0,o,OBJ_LABEL,0,0,0);
   ObjectSetString(0,o,OBJPROP_TEXT,txt);      ObjectSetInteger(0,o,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,o,OBJPROP_YDISTANCE,y);  ObjectSetInteger(0,o,OBJPROP_COLOR,c);
   ObjectSetInteger(0,o,OBJPROP_FONTSIZE,sz);  ObjectSetString(0,o,OBJPROP_FONT,bold?"Arial Bold":"Arial");
   ObjectSetInteger(0,o,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,o,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,o,OBJPROP_BACK,false);
}
string TimeAgoStr(datetime t)
{
   int s=(int)(TimeCurrent()-t);
   if(s<60) return IntegerToString(s)+"s ago";
   if(s<3600) return IntegerToString(s/60)+"m ago";
   return IntegerToString(s/3600)+"h ago";
}

//+------------------------------------------------------------------+
//|  HELPERS                                                          |
//+------------------------------------------------------------------+
void GetTimeframes(string tt,ENUM_TIMEFRAMES &bTF,ENUM_TIMEFRAMES &lTF,ENUM_TIMEFRAMES &boTF,ENUM_TIMEFRAMES &eTF)
{
   if(tt=="Scalp") {bTF=scalp_bias_tf;lTF=scalp_liq_tf;boTF=scalp_bos_tf;eTF=scalp_entry_tf;}
   else if(tt=="Day") {bTF=day_bias_tf;lTF=day_liq_tf;boTF=day_bos_tf;eTF=day_entry_tf;}
   else          {bTF=swing_bias_tf;lTF=swing_liq_tf;boTF=swing_bos_tf;eTF=swing_entry_tf;}
}
string TFToStr(ENUM_TIMEFRAMES tf)
{
   switch(tf){case PERIOD_M1:return"M1";case PERIOD_M5:return"M5";case PERIOD_M15:return"M15";
   case PERIOD_M30:return"M30";case PERIOD_H1:return"H1";case PERIOD_H4:return"H4";
   case PERIOD_D1:return"D1";case PERIOD_W1:return"W1";default:return"TF";}
}
int CountOpenTrades()
{int n=0;for(int i=PositionsTotal()-1;i>=0;i--) if(posInfo.SelectByIndex(i)&&posInfo.Magic()==MagicNumber)n++;return n;}

int FindInstrumentIndex(string symbol)
{
   for(int i = 0; i < activeCount; i++)
      if(activeInstruments[i] == symbol) return i;
   return -1;
}

int CountDirectionalOpenTrades(string symbol, int direction)
{
   int n = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != symbol || posInfo.Magic() != MagicNumber) continue;
      int pd = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
      if(pd == direction) n++;
   }
   return n;
}

double GetDirectionalBasketProfit(string symbol, int direction)
{
   double profit = 0.0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != symbol || posInfo.Magic() != MagicNumber) continue;
      int pd = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
      if(pd == direction) profit += posInfo.Profit();
   }
   return profit;
}

int CountPendingOrders(string symbol)
{
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0) continue;
      if(OrderGetString(ORDER_SYMBOL)!=symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC)!=MagicNumber) continue;
      count++;
   }
   return count;
}
//+------------------------------------------------------------------+
//|  SMART TRADING RULES ? daily reset + protection checks           |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   // Check if it's a new day ? reset daily counters
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   MqlDateTime lastDt;
   TimeToStruct(lastTradeDay, lastDt);
   if(dt.day != lastDt.day || lastTradeDay == 0)
   {
      dailyTradeCount   = 0;
      smartRulesBlocked = false;
      smartBlockReason  = "";
      dayStartBalance   = AccountInfoDouble(ACCOUNT_BALANCE);
      lastTradeDay      = TimeCurrent();
      SaveSmartState();   // Batch A #1: persist new-day anchor immediately.
      Print("[SMART] New day - counters reset. Day balance: $", dayStartBalance);
   }
}

bool IsSmartRulesAllowed()
{
   CheckDailyReset();

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   // Rule 1: Max trades per day
   if(dailyTradeCount >= MaxTradesPerDay)
   {
      smartRulesBlocked = true;
      smartBlockReason  = "[!] MAX TRADES/DAY (" + IntegerToString(dailyTradeCount) + "/" + IntegerToString(MaxTradesPerDay) + ") - Signals only";
      return false;
   }

   // Rule 2: Consecutive losses gate with auto-cooldown
   if(consecutiveLosses >= MaxConsecutiveLosses)
   {
      // Check if cooldown period has passed ? auto resume
      if(LossCooldownMinutes > 0 && lossBlockedSince > 0)
      {
         int minutesPassed = (int)((TimeCurrent() - lossBlockedSince) / 60);
         if(minutesPassed >= LossCooldownMinutes)
         {
            // Auto resume after cooldown
            consecutiveLosses = 0;
            lossBlockedSince  = 0;
            smartRulesBlocked = false;
            smartBlockReason  = "";
            SaveSmartState();   // Batch A #1: persist reset so cooldown doesn't re-engage on restart.
            Print("[SMART] Loss cooldown expired - auto trading resumed");
            if(PushNotification) SendNotification("[OK] JOJOS SMC - Cooldown ended, auto trading resumed!");
         }
         else
         {
            int minsLeft = LossCooldownMinutes - minutesPassed;
            smartRulesBlocked = true;
            smartBlockReason  = "[X] " + IntegerToString(consecutiveLosses) + " losses - Cooling down " + IntegerToString(minsLeft) + " min left";
            return false;
         }
      }
      else if(LossCooldownMinutes == 0)
      {
         // Manual reset mode
         smartRulesBlocked = true;
         smartBlockReason  = "[X] " + IntegerToString(consecutiveLosses) + " losses - Manual reset required";
         return false;
      }
   }

   // Rule 3: Daily profit lock
   if(dayStartBalance > 0)
   {
      double dailyProfitPct = (balance - dayStartBalance) / dayStartBalance * 100.0;
      if(dailyProfitPct >= DailyProfitLockPct)
      {
         smartRulesBlocked = true;
         smartBlockReason  = "[OK] PROFIT LOCKED +" + DoubleToString(dailyProfitPct,1) + "% - Great day! Stop here.";
         return false;
      }
   }

   smartRulesBlocked = false;
   smartBlockReason  = "";
   return true;
}

bool IsDailyLossExceeded()
{
   // FIX v2: previously anchored on startBalance (set once at OnInit), so after
   // a few days of running this stopped being a "daily" check. Now uses
   // dayStartBalance which is reset each day in CheckDailyReset().
   double anchor = (dayStartBalance > 0 ? dayStartBalance : startBalance);
   double eq     = AccountInfoDouble(ACCOUNT_EQUITY);
   double maxLoss = anchor * MaxDailyLossPct / 100.0;
   if((anchor - eq) >= maxLoss)
   {
      static bool warned = false;
      static datetime warnedOn = 0;
      // Re-warn once per day rather than once forever
      if(!warned || warnedOn != lastTradeDay)
      {
         Print("[STOP] Daily loss limit hit (", MaxDailyLossPct,
               "% of $", DoubleToString(anchor, 2),
               ") - AUTO TRADING STOPPED for today.");
         Print("[!] Signals continue, no orders placed.");
         warned = true;
         warnedOn = lastTradeDay;
      }
      return true;
   }
   return false;
}
//+------------------------------------------------------------------+
//|  CHART EVENT - Y/N keys for trade confirmation                   |
//|  FIX v2: this handler was missing entirely. Confirmation popup    |
//|  drew on screen but pressing Y/N did nothing - signals timed out. |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_KEYDOWN) return;
   if(!hasPendingSignal) return;

   // Y / y = 89 / 121, N / n = 78 / 110
   if(lparam == 89 || lparam == 121)
   {
      Print("[CONFIRM] Y pressed - executing pending signal: ", pendingSignal.shortName);
      hasPendingSignal = false;
      ObjectsDeleteAll(0, DB_PREFIX + "CB_");
      dailyTradeCount++;
      SaveSmartState();   // Batch A #1
      ExecuteSignal(pendingSignal);
      if(ShowDashboard) DrawDashboard();
   }
   else if(lparam == 78 || lparam == 110)
   {
      Print("[CONFIRM] N pressed - signal skipped: ", pendingSignal.shortName);
      hasPendingSignal = false;
      ObjectsDeleteAll(0, DB_PREFIX + "CB_");
      if(ShowDashboard) DrawDashboard();
   }
}

void OnDeinit(const int reason){SaveSmartState();ObjectsDeleteAll(0,DB_PREFIX);Print("Jojos SMC Deriv EA stopped. Signals: ",signalCount);}
//+------------------------------------------------------------------+

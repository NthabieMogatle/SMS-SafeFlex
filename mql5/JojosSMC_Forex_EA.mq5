//+------------------------------------------------------------------+
//|                    JojosSMC_EA.mq5                             |
//|         Smart Money Concepts Expert Advisor                      |
//|    Based on Phineas SMC Book - Setup 1 & Setup 2                |
//|    Instruments: Forex, Crypto, Indices, Gold                     |
//|    Trade Types:  Scalp | Day Trade | Swing                       |
//+------------------------------------------------------------------+
#property copyright "Jojos SMC EA"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

CTrade        trade;
CPositionInfo posInfo;
COrderInfo    orderInfo;

//+------------------------------------------------------------------+
//|  INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+

// -- TRADE MODE
input group "=== TRADE MODE ==="
input bool   AlertOnly        = false;  // TRUE = alerts only, no orders placed ever
input bool   ExecuteTrades    = true;   // TRUE = execute trades automatically at market
input bool   AutoExecute      = true;   // Legacy option kept for compatibility
                                        // FALSE = show confirmation popup, press Y to trade
// NOTE: If AlertOnly=true, no orders are placed regardless of ExecuteTrades/AutoExecute
// NOTE: If ExecuteTrades=true or AutoExecute=true, ShowTradeConfirm popup is skipped - orders fire instantly
// NOTE: If AutoExecute=false, you must press Y on the popup to confirm each trade
input bool   ShowTradeConfirm = true;   // Show confirmation popup (only used when AutoExecute=false)
input bool   EnableDayTrade      = true;   // Enable Day trades (H4->H1->M15->M5)
input bool   EnableSwing         = true;   // Enable Swing trades (Daily->H4->H1->M15)
input bool   EnableContinuation  = true;   // Enable Continuation trades (FVG/OB pullback on open trade)

// -- SETUP SELECTION
input group "=== SETUPS ==="
input bool   UseSetup1        = true;    // Setup 1: Stop Hunt + BOS + RTO
input bool   UseSetup2        = true;    // Setup 2: SMS + BMS + RTO
input bool   UseConfluence3D  = true;    // Confluence: 3-Drive (3rd trendline touch inside OB)
input bool   UseInducement    = true;    // Confluence: Inducement trap before OB
input bool   UseQML           = true;    // Confluence: QML (Quasimodo Level) + OB kill zone
input bool   UseFVG           = true;    // Confluence: Fair Value Gap / Imbalance
input bool   UseBreakerBlock  = true;    // Confluence: Breaker Block (failed OB)
input bool   UseCHoCH         = true;    // Confluence: Change of Character confirmation
input int    MinConfidence     = 65;     // Minimum confidence score to take signal

// -- DASHBOARD
input group "=== DASHBOARD ==="
input bool   ShowDashboard    = true;   // Show on-chart dashboard
input int    Dashboard_X      = 20;     // Dashboard X position (pixels from left)
input int    Dashboard_Y      = 30;     // Dashboard Y position (pixels from top)
input int    ConfirmTimeout   = 30;     // Seconds before confirmation popup times out

// -- RISK MANAGEMENT
input group "=== RISK MANAGEMENT ==="
input bool   UseManualLot          = false;   // TRUE = use fixed lot size below | FALSE = auto % risk
input double ManualLotSize         = 0.01;    // Fixed lot size (used when UseManualLot = true)
input double RiskPercent           = 1.0;     // Auto risk % per trade (used when UseManualLot = false)
input double MaxDailyLossPct       = 3.0;     // Max daily loss % before EA stops
input int    MaxOpenTrades         = 5;       // Max simultaneous open trades
input double MinRR                 = 2.0;     // Minimum Risk:Reward ratio

// -- SMART TRADING RULES
input group "=== SMART TRADING RULES ==="
input int    MaxTradesPerDay       = 3;       // Max trades per day then alerts only
input int    MaxConsecutiveLosses  = 2;       // After X losses in a row - pause auto trade
input int    LossCooldownMinutes   = 30;      // Auto resume after X minutes (0 = manual reset only)
input int    PositionsPerSignal    = 5;       // Positions to open per signal (all same entry/SL/TP)
// NOTE: 5 positions x 0.01 lot = 0.05 total exposure per signal
input double DailyProfitLockPct   = 3.0;     // Lock profits at X% gain - stop trading
input bool   MoveToBreakeven       = true;    // Enable breakeven management
input double BreakevenConfirmPct   = 50.0;    // % of TP1 distance price must move before SL moves
// GUIDE: 50% = halfway to TP1 (recommended)
//        30% = more aggressive (moves SL sooner)
//        70% = very conservative (waits longer)

// -- DAY TRADE SETTINGS
input group "=== DAY TRADE (H4->H1->M15->M5) ==="
input double Day_SL_Pct       = 1.5;    // SL % of entry price
input double Day_TP1_Pct      = 3.8;    // TP1 % (fallback if no swing found)
input double Day_TP2_Pct      = 6.0;    // TP2 % (fallback if no swing found)

// -- SWING SETTINGS
input group "=== SWING (Daily->H4->H1->M15) ==="
input double Swing_SL_Pct     = 3.0;    // SL % of entry price
input double Swing_TP1_Pct    = 7.5;    // TP1 % (fallback if no swing found)
input double Swing_TP2_Pct    = 13.0;   // TP2 % (fallback if no swing found)

// -- SMC DETECTION SETTINGS
input group "=== SMC DETECTION ==="
input int    SwingLookback    = 20;      // Bars to look back for swing highs/lows
input int    OBLookback       = 10;      // Bars to look back for Order Block
input double LiqSweepPct      = 0.1;    // Min % spike for liquidity sweep
input int    BOSBars          = 3;       // Bars confirming BOS close
input double FVG_MinPct       = 0.05;   // Min % gap size for FVG
input int    CHoCH_Lookback   = 15;     // Bars to look for CHoCH

// -- 3-DRIVE SETTINGS
input group "=== 3-DRIVE DETECTION ==="
input int    Drive3_Lookback  = 40;     // Bars to look back for 3-Drive pattern
input double Drive3_Tolerance = 0.3;   // % tolerance for trendline touches inside OB
input int    Drive3_MinTouches = 3;    // Minimum touches to confirm 3-Drive (must be 3)

// -- QML SETTINGS
input group "=== QML (QUASIMODO LEVEL) ==="
input int    QML_Lookback     = 30;    // Bars to look back for QML pattern
input double QML_Tolerance    = 0.2;  // % tolerance for QML level match with OB
// QML pattern: Left Shoulder (LS) -> Head -> Right Shoulder (RS)
// RS must be LOWER than LS (bullish QML) or HIGHER than LS (bearish QML)
// Where QML intersects OB = kill zone = sniper entry

// -- SESSIONS (Forex/Gold/Indices: trade London/NY only, Crypto: 24/7)
input group "=== TRADING SESSIONS (GMT) ==="
input bool   TradeLondonSession  = true;  // London Session (07:00 - 16:00 GMT)
input bool   TradeNYSession      = true;  // New York Session (12:00 - 21:00 GMT)
input bool   TradeOverlapSession = true;  // London/NY Overlap (12:00 - 16:00 GMT) - highest liquidity
input int    LondonOpen          = 7;     // London open hour (GMT)
input int    LondonClose         = 16;    // London close hour (GMT)
input int    NYOpen              = 12;    // New York open hour (GMT)
input int    NYClose             = 21;    // New York close hour (GMT)
// NOTE: This forex version uses London/NY sessions for Forex/Gold/Indices, while Crypto trades 24/7.

// -- ALERTS
input group "=== ALERTS ==="
input bool   SoundAlert       = true;    // Play sound on signal
input bool   PushNotification = true;    // Send push notification to phone
input bool   EmailAlert       = false;   // Send email alert
input string AlertSound       = "alert.wav"; // Alert sound file

// -- MAGIC NUMBER
input int    MagicNumber      = 202500;  // Unique EA identifier

//+------------------------------------------------------------------+
//|  STRUCTURES                                                       |
//+------------------------------------------------------------------+
struct SMCSignal
{
   string   symbol;
   string   setup;
   string   tradeType;   // "Day", "Swing"
   int      direction;   // 1=BUY, -1=SELL
   double   entry;
   double   sl;
   double   tp1;
   double   tp2;
   double   rr;
   int      confidence;  // 0-100
   bool     isSniper;    // true = 90%+ = ENTER NOW at market price
   string   details;
   bool     hasLiq;
   bool     hasBOS;
   bool     hasOB;
   bool     hasFVG;
   bool     hasCHoCH;
   bool     hasInducement;
   bool     has3Drive;
};

struct OrderBlock
{
   double   top;
   double   bottom;
   int      type;   // 1=Bullish, -1=Bearish
   int      barIdx;
   bool     valid;
};

struct MarketStructure
{
   string   trend;     // "bullish", "bearish", "ranging"
   double   lastHH;
   double   lastHL;
   double   lastLH;
   double   lastLL;
   bool     valid;
};

//+------------------------------------------------------------------+
//|  GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
datetime lastBarTime   = 0;
double   startBalance  = 0;
int      signalCount   = 0;

// -- PERFORMANCE TRACKING
int      totalTrades   = 0;
int      winTrades     = 0;
int      lossTrades    = 0;
int      breakevenTrades = 0;
double   totalProfit   = 0;
double   totalLoss     = 0;
double   largestWin    = 0;
double   largestLoss   = 0;
double   peakEquity    = 0;
double   maxDrawdown   = 0;
string   lastSignalStr = "None";
datetime lastSignalTime = 0;

// -- PENDING CONFIRMATION
SMCSignal pendingSignal;
bool      hasPendingSignal = false;
datetime  pendingTime      = 0;

// -- DASHBOARD OBJECT NAMES
string    DB_PREFIX        = "SMC_DB_";
int       DB_CW            = 175;

// Smart trading rule trackers
int      dailyTradeCount       = 0;
int      consecutiveLosses     = 0;
bool     smartRulesBlocked     = false;
string   smartBlockReason      = "";
datetime lastTradeDay          = 0;
double   dayStartBalance       = 0;
datetime lossBlockedSince      = 0;

// Timeframe chains
ENUM_TIMEFRAMES day_bias_tf    = PERIOD_H4;
ENUM_TIMEFRAMES day_liq_tf     = PERIOD_H1;
ENUM_TIMEFRAMES day_bos_tf     = PERIOD_M15;
ENUM_TIMEFRAMES day_entry_tf   = PERIOD_M5;

ENUM_TIMEFRAMES swing_bias_tf  = PERIOD_D1;
ENUM_TIMEFRAMES swing_liq_tf   = PERIOD_H4;
ENUM_TIMEFRAMES swing_bos_tf   = PERIOD_H1;
ENUM_TIMEFRAMES swing_entry_tf = PERIOD_M15;

//+------------------------------------------------------------------+
//|  INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   
   startBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   peakEquity   = startBalance;
   
   // Load historical trade performance from this EA
   LoadTradeHistory();
   
   // Draw dashboard
   if(ShowDashboard) DrawDashboard();
   
   Print("+======================================+");
   Print("|     JOJOS SMC EA - INITIALIZED     |");
   Print("+======================================+");
   Print("|  Setup 1:    ", UseSetup1 ? "? ON " : "? OFF", "                    |");
   Print("|  Setup 2:    ", UseSetup2 ? "? ON " : "? OFF", "                    |");
   Print("|  Mode:       ", AlertOnly  ? "Alert Only  " : "Auto Trade  ", "          |");
   Print("|  Confirm:    ", ShowTradeConfirm ? "? ON " : "? OFF", "                   |");
   Print("|  Confidence: ", MinConfidence, "%                          |");
   Print("|  Risk:       ", RiskPercent, "% per trade               |");
   Print("+======================================+");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//|  LOAD HISTORICAL TRADE PERFORMANCE                                |
//+------------------------------------------------------------------+
void LoadTradeHistory()
{
   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;
      
      ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
      if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) continue;
      
      ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT) continue; // Only count closed trades
      
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                    + HistoryDealGetDouble(ticket, DEAL_SWAP)
                    + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      
      totalTrades++;
      if(profit > 0)       { winTrades++;       totalProfit += profit; if(profit > largestWin)  largestWin  = profit; }
      else if(profit < 0)  { lossTrades++;       totalLoss   += profit; if(profit < largestLoss) largestLoss = profit; }
      else                 { breakevenTrades++; }
   }
}

//+------------------------------------------------------------------+
//|  DRAW DASHBOARD ON CHART                                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|  DRAW DASHBOARD - HORIZONTAL (6 columns across bottom of chart)  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|  DRAW DASHBOARD - STYLE 1: CYBERPUNK DARK TECH                   |
//+------------------------------------------------------------------+
void DrawDashboard()
{
   ObjectsDeleteAll(0, DB_PREFIX);
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double profit   = equity - balance;
   double winRate  = totalTrades > 0 ? (double)winTrades / totalTrades * 100.0 : 0;
   double pf       = totalLoss < 0 ? totalProfit / MathAbs(totalLoss) : (totalProfit > 0 ? 999 : 0);
   double dailyPnL = balance - startBalance;
   if(equity > peakEquity) peakEquity = equity;
   double dd = peakEquity > 0 ? (peakEquity - equity) / peakEquity * 100.0 : 0;
   if(dd > maxDrawdown) maxDrawdown = dd;

   // Layout constants
   int DX = Dashboard_X;
   int DY = Dashboard_Y;
   int TH = 24;        // header height
   int DH = 200;       // total height
   int CW = 175;       // column width
   int TW = CW * 6;    // total width

   // Main background - deep dark
   DB_Rect("BG",    DX, DY, TW, DH,  C'8,11,22',  C'0,140,200', 1);
   // Header bar - dark blue with subtle glow
   DB_Rect("BGHDR", DX, DY, TW, TH,  C'10,20,50', C'0,180,255', 1);
   // Accent line under header
   DB_Rect("ACL",   DX, DY+TH, TW, 1, C'0,180,255', C'0,180,255', 0);

   // Column dividers - subtle cyan
   for(int c=1;c<6;c++)
      DB_Rect("DIV"+IntegerToString(c), DX+CW*c, DY+TH+1, 1, DH-TH-1, C'0,100,150', C'0,100,150', 0);

   // HEADER
   int ot = CountOpenTrades();
   color otC = ot >= MaxOpenTrades ? clrOrange : C'0,210,255';
   DB_Label("TTL",  DX+8,   DY+6,  "JOJOS SMC EA v1.0",       clrWhite, 9, true);
   DB_Label("SYM",  DX+180, DY+6,  _Symbol+" | "+TFToStr(Period()), C'0,180,255', 8, false);
   // Mode badge
   string modeStr = AlertOnly ? "ALERT ONLY" : ((ExecuteTrades || AutoExecute) ? "EXECUTE TRADES" : "CONFIRM Y/N");
   color  modeClr = AlertOnly ? clrGold : ((ExecuteTrades || AutoExecute) ? C'0,255,136' : C'0,210,255');
   DB_Label("MOD",  DX+330, DY+6,  modeStr, modeClr, 8, true);
   DB_Label("CNF",  DX+470, DY+6,  "MIN:"+IntegerToString(MinConfidence)+"%  POS:"+IntegerToString(PositionsPerSignal), C'0,160,200', 8, false);
   DB_Label("OPT",  DX+680, DY+6,  "TRADES:"+IntegerToString(ot)+"/"+IntegerToString(MaxOpenTrades), otC, 8, true);
   string rskStr = UseManualLot ? "LOT:"+DoubleToString(ManualLotSize,3) : "RISK:"+DoubleToString(RiskPercent,1)+"%";
   DB_Label("RSK",  DX+830, DY+6,  rskStr, C'0,160,200', 8, false);

   int c1=DX+8, c2=DX+CW+8, c3=DX+CW*2+8, c4=DX+CW*3+8, c5=DX+CW*4+8, c6=DX+CW*5+8;
   int y0 = DY+TH+7;
   color HDR = C'0,140,180';   // section header color - dim cyan
   color LBL = C'100,140,160'; // label color - muted
   color VAL = clrWhite;        // value color
   color GRN = C'0,220,120';   // green
   color RED = C'255,80,100';  // red
   color CYN = C'0,200,255';   // cyan

   // COL 1 - ACCOUNT
   DB_Label("C1T",c1,y0,"-- ACCOUNT ------",HDR,8,false); int cy=y0+13;
   DB_Label("BL",c1,cy,"Balance:",LBL,9,false); DB_Label("BV",c1+82,cy,"$"+DoubleToString(balance,2),VAL,9,true); cy+=13;
   DB_Label("EL",c1,cy,"Equity:", LBL,9,false); DB_Label("EV",c1+82,cy,"$"+DoubleToString(equity,2), VAL,9,true); cy+=13;
   color pC=profit>=0?GRN:RED;
   DB_Label("PL",c1,cy,"Open P&L:",LBL,9,false); DB_Label("PV",c1+82,cy,(profit>=0?"+":"")+DoubleToString(profit,2),pC,9,true); cy+=13;
   color dC=dailyPnL>=0?GRN:RED;
   DB_Label("DL",c1,cy,"Daily P&L:",LBL,9,false); DB_Label("DV",c1+82,cy,(dailyPnL>=0?"+":"")+DoubleToString(dailyPnL,2),dC,9,true); cy+=13;
   double dlp=startBalance>0?MathAbs(MathMin(dailyPnL,0))/startBalance*100.0:0;
   if(dlp>MaxDailyLossPct*0.7)
      DB_Label("DW",c1,cy,"[!] "+DoubleToString(dlp,1)+"%/"+DoubleToString(MaxDailyLossPct,0)+"%",dlp>=MaxDailyLossPct?RED:clrOrange,8,false);

   // COL 2 - PERFORMANCE
   DB_Label("C2T",c2,y0,"-- PERFORMANCE ---",HDR,8,false); cy=y0+13;
   DB_Label("TL",c2,cy,"Total:",  LBL,9,false); DB_Label("TV",c2+82,cy,IntegerToString(totalTrades),VAL,9,true); cy+=13;
   color wrC=winRate>=60?GRN:winRate>=45?clrGold:RED;
   DB_Label("WRL",c2,cy,"Win Rate:",LBL,9,false); DB_Label("WRV",c2+82,cy,DoubleToString(winRate,1)+"%",wrC,9,true); cy+=13;
   color pfC=pf>=2?GRN:pf>=1.5?clrGold:RED;
   DB_Label("PFL",c2,cy,"Prof.Fac.:",LBL,9,false); DB_Label("PFV",c2+82,cy,pf>=999?"inf":DoubleToString(pf,2),pfC,9,true); cy+=13;
   color ddC=dd<5?GRN:dd<10?clrGold:RED;
   DB_Label("DDL",c2,cy,"Max DD:",  LBL,9,false); DB_Label("DDV",c2+82,cy,DoubleToString(maxDrawdown,1)+"%",ddC,9,true); cy+=13;
   DB_Label("GWL",c2,cy,"Best:",    LBL,9,false); DB_Label("GWV",c2+82,cy,"+$"+DoubleToString(largestWin,2),GRN,9,true); cy+=13;
   DB_Label("GLL",c2,cy,"Worst:",   LBL,9,false); DB_Label("GLV",c2+82,cy,"$"+DoubleToString(largestLoss,2),RED,9,true);

   // COL 3 - WIN/LOSS + SMART RULES
   DB_Label("C3T",c3,y0,"-- WIN/LOSS ------",HDR,8,false); cy=y0+13;
   DB_Label("WL",c3,cy,"Wins:",    LBL,9,false); DB_Label("WV",c3+82,cy,IntegerToString(winTrades)+" ("+DoubleToString(winRate,1)+"%)",GRN,9,true); cy+=13;
   DB_Label("LL",c3,cy,"Losses:",  LBL,9,false); DB_Label("LV",c3+82,cy,IntegerToString(lossTrades),RED,9,true); cy+=13;
   DB_Label("BL2",c3,cy,"Breakeven:",LBL,9,false); DB_Label("BV2",c3+82,cy,IntegerToString(breakevenTrades),clrGold,9,true); cy+=13;
   // Win rate bar
   DB_Rect("WBG",c3,cy,160,4,C'15,30,50',C'15,30,50',0);
   int wbF=(int)(160.0*winRate/100.0);
   if(wbF>0) DB_Rect("WBF",c3,cy,wbF,4,winRate>=60?C'0,220,120':winRate>=45?C'220,170,0':C'220,60,60',winRate>=60?C'0,220,120':C'220,60,60',0);
   cy+=10;
   // Smart rules
   DB_Label("C3S",c3,cy,"-- SMART RULES ---",HDR,8,false); cy+=12;
   DB_Label("DTL",c3,cy,"Today:", LBL,9,false);
   DB_Label("DTV",c3+82,cy,IntegerToString(dailyTradeCount)+"/"+IntegerToString(MaxTradesPerDay),dailyTradeCount>=MaxTradesPerDay?clrOrange:GRN,9,true); cy+=13;
   DB_Label("CLL",c3,cy,"Streak:", LBL,9,false);
   DB_Label("CLV",c3+82,cy,IntegerToString(consecutiveLosses)+" losses",consecutiveLosses>=MaxConsecutiveLosses?RED:consecutiveLosses>0?clrOrange:GRN,9,true); cy+=13;
   DB_Label("PLK",c3,cy,"Profit Lock:", LBL,9,false);
   DB_Label("PLV",c3+82,cy,DoubleToString(DailyProfitLockPct,0)+"%",clrGold,9,true);

   // COL 4 - CONFLUENCE
   DB_Label("C4T",c4,y0,"-- CONFLUENCE ----",HDR,8,false); cy=y0+13;
   DB_Label("CF1",c4,   cy,(UseFVG?"[+]":"[ ]")+" FVG",       UseFVG?GRN:LBL,8,false);
   DB_Label("CF2",c4+86,cy,(UseQML?"[+]":"[ ]")+" QML",       UseQML?GRN:LBL,8,false); cy+=13;
   DB_Label("CF3",c4,   cy,(UseConfluence3D?"[+]":"[ ]")+" 3-Drive", UseConfluence3D?GRN:LBL,8,false);
   DB_Label("CF4",c4+86,cy,(UseCHoCH?"[+]":"[ ]")+" CHoCH",   UseCHoCH?GRN:LBL,8,false); cy+=13;
   DB_Label("CF5",c4,   cy,(UseInducement?"[+]":"[ ]")+" Induce", UseInducement?GRN:LBL,8,false);
   DB_Label("CF6",c4+86,cy,(UseBreakerBlock?"[+]":"[ ]")+" BB", UseBreakerBlock?GRN:LBL,8,false); cy+=16;
   DB_Label("SNT",c4,cy,"-- CONFIDENCE ----",HDR,8,false); cy+=12;
   DB_Label("SN1",c4,cy,IntegerToString(MinConfidence)+"-89%  Normal",LBL,8,false); cy+=12;
   DB_Label("SN2",c4,cy,"90%+    SNIPER ENTRY",clrGold,8,true); cy+=14;
   DB_Label("POS",c4,cy,"Positions/Signal: "+IntegerToString(PositionsPerSignal),CYN,8,true);

   // COL 5 - STATUS & SIGNAL
   DB_Label("C5T",c5,y0,"-- STATUS --------",HDR,8,false); cy=y0+13;
   // Scanning status
   bool isSessionActive = IsCrypto(_Symbol) || IsLondonSession() || IsNYSession();
   string scanStr; color scanC;
   if(smartRulesBlocked)          { scanStr="PAUSED";      scanC=clrOrange;    }
   else if(IsDailyLossExceeded()) { scanStr="DAILY LIMIT"; scanC=RED;          }
   else if(!isSessionActive)      { scanStr="OFF SESSION"; scanC=RED;          }
   else                           { scanStr="SCANNING..."; scanC=GRN;          }
   DB_Label("SCN",c5,cy,"Status:",LBL,9,false); DB_Label("SCNV",c5+72,cy,scanStr,scanC,9,true); cy+=13;
   DB_Label("DTL2",c5,cy,"Today:",LBL,9,false);
   DB_Label("DTV2",c5+72,cy,IntegerToString(dailyTradeCount)+"/"+IntegerToString(MaxTradesPerDay)+" trades",dailyTradeCount>=MaxTradesPerDay?clrOrange:VAL,8,true); cy+=13;
   if(consecutiveLosses>0){ DB_Label("CLL2",c5,cy,"Losses:",LBL,9,false); DB_Label("CLV2",c5+72,cy,IntegerToString(consecutiveLosses)+" in a row",consecutiveLosses>=MaxConsecutiveLosses?RED:clrOrange,8,true); cy+=13; }
   // Session
   bool isCryptoChart = IsCrypto(_Symbol);
   string sess  = isCryptoChart ? "24/7 CRYPTO" : GetCurrentSession();
   color  sessC = isCryptoChart ? GRN : (IsLondonSession()&&IsNYSession())?clrGold:(IsLondonSession()||IsNYSession())?GRN:RED;
   DB_Label("SESL",c5,cy,"Session:",LBL,9,false); DB_Label("SESV",c5+72,cy,sess,sessC,8,true); cy+=13;
   DB_Label("MCL",c5,cy,"Min Conf:",LBL,9,false); DB_Label("MCV",c5+72,cy,IntegerToString(MinConfidence)+"%",CYN,9,true); cy+=13;
   // Last signal
   DB_Label("C5S",c5,cy,"-- LAST SIGNAL ---",HDR,8,false); cy+=12;
   DB_Label("SLV",c5,cy,lastSignalStr,clrYellow,8,false); cy+=12;
   if(lastSignalTime>0) DB_Label("SLT",c5,cy,TimeAgoStr(lastSignalTime),LBL,8,false);
   if(smartRulesBlocked && smartBlockReason!="") { DB_Label("SBR",c5,cy+12,smartBlockReason,clrOrange,7,false); }

   // COL 6 - RECENT TRADES
   DB_Label("C6T",c6,y0,"-- RECENT TRADES -",HDR,8,false); cy=y0+13;
   HistorySelect(0,TimeCurrent());
   int dc=0;
   for(int d=HistoryDealsTotal()-1;d>=0&&dc<8;d--)
   {
      ulong dt=HistoryDealGetTicket(d);
      if(HistoryDealGetInteger(dt,DEAL_MAGIC)!=MagicNumber) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(dt,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      double dp=HistoryDealGetDouble(dt,DEAL_PROFIT)+HistoryDealGetDouble(dt,DEAL_SWAP)+HistoryDealGetDouble(dt,DEAL_COMMISSION);
      string ds=HistoryDealGetString(dt,DEAL_SYMBOL);
      string dd2=HistoryDealGetInteger(dt,DEAL_TYPE)==DEAL_TYPE_BUY?"BUY":"SEL";
      string ic=dp>0.01?"[+]":dp<-0.01?"[-]":"[=]";
      color dc2=dp>0.01?GRN:dp<-0.01?RED:clrGold;
      // Colored left border for win/loss
      DB_Rect("THB"+IntegerToString(dc),c6,cy,2,11,dc2,dc2,0);
      DB_Label("TH"+IntegerToString(dc),c6+5,cy,ic+" "+dd2+" "+ds+"  "+(dp>=0?"+":"")+DoubleToString(dp,2),dc2,8,false);
      cy+=12; dc++;
   }
   if(dc==0) DB_Label("TH0",c6,cy,"No closed trades yet",LBL,8,false);

   // Footer
   DB_Label("FOOT",DX+8,DY+DH-11,"Jojos SMC EA v1.0 - ELITE SMC System  |  Min Confidence: "+IntegerToString(MinConfidence)+"%  |  Sniper: 90%+  |  Positions/Signal: "+IntegerToString(PositionsPerSignal),C'0,60,100',7,false);

   if(hasPendingSignal&&ShowTradeConfirm) DrawConfirmBox();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//|  CONFIRMATION BOX - CYBERPUNK STYLE                              |
//+------------------------------------------------------------------+
void DrawConfirmBox()
{
   int cw=285, cx=Dashboard_X+(DB_CW*6)/2-cw/2, cy=Dashboard_Y-310;
   if(cy<10) cy=10;
   string arrow=pendingSignal.direction==1?"[BUY]":"[SELL]";
   color aC=pendingSignal.direction==1?C'0,220,120':C'255,80,100';
   string typeLabel="",typeTF="";
   if(pendingSignal.tradeType=="Day")        {typeLabel="[D] DAY TRADE";   typeTF="H4 - M5";}
   else if(pendingSignal.tradeType=="Swing") {typeLabel="[S] SWING TRADE"; typeTF="Daily - M15";}
   int tl=ConfirmTimeout>0?ConfirmTimeout-(int)(TimeCurrent()-pendingTime):-1;
   string ts=tl>0?" ("+IntegerToString(tl)+"s)":"";

   DB_Rect("CB_BG",cx,cy,cw,285,C'5,8,20',C'0,180,255',2);
   DB_Rect("CB_HD",cx,cy,cw,32, C'8,20,55',C'0,180,255',0);
   DB_Rect("CB_ACL",cx,cy+32,cw,1,C'0,180,255',C'0,180,255',0);
   DB_Label("CB_TI",cx+10,cy+9,pendingSignal.isSniper?"[SNIPER] SNIPER ENTRY"+ts:"[!] TRADE SIGNAL"+ts,
            pendingSignal.isSniper?clrGold:clrWhite,10,true);
   int y2=cy+40;
   DB_Label("CB_DR",cx+10,y2,arrow+" "+pendingSignal.symbol,aC,14,true); y2+=20;
   DB_Label("CB_TY",cx+10,y2,typeLabel,clrGold,10,true); y2+=14;
   DB_Label("CB_TF",cx+10,y2,"TF: "+typeTF,C'0,160,200',8,false); y2+=12;
   DB_Label("CB_ST",cx+10,y2,pendingSignal.setup,C'0,180,255',8,false); y2+=12;
   color cC=pendingSignal.confidence>=90?clrGold:pendingSignal.confidence>=80?C'0,220,120':C'0,200,255';
   DB_Label("CB_CF",cx+10,y2,"Confidence: "+IntegerToString(pendingSignal.confidence)+"%"+(pendingSignal.isSniper?" [SNIPER]":""),cC,9,true); y2+=16;
   DB_Label("CB_EL",cx+10,y2,"Entry:",    C'0,140,180',9,false); DB_Label("CB_EV",cx+95,y2,DoubleToString(pendingSignal.entry,_Digits),clrWhite,9,true);      y2+=13;
   DB_Label("CB_SLL",cx+10,y2,"Stop Loss:",C'0,140,180',9,false); DB_Label("CB_SV",cx+95,y2,DoubleToString(pendingSignal.sl,_Digits),   C'255,80,100',9,true); y2+=13;
   DB_Label("CB_T1L",cx+10,y2,"TP1:",     C'0,140,180',9,false); DB_Label("CB_T1V",cx+95,y2,DoubleToString(pendingSignal.tp1,_Digits),  C'0,220,120',9,true);  y2+=13;
   DB_Label("CB_T2L",cx+10,y2,"TP2:",     C'0,140,180',9,false); DB_Label("CB_T2V",cx+95,y2,DoubleToString(pendingSignal.tp2,_Digits),  C'0,220,120',9,true);  y2+=13;
   DB_Label("CB_RL", cx+10,y2,"R:R:",     C'0,140,180',9,false); DB_Label("CB_RV", cx+95,y2,"1:"+DoubleToString(pendingSignal.rr,1),    C'0,200,255',9,true);  y2+=16;
   DB_Label("CB_PS", cx+10,y2,"Positions: "+IntegerToString(PositionsPerSignal)+" x "+DoubleToString(ManualLotSize,3)+" lot", C'0,180,255',8,true); y2+=14;
   DB_Rect("CB_YES",cx+10,   y2,132,26,C'0,80,30', C'0,180,80',  0);
   DB_Rect("CB_NO", cx+148,  y2,132,26,C'80,10,10',C'180,40,40', 0);
   DB_Label("CB_YL",cx+20,   y2+7,"[Y] YES - TRADE",clrWhite,9,true);
   DB_Label("CB_NL",cx+158,  y2+7,"[N] SKIP",       clrWhite,9,true); y2+=30;
   DB_Label("CB_HT",cx+10,   y2,"Press Y to confirm  -  N to skip",C'0,100,140',7,false);
}

void DB_Rect(string name, int x, int y, int w, int h, color bg, color border, int bw)
{
   string obj = DB_PREFIX + name;
   if(ObjectFind(0, obj) < 0) ObjectCreate(0, obj, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, obj, OBJPROP_XSIZE,      w);
   ObjectSetInteger(0, obj, OBJPROP_YSIZE,      h);
   ObjectSetInteger(0, obj, OBJPROP_BGCOLOR,    bg);
   ObjectSetInteger(0, obj, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, obj, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, obj, OBJPROP_WIDTH,      bw);
   ObjectSetInteger(0, obj, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj, OBJPROP_BACK,       true);
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//|  DASHBOARD HELPER: CREATE LABEL                                   |
//+------------------------------------------------------------------+
void DB_Label(string name, int x, int y, string text, color clr, int fontSize, bool bold)
{
   string obj = DB_PREFIX + name;
   if(ObjectFind(0, obj) < 0) ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0,  obj, OBJPROP_TEXT,      text);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, obj, OBJPROP_FONTSIZE,  fontSize);
   ObjectSetString(0,  obj, OBJPROP_FONT,      bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, obj, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, obj, OBJPROP_BACK,      false);
}

//+------------------------------------------------------------------+
//|  TIME AGO STRING                                                   |
//+------------------------------------------------------------------+
string TimeAgoStr(datetime t)
{
   int secs = (int)(TimeCurrent() - t);
   if(secs < 60)   return IntegerToString(secs) + "s ago";
   if(secs < 3600) return IntegerToString(secs/60) + "m ago";
   return IntegerToString(secs/3600) + "h ago";
}

//+------------------------------------------------------------------+
//|  KEYBOARD HANDLER - Y = confirm trade, N = skip                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_KEYDOWN)
   {
      if(hasPendingSignal)
      {
         if(lparam == 89) // Y key
         {
            Print("[OK] Trade confirmed by user: ", pendingSignal.symbol);
            ExecuteSignal(pendingSignal);
            hasPendingSignal = false;
            ObjectsDeleteAll(0, DB_PREFIX + "CB_");
            if(ShowDashboard) DrawDashboard();
         }
         else if(lparam == 78) // N key
         {
            Print("[X] Trade skipped by user: ", pendingSignal.symbol);
            hasPendingSignal = false;
            ObjectsDeleteAll(0, DB_PREFIX + "CB_");
            if(ShowDashboard) DrawDashboard();
         }
      }
   }
}

//+------------------------------------------------------------------+
//|  EXECUTE SIGNAL (actual order placement)                          |
//+------------------------------------------------------------------+
void ExecuteSignal(SMCSignal &sig)
{
   // Direction-only guard per symbol
   int existingPositions = CountOpenTradesForSymbol(sig.symbol);
   if(existingPositions >= PositionsPerSignal)
   {
      Print("[!] Position guard: ", existingPositions, " positions already open for ", sig.symbol, " - skipping");
      return;
   }

   double lotSize = CalculateLotSize(sig.symbol, sig.entry, sig.sl);
   if(lotSize <= 0) { Print("[X] Invalid lot size"); return; }

   int    digits  = (int)SymbolInfoInteger(sig.symbol, SYMBOL_DIGITS);
   double ask     = SymbolInfoDouble(sig.symbol, SYMBOL_ASK);
   double bid     = SymbolInfoDouble(sig.symbol, SYMBOL_BID);
   double useEntry = (sig.direction == 1 ? ask : bid);
   double slDist   = MathAbs(sig.entry - sig.sl);
   double useSL    = sig.sl;
   double useTP    = sig.tp1;

   if(sig.direction == 1)
   {
      if(useSL >= useEntry)
         useSL = NormalizeDouble(useEntry - slDist, digits);
      if(useTP <= useEntry)
      {
         useTP = GetSwingTP(sig.symbol, biasTFForSniper(sig.tradeType), 1, useEntry, 1);
         if(useTP == 0 || useTP <= useEntry)
            useTP = NormalizeDouble(useEntry + slDist * 2.5, digits);
      }
   }
   else
   {
      if(useSL <= useEntry)
         useSL = NormalizeDouble(useEntry + slDist, digits);
      if(useTP >= useEntry || useTP == 0)
      {
         useTP = GetSwingTP(sig.symbol, biasTFForSniper(sig.tradeType), -1, useEntry, 1);
         if(useTP == 0 || useTP >= useEntry)
            useTP = NormalizeDouble(useEntry - slDist * 2.5, digits);
      }
   }

   int placed = 0;
   for(int p = 0; p < PositionsPerSignal; p++)
   {
      bool result = false;
      string comment = "ELITE SMC SYSTEM [" + IntegerToString(p+1) + "/" + IntegerToString(PositionsPerSignal) + "]";

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
      Print("[OK] ", placed, "/", PositionsPerSignal, " positions executed: ",
            sig.direction==1?"BUY":"SELL", " ", sig.symbol,
            " @ market SL:", useSL, " TP:", useTP, " Lot:", lotSize);
   }
   else Print("[X] All positions failed for ", sig.symbol);
}

//+------------------------------------------------------------------+
//|  UPDATE TRADE STATS WHEN TRADE CLOSES                             |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   
   ulong ticket = trans.deal;
   if(!HistoryDealSelect(ticket)) return;
   if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) return;
   
   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT) return;
   
   double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                 + HistoryDealGetDouble(ticket, DEAL_SWAP)
                 + HistoryDealGetDouble(ticket, DEAL_COMMISSION);

   totalTrades++;
   if(profit > 0.01)
   {
      winTrades++; totalProfit += profit;
      if(profit > largestWin) largestWin = profit;
      consecutiveLosses = 0; // reset streak on win
   }
   else if(profit < -0.01)
   {
      lossTrades++; totalLoss += profit;
      if(profit < largestLoss) largestLoss = profit;
      consecutiveLosses++;
      if(consecutiveLosses >= MaxConsecutiveLosses)
      {
         smartRulesBlocked = true;
         lossBlockedSince  = TimeCurrent();
         string cooldownMsg = LossCooldownMinutes > 0
            ? "Auto resumes in " + IntegerToString(LossCooldownMinutes) + " minutes."
            : "Manual reset required.";
         smartBlockReason = "[X] " + IntegerToString(consecutiveLosses) + " losses in a row - " + cooldownMsg;
         if(PushNotification) SendNotification("[!] JOJOS SMC - " + IntegerToString(consecutiveLosses) + " losses in a row!\n" + cooldownMsg + "\nSignals continue.");
         Print("[SMART] ", smartBlockReason);
      }
   }
   else { breakevenTrades++; }

   string sym     = HistoryDealGetString(ticket, DEAL_SYMBOL);
   string result2 = profit > 0 ? "WIN [OK] +" : (profit < 0 ? "LOSS [X] " : "BE [-] ");
   lastSignalStr  = result2 + DoubleToString(MathAbs(profit), 2) + " | " + sym;
   lastSignalTime = TimeCurrent();

   if(ShowDashboard) DrawDashboard();
   
   Print("Trade closed: ", result2, "$", DoubleToString(profit, 2),
         " | Wins:", winTrades, " Losses:", lossTrades,
         " | Win Rate:", DoubleToString(totalTrades > 0 ? (double)winTrades/totalTrades*100 : 0, 1), "%");
}

//+------------------------------------------------------------------+
//|  MAIN TICK FUNCTION                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Refresh dashboard every tick for live P&L
   if(ShowDashboard) DrawDashboard();
   
   // Handle confirmation timeout
   if(hasPendingSignal && ShowTradeConfirm && ConfirmTimeout > 0)
   {
      if((int)(TimeCurrent() - pendingTime) >= ConfirmTimeout)
      {
         Print("[TIME] Confirmation timed out for: ", pendingSignal.symbol, " - signal skipped");
         hasPendingSignal = false;
         ObjectsDeleteAll(0, DB_PREFIX + "CB_");
      }
   }
   
   // Only run signal detection on new bar (M5 pace)
   // New bar check (M1 pace) ? faster detection, max 1 min delay instead of 5
   datetime currentBar = iTime(_Symbol, PERIOD_M1, 0);
   if(currentBar == lastBarTime) return;
   lastBarTime = currentBar;

   // Signal cooldown ? minimum 60 seconds between signals on same symbol
   if(lastSignalTime > 0 && TimeCurrent() - lastSignalTime < 900) return; // 15 min cooldown

   // Daily loss check - stop trading but KEEP sending alerts
   bool dailyLimitHit = IsDailyLossExceeded();

   // Max trades check - still ALERT even when full, just don't place orders
   bool tradingFull = dailyLimitHit || (CountOpenTrades() >= MaxOpenTrades);

   // Don't scan if already waiting for confirmation
   if(hasPendingSignal) return;

   // Manage existing trades (breakeven etc)
   if(!dailyLimitHit) ManageOpenTrades();

   // Always scan and alert - tradingFull flag prevents order placement
   ScanForSignals(_Symbol, tradingFull);
}

//+------------------------------------------------------------------+
//|  SESSION DETECTION                                                |
//+------------------------------------------------------------------+

// Returns true if the symbol is a crypto pair
bool IsCrypto(string symbol)
{
   string s = symbol;
   StringToUpper(s);
   return (StringFind(s,"BTC")>=0 || StringFind(s,"ETH")>=0 ||
           StringFind(s,"XRP")>=0 || StringFind(s,"LTC")>=0 ||
           StringFind(s,"BCH")>=0 || StringFind(s,"ADA")>=0 ||
           StringFind(s,"DOT")>=0 || StringFind(s,"SOL")>=0);
}

// Returns true if current GMT time is inside London Session
bool IsLondonSession()
{
   datetime gmtTime  = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(gmtTime, dt);
   int hour = dt.hour;
   return (hour >= LondonOpen && hour < LondonClose);
}

// Returns true if current GMT time is inside NY Session
bool IsNYSession()
{
   datetime gmtTime  = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(gmtTime, dt);
   int hour = dt.hour;
   return (hour >= NYOpen && hour < NYClose);
}

// Returns true if inside the London/NY overlap (best liquidity)
bool IsOverlapSession()
{
   return (IsLondonSession() && IsNYSession());
}

// Returns true if the EA is allowed to trade this symbol right now
// Crypto = always yes. Swing = always yes. Forex/Gold/Indices = session check.
bool IsSessionAllowed(string symbol, string tradeType)
{
   // Crypto trades 24/7. Forex/Gold/Indices use London/NY session filters.
   if(IsCrypto(symbol)) return true;

   bool inLondon  = IsLondonSession();
   bool inNY      = IsNYSession();
   bool inOverlap = inLondon && inNY;

   if(TradeOverlapSession && inOverlap) return true;
   if(TradeLondonSession && inLondon && !inNY) return true;
   if(TradeNYSession && inNY && !inLondon) return true;

   return false;
}

// Returns a string describing the current session for dashboard
string GetCurrentSession()
{
   bool inLondon = IsLondonSession();
   bool inNY     = IsNYSession();
   if(inLondon && inNY) return "London/NY Overlap [BEST]";
   if(inLondon)         return "London Session";
   if(inNY)             return "New York Session";
   return "Off Session";
}

//+------------------------------------------------------------------+
//|  SCAN FOR SMC SIGNALS                                             |
//+------------------------------------------------------------------+
void ScanForSignals(string symbol, bool tradingFull = false)
{
   SMCSignal sig;

   // -- DAY TRADE (H4->H1->M15->M5) - Session check applies
   if(EnableDayTrade && IsSessionAllowed(symbol, "Day"))
   {
      if(UseSetup1 && DetectSetup1(symbol, "Day", sig))
         if(ValidateSignal(sig)) { ProcessSignal(sig, tradingFull); return; }
      if(UseSetup2 && DetectSetup2(symbol, "Day", sig))
         if(ValidateSignal(sig)) { ProcessSignal(sig, tradingFull); return; }
   }

   // -- SWING (Daily->H4->H1->M15) - NO session filter
   if(EnableSwing && IsSessionAllowed(symbol, "Swing"))
   {
      if(UseSetup1 && DetectSetup1(symbol, "Swing", sig))
         if(ValidateSignal(sig)) { ProcessSignal(sig, tradingFull); return; }
      if(UseSetup2 && DetectSetup2(symbol, "Swing", sig))
         if(ValidateSignal(sig)) { ProcessSignal(sig, tradingFull); return; }
   }

   // -- CONTINUATION ? FVG/OB pullback on existing open trade
   if(EnableContinuation)
   {
      string types[2] = {"Day","Swing"};
      for(int t=0;t<2;t++)
      {
         if(types[t]=="Day"   && !EnableDayTrade) continue;
         if(types[t]=="Swing" && !EnableSwing)    continue;
         if(DetectContinuation(symbol, types[t], sig))
            if(ValidateSignal(sig)) { ProcessSignal(sig, tradingFull); return; }
      }
   }
}

//+------------------------------------------------------------------+
//|  SETUP 1 DETECTION: Stop Hunt + BOS + Return to OB               |
//+------------------------------------------------------------------+
bool DetectSetup1(string symbol, string tradeType, SMCSignal &sig)
{
   // Get timeframes for this trade type
   ENUM_TIMEFRAMES biasTF, liqTF, bosTF, entryTF;
   GetTimeframes(tradeType, biasTF, liqTF, bosTF, entryTF);
   
   // -- STEP 1: Confirm HTF market structure bias
   MarketStructure ms = GetMarketStructure(symbol, biasTF);
   if(!ms.valid || ms.trend == "ranging") return false;
   
   // -- STEP 2: Detect liquidity sweep (Stop Hunt) on liqTF
   bool sslSwept = false, bslSwept = false;
   double sweepLevel = 0;
   if(!DetectLiquiditySweep(symbol, liqTF, sslSwept, bslSwept, sweepLevel)) return false;
   
   // Direction must match HTF bias
   if(ms.trend == "bullish" && !sslSwept) return false;  // Need SSL sweep for BUY
   if(ms.trend == "bearish" && !bslSwept) return false;  // Need BSL sweep for SELL
   
   int direction = (sslSwept && ms.trend == "bullish") ? 1 : -1;
   
   // -- STEP 3: Confirm BOS on bosTF
   bool bosConfirmed = DetectBOS(symbol, bosTF, direction);
   if(!bosConfirmed) return false;
   
   // -- STEP 4: Find Order Block on entryTF
   OrderBlock ob;
   if(!FindOrderBlock(symbol, entryTF, direction, ob)) return false;
   
   // -- STEP 5: Check if price is returning to OB (RTO)
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(!IsPriceNearOB(currentPrice, ob, direction)) return false;
   
   // -- STEP 6: Check confluence (all live chart detections)
   bool hasFVG        = UseFVG          ? DetectFVG(symbol, entryTF, direction) : false;
   bool hasCHoCH      = UseCHoCH        ? DetectCHoCH(symbol, bosTF, direction) : false;
   bool hasInducement = UseInducement   ? DetectInducement(symbol, entryTF, direction) : false;
   bool has3Drive     = UseConfluence3D ? Detect3Drive(symbol, entryTF, direction, ob) : false;
   
   // QML - Quasimodo Level intersecting OB = kill zone
   double qmlLevel = 0;
   bool   hasQML   = UseQML ? DetectQML(symbol, entryTF, direction, ob, qmlLevel) : false;
   
   // Breaker Block - failed OB now flipped role
   OrderBlock breakerOB;
   bool hasBB = UseBreakerBlock ? DetectBreakerBlock(symbol, entryTF, direction, breakerOB) : false;
   
   // If QML detected - use QML level as entry (more precise = sniper entry)
   double entry;
   if(hasQML && qmlLevel > 0)
      entry = qmlLevel; // Enter exactly at QML inside OB
   else if(direction == 1)
      entry = ob.top   + _Point * 2;
   else
      entry = ob.bottom - _Point * 2;
   double sl    = (direction == 1) ? ob.bottom - _Point * 5 : ob.top + _Point * 5;
   double slDist = MathAbs(entry - sl);

   // Reject noise OBs with unrealistically tiny SL
   if(slDist < entry * 0.0005) return false;

   // TP = Previous swing HIGH (BUY) or swing LOW (SELL) per Phineas book
   double tp1 = GetSwingTP(symbol, getTpTF(tradeType), direction, entry, 1);
   double tp2 = GetSwingTP(symbol, getTpTF(tradeType), direction, entry, 2);
   if(tp1 == 0 || (direction==1 && tp1 <= entry) || (direction==-1 && tp1 >= entry))
      tp1 = (direction == 1) ? entry + slDist * 2.5 : entry - slDist * 2.5;
   if(tp2 == 0 || (direction==1 && tp2 <= tp1) || (direction==-1 && tp2 >= tp1))
      tp2 = (direction == 1) ? entry + slDist * 4.0 : entry - slDist * 4.0;

   double rr = MathAbs(tp1 - entry) / MathAbs(entry - sl);
   if(rr < MinRR || rr > 20.0) return false;
   
   // -- CONFIDENCE SCORE (0-100)
   int confidence = 50; // Base: structure + liq sweep + BOS + OB confirmed
   if(hasFVG)        confidence += 8;
   if(hasCHoCH)      confidence += 8;
   if(hasInducement) confidence += 6;
   if(has3Drive)     confidence += 12; // Strong - 3rd trendline touch inside OB
   if(hasQML)        confidence += 15; // Strongest - QML+OB = kill zone
   if(hasBB)         confidence += 7;
   confidence = MathMin(confidence, 100);
   if(confidence < MinConfidence) return false;
   
   // -- SNIPER: 90%+ confidence = ENTER NOW at market price
   bool isSniper = (confidence >= 90);
   if(isSniper)
   {
      // Override entry to current market price - enter immediately
      entry = SymbolInfoDouble(symbol, direction==1 ? SYMBOL_ASK : SYMBOL_BID);
   }
   
   // -- BUILD SIGNAL DETAILS
   string entryType = isSniper ? "[SNIPER] SNIPER - ENTER NOW (90%+)" 
                    : (hasQML || hasCHoCH) ? "CONFIRMATION ENTRY" : "RISK ENTRY";
   string details = "------------------------------\n";
   details += "SETUP 1 - Stop Hunt + BOS + RTO\n";
   details += tradeType + " | " + symbol + " | " + entryType + "\n";
   details += "------------------------------\n";
   details += "BIAS:    " + TFToStr(biasTF)  + " (market structure)\n";
   details += "HUNT:    " + TFToStr(liqTF)   + " (stop hunt / liquidity)\n";
   details += "BOS:     " + TFToStr(bosTF)   + " (break of structure)\n";
   details += "TRIGGER: " + TFToStr(entryTF) + " (OB + entry + confluence)\n";
   details += "TP REF:  " + TFToStr(getTpTF(tradeType)) + " (swing high/low target)\n";
   details += "------------------------------\n";
   details += "[OK] " + (sslSwept ? "SSL Swept" : "BSL Swept") + " on " + TFToStr(liqTF) + " (Stop Hunt)\n";
   details += "[OK] BOS confirmed on " + TFToStr(bosTF) + "\n";
   details += "[OK] " + (direction==1 ? "Bullish" : "Bearish") + " OB on " + TFToStr(entryTF) + " << ENTRY ZONE\n";
   if(hasFVG)        details += "[OK] FVG/Imbalance near OB on " + TFToStr(entryTF) + "\n";
   if(hasInducement) details += "[OK] Inducement trap before OB\n";
   if(hasCHoCH)      details += "[OK] CHoCH confirmed on " + TFToStr(entryTF) + "\n";
   if(hasBB)         details += "[OK] Breaker Block on " + TFToStr(entryTF) + "\n";
   if(has3Drive)     details += "[OK] 3-DRIVE: 3rd touch inside OB on " + TFToStr(entryTF) + "\n";
   if(hasQML)        details += "[OK] QML KILL ZONE at " + DoubleToString(qmlLevel, _Digits) + " on " + TFToStr(entryTF) + "\n";
   if(isSniper)      details += "[SNIPER] SNIPER ENTRY - 90%+ confidence - OPEN TRADE NOW!\n";
   details += "------------------------------\n";
   details += "R:R = 1:" + DoubleToString(MathAbs(tp1-entry)/MathAbs(entry-sl), 1);
   
   // -- FILL SIGNAL
   sig.symbol        = symbol;
   sig.setup         = "Setup 1 - SH+BOS+RTO";
   sig.tradeType     = tradeType;
   sig.direction     = direction;
   sig.entry         = NormalizeDouble(entry, _Digits);
   sig.sl            = NormalizeDouble(sl, _Digits);
   sig.tp1           = NormalizeDouble(tp1, _Digits);
   sig.tp2           = NormalizeDouble(tp2, _Digits);
   sig.rr            = MathAbs(tp1-entry)/MathAbs(entry-sl);
   sig.confidence    = confidence;
   sig.isSniper      = isSniper;
   sig.details       = details;
   sig.hasLiq        = true;
   sig.hasBOS        = true;
   sig.hasOB         = true;
   sig.hasFVG        = hasFVG;
   sig.hasCHoCH      = hasCHoCH;
   sig.hasInducement = hasInducement;
   sig.has3Drive     = has3Drive;
   
   return true;
}

//+------------------------------------------------------------------+
//|  SETUP 2 DETECTION: SMS + BMS + Return to OB                     |
//+------------------------------------------------------------------+
bool DetectSetup2(string symbol, string tradeType, SMCSignal &sig)
{
   ENUM_TIMEFRAMES biasTF, liqTF, bosTF, entryTF;
   GetTimeframes(tradeType, biasTF, liqTF, bosTF, entryTF);
   
   // -- STEP 1: HTF structure
   MarketStructure ms = GetMarketStructure(symbol, biasTF);
   if(!ms.valid) return false;
   
   // -- STEP 2: SMS - price FAILS to make new HH or LL
   int smsDirection = 0;
   string smsDetail = "";
   if(!DetectSMS(symbol, liqTF, smsDirection, smsDetail)) return false;
   
   // -- STEP 3: BMS - Break of Market Structure
   if(!DetectBOS(symbol, bosTF, smsDirection)) return false;
   
   // -- STEP 4: Find Order Block
   OrderBlock ob;
   if(!FindOrderBlock(symbol, entryTF, smsDirection, ob)) return false;
   
   // -- STEP 5: Price returning to OB
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(!IsPriceNearOB(currentPrice, ob, smsDirection)) return false;
   
   // -- STEP 6: Confluence
   bool hasFVG        = UseFVG          ? DetectFVG(symbol, entryTF, smsDirection) : false;
   bool hasCHoCH      = UseCHoCH        ? DetectCHoCH(symbol, bosTF, smsDirection) : false;
   bool hasInducement = UseInducement   ? DetectInducement(symbol, entryTF, smsDirection) : false;
   bool has3Drive     = UseConfluence3D ? Detect3Drive(symbol, entryTF, smsDirection, ob) : false;
   double qmlLevel2   = 0;
   bool   hasQML2     = UseQML ? DetectQML(symbol, entryTF, smsDirection, ob, qmlLevel2) : false;
   OrderBlock breakerOB2;
   bool hasBB2 = UseBreakerBlock ? DetectBreakerBlock(symbol, entryTF, smsDirection, breakerOB2) : false;
   
   // Use QML level as entry if detected
   double entry2;
   if(hasQML2 && qmlLevel2 > 0)
      entry2 = qmlLevel2;
   else if(smsDirection == 1)
      entry2 = ob.top   + _Point * 2;
   else
      entry2 = ob.bottom - _Point * 2;
   
   // -- CALCULATE LEVELS
   double sl     = (smsDirection == 1) ? ob.bottom - _Point * 5 : ob.top + _Point * 5;
   double slDist = MathAbs(entry2 - sl);

   // Reject noise OBs with unrealistically tiny SL
   if(slDist < entry2 * 0.0005) return false;

   // TP = Previous swing HIGH (BUY) or swing LOW (SELL) per Phineas book
   double tp1 = GetSwingTP(symbol, getTpTF(tradeType), smsDirection, entry2, 1);
   double tp2 = GetSwingTP(symbol, getTpTF(tradeType), smsDirection, entry2, 2);
   if(tp1 == 0 || (smsDirection==1 && tp1 <= entry2) || (smsDirection==-1 && tp1 >= entry2))
      tp1 = (smsDirection == 1) ? entry2 + slDist * 2.5 : entry2 - slDist * 2.5;
   if(tp2 == 0 || (smsDirection==1 && tp2 <= tp1) || (smsDirection==-1 && tp2 >= tp1))
      tp2 = (smsDirection == 1) ? entry2 + slDist * 4.0 : entry2 - slDist * 4.0;

   double rr = MathAbs(tp1 - entry2) / MathAbs(entry2 - sl);
   if(rr < MinRR || rr > 20.0) return false;
   
   // -- CONFIDENCE
   int confidence = 45;
   if(hasFVG)        confidence += 8;
   if(hasCHoCH)      confidence += 10;
   if(hasInducement) confidence += 6;
   if(has3Drive)     confidence += 12;
   if(hasQML2)       confidence += 15;
   if(hasBB2)        confidence += 7;
   confidence = MathMin(confidence, 100);
   if(confidence < MinConfidence) return false;
   
   // -- SNIPER: 90%+ = ENTER NOW
   bool isSniper2 = (confidence >= 90);
   if(isSniper2)
      entry2 = SymbolInfoDouble(symbol, smsDirection==1 ? SYMBOL_ASK : SYMBOL_BID);
   
   // -- DETAILS
   string entryType2 = isSniper2 ? "[SNIPER] SNIPER - ENTER NOW (90%+)"
                     : (hasQML2 || hasCHoCH) ? "CONFIRMATION ENTRY" : "RISK ENTRY";
   string details = "------------------------------\n";
   details += "SETUP 2 - SMS + BMS + RTO\n";
   details += tradeType + " | " + symbol + " | " + entryType2 + "\n";
   details += "------------------------------\n";
   details += "BIAS:    " + TFToStr(biasTF)  + " (market structure)\n";
   details += "SMS:     " + TFToStr(liqTF)   + " (shift of market structure)\n";
   details += "BMS:     " + TFToStr(bosTF)   + " (break of market structure)\n";
   details += "TRIGGER: " + TFToStr(entryTF) + " (OB + entry + confluence)\n";
   details += "TP REF:  " + TFToStr(getTpTF(tradeType)) + " (swing high/low target)\n";
   details += "------------------------------\n";
   details += "[OK] " + smsDetail + "\n";
   details += "[OK] BMS on " + TFToStr(bosTF) + "\n";
   details += "[OK] " + (smsDirection==1?"Bullish":"Bearish") + " OB on " + TFToStr(entryTF) + " << ENTRY ZONE\n";
   if(hasFVG)        details += "[OK] FVG/Imbalance near OB on " + TFToStr(entryTF) + "\n";
   if(hasInducement) details += "[OK] Inducement trap before OB\n";
   if(hasCHoCH)      details += "[OK] CHoCH confirmed on " + TFToStr(entryTF) + "\n";
   if(hasBB2)        details += "[OK] Breaker Block on " + TFToStr(entryTF) + "\n";
   if(has3Drive)     details += "[OK] 3-DRIVE: 3rd touch inside OB on " + TFToStr(entryTF) + "\n";
   if(hasQML2)       details += "[OK] QML KILL ZONE at " + DoubleToString(qmlLevel2,_Digits) + " on " + TFToStr(entryTF) + "\n";
   if(isSniper2)     details += "[SNIPER] SNIPER ENTRY - 90%+ confidence - OPEN TRADE NOW!\n";
   details += "------------------------------\n";
   details += "R:R = 1:" + DoubleToString(rr,1);
   
   sig.symbol        = symbol;
   sig.setup         = "Setup 2 - SMS+BMS+RTO";
   sig.tradeType     = tradeType;
   sig.direction     = smsDirection;
   sig.entry         = NormalizeDouble(entry2, _Digits);
   sig.sl            = NormalizeDouble(sl,     _Digits);
   sig.tp1           = NormalizeDouble(tp1,    _Digits);
   sig.tp2           = NormalizeDouble(tp2,    _Digits);
   sig.rr            = rr;
   sig.confidence    = confidence;
   sig.isSniper      = isSniper2;
   sig.details       = details;
   sig.hasLiq        = false;
   sig.hasBOS        = true;
   sig.hasOB         = true;
   sig.hasFVG        = hasFVG;
   sig.hasCHoCH      = hasCHoCH;
   sig.hasInducement = hasInducement;
   sig.has3Drive     = has3Drive;
   
   return true;
}

//+------------------------------------------------------------------+
//|  MARKET STRUCTURE DETECTION                                       |
//+------------------------------------------------------------------+
MarketStructure GetMarketStructure(string symbol, ENUM_TIMEFRAMES tf)
{
   MarketStructure ms;
   ms.valid = false;
   ms.trend = "ranging";
   
   int bars = SwingLookback * 2;
   double highs[], lows[], closes[];
   ArraySetAsSeries(highs,  true);
   ArraySetAsSeries(lows,   true);
   ArraySetAsSeries(closes, true);
   
   if(CopyHigh(symbol, tf, 0, bars, highs)  < bars) return ms;
   if(CopyLow(symbol,  tf, 0, bars, lows)   < bars) return ms;
   if(CopyClose(symbol,tf, 0, bars, closes) < bars) return ms;
   
   // Find swing highs and lows
   double swingHighs[], swingLows[];
   ArrayResize(swingHighs, 0);
   ArrayResize(swingLows,  0);
   
   for(int i = 2; i < bars - 2; i++)
   {
      // Swing High
      if(highs[i] > highs[i+1] && highs[i] > highs[i-1] &&
         highs[i] > highs[i+2] && highs[i] > highs[i-2])
      {
         int sz = ArraySize(swingHighs);
         ArrayResize(swingHighs, sz + 1);
         swingHighs[sz] = highs[i];
      }
      // Swing Low
      if(lows[i] < lows[i+1] && lows[i] < lows[i-1] &&
         lows[i] < lows[i+2] && lows[i] < lows[i-2])
      {
         int sz = ArraySize(swingLows);
         ArrayResize(swingLows, sz + 1);
         swingLows[sz] = lows[i];
      }
   }
   
   int nhigh = ArraySize(swingHighs);
   int nlow  = ArraySize(swingLows);
   if(nhigh < 2 || nlow < 2) return ms;
   
   bool isHH = swingHighs[0] > swingHighs[1];  // Recent high > previous high
   bool isHL = swingLows[0]  > swingLows[1];   // Recent low  > previous low
   bool isLH = swingHighs[0] < swingHighs[1];
   bool isLL = swingLows[0]  < swingLows[1];
   
   if(isHH && isHL)      { ms.trend = "bullish"; ms.lastHH = swingHighs[0]; ms.lastHL = swingLows[0]; }
   else if(isLH && isLL) { ms.trend = "bearish"; ms.lastLH = swingHighs[0]; ms.lastLL = swingLows[0]; }
   else                  { ms.trend = "ranging"; }
   
   ms.valid = true;
   return ms;
}

//+------------------------------------------------------------------+
//|  LIQUIDITY SWEEP DETECTION (Stop Hunt)                            |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|  GET TP FROM PREVIOUS SWING HIGH OR LOW (Per Phineas Book)       |
//|  BUY  -> TP = previous swing HIGH on the setup timeframe         |
//|  SELL -> TP = previous swing LOW  on the setup timeframe         |
//+------------------------------------------------------------------+
double GetSwingTP(string symbol, ENUM_TIMEFRAMES tf, int direction, double entry, int swingNumber)
{
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);
   int bars = 100;
   if(CopyHigh(symbol, tf, 0, bars, highs) < bars) return 0;
   if(CopyLow(symbol,  tf, 0, bars, lows)  < bars) return 0;
   int found = 0;
   if(direction == 1) // BUY -> target previous swing HIGH above entry
   {
      for(int i = 2; i < bars - 2; i++)
      {
         if(highs[i] > highs[i+1] && highs[i] > highs[i-1] &&
            highs[i] > highs[i+2] && highs[i] > highs[i-2])
         {
            if(highs[i] > entry)
            { found++; if(found == swingNumber) return highs[i]; }
         }
      }
   }
   else // SELL -> target previous swing LOW below entry
   {
      for(int i = 2; i < bars - 2; i++)
      {
         if(lows[i] < lows[i+1] && lows[i] < lows[i-1] &&
            lows[i] < lows[i+2] && lows[i] < lows[i-2])
         {
            if(lows[i] < entry)
            { found++; if(found == swingNumber) return lows[i]; }
         }
      }
   }
   return 0; // not found ? caller will use fallback R:R
}

// TP timeframe per Phineas book: Day=H1, Swing=H4
ENUM_TIMEFRAMES getTpTF(string tradeType)
{
   if(tradeType == "Day") return PERIOD_H1;  // Day TP on H1
   return PERIOD_H4;                         // Swing TP on H4
}

// Bias timeframe for sniper TP lookup: Day=H1, Swing=H4
ENUM_TIMEFRAMES biasTFForSniper(string tradeType)
{
   if(tradeType == "Day") return PERIOD_H1;  // Day bias = H1
   return PERIOD_H4;                         // Swing bias = H4
}

bool DetectLiquiditySweep(string symbol, ENUM_TIMEFRAMES tf,
                           bool &sslSwept, bool &bslSwept, double &level)
{
   sslSwept = false;
   bslSwept = false;
   
   double highs[], lows[], closes[];
   ArraySetAsSeries(highs,  true);
   ArraySetAsSeries(lows,   true);
   ArraySetAsSeries(closes, true);
   
   int bars = SwingLookback + 10;
   if(CopyHigh(symbol,  tf, 0, bars, highs)  < bars) return false;
   if(CopyLow(symbol,   tf, 0, bars, lows)   < bars) return false;
   if(CopyClose(symbol, tf, 0, bars, closes) < bars) return false;
   
   // Find recent equal highs and lows (potential liquidity pools)
   double prevHighMax = 0, prevLowMin = DBL_MAX;
   for(int i = 3; i < bars - 3; i++)
   {
      if(highs[i] > prevHighMax) prevHighMax = highs[i];
      if(lows[i]  < prevLowMin)  prevLowMin  = lows[i];
   }
   
   // Check most recent 3 bars for sweep
   double recentLow  = MathMin(MathMin(lows[0],  lows[1]),  lows[2]);
   double recentHigh = MathMax(MathMax(highs[0], highs[1]), highs[2]);
   double recentClose = closes[0];
   
   // SSL Sweep: spike below prev low, close back above
   if(recentLow < prevLowMin && recentClose > prevLowMin)
   {
      double wickSize = prevLowMin - recentLow;
      if(wickSize / prevLowMin * 100.0 >= LiqSweepPct)
      {
         sslSwept = true;
         level    = prevLowMin;
         return true;
      }
   }
   
   // BSL Sweep: spike above prev high, close back below
   if(recentHigh > prevHighMax && recentClose < prevHighMax)
   {
      double wickSize = recentHigh - prevHighMax;
      if(wickSize / prevHighMax * 100.0 >= LiqSweepPct)
      {
         bslSwept = true;
         level    = prevHighMax;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//|  BOS / BMS DETECTION                                              |
//+------------------------------------------------------------------+
bool DetectBOS(string symbol, ENUM_TIMEFRAMES tf, int direction)
{
   double highs[], lows[], closes[];
   ArraySetAsSeries(highs,  true);
   ArraySetAsSeries(lows,   true);
   ArraySetAsSeries(closes, true);
   
   int bars = SwingLookback + 5;
   if(CopyHigh(symbol,  tf, 0, bars, highs)  < bars) return false;
   if(CopyLow(symbol,   tf, 0, bars, lows)   < bars) return false;
   if(CopyClose(symbol, tf, 0, bars, closes) < bars) return false;
   
   // Find previous swing extreme
   double prevSwingHigh = 0, prevSwingLow = DBL_MAX;
   for(int i = BOSBars; i < bars - 2; i++)
   {
      if(highs[i] > highs[i+1] && highs[i] > highs[i-1])
         if(highs[i] > prevSwingHigh) prevSwingHigh = highs[i];
      if(lows[i] < lows[i+1] && lows[i] < lows[i-1])
         if(lows[i] < prevSwingLow) prevSwingLow = lows[i];
   }
   
   // Bullish BOS: recent close above previous swing high
   if(direction == 1 && prevSwingHigh > 0)
   {
      if(closes[0] > prevSwingHigh && closes[1] < prevSwingHigh)
         return true;
      // Also check recent bars
      for(int i = 0; i < BOSBars; i++)
         if(closes[i] > prevSwingHigh) return true;
   }
   
   // Bearish BOS: recent close below previous swing low
   if(direction == -1 && prevSwingLow < DBL_MAX)
   {
      if(closes[0] < prevSwingLow && closes[1] > prevSwingLow)
         return true;
      for(int i = 0; i < BOSBars; i++)
         if(closes[i] < prevSwingLow) return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//|  SMS DETECTION (Shift of Market Structure)                        |
//+------------------------------------------------------------------+
bool DetectSMS(string symbol, ENUM_TIMEFRAMES tf, int &direction, string &detail)
{
   MarketStructure ms = GetMarketStructure(symbol, tf);
   if(!ms.valid) return false;
   
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);
   
   int bars = SwingLookback * 2;
   if(CopyHigh(symbol, tf, 0, bars, highs) < bars) return false;
   if(CopyLow(symbol,  tf, 0, bars, lows)  < bars) return false;
   
   // Collect swing lows and highs
   double swingLows[20], swingHighs[20];
   int nL = 0, nH = 0;
   
   for(int i = 2; i < bars - 2 && nL < 20 && nH < 20; i++)
   {
      if(lows[i] < lows[i+1] && lows[i] < lows[i-1])
         swingLows[nL++] = lows[i];
      if(highs[i] > highs[i+1] && highs[i] > highs[i-1])
         swingHighs[nH++] = highs[i];
   }
   
   if(nL >= 3)
   {
      // Bullish SMS: was making LL but failed - printed HL instead
      if(swingLows[0] > swingLows[1] && swingLows[1] <= swingLows[2])
      {
         direction = 1;
         detail    = "SMS: Failed to make new Lower Low - printed Higher Low (bullish shift)";
         return true;
      }
   }
   
   if(nH >= 3)
   {
      // Bearish SMS: was making HH but failed - printed LH instead
      if(swingHighs[0] < swingHighs[1] && swingHighs[1] >= swingHighs[2])
      {
         direction = -1;
         detail    = "SMS: Failed to make new Higher High - printed Lower High (bearish shift)";
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//|  ORDER BLOCK DETECTION                                            |
//+------------------------------------------------------------------+
bool FindOrderBlock(string symbol, ENUM_TIMEFRAMES tf, int direction, OrderBlock &ob)
{
   double opens[], highs[], lows[], closes[];
   ArraySetAsSeries(opens,  true); ArraySetAsSeries(highs,  true);
   ArraySetAsSeries(lows,   true); ArraySetAsSeries(closes, true);

   int bars = OBLookback + 5;
   if(CopyOpen(symbol,  tf, 0, bars, opens)  < bars) return false;
   if(CopyHigh(symbol,  tf, 0, bars, highs)  < bars) return false;
   if(CopyLow(symbol,   tf, 0, bars, lows)   < bars) return false;
   if(CopyClose(symbol, tf, 0, bars, closes) < bars) return false;

   ob.valid = false;
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   double minOBSize    = currentPrice * 0.0001;

   // Find BEST OB (largest body) that price is approaching ? not just first found
   OrderBlock bestOB; bestOB.valid = false;
   double bestSize = 0;

   for(int i = 1; i < bars - 1; i++)
   {
      double bodySize = MathAbs(closes[i] - opens[i]);
      double nextBody = MathAbs(closes[i-1] - opens[i-1]);
      if(nextBody < bodySize * 1.5) continue;
      if(bodySize < minOBSize) continue;

      // Bullish OB: last bearish candle before bullish impulse
      if(direction == 1 && closes[i] < opens[i] && closes[i-1] > opens[i-1])
      {
         double obTop = opens[i], obBot = lows[i], obRange = obTop - obBot;
         if(obRange < minOBSize) continue;
         if(obTop >= currentPrice) continue; // OB must be BELOW price (price returning down)
         if(bodySize > bestSize)
         {
            bestSize = bodySize;
            bestOB.top = obTop; bestOB.bottom = obBot;
            bestOB.type = 1; bestOB.barIdx = i; bestOB.valid = true;
         }
      }
      // Bearish OB: last bullish candle before bearish impulse
      else if(direction == -1 && closes[i] > opens[i] && closes[i-1] < opens[i-1])
      {
         double obTop = highs[i], obBot = opens[i], obRange = obTop - obBot;
         if(obRange < minOBSize) continue;
         if(obBot <= currentPrice) continue; // OB must be ABOVE price (price returning up)
         if(bodySize > bestSize)
         {
            bestSize = bodySize;
            bestOB.top = obTop; bestOB.bottom = obBot;
            bestOB.type = -1; bestOB.barIdx = i; bestOB.valid = true;
         }
      }
   }

   if(bestOB.valid) { ob = bestOB; return true; }
   return false;
}

//+------------------------------------------------------------------+
//|  CHECK IF PRICE IS NEAR ORDER BLOCK (RTO)                        |
//+------------------------------------------------------------------+
bool IsPriceNearOB(double price, OrderBlock &ob, int direction)
{
   if(!ob.valid) return false;

   double obRange = ob.top - ob.bottom;

   // Reject tiny noise OBs ? min size 0.01% of price
   double minOBSize = price * 0.0001;
   if(obRange < minOBSize) return false;

   // Allow wick through OB by up to 100% of OB range (stop hunt wick)
   double wickAllow = obRange * 1.0;

   if(direction == 1) // BUY ? price approaching or wicking through OB
      return (price >= ob.bottom - wickAllow && price <= ob.top + obRange * 3.0);
   else               // SELL ? price approaching or wicking through OB
      return (price >= ob.bottom - obRange * 3.0 && price <= ob.top + wickAllow);
}

//+------------------------------------------------------------------+
//|  FVG DETECTION (Fair Value Gap / Imbalance)                      |
//+------------------------------------------------------------------+
bool DetectFVG(string symbol, ENUM_TIMEFRAMES tf, int direction)
{
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);
   
   int bars = 20;
   if(CopyHigh(symbol, tf, 0, bars, highs) < bars) return false;
   if(CopyLow(symbol,  tf, 0, bars, lows)  < bars) return false;
   
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   
   for(int i = 1; i < bars - 1; i++)
   {
      // Bullish FVG: C3 low > C1 high (gap going up)
      if(direction == 1)
      {
         double gap = lows[i-1] - highs[i+1];
         if(gap > 0 && gap / price * 100.0 >= FVG_MinPct)
            return true;
      }
      if(direction == -1)
      {
         double gap = lows[i+1] - highs[i-1];
         if(gap > 0 && gap / price * 100.0 >= FVG_MinPct)
            return true;
      }
   }
   return false;
}

bool GetFVGLevels(string symbol, ENUM_TIMEFRAMES tf, int direction, double &fvgTop, double &fvgBot)
{
   double highs[], lows[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   int bars = 20;
   if(CopyHigh(symbol,tf,0,bars,highs)<bars) return false;
   if(CopyLow(symbol,tf,0,bars,lows)<bars)   return false;
   double price = SymbolInfoDouble(symbol,SYMBOL_BID);
   for(int i=1;i<bars-1;i++)
   {
      if(direction==1)
      {
         double gap = lows[i-1] - highs[i+1];
         if(gap > 0 && gap/price*100.0 >= FVG_MinPct)
         { fvgTop=lows[i-1]; fvgBot=highs[i+1]; return true; }
      }
      else
      {
         double gap = lows[i+1] - highs[i-1];
         if(gap > 0 && gap/price*100.0 >= FVG_MinPct)
         { fvgTop=lows[i+1]; fvgBot=highs[i-1]; return true; }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//|  DETECT CONTINUATION ? FVG/OB pullback on existing open trade    |
//+------------------------------------------------------------------+
bool DetectContinuation(string symbol, string tradeType, SMCSignal &sig)
{
   // Step 1 ? find open trade on this symbol
   int openDir = 0; double openTP = 0;
   for(int p=PositionsTotal()-1;p>=0;p--)
   {
      if(!posInfo.SelectByIndex(p)) continue;
      if(posInfo.Symbol()!=symbol) continue;
      if(posInfo.Magic()!=MagicNumber) continue;
      openDir = posInfo.PositionType()==POSITION_TYPE_BUY ? 1 : -1;
      openTP  = posInfo.TakeProfit();
      break;
   }
   if(openDir==0) return false;

   ENUM_TIMEFRAMES biasTF, liqTF, bosTF, entryTF;
   GetTimeframes(tradeType, biasTF, liqTF, bosTF, entryTF);

   MarketStructure ms = GetMarketStructure(symbol, biasTF);
   if(openDir==1  && ms.trend!="bullish") return false;
   if(openDir==-1 && ms.trend!="bearish") return false;

   double currentPrice = SymbolInfoDouble(symbol,SYMBOL_BID);
   int    digits = (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   double pt     = _Point;
   double entryPrice=0, slPrice=0;
   string contType="";
   double fvgTop=0, fvgBot=0;

   if(GetFVGLevels(symbol,entryTF,openDir,fvgTop,fvgBot))
   {
      bool priceAtFVG = openDir==1
         ? (currentPrice>=fvgBot-(fvgTop-fvgBot) && currentPrice<=fvgTop)
         : (currentPrice<=fvgTop+(fvgTop-fvgBot) && currentPrice>=fvgBot);
      if(!priceAtFVG) return false;
      entryPrice = openDir==1 ? fvgTop : fvgBot;
      slPrice    = openDir==1 ? fvgBot-pt*5 : fvgTop+pt*5;
      contType   = "FVG";
   }
   else
   {
      OrderBlock ob;
      if(!FindOrderBlock(symbol,entryTF,openDir,ob)) return false;
      if(!IsPriceNearOB(currentPrice,ob,openDir))   return false;
      entryPrice = openDir==1 ? ob.top+pt*2 : ob.bottom-pt*2;
      slPrice    = openDir==1 ? ob.bottom-pt*5 : ob.top+pt*5;
      contType   = "OB";
   }

   double slDist = MathAbs(entryPrice-slPrice);
   if(slDist < entryPrice*0.0005) return false;

   double tp1 = openTP>0 ? openTP : GetSwingTP(symbol,getTpTF(tradeType),openDir,entryPrice,1);
   if(tp1==0||(openDir==1&&tp1<=entryPrice)||(openDir==-1&&tp1>=entryPrice))
      tp1 = openDir==1 ? entryPrice+slDist*2.5 : entryPrice-slDist*2.5;
   double tp2 = openDir==1 ? tp1+slDist : tp1-slDist;

   double rr = MathAbs(tp1-entryPrice)/slDist;
   if(rr<MinRR||rr>20.0) return false;

   int confidence=60;
   if(contType=="FVG") confidence+=15;
   if(contType=="OB")  confidence+=10;
   bool hasCH = UseCHoCH ? DetectCHoCH(symbol,bosTF,openDir) : false;
   if(hasCH) confidence+=8;
   confidence=MathMin(confidence,100);

   sig.symbol    =symbol; sig.tradeType=tradeType; sig.direction=openDir;
   sig.setup     ="Continuation - "+contType+" pullback";
   sig.entry     =NormalizeDouble(entryPrice,digits);
   sig.sl        =NormalizeDouble(slPrice,digits);
   sig.tp1       =NormalizeDouble(tp1,digits);
   sig.tp2       =NormalizeDouble(tp2,digits);
   sig.rr        =NormalizeDouble(rr,1);
   sig.confidence=confidence;
   sig.isSniper  =(confidence>=90);
   sig.hasFVG    =(contType=="FVG");
   sig.hasOB     =(contType=="OB");
   sig.hasCHoCH  =hasCH;
   sig.details   ="[OK] Open trade confirmed\n[OK] "+contType+" continuation\nR:R = 1:"+DoubleToString(rr,1);
   return true;
}

//+------------------------------------------------------------------+
//|  CHoCH DETECTION (Change of Character)                           |
//+------------------------------------------------------------------+
bool DetectCHoCH(string symbol, ENUM_TIMEFRAMES tf, int direction)
{
   double highs[], lows[], closes[];
   ArraySetAsSeries(highs,  true);
   ArraySetAsSeries(lows,   true);
   ArraySetAsSeries(closes, true);
   
   int bars = CHoCH_Lookback;
   if(CopyHigh(symbol,  tf, 0, bars, highs)  < bars) return false;
   if(CopyLow(symbol,   tf, 0, bars, lows)   < bars) return false;
   if(CopyClose(symbol, tf, 0, bars, closes) < bars) return false;
   
   // Find recent swing high and low
   double recentSwingHigh = 0, recentSwingLow = DBL_MAX;
   double prevSwingHigh   = 0, prevSwingLow   = DBL_MAX;
   bool   foundFirst      = false;
   
   for(int i = 1; i < bars - 1; i++)
   {
      if(highs[i] > highs[i+1] && highs[i] > highs[i-1])
      {
         if(!foundFirst) { recentSwingHigh = highs[i]; foundFirst = true; }
         else { prevSwingHigh = highs[i]; break; }
      }
   }
   foundFirst = false;
   for(int i = 1; i < bars - 1; i++)
   {
      if(lows[i] < lows[i+1] && lows[i] < lows[i-1])
      {
         if(!foundFirst) { recentSwingLow = lows[i]; foundFirst = true; }
         else { prevSwingLow = lows[i]; break; }
      }
   }
   
   // Bullish CHoCH: recent low > prev low AND close breaks above recent swing high
   if(direction == 1 && recentSwingLow < DBL_MAX && prevSwingLow < DBL_MAX)
      if(recentSwingLow > prevSwingLow && closes[0] > recentSwingHigh)
         return true;
   
   // Bearish CHoCH: recent high < prev high AND close breaks below recent swing low
   if(direction == -1 && recentSwingHigh > 0 && prevSwingHigh > 0)
      if(recentSwingHigh < prevSwingHigh && closes[0] < recentSwingLow)
         return true;
   
   return false;
}

//+------------------------------------------------------------------+
//|  INDUCEMENT DETECTION                                             |
//+------------------------------------------------------------------+
bool DetectInducement(string symbol, ENUM_TIMEFRAMES tf, int direction)
{
   double opens[], closes[];
   ArraySetAsSeries(opens,  true);
   ArraySetAsSeries(closes, true);
   
   int bars = 10;
   if(CopyOpen(symbol,  tf, 0, bars, opens)  < bars) return false;
   if(CopyClose(symbol, tf, 0, bars, closes) < bars) return false;
   
   // Look for small candle(s) sandwiched between larger candles
   int smallCount = 0;
   for(int i = 1; i < bars - 1; i++)
   {
      double prevSize = MathAbs(closes[i+1] - opens[i+1]);
      double currSize = MathAbs(closes[i]   - opens[i]);
      double nextSize = MathAbs(closes[i-1] - opens[i-1]);
      
      if(prevSize > 0 && nextSize > 0)
         if(currSize < prevSize * 0.35 && currSize < nextSize * 0.35)
            smallCount++;
   }
   
   return (smallCount >= 2);
}

//+------------------------------------------------------------------+
//|  3-DRIVE DETECTION (Live Chart - Trendline Touches Inside OB)    |
//|  Per Phineas: "When price touches our 3rd touch inside OB we     |
//|  enter." - 3 symmetrical trendline touches inside the OB zone    |
//+------------------------------------------------------------------+
bool Detect3Drive(string symbol, ENUM_TIMEFRAMES tf, int direction, OrderBlock &ob)
{
   if(!ob.valid || !UseConfluence3D) return false;
   
   double highs[], lows[], closes[];
   ArraySetAsSeries(highs,  true);
   ArraySetAsSeries(lows,   true);
   ArraySetAsSeries(closes, true);
   
   int bars = Drive3_Lookback;
   if(CopyHigh(symbol,  tf, 0, bars, highs)  < bars) return false;
   if(CopyLow(symbol,   tf, 0, bars, lows)   < bars) return false;
   if(CopyClose(symbol, tf, 0, bars, closes) < bars) return false;
   
   double obMid      = (ob.top + ob.bottom) / 2.0;
   double obRange    = ob.top - ob.bottom;
   double tolerance  = obRange * (Drive3_Tolerance / 100.0 * 100.0 + 1.0);
   
   // -- FIND SWING POINTS INSIDE OR TOUCHING THE OB ZONE
   // For BUY: we look for swing LOWS inside the bullish OB zone
   // For SELL: we look for swing HIGHS inside the bearish OB zone
   double touchPrices[];
   int    touchBars[];
   ArrayResize(touchPrices, 0);
   ArrayResize(touchBars,   0);
   
   for(int i = 2; i < bars - 2; i++)
   {
      if(direction == 1) // Bullish: look for lows touching the OB
      {
         // Swing low inside OB zone
         bool isSwingLow = (lows[i] < lows[i+1] && lows[i] < lows[i-1] &&
                            lows[i] < lows[i+2] && lows[i] < lows[i-2]);
         bool insideOB   = (lows[i] >= ob.bottom - tolerance && lows[i] <= ob.top + tolerance);
         
         if(isSwingLow && insideOB)
         {
            int sz = ArraySize(touchPrices);
            ArrayResize(touchPrices, sz + 1);
            ArrayResize(touchBars,   sz + 1);
            touchPrices[sz] = lows[i];
            touchBars[sz]   = i;
         }
      }
      else // Bearish: look for highs touching the OB
      {
         bool isSwingHigh = (highs[i] > highs[i+1] && highs[i] > highs[i-1] &&
                             highs[i] > highs[i+2] && highs[i] > highs[i-2]);
         bool insideOB    = (highs[i] >= ob.bottom - tolerance && highs[i] <= ob.top + tolerance);
         
         if(isSwingHigh && insideOB)
         {
            int sz = ArraySize(touchPrices);
            ArrayResize(touchPrices, sz + 1);
            ArrayResize(touchBars,   sz + 1);
            touchPrices[sz] = highs[i];
            touchBars[sz]   = i;
         }
      }
   }
   
   int nTouches = ArraySize(touchPrices);
   if(nTouches < Drive3_MinTouches) return false;
   
   // -- VERIFY TRENDLINE IS VALID (touches form a descending/ascending line)
   // For BUY 3-Drive: touches should form a DESCENDING trendline (lows getting lower = 3-drive bottom)
   // For SELL 3-Drive: touches should form an ASCENDING trendline (highs getting higher = 3-drive top)
   if(nTouches >= 3)
   {
      // Check if the 3 most recent touches form a consistent trendline
      // Using first and last touch to define the line, middle touch should be near it
      double p1 = touchPrices[nTouches-1]; // oldest
      double p2 = touchPrices[nTouches-2]; // middle
      double p3 = touchPrices[0];           // most recent (this is the 3rd touch = entry)
      
      int b1 = touchBars[nTouches-1];
      int b2 = touchBars[nTouches-2];
      int b3 = touchBars[0];
      
      // Calculate expected price at b2 using trendline from b1 to b3
      if(b1 != b3)
      {
         double slope     = (p3 - p1) / (b3 - b1);
         double expected  = p1 + slope * (b2 - b1);
         double lineError = MathAbs(p2 - expected) / obRange;
         
         // Middle touch should be within 50% of OB range from the trendline
         if(lineError > 0.5) return false;
      }
      
      // For BUY: trendline should be descending (3 drives to a bottom)
      // For SELL: trendline should be ascending (3 drives to a top)
      if(direction == 1 && p3 >= p1) return false; // Not descending
      if(direction == -1 && p3 <= p1) return false; // Not ascending
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//|  QML DETECTION (Quasimodo Level)                                  |
//|  Per Phineas: QML acts as confluence with OB for sniper entry.   |
//|  Kill zone = where QML intersects the Order Block.               |
//|                                                                    |
//|  QML Pattern (Bullish):                                           |
//|    Left Shoulder (LS) high -> Head (lower low) -> Right Shoulder   |
//|    (RS) high that is LOWER than LS -> price drops below RS =      |
//|    QML level. Entry when price touches QML inside OB.            |
//|                                                                    |
//|  QML Pattern (Bearish):                                           |
//|    Left Shoulder (LS) low -> Head (higher high) -> Right Shoulder  |
//|    (RS) low that is HIGHER than LS -> price rises above RS =      |
//|    QML level. Entry when price touches QML inside OB.            |
//+------------------------------------------------------------------+
bool DetectQML(string symbol, ENUM_TIMEFRAMES tf, int direction,
               OrderBlock &ob, double &qmlLevel)
{
   if(!ob.valid || !UseQML) return false;
   
   qmlLevel = 0;
   
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);
   
   int bars = QML_Lookback;
   if(CopyHigh(symbol, tf, 0, bars, highs) < bars) return false;
   if(CopyLow(symbol,  tf, 0, bars, lows)  < bars) return false;
   
   // Find swing highs and lows for QML pattern
   double swingHighs[10], swingLows[10];
   int    swingHighBars[10], swingLowBars[10];
   int    nH = 0, nL = 0;
   
   for(int i = 2; i < bars - 2 && (nH < 10 || nL < 10); i++)
   {
      if(nH < 10 && highs[i] > highs[i+1] && highs[i] > highs[i-1] &&
         highs[i] > highs[i+2] && highs[i] > highs[i-2])
      {
         swingHighs[nH]     = highs[i];
         swingHighBars[nH]  = i;
         nH++;
      }
      if(nL < 10 && lows[i] < lows[i+1] && lows[i] < lows[i-1] &&
         lows[i] < lows[i+2] && lows[i] < lows[i-2])
      {
         swingLows[nL]     = lows[i];
         swingLowBars[nL]  = i;
         nL++;
      }
   }
   
   double tolerance = (ob.top - ob.bottom) * (QML_Tolerance / 100.0 * 100.0 + 1.0);
   
   if(direction == 1 && nH >= 3) // Bullish QML
   {
      // Pattern: LS_high -> Head_low -> RS_high where RS < LS
      // Then QML level = RS high level
      // This creates a "failed higher high" - LS is higher than RS
      for(int i = 0; i < nH - 2; i++)
      {
         double ls = swingHighs[i+2]; // Left Shoulder (older)
         double rs = swingHighs[i];   // Right Shoulder (newer)
         
         // RS must be LOWER than LS (failed higher high = bullish QML)
         if(rs < ls)
         {
            qmlLevel = rs; // QML level is the Right Shoulder
            
            // Check if QML level intersects with our OB
            bool qmlInOB = (qmlLevel >= ob.bottom - tolerance &&
                            qmlLevel <= ob.top   + tolerance);
            
            if(qmlInOB)
            {
               Print("[OK] QML (Bullish) detected at ", qmlLevel,
                     " | OB zone: ", ob.bottom, " - ", ob.top);
               return true;
            }
         }
      }
   }
   
   if(direction == -1 && nL >= 3) // Bearish QML
   {
      // Pattern: LS_low -> Head_high -> RS_low where RS > LS
      // RS must be HIGHER than LS (failed lower low = bearish QML)
      for(int i = 0; i < nL - 2; i++)
      {
         double ls = swingLows[i+2]; // Left Shoulder (older)
         double rs = swingLows[i];   // Right Shoulder (newer)
         
         // RS must be HIGHER than LS (failed lower low = bearish QML)
         if(rs > ls)
         {
            qmlLevel = rs; // QML level is the Right Shoulder
            
            bool qmlInOB = (qmlLevel >= ob.bottom - tolerance &&
                            qmlLevel <= ob.top   + tolerance);
            
            if(qmlInOB)
            {
               Print("[OK] QML (Bearish) detected at ", qmlLevel,
                     " | OB zone: ", ob.bottom, " - ", ob.top);
               return true;
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//|  BREAKER BLOCK DETECTION                                          |
//|  A failed OB that has been broken - now acts as resistance       |
//|  (was support) or support (was resistance)                       |
//+------------------------------------------------------------------+
bool DetectBreakerBlock(string symbol, ENUM_TIMEFRAMES tf, int direction,
                         OrderBlock &breakerOB)
{
   if(!UseBreakerBlock) return false;
   
   double closes[];
   ArraySetAsSeries(closes, true);
   
   int bars = OBLookback + 10;
   if(CopyClose(symbol, tf, 0, bars, closes) < bars) return false;
   
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   
   // Look for previously detected OBs that have been violated
   // Then check if price is returning to them (now as breaker blocks)
   OrderBlock oldOB;
   
   // Check for old bullish OB that was violated (becomes bearish breaker)
   if(direction == -1)
   {
      if(FindOrderBlock(symbol, tf, 1, oldOB)) // Find bullish OB
      {
         // If price has closed BELOW the OB bottom, it's been violated
         bool violated = false;
         for(int i = 0; i < 10; i++)
            if(closes[i] < oldOB.bottom) { violated = true; break; }
         
         if(violated)
         {
            // Now returning to the violated OB from below = bearish breaker block
            bool returning = (currentPrice >= oldOB.bottom * 0.998 &&
                              currentPrice <= oldOB.top * 1.002);
            if(returning)
            {
               breakerOB = oldOB;
               breakerOB.type = -1; // Now acting as bearish
               return true;
            }
         }
      }
   }
   
   // Check for old bearish OB that was violated (becomes bullish breaker)
   if(direction == 1)
   {
      if(FindOrderBlock(symbol, tf, -1, oldOB)) // Find bearish OB
      {
         bool violated = false;
         for(int i = 0; i < 10; i++)
            if(closes[i] > oldOB.top) { violated = true; break; }
         
         if(violated)
         {
            bool returning = (currentPrice >= oldOB.bottom * 0.998 &&
                              currentPrice <= oldOB.top * 1.002);
            if(returning)
            {
               breakerOB = oldOB;
               breakerOB.type = 1; // Now acting as bullish
               return true;
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//|  VALIDATE SIGNAL                                                  |
//+------------------------------------------------------------------+
bool ValidateSignal(SMCSignal &sig)
{
   // Check R:R
   if(sig.rr < MinRR) return false;
   
   // Check confidence
   if(sig.confidence < 50) return false;
   
   // Check we don't already have a signal for this symbol+direction
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == sig.symbol && posInfo.Magic() == MagicNumber)
         {
            int posDir = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
            if(posDir == sig.direction) return false; // Already in this direction
         }
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//|  PROCESS SIGNAL - Alert and/or Place Order                       |
//+------------------------------------------------------------------+
void ProcessSignal(SMCSignal &sig, bool tradingFull = false)
{
   string dirStr   = (sig.direction == 1) ? "BUY"  : "SELL";
   string arrow    = (sig.direction == 1) ? "[BUY]"    : "[SELL]";
   string typeBadge = "", typeIcon = "";
   if(sig.tradeType == "Day")        { typeBadge = "[D] DAY TRADE (H4->H1->M15->M5)";      typeIcon = "[D]"; }
   else if(sig.tradeType == "Swing") { typeBadge = "[S] SWING TRADE (Daily->H4->H1->M15)"; typeIcon = "[S]"; }
   if(sig.setup == "Continuation - FVG pullback" || sig.setup == "Continuation - OB pullback")
   {
      string contSrc = sig.hasFVG ? "FVG" : "OB";
      typeBadge = "[CONT] CONTINUATION - "+contSrc+" pullback ("+sig.tradeType+")";
      typeIcon  = "[C]";
   }

   // -- SNIPER LABEL
   string sniperTag  = sig.isSniper ? " [SNIPER] SNIPER" : "";
   bool   dailyHit   = IsDailyLossExceeded();
   string fullStatus = !tradingFull ? "" : (dailyHit ? " [STOP] DAILY LIMIT - ALERT ONLY" : " [!]? MAX TRADES - ALERT ONLY");

   string msgTitle = (sig.isSniper ? "[SNIPER] SNIPER " : "") + arrow + " " + dirStr
                   + " " + sig.symbol + " | " + typeIcon + " " + sig.tradeType
                   + " | " + sig.setup + fullStatus;

   string msgBody = "==============================\n"
                  + (sig.isSniper ? "[SNIPER][SNIPER] SNIPER ENTRY - OPEN NOW! [SNIPER][SNIPER]\n" : "")
                  + arrow + " " + dirStr + " " + sig.symbol + "\n"
                  + typeBadge + "\n"
                  + sig.setup + "\n"
                  + "Session: " + (IsCrypto(sig.symbol) ? "CRYPTO 24/7" : GetCurrentSession()) + "\n"
                  + "Confidence: " + IntegerToString(sig.confidence) + "%" + sniperTag + "\n"
                  + "==============================\n"
                  + (sig.isSniper
                     ? "[NOW] MARKET " + dirStr + " NOW - price is AT the zone!\n"
                     : "Entry:  " + DoubleToString(sig.entry, _Digits) + "\n")
                  + "SL:     " + DoubleToString(sig.sl,    _Digits) + "\n"
                  + "TP1:    " + DoubleToString(sig.tp1,   _Digits) + "\n"
                  + "TP2:    " + DoubleToString(sig.tp2,   _Digits) + "\n"
                  + "R:R     1:" + DoubleToString(sig.rr,  1) + "\n"
                  + "==============================\n"
                  + sig.details;

   if(tradingFull)
   {
      if(dailyHit)
      {
         // Daily limit hit ? NO notification, dashboard only
         lastSignalStr  = (sig.isSniper ? "[SNIPER] " : "") + arrow + " " + dirStr
                        + " " + sig.symbol + " | " + typeIcon + " " + sig.tradeType
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
   if(SoundAlert)       PlaySound(sig.isSniper ? "alert2.wav" : AlertSound);
   if(PushNotification) SendNotification(msgTitle + "\n" + msgBody);
   if(EmailAlert)       SendMail(msgTitle, msgBody);

   lastSignalStr  = (sig.isSniper ? "[SNIPER] " : "") + arrow + " " + dirStr
                  + " " + sig.symbol + " | " + typeIcon + " " + sig.tradeType
                  + " | " + IntegerToString(sig.confidence) + "%"
                  + (sig.isSniper ? " SNIPER" : "")
                  + (tradingFull ? " (FULL)" : "");
   lastSignalTime = TimeCurrent();

   Print("=======================================");
   if(sig.isSniper) Print("[SNIPER][SNIPER] SNIPER SIGNAL - 90%+ CONFIDENCE [SNIPER][SNIPER]");
   Print("SIGNAL: ", msgTitle);
   if(tradingFull) Print("[!] MAX TRADES - alert only");
   Print(msgBody);
   Print("=======================================");

   if(tradingFull) { if(ShowDashboard) DrawDashboard(); return; }
   if(AlertOnly)   return;

   // -- SMART RULES CHECK
   if(!IsSmartRulesAllowed())
   {
      Print("[SMART] Auto trade blocked: ", smartBlockReason);
      lastSignalStr  = smartBlockReason;
      lastSignalTime = TimeCurrent();
      if(ShowDashboard) DrawDashboard();
      return;
   }

   // -- EXECUTE TRADES: execute immediately at market price
   if(ExecuteTrades || AutoExecute || sig.isSniper)
   {
      Print("[EXECUTE] Executing at market: ", sig.direction==1?"BUY":"SELL", " ", sig.symbol,
            " | Confidence:", sig.confidence, "%");
      dailyTradeCount++;
      ExecuteSignal(sig);
      if(ShowDashboard) DrawDashboard();
      return;
   }

   // -- CONFIRMATION POPUP: show popup, wait for Y/N
   if(ShowTradeConfirm)
   {
      pendingSignal    = sig;
      hasPendingSignal = true;
      pendingTime      = TimeCurrent();
      Print("[WAIT] Awaiting confirmation - Press Y (", typeBadge, "), N to skip");
      if(ShowDashboard) DrawDashboard();
      return;
   }

   // -- FALLBACK: execute directly
   dailyTradeCount++;
   ExecuteSignal(sig);
}

//+------------------------------------------------------------------+
//|  LOT SIZE CALCULATION (Risk-based)                                |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double entry, double sl)
{
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   // -- HARD CAP: never allow more than 1.0 lot regardless of settings
   double hardCap = MathMin(maxLot, 1.0);

   // -- MANUAL LOT MODE: use fixed lot set by user
   if(UseManualLot)
   {
      double lot = MathFloor(ManualLotSize / lotStep) * lotStep;
      lot = MathMax(minLot, MathMin(hardCap, lot));
      return NormalizeDouble(lot, 2);
   }

   // -- AUTO RISK MODE: calculate lot based on % risk
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * RiskPercent / 100.0;
   double slPips     = MathAbs(entry - sl) / _Point;
   if(slPips <= 0) return minLot;

   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0 || tickSize <= 0) return minLot;

   double pipValue = tickValue / tickSize * _Point;
   double lotSize  = riskAmount / (slPips * pipValue);

   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   // Apply hard cap
   lotSize = MathMax(minLot, MathMin(hardCap, lotSize));
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//|  MANAGE OPEN TRADES (Breakeven, Trailing Stop)                   |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   if(!MoveToBreakeven) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != MagicNumber) continue;

      string symbol = posInfo.Symbol();
      double entry  = posInfo.PriceOpen();
      double sl     = posInfo.StopLoss();
      double tp     = posInfo.TakeProfit();
      double price  = posInfo.PriceCurrent();
      double pt     = SymbolInfoDouble(symbol, SYMBOL_POINT);

      // Move to breakeven only after price confirms BreakevenConfirmPct% of TP1 distance
      double confirmDist = MathAbs(tp - entry) * (BreakevenConfirmPct / 100.0);

      if(posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         if(price >= entry + confirmDist && sl < entry)
         {
            double newSL = entry + pt * 5;
            trade.PositionModify(posInfo.Ticket(), newSL, tp);
            Print("[BE] BUY breakeven: ", symbol, " entry:", entry, " confirmed at:", price);
         }
      }
      else if(posInfo.PositionType() == POSITION_TYPE_SELL)
      {
         if(price <= entry - confirmDist && sl > entry)
         {
            double newSL = entry - pt * 5;
            trade.PositionModify(posInfo.Ticket(), newSL, tp);
            Print("[BE] SELL breakeven: ", symbol, " entry:", entry, " confirmed at:", price);
         }
      }
   }
}

//+------------------------------------------------------------------+
//|  HELPER: COUNT OPEN TRADES                                        |
//+------------------------------------------------------------------+
int CountOpenTrades()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(posInfo.SelectByIndex(i))
         if(posInfo.Magic() == MagicNumber) count++;
   return count;
}

// Count pending orders for a specific symbol ? prevents duplicate limit orders
int CountPendingOrders(string symbol)
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      count++;
   }
   return count;
}

int CountOpenTradesForSymbol(string symbol)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != symbol) continue;
      if(posInfo.Magic() != MagicNumber) continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//|  HELPER: CHECK DAILY LOSS LIMIT                                   |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|  SMART TRADING RULES                                              |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   MqlDateTime dt, lastDt;
   TimeToStruct(TimeCurrent(), dt);
   TimeToStruct(lastTradeDay, lastDt);
   if(dt.day != lastDt.day || lastTradeDay == 0)
   {
      dailyTradeCount   = 0;
      smartRulesBlocked = false;
      smartBlockReason  = "";
      dayStartBalance   = AccountInfoDouble(ACCOUNT_BALANCE);
      lastTradeDay      = TimeCurrent();
      Print("[SMART] New day - counters reset. Day balance: $", dayStartBalance);
   }
}

bool IsSmartRulesAllowed()
{
   CheckDailyReset();

   // Rule 1: Max trades per day
   if(dailyTradeCount >= MaxTradesPerDay)
   {
      smartRulesBlocked = true;
      smartBlockReason  = "[!] MAX " + IntegerToString(MaxTradesPerDay) + " TRADES TODAY - Signals only";
      return false;
   }

   // Rule 2: Consecutive losses gate with auto-cooldown
   if(consecutiveLosses >= MaxConsecutiveLosses)
   {
      if(LossCooldownMinutes > 0 && lossBlockedSince > 0)
      {
         int minutesPassed = (int)((TimeCurrent() - lossBlockedSince) / 60);
         if(minutesPassed >= LossCooldownMinutes)
         {
            consecutiveLosses = 0;
            lossBlockedSince  = 0;
            smartRulesBlocked = false;
            smartBlockReason  = "";
            Print("[SMART] Loss cooldown expired - auto trading resumed");
            if(PushNotification) SendNotification("[OK] JOJOS SMC - Cooldown ended, auto trading resumed!");
         }
         else
         {
            int minsLeft = LossCooldownMinutes - minutesPassed;
            smartRulesBlocked = true;
            smartBlockReason  = "[X] " + IntegerToString(consecutiveLosses) + " losses - " + IntegerToString(minsLeft) + " min cooldown left";
            return false;
         }
      }
      else if(LossCooldownMinutes == 0)
      {
         smartRulesBlocked = true;
         smartBlockReason  = "[X] " + IntegerToString(consecutiveLosses) + " losses - Manual reset required";
         return false;
      }
   }

   // Rule 3: Daily profit lock
   if(dayStartBalance > 0)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
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
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double maxLoss = startBalance * MaxDailyLossPct / 100.0;
   
   if((startBalance - equity) >= maxLoss)
   {
      static bool warned = false;
      if(!warned)
      {
         // Log to journal only ? NO push notification (shows on dashboard instead)
         Print("[STOP] Daily loss limit reached (", MaxDailyLossPct, "%) - AUTO TRADING STOPPED for today.");
         Print("[!] Check dashboard for status. Signals continue - no orders placed.");
         warned = true;
      }
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//|  HELPER: GET TIMEFRAMES FOR TRADE TYPE                            |
//+------------------------------------------------------------------+
void GetTimeframes(string tradeType,
                   ENUM_TIMEFRAMES &biasTF, ENUM_TIMEFRAMES &liqTF,
                   ENUM_TIMEFRAMES &bosTF,  ENUM_TIMEFRAMES &entryTF)
{
   if(tradeType == "Day")
   {
      biasTF  = day_bias_tf;    // H4
      liqTF   = day_liq_tf;     // H1
      bosTF   = day_bos_tf;     // M15
      entryTF = day_entry_tf;   // M5
   }
   else // Swing
   {
      biasTF  = swing_bias_tf;  // Daily
      liqTF   = swing_liq_tf;   // H4
      bosTF   = swing_bos_tf;   // H1
      entryTF = swing_entry_tf; // M15
   }
}

//+------------------------------------------------------------------+
//|  HELPER: GET TP/SL PERCENTAGES                                    |
//+------------------------------------------------------------------+
void GetTPSL(string tradeType, double &tp1Pct, double &tp2Pct)
{
   if(tradeType == "Day") { tp1Pct = Day_TP1_Pct;   tp2Pct = Day_TP2_Pct;   }
   else                   { tp1Pct = Swing_TP1_Pct; tp2Pct = Swing_TP2_Pct; }
}

double GetSLPct(string tradeType)
{
   if(tradeType == "Day") return Day_SL_Pct;
   return Swing_SL_Pct;
}

//+------------------------------------------------------------------+
//|  HELPER: TIMEFRAME TO STRING                                      |
//+------------------------------------------------------------------+
string TFToStr(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      default:         return "TF";
   }
}

//+------------------------------------------------------------------+
//|  DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, DB_PREFIX);
   Print("Jojos SMC EA stopped.");
   Print("Total signals: ",  signalCount);
   Print("Total trades: ",   totalTrades);
   Print("Wins: ",           winTrades, " | Losses: ", lossTrades, " | BE: ", breakevenTrades);
   double wr = totalTrades > 0 ? (double)winTrades / totalTrades * 100.0 : 0;
   Print("Win Rate: ",       DoubleToString(wr, 1), "%");
   Print("Total Profit: $",  DoubleToString(totalProfit + totalLoss, 2));
}
//+------------------------------------------------------------------+

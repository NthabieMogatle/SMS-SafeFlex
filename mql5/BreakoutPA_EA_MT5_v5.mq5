//+------------------------------------------------------------------+
//|  BreakoutPA_EA_MT5_v5.mq5                                        |
//|  Strategy : Support/Resistance Breakout + Price Action           |
//|  Timeframe: M15 or H1                                            |
//|  Markets  : Forex | Gold | Silver | Bitcoin | US30 | NAS | SPX   |
//|  Features : AutoTrade · Manual Lot · Dashboard · Trailing Stop   |
//|             Push Alerts · Signal-only mode · Performance Stats    |
//+------------------------------------------------------------------+
#property copyright   "Custom EA"
#property version     "5.00"
#property description "Breakout + Price Action EA — MT5 v5"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>

CTrade        trade;
CPositionInfo posInfo;
CDealInfo     dealInfo;

//=== INPUTS =========================================================

input group "=== Trade Mode ==="
input bool   AutoTrade       = false;  // TRUE=auto trade | FALSE=signals only
input bool   ManualLot       = false;  // TRUE=fixed lot  | FALSE=auto risk %
input double FixedLotSize    = 0.10;   // Fixed lot size (if ManualLot=true)

input group "=== Risk Management ==="
input double RiskPercent     = 1.0;    // % account risk per trade
input double RewardRatio     = 2.0;    // TP reward:risk ratio

input group "=== Strategy ==="
input int    SwingLookback   = 50;
input int    ATR_Period      = 14;
input double ATR_Buffer      = 0.5;

input group "=== Trailing Stop ==="
input bool   UseTrailingStop = true;
input double TrailATR_Multi  = 1.0;
input double TrailStep_Multi = 0.3;

input group "=== Safety ==="
input double MaxDailyLossPct       = 3.0;    // Max daily loss % before EA stops opening trades (0 = off)
input int    MaxTradesPerDay       = 5;      // Max auto-trades per day (0 = off; signals not counted)
input int    MaxConsecutiveLosses  = 2;      // After X losses in a row, pause auto trading (0 = off)
input int    LossCooldownMinutes   = 30;     // Auto-resume after X minutes (0 = manual reset only)

input group "=== Sessions (Server Hour) ==="
input bool   LondonSession   = false;
input int    LondonOpen      = 8;
input int    LondonClose     = 12;
input bool   NewYorkSession  = false;
input int    NYOpen          = 13;
input int    NYClose         = 17;
input bool   AsianSession    = false;
input int    AsianOpen       = 0;
input int    AsianClose      = 6;

input group "=== Direction ==="
input bool   TradeBUY        = true;
input bool   TradeSELL       = true;

input group "=== Alerts ==="
input bool   AlertOnSignal   = true;
input bool   PushNotify      = true;
input bool   EmailAlert      = false;

input group "=== Display ==="
input bool   ShowDashboard   = true;
input int    DashX           = 12;
input int    DashY           = 12;

input group "=== EA ==="
input int    MagicNumber     = 202405;

//=== GLOBALS ========================================================
string   EA_Name      = "BreakoutPA v5";
datetime lastBarTime  = 0;
int      atrHandle;
double   atrBuffer[];

int      totalTrades    = 0;
int      winTrades      = 0;
int      lossTrades     = 0;
double   totalProfit    = 0.0;
double   totalLoss      = 0.0;
double   grossPnL       = 0.0;
double   bestTrade      = 0.0;
double   worstTrade     = 0.0;
ulong    lastDealTicket = 0;
string   lastSignal     = "WAITING...";
string   lastSignalDir  = "";

double   dayStartBalance   = 0.0;
datetime lastTradeDay      = 0;
bool     dailyLossWarned   = false;
int      dailyTradeCount   = 0;
bool     maxTradesWarned   = false;
int      consecutiveLosses = 0;
datetime lossBlockedSince  = 0;
bool     streakWarned      = false;
bool     initialStatsLoaded = false;   // suppresses streak/notify during OnInit history backfill

//=== INSTRUMENT =====================================================
enum ENUM_INSTRUMENT { INST_FOREX, INST_GOLD, INST_SILVER, INST_CRYPTO, INST_INDEX, INST_SYNTHETIC, INST_OTHER };

ENUM_INSTRUMENT GetInstrumentType()
{
   string s = Symbol();
   // Deriv synthetic volatility indices come in long-form ("Volatility 75 Index",
   // "Volatility 100 (1s) Index") and whitelabel short-form ("VOL_75", "VOL_100_1S").
   // Check before the forex length fallback so the long form doesn't fall through.
   if(StringFind(s,"Volatility")>=0 || StringFind(s,"VOL_")>=0)                 return INST_SYNTHETIC;
   if(StringFind(s,"XAG")>=0 || StringFind(s,"SILVER")>=0)                     return INST_SILVER;
   if(StringFind(s,"XAU")>=0 || StringFind(s,"GOLD")>=0)                       return INST_GOLD;
   if(StringFind(s,"BTC")>=0 || StringFind(s,"ETH")>=0 ||
      StringFind(s,"LTC")>=0 || StringFind(s,"XRP")>=0)                        return INST_CRYPTO;
   if(StringFind(s,"US30")>=0 || StringFind(s,"DJ30")>=0 ||
      StringFind(s,"DOW")>=0  || StringFind(s,"WS30")>=0 ||
      StringFind(s,"NAS")>=0  || StringFind(s,"SPX")>=0  ||
      StringFind(s,"US500")>=0|| StringFind(s,"SP500")>=0||
      StringFind(s,"DAX")>=0  || StringFind(s,"FTSE")>=0 ||
      StringFind(s,"GER")>=0  || StringFind(s,"UK100")>=0)                     return INST_INDEX;
   if(StringLen(s)==6 || StringLen(s)==7)                                       return INST_FOREX;
   return INST_OTHER;
}

string InstrumentName()
{
   switch(GetInstrumentType())
   {
      case INST_GOLD:      return "GOLD";
      case INST_SILVER:    return "SILVER";
      case INST_CRYPTO:    return "CRYPTO";
      case INST_INDEX:     return "INDEX";
      case INST_SYNTHETIC: return "VOL INDEX";
      case INST_FOREX:     return "FOREX";
      default:             return "CFD";
   }
}

int PriceDecimals()
{
   switch(GetInstrumentType())
   {
      case INST_INDEX:     return 2;
      case INST_GOLD:      return 2;
      case INST_SILVER:    return 3;
      case INST_CRYPTO:    return 2;
      // Synthetic digits vary per index (V10/V25/V75/V100 and their 1s variants
      // each have their own precision). Defer to _Digits which MT5 sets per
      // symbol — explicit case documents that this is intentional, not a fall-
      // through.
      case INST_SYNTHETIC: return _Digits;
      default:             return _Digits;
   }
}

string FmtPrice(double p) { return DoubleToString(p, PriceDecimals()); }

//=== SESSION ========================================================
bool IsActiveSession()
{
   // No session filter requested -> trade 24/7 (synthetic-index default).
   if(!LondonSession && !NewYorkSession && !AsianSession) return true;
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   int h = tm.hour;
   if(LondonSession  && h>=LondonOpen && h<LondonClose) return true;
   if(NewYorkSession && h>=NYOpen     && h<NYClose)      return true;
   if(AsianSession   && h>=AsianOpen  && h<AsianClose)   return true;
   return false;
}

//=== S/R ============================================================
double GetSwingHigh(int lb)
{
   double v=0;
   for(int i=1;i<=lb;i++) v=MathMax(v,iHigh(Symbol(),PERIOD_CURRENT,i));
   return v;
}
double GetSwingLow(int lb)
{
   double v=DBL_MAX;
   for(int i=1;i<=lb;i++) v=MathMin(v,iLow(Symbol(),PERIOD_CURRENT,i));
   return v;
}

//=== PRICE ACTION ===================================================
bool IsBullishEngulfing()
{
   double o1=iOpen(Symbol(),PERIOD_CURRENT,1),c1=iClose(Symbol(),PERIOD_CURRENT,1);
   double o2=iOpen(Symbol(),PERIOD_CURRENT,2),c2=iClose(Symbol(),PERIOD_CURRENT,2);
   return(c2<o2&&c1>o1&&o1<=c2&&c1>=o2);
}
bool IsBearishEngulfing()
{
   double o1=iOpen(Symbol(),PERIOD_CURRENT,1),c1=iClose(Symbol(),PERIOD_CURRENT,1);
   double o2=iOpen(Symbol(),PERIOD_CURRENT,2),c2=iClose(Symbol(),PERIOD_CURRENT,2);
   return(c2>o2&&c1<o1&&o1>=c2&&c1<=o2);
}
bool IsBullishPinBar()
{
   double o=iOpen(Symbol(),PERIOD_CURRENT,1),c=iClose(Symbol(),PERIOD_CURRENT,1);
   double h=iHigh(Symbol(),PERIOD_CURRENT,1),l=iLow(Symbol(),PERIOD_CURRENT,1);
   double body=MathAbs(c-o),lower=MathMin(c,o)-l,upper=h-MathMax(c,o);
   return(body>0&&lower>=body*2.0&&upper<=body*0.5);
}
bool IsBearishPinBar()
{
   double o=iOpen(Symbol(),PERIOD_CURRENT,1),c=iClose(Symbol(),PERIOD_CURRENT,1);
   double h=iHigh(Symbol(),PERIOD_CURRENT,1),l=iLow(Symbol(),PERIOD_CURRENT,1);
   double body=MathAbs(c-o),upper=h-MathMax(c,o),lower=MathMin(c,o)-l;
   return(body>0&&upper>=body*2.0&&lower<=body*0.5);
}
bool IsInsideBar()
{
   double h1=iHigh(Symbol(),PERIOD_CURRENT,1),l1=iLow(Symbol(),PERIOD_CURRENT,1);
   double h2=iHigh(Symbol(),PERIOD_CURRENT,2),l2=iLow(Symbol(),PERIOD_CURRENT,2);
   return(h1<h2&&l1>l2);
}

//=== LOT SIZE =======================================================
double NormalizeLot(double lots)
{
   double mn=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   double mx=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   double st=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
   if(st<=0)st=0.01;
   // Step-aware decimal precision. MathFloor(lots/st)*st can land on
   // 0.122999... in float; without a NormalizeDouble lock to the step's
   // digit count, some brokers reject the implied precision. Computing
   // stepDigits from the step itself keeps 0.001-step instruments correct
   // (where a hardcoded NormalizeDouble(_, 2) would round 0.001 -> 0.00).
   int stepDigits = (st >= 1.0) ? 0 : (int)MathCeil(-MathLog10(st));
   if(stepDigits < 0) stepDigits = 0;
   if(stepDigits > 8) stepDigits = 8;
   lots=MathFloor(lots/st)*st;
   lots=MathMax(mn,MathMin(mx,lots));
   return NormalizeDouble(lots, stepDigits);
}
double CalcLotSize(double slDist)
{
   if(ManualLot) return NormalizeLot(FixedLotSize);
   if(slDist<=0) return SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   double tv=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0||ts<=0) return SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   double risk=AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercent/100.0;
   return NormalizeLot(risk/(slDist/ts*tv));
}

// Pre-flight margin check. Without it, oversized lots on low-leverage
// accounts (common on Deriv synthetics) produce retcode 10019 cascades
// from trade.Buy/Sell. Returns true if the order is affordable; logs a
// [SKIP] line and returns false otherwise.
bool HasMarginFor(ENUM_ORDER_TYPE orderType, double lot, double price)
{
   double marginRequired = 0.0;
   if(!OrderCalcMargin(orderType, Symbol(), lot, price, marginRequired))
   {
      Print("[SKIP] OrderCalcMargin failed: ", Symbol(), " err=", GetLastError());
      return false;
   }
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(marginRequired > freeMargin)
   {
      Print("[SKIP] Insufficient margin: need $", DoubleToString(marginRequired,2),
            " have $", DoubleToString(freeMargin,2),
            " for ", DoubleToString(lot,3), " lots on ", Symbol());
      return false;
   }
   return true;
}

//=== POSITION =======================================================
bool HasOpenPosition()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(posInfo.SelectByIndex(i))
         if(posInfo.Symbol()==Symbol()&&posInfo.Magic()==(long)MagicNumber)
            return true;
   return false;
}

//=== TRAILING STOP ==================================================
void ManageTrailingStop()
{
   if(!UseTrailingStop) return;
   double atr=atrBuffer[0];
   if(atr<=0) return;
   double td=atr*TrailATR_Multi, ts=atr*TrailStep_Multi;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol()!=Symbol()||posInfo.Magic()!=(long)MagicNumber) continue;
      double sl=posInfo.StopLoss(),price=posInfo.PriceCurrent();
      if(posInfo.PositionType()==POSITION_TYPE_BUY)
      {
         double nsl=NormalizeDouble(price-td,_Digits);
         if(nsl>sl+ts) trade.PositionModify(posInfo.Ticket(),nsl,posInfo.TakeProfit());
      }
      else
      {
         double nsl=NormalizeDouble(price+td,_Digits);
         if(nsl<sl-ts||sl==0) trade.PositionModify(posInfo.Ticket(),nsl,posInfo.TakeProfit());
      }
   }
}

//=== PERFORMANCE ====================================================
void UpdatePerformanceStats()
{
   if(!HistorySelect(0,TimeCurrent())) return;
   int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      ulong t=HistoryDealGetTicket(i);
      if(t==0||t<=lastDealTicket) continue;
      if(HistoryDealGetInteger(t,DEAL_MAGIC)!=(long)MagicNumber) continue;
      if(HistoryDealGetString(t,DEAL_SYMBOL)!=Symbol()) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(t,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      double p=HistoryDealGetDouble(t,DEAL_PROFIT)
              +HistoryDealGetDouble(t,DEAL_SWAP)
              +HistoryDealGetDouble(t,DEAL_COMMISSION);
      totalTrades++; grossPnL+=p;
      if(p>=0){winTrades++;  totalProfit+=p; if(p>bestTrade)  bestTrade=p;}
      else    {lossTrades++; totalLoss  +=p; if(p<worstTrade) worstTrade=p;}

      // Streak detection. Only runs after OnInit's history backfill has
      // completed, so attaching the EA mid-session doesn't trigger warnings
      // from old deals. Breakeven (|p| <= 0.01) is neutral and does not
      // change the streak — matches the Deriv reference shape and is
      // tighter than the cumulative-stats win/loss split above.
      if(initialStatsLoaded)
      {
         if(p > 0.01)
         {
            if(consecutiveLosses > 0)
               Print("[STREAK] Win — streak reset (was ", consecutiveLosses, ")");
            consecutiveLosses = 0;
            streakWarned      = false;
         }
         else if(p < -0.01)
         {
            consecutiveLosses++;
            if(MaxConsecutiveLosses > 0 && consecutiveLosses >= MaxConsecutiveLosses && !streakWarned)
            {
               lossBlockedSince = TimeCurrent();
               string cooldownTxt = LossCooldownMinutes > 0
                  ? "cooldown " + IntegerToString(LossCooldownMinutes) + " min"
                  : "manual reset required";
               Print("[STOP] Consecutive losses reached (", consecutiveLosses,
                     "/", MaxConsecutiveLosses, ") — ", cooldownTxt,
                     " — signals continue, no new orders.");
               if(PushNotify)
               {
                  string streakPush = StringFormat("%s: %d losses in a row. %s. Signals continue.",
                                                   EA_Name, consecutiveLosses,
                                                   LossCooldownMinutes > 0
                                                      ? "Auto-resume in " + IntegerToString(LossCooldownMinutes) + " min"
                                                      : "Manual reset required");
                  if(StringLen(streakPush) > 250) streakPush = StringSubstr(streakPush, 0, 250);
                  SendNotification(streakPush);
               }
               streakWarned = true;
            }
         }
      }

      lastDealTicket=t;
   }
}

//=== ALERTS =========================================================
void SendAlerts(string dir,double entry,double sl,double tp,double lots)
{
   string mode=AutoTrade?"AUTO-TRADED":"SIGNAL ONLY";
   string ls=ManualLot?StringFormat("%.2f lots (manual)",lots)
                      :StringFormat("%.2f lots (%.1f%% risk)",lots,RiskPercent);
   string msg=StringFormat("%s [%s]\n%s  %s\nEntry : %s\nSL    : %s\nTP    : %s\nLot   : %s",
      EA_Name,mode,Symbol(),dir,FmtPrice(entry),FmtPrice(sl),FmtPrice(tp),ls);

   // Compact push body. MT5 SendNotification has a ~255 char cap and silently
   // drops over-length messages. Today's msg is ~130 chars on short symbols
   // and stays under the limit, but a long broker symbol or future field
   // addition could push it over without warning. Cap defensively here and
   // keep the full msg for Alert/Email/Print.
   string pushBody = StringFormat("%s %s %s E:%s SL:%s TP:%s %s",
                                  EA_Name, dir, Symbol(),
                                  FmtPrice(entry), FmtPrice(sl), FmtPrice(tp), ls);
   if(StringLen(pushBody) > 250) pushBody = StringSubstr(pushBody, 0, 250);

   if(AlertOnSignal) Alert(msg);
   if(PushNotify)    SendNotification(pushBody);
   if(EmailAlert)    SendMail(EA_Name+" | "+Symbol()+" "+dir,msg);
   Print(msg);
}

//=== DASHBOARD ======================================================
// Uses larger font (9pt), wider panel (290px), cleaner section headers
// with solid separator bars drawn as thin rectangles for visual structure

void DrawSeparator(string name,int x,int y,int w)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,1);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,C'45,55,75');
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
}

void DLabel(string name,int x,int y,string txt,color col,int fs,bool bold)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,name,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fs);
   ObjectSetString(0,name,OBJPROP_FONT,bold?"Arial Bold":"Arial");
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
}

void DRect(string name,int x,int y,int w,int h,color bg,color border)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
}

void UpdateDashboard(double res,double sup,double atr,bool sess)
{
   if(!ShowDashboard) return;

   int x=DashX, y=DashY;
   int w=290;          // panel width
   int lh=19;          // row height  (bigger = more readable)
   int fs=9;           // font size
   int pad=10;         // left padding inside panel

   // Row count: 1 title + 1 gap + 11 market rows + 1 sep + 1 gap + 8 perf rows = 23 rows + extras
   int panelH = lh*24 + 28;

   // ── Background panels ──────────────────────────────────────────
   DRect("dp_bg",  x,   y,         w, panelH,      C'13,17,25',  C'40,52,72');
   DRect("dp_hdr", x,   y,         w, lh+10,       C'18,58,130', C'30,80,180');
   DRect("dp_mhdr",x,   y+lh+14,   w, lh+4,        C'20,26,38',  C'40,52,72');
   DRect("dp_phdr",x,   y+lh*14+18,w, lh+4,        C'20,26,38',  C'40,52,72');

   // ── Header ─────────────────────────────────────────────────────
   DLabel("dp_t1", x+pad, y+4,      EA_Name,                    clrWhite,       10, true);
   DLabel("dp_t2", x+pad, y+4,      EA_Name,                    clrWhite,       10, true);
   // symbol + badge right-aligned area
   string badge = Symbol()+" ["+InstrumentName()+"]";
   DLabel("dp_sym",x+130, y+6,      badge,                      C'150,200,255', 9,  false);

   // ── MARKET section header ──────────────────────────────────────
   int r = y+lh+16;
   DLabel("dp_mh", x+pad, r+2,      "  MARKET STATUS",          C'120,160,220', 8,  true);
   r += lh+6;

   bool   inTrade  = HasOpenPosition();
   string modeStr  = AutoTrade ? "AUTO TRADE" : "SIGNAL ONLY";
   string sessStr  = sess      ? "ACTIVE"     : "CLOSED";
   string tradeStr = inTrade   ? "YES"        : "NO";
   string lotStr   = ManualLot ? StringFormat("Fixed %.2f lots",FixedLotSize)
                               : StringFormat("%.1f%% risk / auto lot",RiskPercent);
   string trailStr = UseTrailingStop
                   ? StringFormat("ON   (ATR x %.1f)",TrailATR_Multi)
                   : "OFF";

   color cGreen = C'80,220,120';
   color cRed   = C'230,80,80';
   color cGold  = C'230,185,60';
   color cBlue  = C'100,170,255';
   color cDim   = C'90,100,120';
   color cText  = C'195,200,215';

   color cMode  = AutoTrade ? cGreen : cGold;
   color cSess  = sess      ? cGreen : cRed;
   color cTrade = inTrade   ? cGold  : cDim;
   color cSig   = StringFind(lastSignalDir,"BUY") >=0 ? cGreen
                : StringFind(lastSignalDir,"SELL")>=0 ? cRed : cText;

   // Two-column layout: label on left, value on right
   int lx=x+pad, vx=x+130;

   DLabel("dp_ml1",lx,r,"Mode",    cDim,  fs,false); DLabel("dp_mv1",vx,r,modeStr,  cMode, fs,true);  r+=lh;
   DLabel("dp_ml2",lx,r,"Session", cDim,  fs,false); DLabel("dp_mv2",vx,r,sessStr,  cSess, fs,true);  r+=lh;
   DLabel("dp_ml3",lx,r,"TF",      cDim,  fs,false); DLabel("dp_mv3",vx,r,TFtoString(Period()),cText,fs,false); r+=lh;
   DrawSeparator("dp_sep1",x+pad,r,w-pad*2); r+=4;
   DLabel("dp_ml4",lx,r,"Resist",  cDim,  fs,false); DLabel("dp_mv4",vx,r,FmtPrice(res), cText,fs,false); r+=lh;
   DLabel("dp_ml5",lx,r,"Support", cDim,  fs,false); DLabel("dp_mv5",vx,r,FmtPrice(sup), cText,fs,false); r+=lh;
   DLabel("dp_ml6",lx,r,"ATR",     cDim,  fs,false); DLabel("dp_mv6",vx,r,FmtPrice(atr), cText,fs,false); r+=lh;
   DrawSeparator("dp_sep2",x+pad,r,w-pad*2); r+=4;
   DLabel("dp_ml7",lx,r,"Lot Mode",cDim,  fs,false); DLabel("dp_mv7",vx,r,lotStr,   cBlue, fs,false); r+=lh;
   DLabel("dp_ml8",lx,r,"Trail",   cDim,  fs,false); DLabel("dp_mv8",vx,r,trailStr, UseTrailingStop?cGreen:cDim,fs,false); r+=lh;
   DLabel("dp_ml9",lx,r,"In Trade",cDim,  fs,false); DLabel("dp_mv9",vx,r,tradeStr, cTrade,fs,true);  r+=lh;
   DrawSeparator("dp_sep3",x+pad,r,w-pad*2); r+=6;
   DLabel("dp_mla",lx,r,"Signal",  cDim,  fs,false); DLabel("dp_mva",vx,r,lastSignal,cSig, fs,true);  r+=lh;

   // ── PERFORMANCE section header ─────────────────────────────────
   r+=4;
   DRect("dp_phdr2",x,r,w,lh+4,C'20,26,38',C'40,52,72');
   DLabel("dp_ph", x+pad, r+2, "  PERFORMANCE",  C'120,160,220', 8, true);
   r+=lh+6;

   double winRate = totalTrades>0 ? (double)winTrades/totalTrades*100.0 : 0.0;
   double avgWin  = winTrades >0  ? totalProfit/winTrades  : 0.0;
   double avgLoss = lossTrades>0  ? totalLoss/lossTrades   : 0.0;
   double pf      = (totalLoss!=0)? MathAbs(totalProfit/totalLoss) : 0.0;
   color  cPnL    = grossPnL>=0   ? cGreen : cRed;
   color  cWR     = winRate>=50   ? cGreen : cRed;
   color  cPF     = pf>=1.5       ? cGreen : (pf>=1.0 ? cGold : cRed);

   DLabel("dp_pl1",lx,r,"Trades",  cDim,fs,false);
   DLabel("dp_pv1",vx,r,StringFormat("%d   (W: %d  |  L: %d)",totalTrades,winTrades,lossTrades),cText,fs,false); r+=lh;

   DLabel("dp_pl2",lx,r,"Win Rate",cDim,fs,false);
   DLabel("dp_pv2",vx,r,StringFormat("%.1f%%",winRate),cWR,fs,true); r+=lh;

   DLabel("dp_pl3",lx,r,"Net P&L", cDim,fs,false);
   DLabel("dp_pv3",vx,r,StringFormat("%+.2f",grossPnL),cPnL,fs,true); r+=lh;

   DrawSeparator("dp_sep4",x+pad,r,w-pad*2); r+=4;

   DLabel("dp_pl4",lx,r,"Avg Win", cDim,fs,false);
   DLabel("dp_pv4",vx,r,StringFormat("%+.2f",avgWin),cGreen,fs,false); r+=lh;

   DLabel("dp_pl5",lx,r,"Avg Loss",cDim,fs,false);
   DLabel("dp_pv5",vx,r,StringFormat("%.2f",avgLoss),cRed,fs,false); r+=lh;

   DLabel("dp_pl6",lx,r,"Prof Factor",cDim,fs,false);
   DLabel("dp_pv6",vx,r,StringFormat("%.2f",pf),cPF,fs,true); r+=lh;

   DLabel("dp_pl7",lx,r,"Best Trade",cDim,fs,false);
   DLabel("dp_pv7",vx,r,StringFormat("%+.2f",bestTrade),cGreen,fs,false); r+=lh;

   DLabel("dp_pl8",lx,r,"Worst Trade",cDim,fs,false);
   DLabel("dp_pv8",vx,r,StringFormat("%.2f",worstTrade),cRed,fs,false);

   ChartRedraw();
}

string TFtoString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";  case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15"; case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";  case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";  default:         return "?";
   }
}

void DeleteDashboard()
{
   string n[]={"dp_bg","dp_hdr","dp_mhdr","dp_phdr","dp_phdr2",
               "dp_t1","dp_t2","dp_sym","dp_mh","dp_ph",
               "dp_sep1","dp_sep2","dp_sep3","dp_sep4",
               "dp_ml1","dp_mv1","dp_ml2","dp_mv2","dp_ml3","dp_mv3",
               "dp_ml4","dp_mv4","dp_ml5","dp_mv5","dp_ml6","dp_mv6",
               "dp_ml7","dp_mv7","dp_ml8","dp_mv8","dp_ml9","dp_mv9",
               "dp_mla","dp_mva",
               "dp_pl1","dp_pv1","dp_pl2","dp_pv2","dp_pl3","dp_pv3",
               "dp_pl4","dp_pv4","dp_pl5","dp_pv5","dp_pl6","dp_pv6",
               "dp_pl7","dp_pv7","dp_pl8","dp_pv8"};
   for(int i=0;i<ArraySize(n);i++) ObjectDelete(0,n[i]);
   ChartRedraw();
}

//=== SAFETY: DAILY LOSS LIMIT =======================================
void CheckDailyReset()
{
   // Re-anchor dayStartBalance on day rollover (server day). Also seeds the
   // anchor on first call when lastTradeDay is still 0.
   MqlDateTime dt;     TimeToStruct(TimeCurrent(), dt);
   MqlDateTime lastDt; TimeToStruct(lastTradeDay,  lastDt);
   if(dt.day != lastDt.day || lastTradeDay == 0)
   {
      dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      lastTradeDay    = TimeCurrent();
      dailyLossWarned = false;
      dailyTradeCount = 0;
      maxTradesWarned = false;
   }
}

bool IsLossCooldownActive()
{
   if(MaxConsecutiveLosses <= 0) return false;
   if(consecutiveLosses < MaxConsecutiveLosses) return false;
   if(LossCooldownMinutes > 0 && lossBlockedSince > 0)
   {
      int minsLeft = LossCooldownMinutes - (int)((TimeCurrent() - lossBlockedSince) / 60);
      if(minsLeft <= 0)
      {
         Print("[RESUME] Loss cooldown expired — auto trading resumed.");
         consecutiveLosses = 0;
         lossBlockedSince  = 0;
         streakWarned      = false;
         return false;
      }
      return true;
   }
   // LossCooldownMinutes == 0 -> manual reset, stay blocked.
   return true;
}

bool IsMaxTradesReached()
{
   if(MaxTradesPerDay <= 0) return false;   // 0 disables the cap
   if(dailyTradeCount >= MaxTradesPerDay)
   {
      if(!maxTradesWarned)
      {
         Print("[STOP] Max trades reached (", dailyTradeCount, "/", MaxTradesPerDay,
               ") — signals continue, no new orders today.");
         maxTradesWarned = true;
      }
      return true;
   }
   return false;
}

bool IsDailyLossExceeded()
{
   if(MaxDailyLossPct <= 0) return false;   // 0 disables the cap
   double anchor = (dayStartBalance > 0 ? dayStartBalance : AccountInfoDouble(ACCOUNT_BALANCE));
   double eq     = AccountInfoDouble(ACCOUNT_EQUITY);
   double maxLoss = anchor * MaxDailyLossPct / 100.0;
   if((anchor - eq) >= maxLoss)
   {
      if(!dailyLossWarned)
      {
         Print("[STOP] Daily loss limit hit (", DoubleToString(MaxDailyLossPct,2),
               "% of $", DoubleToString(anchor,2),
               ") equity=$", DoubleToString(eq,2),
               " — no new trades today.");
         dailyLossWarned = true;
      }
      return true;
   }
   return false;
}

//=== INIT ===========================================================
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   atrHandle=iATR(Symbol(),PERIOD_CURRENT,ATR_Period);
   if(atrHandle==INVALID_HANDLE){Alert("ATR init failed");return INIT_FAILED;}
   ArraySetAsSeries(atrBuffer,true);
   UpdatePerformanceStats();
   initialStatsLoaded = true;   // streak detection arms only after history backfill
   CheckDailyReset();
   Print(EA_Name," | ",Symbol()," | ",InstrumentName()," | ",AutoTrade?"AUTO":"SIGNAL ONLY");
   return INIT_SUCCEEDED;
}

//=== DEINIT =========================================================
void OnDeinit(const int reason)
{
   DeleteDashboard();
   IndicatorRelease(atrHandle);
}

//=== TICK ===========================================================
void OnTick()
{
   if(CopyBuffer(atrHandle,0,0,3,atrBuffer)<3) return;
   if(AutoTrade) ManageTrailingStop();
   UpdatePerformanceStats();
   CheckDailyReset();

   if(iTime(Symbol(),PERIOD_CURRENT,0)==lastBarTime) return;
   lastBarTime=iTime(Symbol(),PERIOD_CURRENT,0);

   double atr=atrBuffer[1];
   double buf=atr*ATR_Buffer;
   double res=GetSwingHigh(SwingLookback);
   double sup=GetSwingLow(SwingLookback);
   bool   sess=IsActiveSession();

   lastSignal="WAITING..."; lastSignalDir="";
   UpdateDashboard(res,sup,atr,sess);
   if(!sess||HasOpenPosition()) return;
   if(IsDailyLossExceeded())
   {
      lastSignal = "STOPPED: daily loss limit";
      UpdateDashboard(res,sup,atr,sess);
      return;
   }

   double c1=iClose(Symbol(),PERIOD_CURRENT,1);

   if(TradeBUY && c1>res+buf && (IsBullishEngulfing()||IsBullishPinBar()||IsInsideBar()))
   {
      double entry=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
      double sl   =NormalizeDouble(sup-buf,_Digits);
      double tp   =NormalizeDouble(entry+(entry-sl)*RewardRatio,_Digits);
      double lots =CalcLotSize(entry-sl);
      lastSignalDir="BUY";
      lastSignal=StringFormat("BUY @ %s  SL %s  TP %s",FmtPrice(entry),FmtPrice(sl),FmtPrice(tp));
      SendAlerts("BUY",entry,sl,tp,lots);
      if(AutoTrade&&lots>0 && !IsMaxTradesReached() && !IsLossCooldownActive() && HasMarginFor(ORDER_TYPE_BUY,lots,entry))
      {
         // Capture trade.Buy() return so we only count successful sends
         // (deviates from the Deriv reference which increments unconditionally —
         // candidate for back-port to the Deriv EA).
         if(trade.Buy(lots,Symbol(),entry,sl,tp,"BreakoutPA BUY")) dailyTradeCount++;
      }
      UpdateDashboard(res,sup,atr,sess);
   }

   if(TradeSELL && c1<sup-buf && (IsBearishEngulfing()||IsBearishPinBar()||IsInsideBar()))
   {
      double entry=SymbolInfoDouble(Symbol(),SYMBOL_BID);
      double sl   =NormalizeDouble(res+buf,_Digits);
      double tp   =NormalizeDouble(entry-(sl-entry)*RewardRatio,_Digits);
      double lots =CalcLotSize(sl-entry);
      lastSignalDir="SELL";
      lastSignal=StringFormat("SELL @ %s  SL %s  TP %s",FmtPrice(entry),FmtPrice(sl),FmtPrice(tp));
      SendAlerts("SELL",entry,sl,tp,lots);
      if(AutoTrade&&lots>0 && !IsMaxTradesReached() && !IsLossCooldownActive() && HasMarginFor(ORDER_TYPE_SELL,lots,entry))
      {
         if(trade.Sell(lots,Symbol(),entry,sl,tp,"BreakoutPA SELL")) dailyTradeCount++;
      }
      UpdateDashboard(res,sup,atr,sess);
   }
}
//+------------------------------------------------------------------+

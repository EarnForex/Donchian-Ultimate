//+------------------------------------------------------------------+
//|                                                Donchian Ultimate |
//|                                      Copyright © 2023, EarnForex |
//|                                        https://www.earnforex.com |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2023"
#property link      "https://www.earnforex.com/metatrader-indicators/Donchian-Ultimate/"
#property version   "1.00"
#property icon      "\\Files\\EF-Icon-64x64px.ico"
#property strict

#property description "A classic Donchian Channel indicator with extra features:"
#property description " * MTF support"
#property description " * Multiple boundary calculation options"
#property description " * Support and resistance zones"
#property description " * Alert system"

#property indicator_chart_window
#property indicator_buffers 9
#property indicator_color1 clrGreen
#property indicator_type1 DRAW_LINE
#property indicator_width1 2
#property indicator_label1 "Upper Line"
#property indicator_color2 clrRed
#property indicator_type2 DRAW_LINE
#property indicator_width2 2
#property indicator_label2 "Lower Line"
#property indicator_color3 clrPaleGreen
#property indicator_type3 DRAW_HISTOGRAM
#property indicator_style3 STYLE_DOT
#property indicator_width3 1
#property indicator_color4 clrPaleGreen
#property indicator_type4 DRAW_HISTOGRAM
#property indicator_style4 STYLE_DOT
#property indicator_width4 1
#property indicator_color5 clrPaleGreen
#property indicator_type5 DRAW_LINE
#property indicator_width5 1
#property indicator_label5 "Resistance"
#property indicator_color6 clrSalmon
#property indicator_type6 DRAW_LINE
#property indicator_width6 1
#property indicator_label6 "Support"
#property indicator_color7 clrSalmon
#property indicator_type7 DRAW_HISTOGRAM
#property indicator_style7 STYLE_DOT
#property indicator_width7 1
#property indicator_color8 clrSalmon
#property indicator_type8 DRAW_HISTOGRAM
#property indicator_style8 STYLE_DOT
#property indicator_width8 1
#property indicator_color9 clrBlue
#property indicator_type9 DRAW_LINE
#property indicator_width9 1
#property indicator_label9 "Mid Line"

// Enumeration for price type:
enum ENUM_PRICE_TYPE
{
    PRICE_HH_LL, // Highest High (Lowest Low)
    PRICE_AVER_HHHO_LLLO, // Average Highest High, Highest Open (Lowest Low, Lowest Open)
    PRICE_AVER_HHHC_LLLC, // Average Highest High, Highest Close (Lowest Low, Lowest Close)
    PRICE_HO_LO, // Highest Open (Lowest Open)
    PRICE_HC_LC // Highest Close (Lowest Close)
};

// Enumeration for alert candle:
enum ENUM_ALERT_CANDLE
{
    ALERT_PREVIOUS_CANDLE, // Previous
    ALERT_CURRENT_CANDLE // Current
};

input int IndPeriod = 20; // Period
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // Timeframe
input ENUM_PRICE_TYPE PriceType = PRICE_HH_LL;
input int Shift = 0;
input bool IsShowResistanceSpan = true; // Show Resistance Span
input bool IsShowSupportSpan = true; // Show Support Span
input ENUM_ALERT_CANDLE AlertCandle = ALERT_PREVIOUS_CANDLE; // Alert Candle
input bool IsAlertMidLineBullishCrossing = true; // Alert About Bullish Crossing of Mid Line
input bool IsAlertMidLineBearishCrossing = true; // Alert About Bearish Crossing of Mid Line
input bool IsAlertCandleCloseInsideResistance = true; // Alert About Candle Close Inside Resistance
input bool IsAlertCandleCloseInsideSupport = true; // Alert About Candle Close Inside Support
input bool IsShowAlert = false; // Show Alert
input bool IsSendEmail = false; // Send Email
input bool IsSendNotification = false; // Send Notification

double UpBuffer[];
double DownBuffer[];
double ResistanceBuffer[];
double SupportBuffer[];
double ResistanceFillingBuffer[];
double SupportFillingBuffer[];
double MidBuffer[];
double ResistanceFillingAddBuffer[];
double SupportFillingAddBuffer[];

ENUM_TIMEFRAMES Timeframe; // Timeframe of operation
int deltaHighTF; // Difference in candles count from the higher timeframe

// Global variables for alerts
bool IsMidLineBullishCrossing; // Variable for storing that it is bullish crossing of mid line
bool IsMidLineBearishCrossing; // Variable for storing that it is bearish crossing of mid line
bool IsCandleCloseInsideResistance; // Variable for storing that candle closes inside resistance
bool IsCandleCloseInsideSupport; // Variable for storing that candle closes inside support
string MidLineBullishCrossingAlertMessage; // Message for alerting that it is bullish crossing of mid line
string MidLineBearishCrossingAlertMessage; // Message for alerting that it is bearish crossing of mid line
string CandleCloseInsideResistanceAlertMessage; // Message for alerting that candle closes inside resistance
string CandleCloseInsideSupportAlertMessage; // Message for alerting that candle closes inside support
int RatesTotal;
int PrevCalculated;
string AlertPrefix;

int OnInit()
{
    IndicatorDigits(_Digits);
    
    SetIndexBuffer(0, UpBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, DownBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, ResistanceFillingBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, ResistanceFillingAddBuffer, INDICATOR_DATA);
    SetIndexBuffer(4, ResistanceBuffer, INDICATOR_DATA);
    SetIndexBuffer(5, SupportFillingBuffer, INDICATOR_DATA);
    SetIndexBuffer(6, SupportFillingAddBuffer, INDICATOR_DATA);
    SetIndexBuffer(7, SupportBuffer, INDICATOR_DATA);
    SetIndexBuffer(8, MidBuffer, INDICATOR_DATA);

    for (int i = 0; i < 9; i++)
    {
        SetIndexDrawBegin(i, IndPeriod - 1 + Shift);
        SetIndexEmptyValue(i, EMPTY_VALUE);
    }

    SetIndexLabel(2, NULL);
    SetIndexLabel(3, NULL);
    SetIndexLabel(6, NULL);
    SetIndexLabel(7, NULL);

    ArraySetAsSeries(UpBuffer, false);
    ArraySetAsSeries(DownBuffer, false);
    ArraySetAsSeries(MidBuffer, false);
    ArraySetAsSeries(ResistanceBuffer, false);
    ArraySetAsSeries(SupportBuffer, false);
    ArraySetAsSeries(ResistanceFillingBuffer, false);
    ArraySetAsSeries(SupportFillingBuffer, false);
    ArraySetAsSeries(ResistanceFillingAddBuffer, false);
    ArraySetAsSeries(SupportFillingAddBuffer, false);

    // Initializing global variables:
    MidLineBullishCrossingAlertMessage = "Bullish Crossing of Mid Line";
    MidLineBearishCrossingAlertMessage = "Bearish Crossing of Mid Line";
    CandleCloseInsideResistanceAlertMessage = "Candle Close Inside Resistance";
    CandleCloseInsideSupportAlertMessage = "Candle Close Inside Support";
    IsMidLineBullishCrossing = false;
    IsMidLineBearishCrossing = false;
    IsCandleCloseInsideResistance = false;
    IsCandleCloseInsideSupport = false;
    RatesTotal = 0;
    PrevCalculated = 0;

    // Setting values for the higher timeframe:
    Timeframe = InpTimeframe;
    if (InpTimeframe < Period())
    {
        Timeframe = (ENUM_TIMEFRAMES)Period();
    }
    AlertPrefix = _Symbol + " @ " + EnumToString((ENUM_TIMEFRAMES)_Period);
    if (Timeframe != Period()) AlertPrefix += " (" + EnumToString(Timeframe) + ") ";
    StringReplace(AlertPrefix, "PERIOD_", "");

    deltaHighTF = 0;
    if (Timeframe > Period())
    {
        deltaHighTF = Timeframe / Period();
    }

    return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if (rates_total < IndPeriod)
    {
        return 0;
    }

    RatesTotal = rates_total;
    PrevCalculated = prev_calculated;

    // Preliminary calculations:
    int pos = prev_calculated - 1 - deltaHighTF;

    int startIndex = IndPeriod - 1 + Shift;
    if (pos < startIndex)
    {
        for (int i = 0; i < startIndex; i++)
        {
            UpBuffer[i] = EMPTY_VALUE;
            DownBuffer[i] = EMPTY_VALUE;
            ResistanceBuffer[i] = EMPTY_VALUE;
            SupportBuffer[i] = EMPTY_VALUE;
            MidBuffer[i] = EMPTY_VALUE;
            ResistanceFillingBuffer[i] = EMPTY_VALUE;
            SupportFillingBuffer[i] = EMPTY_VALUE;
            ResistanceFillingAddBuffer[i] = EMPTY_VALUE;
            SupportFillingAddBuffer[i] = EMPTY_VALUE;
        }
        pos = startIndex;
    }

    for (int i = pos; i < rates_total && !IsStopped(); i++)
    {
        int index = rates_total - 1 - i + Shift;

        UpBuffer[i] = GetUpLineValue(index);
        DownBuffer[i] = GetDownLineValue(index);

        ResistanceBuffer[i] = GetResistanceValue(index);

        if (IsShowResistanceSpan)
        {
            ResistanceFillingAddBuffer[i] = ResistanceBuffer[i];
            ResistanceFillingBuffer[i] = UpBuffer[i];
        }
        else
        {
            ResistanceFillingAddBuffer[i] = EMPTY_VALUE;
            ResistanceFillingBuffer[i] = EMPTY_VALUE;
            ResistanceBuffer[i] = EMPTY_VALUE;
        }

        SupportBuffer[i] = GetSupportValue(index);

        if (IsShowSupportSpan)
        {
            SupportFillingAddBuffer[i] = DownBuffer[i];
            SupportFillingBuffer[i] = SupportBuffer[i];
        }
        else
        {
            SupportFillingAddBuffer[i] = EMPTY_VALUE;
            SupportFillingBuffer[i] = EMPTY_VALUE;
            SupportBuffer[i] = EMPTY_VALUE;
        }

        MidBuffer[i] = (UpBuffer[i] + DownBuffer[i]) / 2;
    }

    HandleAlerts();

    return rates_total;
}

//+------------------------------------------------------------------+
//| Getting the value for the upper Donchian channel line.           |
//+------------------------------------------------------------------+
double GetUpLineValue(int index)
{
    int shift = iBarShift(_Symbol, Timeframe, iTime(_Symbol, PERIOD_CURRENT, index));

    switch(PriceType)
    {
    case PRICE_HH_LL:
        return iHigh(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_HIGH, IndPeriod, shift));
    case PRICE_AVER_HHHO_LLLO:
        return (iHigh(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_HIGH, IndPeriod, shift)) + iOpen(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_OPEN, IndPeriod, shift))) / 2;
    case PRICE_AVER_HHHC_LLLC:
        return (iHigh(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_HIGH, IndPeriod, shift)) + iClose(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_CLOSE, IndPeriod, shift))) / 2;
    case PRICE_HO_LO:
        return iOpen(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_OPEN, IndPeriod, shift));
    case PRICE_HC_LC:
        return iClose(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_CLOSE, IndPeriod, shift));
    default:
        return EMPTY_VALUE;
    }
}

//+------------------------------------------------------------------+
//| Getting the value for the lower Donchian channel line.           |
//+------------------------------------------------------------------+
double GetDownLineValue(int index)
{
    int shift = iBarShift(_Symbol, Timeframe, iTime(_Symbol, PERIOD_CURRENT, index));

    switch(PriceType)
    {
    case PRICE_HH_LL:
        return iLow(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_LOW, IndPeriod, shift));
    case PRICE_AVER_HHHO_LLLO:
        return (iLow(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_LOW, IndPeriod, shift)) + iOpen(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_OPEN, IndPeriod, shift))) / 2;
    case PRICE_AVER_HHHC_LLLC:
        return (iLow(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_LOW, IndPeriod, shift)) + iClose(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_CLOSE, IndPeriod, shift))) / 2;
    case PRICE_HO_LO:
        return iOpen(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_OPEN, IndPeriod, shift));
    case PRICE_HC_LC:
        return iClose(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_CLOSE, IndPeriod, shift));
    default:
        return EMPTY_VALUE;
    }
}

//+------------------------------------------------------------------+
//| Getting the resistance area's lower boundary.                    |
//+------------------------------------------------------------------+
double GetResistanceValue(int index)
{
    int shift = iBarShift(_Symbol, Timeframe, iTime(_Symbol, PERIOD_CURRENT, index));

    switch(PriceType)
    {
    case PRICE_HH_LL:
        return iLow(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_LOW, IndPeriod, shift));
    case PRICE_AVER_HHHO_LLLO:
        return (iLow(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_LOW, IndPeriod, shift)) + iOpen(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_OPEN, IndPeriod, shift))) / 2;
    case PRICE_AVER_HHHC_LLLC:
        return (iLow(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_LOW, IndPeriod, shift)) + iClose(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_CLOSE, IndPeriod, shift))) / 2;
    case PRICE_HO_LO:
    case PRICE_HC_LC:
        return iLow(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_LOW, IndPeriod, shift));
    default:
        return EMPTY_VALUE;
    }
}

//+------------------------------------------------------------------+
//| Getting the support area's upper boundary.                       |
//+------------------------------------------------------------------+
double GetSupportValue(int index)
{
    int shift = iBarShift(_Symbol, Timeframe, iTime(_Symbol, PERIOD_CURRENT, index));

    switch(PriceType)
    {
    case PRICE_HH_LL:
        return iHigh(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_HIGH, IndPeriod, shift));
    case PRICE_AVER_HHHO_LLLO:
        return (iHigh(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_HIGH, IndPeriod, shift)) + iOpen(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_OPEN, IndPeriod, shift))) / 2;
    case PRICE_AVER_HHHC_LLLC:
        return (iHigh(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_HIGH, IndPeriod, shift)) + iClose(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_CLOSE, IndPeriod, shift))) / 2;
    case PRICE_HO_LO:
    case PRICE_HC_LC:
        return iHigh(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_HIGH, IndPeriod, shift));
    default:
        return EMPTY_VALUE;
    }
}

void HandleAlerts()
{
    if ((!IsShowAlert) && (!IsSendEmail) && (!IsSendNotification)) return; // No alerts are needed

    if (!PrevCalculated)
    {
        RefreshGlobalVariables(); // Refresh alert global variables after attaching indicator.
    }
    else if (PrevCalculated != RatesTotal)
    {
        ResetGlobalVariables(); // Reset alert global variables after new candle forming.
    }

    string isMidLineBullishCrossingMessage = NULL;
    string isMidLineBearishCrossingMessage = NULL;
    string isCandleCloseInsideResistanceMessage = NULL;
    string isCandleCloseInsideSupportMessage = NULL;

    // Checking for alerts and saving info about it
    if ((IsAlertMidLineBullishCrossing) &&
            (!IsMidLineBullishCrossing) &&
            (HasMidLineBullishCrossing()))
    {
        isMidLineBullishCrossingMessage = MidLineBullishCrossingAlertMessage;
        IsMidLineBullishCrossing = true;
    }

    if ((IsAlertMidLineBearishCrossing) &&
            (!IsMidLineBearishCrossing) &&
            (HasMidLineBearishCrossing()))
    {
        isMidLineBearishCrossingMessage = MidLineBearishCrossingAlertMessage;
        IsMidLineBearishCrossing = true;
    }

    if ((IsAlertCandleCloseInsideResistance) &&
            (!IsCandleCloseInsideResistance) &&
            (HasCandleCloseInsideResistance()))
    {
        isCandleCloseInsideResistanceMessage = CandleCloseInsideResistanceAlertMessage;
        IsCandleCloseInsideResistance = true;
    }

    if ((IsAlertCandleCloseInsideSupport) &&
            (!IsCandleCloseInsideSupport) &&
            (HasCandleCloseInsideSupport()))
    {
        isCandleCloseInsideSupportMessage = CandleCloseInsideSupportAlertMessage;
        IsCandleCloseInsideSupport = true;
    }

    IssueAlerts(isMidLineBullishCrossingMessage);
    IssueAlerts(isMidLineBearishCrossingMessage);
    IssueAlerts(isCandleCloseInsideResistanceMessage);
    IssueAlerts(isCandleCloseInsideSupportMessage);
}

void IssueAlerts(string message)
{
    if (message == NULL) return;

    message = "[DU] " + AlertPrefix + message;

    if (IsShowAlert)
    {
        Alert(message);
    }
    if (IsSendEmail)
    {
        SendMail("Donchian Ultimate Alert", message);
    }
    if (IsSendNotification)
    {
        SendNotification(message);
    }
}

//+------------------------------------------------------------------+
//| Checking if there is a mid line bullish crossing.                |
//+------------------------------------------------------------------+
bool HasMidLineBullishCrossing()
{
    int shift = AlertCandle == ALERT_PREVIOUS_CANDLE ? 1 : 0;
    int index = RatesTotal - 1 - shift;

    return ((iOpen(_Symbol, PERIOD_CURRENT, shift) < MidBuffer[index]) &&
           (iClose(_Symbol, PERIOD_CURRENT, shift) > MidBuffer[index]));
}

//+------------------------------------------------------------------+
//| Checking if there is a mid line bearish crossing.                |
//+------------------------------------------------------------------+
bool HasMidLineBearishCrossing()
{
    int shift = AlertCandle == ALERT_PREVIOUS_CANDLE ? 1 : 0;
    int index = RatesTotal - 1 - shift;

    return ((iOpen(_Symbol, PERIOD_CURRENT, shift) > MidBuffer[index]) &&
           (iClose(_Symbol, PERIOD_CURRENT, shift) < MidBuffer[index]));
}

//+------------------------------------------------------------------+
//| Checking whether a candle closes inside the resistance area.     |
//+------------------------------------------------------------------+
bool HasCandleCloseInsideResistance()
{
    int shift = AlertCandle == ALERT_PREVIOUS_CANDLE ? 1 : 0;
    int index = RatesTotal - 1 - shift;

    return ((iOpen(_Symbol, PERIOD_CURRENT, shift) < ResistanceBuffer[index]) &&
           (iClose(_Symbol, PERIOD_CURRENT, shift) > ResistanceBuffer[index]) &&
           (iClose(_Symbol, PERIOD_CURRENT, shift) < UpBuffer[index]));
}

//+------------------------------------------------------------------+
//| Checking whether a candle closes inside the support area.        |
//+------------------------------------------------------------------+
bool HasCandleCloseInsideSupport()
{
    int shift = AlertCandle == ALERT_PREVIOUS_CANDLE ? 1 : 0;
    int index = RatesTotal - 1 - shift;

    return ((iOpen(_Symbol, PERIOD_CURRENT, shift) > SupportBuffer[index]) &&
           (iClose(_Symbol, PERIOD_CURRENT, shift) < SupportBuffer[index]) &&
           (iClose(_Symbol, PERIOD_CURRENT, shift) > DownBuffer[index]));
}

void ResetGlobalVariables()
{
    IsMidLineBullishCrossing = false;
    IsMidLineBearishCrossing = false;
    IsCandleCloseInsideResistance = false;
    IsCandleCloseInsideSupport = false;
}

void RefreshGlobalVariables()
{
    IsMidLineBullishCrossing = HasMidLineBullishCrossing();
    IsMidLineBearishCrossing = HasMidLineBearishCrossing();
    IsCandleCloseInsideResistance = HasCandleCloseInsideResistance();
    IsCandleCloseInsideSupport = HasCandleCloseInsideSupport();
}
//+------------------------------------------------------------------+
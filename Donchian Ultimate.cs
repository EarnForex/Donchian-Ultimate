// -------------------------------------------------------------------------------
//   A classic Donchian Channel indicator with extra features:"
//    * MTF support"
//    * Multiple boundary calculation options"
//    * Support and resistance zones"
//    * Alert system"
//   
//   Version 1.00
//   Copyright 2023, EarnForex.com
//   https://www.earnforex.com/metatrader-indicators/Donchian-Ultimate/
// -------------------------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using cAlgo.API;
using cAlgo.API.Collections;
using cAlgo.API.Indicators;
using cAlgo.API.Internals;

namespace cAlgo;

public enum PriceType
{
    PRICE_HH_LL, // Highest High (Lowest Low)
    PRICE_AVER_HHHO_LLLO, // Average Highest High, Highest Open (Lowest Low, Lowest Open)
    PRICE_AVER_HHHC_LLLC, // Average Highest High, Highest Close (Lowest Low, Lowest Close)
    PRICE_HO_LO, // Highest Open (Lowest Open)
    PRICE_HC_LC // Highest Close (Lowest Close)
}

public enum AlertOnCandle
{
    PreviousCandle,
    CurrentCandle
}

public enum AlertType
{
    MidlineBearishClosing,
    MidlineBullishClosing,
    ResistanceClosing,
    SupportClosing
}

[Cloud("Upper Donchian", "Resistance", FirstColor = "Lime", SecondColor = "Lime", Opacity = 0.5)]
[Cloud("Support", "Lower Donchian", FirstColor = "Orange", SecondColor = "Orange", Opacity = 0.5)]
[Indicator(AccessRights = AccessRights.None, IsOverlay = true)]
public class DonchianMtf : Indicator
{
    #region Parameters

    [Parameter("Higher TF")]
    public TimeFrame InputHigherTimeFrame { get; set; }

    [Parameter("Donchian Periods", DefaultValue = 20)]
    public int InputDonchianPeriods { get; set; }

    [Parameter("Price Type", DefaultValue = PriceType.PRICE_HH_LL)]
    public PriceType InputPriceType { get; set; }

    [Parameter("Shift", DefaultValue = 0)] 
    public int InputShift { get; set; }

    [Parameter("Use Alerts", DefaultValue = true, Group = "Alert")]
    public bool InputUseAlerts { get; set; }

    [Parameter("Alert Type", DefaultValue = AlertOnCandle.CurrentCandle, Group = "Alert")]
    public AlertOnCandle InputAlertOnCandle { get; set; }

    [Parameter("Alert About Bullish Crossing of Mid Line", DefaultValue = true, Group = "Alert")]
    public bool InputAlertMidlineBullishCrossing { get; set; }
    
    [Parameter("Alert About Bearish Crossing of Mid Line", DefaultValue = true, Group = "Alert")]
    public bool InputAlertMidlineBearishCrossing { get; set; }

    [Parameter("Alert About Candle Close Inside Resistance", DefaultValue = true, Group = "Alert")]
    public bool InputAlertCandleCloseInsideResistance { get; set; }
    
    [Parameter("Alert About Candle Close Inside Support", DefaultValue = true, Group = "Alert")]
    public bool InputAlertCandleCloseInsideSupport { get; set; }

    [Parameter("Alert PopUp", DefaultValue = false, Group = "Notifications")]
    public bool InputAlertPopUp { get; set; }

    [Parameter("Alert Email", DefaultValue = false, Group = "Notifications")]
    public bool InputAlertEmail { get; set; }

    [Parameter("Email (from)", DefaultValue = "user@mail.com", Group = "Notifications")]
    public string InputEmailFrom { get; set; }

    [Parameter("Email (to)", DefaultValue = "user@mail.com", Group = "Notifications")]
    public string InputEmailTo { get; set; }

    #endregion

    #region Outputs

    [Output("Upper Donchian", LineColor = "CornflowerBlue")] 
    public IndicatorDataSeries OutputUpperDonchian { get; set; }
    
    [Output("Resistance", LineColor = "Green")] 
    public IndicatorDataSeries OutputResistance { get; set; }
    
    [Output("Middle Line", LineColor = "Gray")]
    public IndicatorDataSeries OutputMiddleLine { get; set; }
    
    [Output("Support", LineColor = "Orange")] 
    public IndicatorDataSeries OutputSupport { get; set; }
    
    [Output("Lower Donchian", LineColor = "CornflowerBlue")]
    public IndicatorDataSeries OutputLowerDonchian { get; set; }

    #endregion
    
    private Bars _highTfBars;
    private double _previousClose = double.NaN;
    private int _midlineClosingIndex, _resistanceClosingIndex, _supportClosingIndex;

    protected override void Initialize()
    {
        _highTfBars = MarketData.GetBars(InputHigherTimeFrame <= TimeFrame 
            ? TimeFrame 
            : InputHigherTimeFrame);
    }

    public override void Calculate(int index)
    {
        if (IsLastBar)
        {
            // Need to update last values according to the High TF Bar that hasn't closed yet.
            var highTfIndex = _highTfBars.OpenTimes.GetIndexByTime(Times[index]);
            var startMainIndex = Times.GetIndexByTime(_highTfBars.OpenTimes[highTfIndex]);
            
            for (int i = startMainIndex; i <= index; i++)
            {
                var ind = i + InputShift;
                
                OutputUpperDonchian[ind] = GetUpLineValue(highTfIndex);
                OutputLowerDonchian[ind] = GetDownLineValue(highTfIndex);
            
                OutputResistance[ind] = GetResistanceValue(highTfIndex);
                OutputMiddleLine[ind] = (OutputUpperDonchian[ind] + OutputLowerDonchian[ind]) / 2.0;
                OutputSupport[ind] = GetSupportValue(highTfIndex);   
            }
        }
        else
        {
            var highTfIndex = _highTfBars.OpenTimes.GetIndexByTime(Times[index]);

            index += InputShift;

            OutputUpperDonchian[index] = GetUpLineValue(highTfIndex);
            OutputLowerDonchian[index] = GetDownLineValue(highTfIndex);
        
            OutputResistance[index] = GetResistanceValue(highTfIndex);
            OutputMiddleLine[index] = (OutputUpperDonchian[index] + OutputLowerDonchian[index]) / 2.0;
            OutputSupport[index] = GetSupportValue(highTfIndex);
        }

        if (!InputUseAlerts)
            return;

        if (InputAlertOnCandle == AlertOnCandle.PreviousCandle)
        {
            index--;

            ProcessAlertsForPreviousCandle(index);
        }
        else
        {
            if (!IsLastBar) return;

            ProcessAlertsForCurrentCandle(index);
        }

        _previousClose = Close[index];
    }

    private void ProcessAlertsForCurrentCandle(int index)
    {
        if (double.IsNaN(_previousClose)) return;
        
        if (InputAlertMidlineBearishCrossing && Close[index] <= OutputMiddleLine[index] &&
            _previousClose > OutputMiddleLine[index])
        {
            Alert("Midline Bearish Crossing", "The middle line has crossed below the lower donchian", index,
                AlertType.MidlineBearishClosing);
        }

        if (InputAlertMidlineBullishCrossing && Close[index] >= OutputMiddleLine[index] &&
            _previousClose < OutputMiddleLine[index])
        {
            Alert("Midline Bullish Crossing", "The middle line has crossed above the upper donchian", index,
                AlertType.MidlineBullishClosing);
        }

        if (InputAlertCandleCloseInsideResistance &&
           (Close[index] >= OutputResistance[index] &&    _previousClose < OutputResistance[index] &&
            Close[index] <  OutputUpperDonchian[index] ||
            Close[index] <= OutputUpperDonchian[index] && _previousClose > OutputUpperDonchian[index] &&
            Close[index] >  OutputResistance[index]))
        {
            Alert("Candle Close Inside Resistance", "The candle has closed inside the resistance", index,
                AlertType.ResistanceClosing);
        }

        if (InputAlertCandleCloseInsideSupport &&
           (Close[index] <= OutputSupport[index] &&       _previousClose > OutputSupport[index] &&
            Close[index] >  OutputLowerDonchian[index] ||
            Close[index] >= OutputLowerDonchian[index] && _previousClose < OutputLowerDonchian[index] &&
            Close[index] <  OutputSupport[index]))
        {
            Alert("Candle Close Inside Support", "The candle has closed inside the support", index,
                AlertType.SupportClosing);
        }
    }

    private void ProcessAlertsForPreviousCandle(int index)
    {
        if (InputAlertMidlineBearishCrossing && Close[index] < Open[index] && Close[index] <= OutputMiddleLine[index] &&
            Close[index - 1] > OutputMiddleLine[index - 1])
        {
            Alert("Midline Bearish Crossing", "The middle line has crossed below the lower donchian", index,
                AlertType.MidlineBearishClosing);
        }

        if (InputAlertMidlineBullishCrossing && Close[index] > Open[index] && Close[index] >= OutputMiddleLine[index] &&
            Close[index - 1] < OutputMiddleLine[index - 1])
        {
            Alert("Midline Bullish Crossing", "The middle line has crossed above the upper donchian", index,
                AlertType.MidlineBullishClosing);
        }

        if (InputAlertCandleCloseInsideResistance &&
           (Close[index] >= OutputResistance[index] &&    Close[index - 1] < OutputResistance[index - 1] &&
            Close[index] <  OutputUpperDonchian[index] ||
            Close[index] <= OutputUpperDonchian[index] && Close[index - 1] > OutputUpperDonchian[index - 1] &&
            Close[index] >  OutputResistance[index]))
        {
            Alert("Candle Close Inside Resistance", "The candle has closed inside the resistance", index,
                AlertType.ResistanceClosing);
        }

        if (InputAlertCandleCloseInsideSupport &&
           (Close[index] <= OutputSupport[index] &&       Close[index - 1] > OutputSupport[index - 1] &&
            Close[index] >  OutputLowerDonchian[index] ||
            Close[index] >= OutputLowerDonchian[index] && Close[index - 1] < OutputLowerDonchian[index - 1] &&
            Close[index] <  OutputSupport[index]))
        {
            Alert("Candle Close Inside Support", "The candle has closed inside the support", index,
                AlertType.SupportClosing);
        }
    }

    public void Alert(string tittle, string message, int index, AlertType alertType)
    {
        if (!IsLastBar) return;

        switch (alertType)
        {
            case AlertType.MidlineBearishClosing:
                if (_midlineClosingIndex >= index)
                    return;
                
                _midlineClosingIndex = index;
                break;
            case AlertType.MidlineBullishClosing:
                if (_midlineClosingIndex >= index)
                    return;
                
                _midlineClosingIndex = index;
                break;
            case AlertType.ResistanceClosing:
                if (_resistanceClosingIndex >= index)
                    return;
                
                _resistanceClosingIndex = index;
                break;
            case AlertType.SupportClosing:
                if (_supportClosingIndex >= index)
                    return;
                
                _supportClosingIndex = index;
                break;
            default:
                throw new ArgumentOutOfRangeException(nameof(alertType), alertType, null);
        }
        
        message = $"{message} at Time = {Times[index]} Close = {Close[index]} Index = {index}";
        
        if (InputAlertEmail) 
            Notifications.SendEmail(InputEmailFrom, InputEmailTo, tittle, message);

        if (InputAlertPopUp) 
            MessageBox.Show(tittle, message, MessageBoxButton.OK);
    }
    
    private double GetUpLineValue(int index)
    {
        var highestHighIndex = IndexOfHighest(HHigh, index);
        var highestOpenIndex = IndexOfHighest(HOpen, index);
        var highestCloseIndex = IndexOfHighest(HClose, index);

        return InputPriceType switch
        {
            PriceType.PRICE_HH_LL => HHigh[highestHighIndex],
            PriceType.PRICE_AVER_HHHO_LLLO => (HHigh[highestHighIndex] + HOpen[highestOpenIndex]) / 2.0,
            PriceType.PRICE_AVER_HHHC_LLLC => (HHigh[highestHighIndex] + HClose[highestCloseIndex]) / 2.0,
            PriceType.PRICE_HO_LO => HOpen[highestOpenIndex],
            PriceType.PRICE_HC_LC => HClose[highestCloseIndex],
            _ => throw new ArgumentOutOfRangeException()
        };
    }

    private double GetDownLineValue(int index)
    {
        var lowestLowIndex = IndexOfLowest(HLow, index);
        var lowestOpenIndex = IndexOfLowest(HOpen, index);
        var lowestCloseIndex = IndexOfLowest(HClose, index);

        return InputPriceType switch
        {
            PriceType.PRICE_HH_LL => HLow[lowestLowIndex],
            PriceType.PRICE_AVER_HHHO_LLLO => (HLow[lowestLowIndex] + HOpen[lowestOpenIndex]) / 2.0,
            PriceType.PRICE_AVER_HHHC_LLLC => (HLow[lowestLowIndex] + HClose[lowestCloseIndex]) / 2.0,
            PriceType.PRICE_HO_LO => HOpen[lowestOpenIndex],
            PriceType.PRICE_HC_LC => HClose[lowestCloseIndex],
            _ => throw new ArgumentOutOfRangeException()
        };
    }
    
    private double GetResistanceValue(int index)
    {
        var highestLowIndex = IndexOfHighest(HLow, index);
        var highestCloseIndex = IndexOfHighest(HClose, index);
        var lowestHighIndex = IndexOfLowest(HHigh, index);

        switch (InputPriceType)
        { 
            case PriceType.PRICE_HH_LL:
                return HLow[highestLowIndex];
            
            case PriceType.PRICE_AVER_HHHO_LLLO:
                var highestOpenIndex = IndexOfHighest(HOpen, index);
                return (HLow[highestLowIndex] + HOpen[highestOpenIndex]) / 2.0;

            case PriceType.PRICE_AVER_HHHC_LLLC:
                return (HLow[highestLowIndex] + HClose[highestCloseIndex]) / 2.0;
            
            case PriceType.PRICE_HO_LO:
            case PriceType.PRICE_HC_LC:
                return HHigh[lowestHighIndex];

            default:
                throw new ArgumentOutOfRangeException();
        }
    }
    
    private double GetSupportValue(int index)
    {
        var lowestHighIndex = IndexOfLowest(HHigh, index);
        var lowestOpenIndex = IndexOfLowest(HOpen, index);
        var lowestCloseIndex = IndexOfLowest(HClose, index);
        var highestLowIndex = IndexOfHighest(HLow, index);
        
        switch (InputPriceType)
        {
            case PriceType.PRICE_HH_LL:
                return HHigh[lowestHighIndex];
            
            case PriceType.PRICE_AVER_HHHO_LLLO:
                return (HHigh[lowestHighIndex] + HOpen[lowestOpenIndex]) / 2.0;
            
            case PriceType.PRICE_AVER_HHHC_LLLC:
                return (HHigh[lowestHighIndex] + HClose[lowestCloseIndex]) / 2.0;
            
            case PriceType.PRICE_HO_LO:
            case PriceType.PRICE_HC_LC:
                return HLow[highestLowIndex];
            default:
                throw new ArgumentOutOfRangeException();
        }
    }

    private int IndexOfLowest(DataSeries series, int index)
    {
        var lowestIndex = index;
        
        for (var i = 0; i < InputDonchianPeriods; i++)
        {
            if (series[index - i] < series[lowestIndex])
            {
                lowestIndex = index - i;
            }
        }
        
        return lowestIndex;
    }
    
    private int IndexOfHighest(DataSeries series, int index)
    {
        var highestIndex = index;
        
        for (var i = 0; i < InputDonchianPeriods; i++)
        {
            if (series[index - i] > series[highestIndex])
            {
                highestIndex = index - i;
            }
        }
        
        return highestIndex;
    }

    #region DataSeriesShortcuts

    public DataSeries Open => Bars.OpenPrices;
    public DataSeries High => Bars.HighPrices;
    public DataSeries Low => Bars.LowPrices;
    public DataSeries Close => Bars.ClosePrices;
    public TimeSeries Times => Bars.OpenTimes;
    public int Index => Bars.Count - 1; 
    
    public DataSeries HOpen => _highTfBars.OpenPrices;
    public DataSeries HHigh => _highTfBars.HighPrices;
    public DataSeries HLow => _highTfBars.LowPrices;
    public DataSeries HClose => _highTfBars.ClosePrices;
    public TimeSeries HTimes => _highTfBars.OpenTimes;
    public int HIndex => _highTfBars.Count - 1;

    #endregion
}
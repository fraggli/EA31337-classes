//+------------------------------------------------------------------+
//|                                                EA31337 framework |
//|                       Copyright 2016-2020, 31337 Investments Ltd |
//|                                       https://github.com/EA31337 |
//+------------------------------------------------------------------+

/*
 * This file is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

// Includes.
#include "../Indicator.mqh"

// Structs.
struct RSIParams : IndicatorParams {
  unsigned int period;
  ENUM_APPLIED_PRICE applied_price;
  
  // Struct constructor.
  void RSIParams(const RSIParams& r) {
    period = r.period;
    applied_price = r.applied_price;
  }
  
  void RSIParams(unsigned int _period, ENUM_APPLIED_PRICE _ap) : period(_period), applied_price(_ap) {
    itype = INDI_RSI;
    max_modes = 1;
    SetDataValueType(TYPE_DOUBLE);
  };
};

/**
 * Implements the Relative Strength Index indicator.
 */
class Indi_RSI : public Indicator {
 protected:
  RSIParams params;

 public:
  /**
   * Class constructor.
   */
  Indi_RSI(const RSIParams &_params)
      : params(_params), Indicator((IndicatorParams)_params) {
    params = _params;
  }
  Indi_RSI(const RSIParams &_params, ENUM_TIMEFRAMES _tf)
      : params(_params), Indicator(INDI_RSI, _tf) {
    // @fixit
    params.tf = _tf;
  }

  /**
   * Returns the indicator value.
   *
   * @docs
   * - https://docs.mql4.com/indicators/irsi
   * - https://www.mql5.com/en/docs/indicators/irsi
   */
  static double iRSI(
      string _symbol = NULL, ENUM_TIMEFRAMES _tf = PERIOD_CURRENT, unsigned int _period = 14,
      ENUM_APPLIED_PRICE _applied_price = PRICE_CLOSE,  // (MT4/MT5): PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW,
                                                        // PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED
      int _shift = 0, Indicator *_obj = NULL) {
#ifdef __MQL4__
    return ::iRSI(_symbol, _tf, _period, _applied_price, _shift);
#else  // __MQL5__
    int _handle = Object::IsValid(_obj) ? _obj.GetState().GetHandle() : NULL;
    double _res[];
    if (_handle == NULL || _handle == INVALID_HANDLE) {
      if ((_handle = ::iRSI(_symbol, _tf, _period, _applied_price)) == INVALID_HANDLE) {
        SetUserError(ERR_USER_INVALID_HANDLE);
        return EMPTY_VALUE;
      } else if (Object::IsValid(_obj)) {
        _obj.SetHandle(_handle);
      }
    }
    int _bars_calc = BarsCalculated(_handle);
    if (GetLastError() > 0) {
      return EMPTY_VALUE;
    } else if (_bars_calc <= 2) {
      SetUserError(ERR_USER_INVALID_BUFF_NUM);
      return EMPTY_VALUE;
    }
    if (CopyBuffer(_handle, 0, _shift, 1, _res) < 0) {
      return EMPTY_VALUE;
    }
    return _res[0];
#endif
  }

  /**
   * Calculates RSI on another indicator.
   */
  static double iRSIOnIndicator(Indicator* _indi, string _symbol = NULL, ENUM_TIMEFRAMES _tf = PERIOD_CURRENT, unsigned int _period = 14,
      ENUM_APPLIED_PRICE _applied_price = PRICE_CLOSE,  // (MT4/MT5): PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW,
                                                        // PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED)
    int _shift = 0, Indicator *_obj = NULL) {

    double indi_values[];
    ArrayResize(indi_values, _period);
    
    for (int i = 0; i < (int)_period; ++i)
      indi_values[i] = _indi.GetEntry(_period - (_shift + i) - 1).value.GetValueDbl(_indi.GetParams().idvtype, _obj.GetParams().indi_mode);
      
    double result = iRSIOnArray(indi_values, 0, _period - 1, _shift);
    
    return result;
  }

  /**
   * Calculates RSI on the array of values.
   */
  static double iRSIOnArray(double &array[],int total,int period,int shift)
  {
    #ifdef __MQL4__
      return ::iRSIOnArray(array, total, period, shift);
    #else
      double diff;
      if(total==0)
      total=ArraySize(array);
      int stop=total-shift;
      if(period<=1 || shift<0 || stop<=period)
      return 0;
      bool isSeries=ArrayGetAsSeries(array);
      if(isSeries)
      ArraySetAsSeries(array,false);
      int i;
      double SumP=0;
      double SumN=0;
      for(i=1; i<=period; i++)
      {
      diff=array[i]-array[i-1];
      if(diff>0)
       SumP+=diff;
      else
       SumN+=-diff;
      }
      double AvgP=SumP/period;
      double AvgN=SumN/period;
      for(; i<stop; i++)
      {
      diff=array[i]-array[i-1];
      AvgP=(AvgP*(period-1)+(diff>0?diff:0))/period;
      AvgN=(AvgN*(period-1)+(diff<0?-diff:0))/period;
      }
      double rsi;
      if(AvgN==0.0)
      {
      rsi=(AvgP==0.0 ? 50.0 : 100.0);
      }
      else
      {
      rsi=100.0-(100.0/(1.0+AvgP/AvgN));
      }
      if(isSeries)
      ArraySetAsSeries(array,true);
      return rsi;
    #endif
  }

  /**
   * Returns the indicator's value.
   */
  double GetValue(int _shift = 0) {
    ResetLastError();
    double _value = EMPTY_VALUE;
    switch (params.idstype) {
      case IDATA_BUILTIN:
        istate.handle = istate.is_changed ? INVALID_HANDLE : istate.handle;
        _value = Indi_RSI::iRSI(GetSymbol(), GetTf(), GetPeriod(), GetAppliedPrice(), _shift, GetPointer(this));
        break;
      case IDATA_INDICATOR:
        _value = Indi_RSI::iRSIOnIndicator(params.indi_data, GetSymbol(), GetTf(), GetPeriod(), GetAppliedPrice(), _shift, GetPointer(this));
        if (iparams.is_draw) {
          draw.DrawLineTo(StringFormat("%s_%s", GetName(), IntegerToString(params.idstype)), GetBarTime(_shift), _value, clrCadetBlue, 1);
        }
        break;
      
    }
    istate.is_ready = _LastError == ERR_NO_ERROR;
    istate.is_changed = false;
    return _value;
  }

  /**
   * Returns the indicator's struct value.
   */
  IndicatorDataEntry GetEntry(int _shift = 0) {
    long _bar_time = GetBarTime(_shift);
    unsigned int _position;
    IndicatorDataEntry _entry;
    if (idata.KeyExists(_bar_time, _position)) {
      _entry = idata.GetByPos(_position);
    } else {
      _entry.timestamp = GetBarTime(_shift);
      _entry.value.SetValue(params.idvtype, GetValue(_shift));
      _entry.SetFlag(INDI_ENTRY_FLAG_IS_VALID, !_entry.value.HasValue(params.idvtype, (double) NULL) && !_entry.value.HasValue(params.idvtype, EMPTY_VALUE));
      if (_entry.IsValid())
        idata.Add(_entry, _bar_time);
    }
    return _entry;
  }

  /**
   * Returns the indicator's entry value.
   */
  MqlParam GetEntryValue(int _shift = 0, int _mode = 0) {
    MqlParam _param = {TYPE_DOUBLE};
    _param.double_value = GetEntry(_shift).value.GetValueDbl(params.idvtype, _mode);
    return _param;
  }

  /* Getters */

  /**
   * Get period value.
   */
  unsigned int GetPeriod() { return params.period; }

  /**
   * Get applied price value.
   */
  ENUM_APPLIED_PRICE GetAppliedPrice() { return params.applied_price; }

  /* Setters */

  /**
   * Set period value.
   */
  void SetPeriod(unsigned int _period) {
    istate.is_changed = true;
    params.period = _period;
  }

  /**
   * Set applied price value.
   */
  void SetAppliedPrice(ENUM_APPLIED_PRICE _applied_price) {
    istate.is_changed = true;
    params.applied_price = _applied_price;
  }

  /* Printer methods */

  /**
   * Returns the indicator's value in plain format.
   */
  string ToString(int _shift = 0) { return GetEntry(_shift).value.ToString(params.idvtype); }
};

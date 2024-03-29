{
    --------------------------------------------
    Filename: sensor.temp_rh.htu21d.spin
    Author: Jesse Burt
    Description: Driver for the HTU21D Temp/RH sensor
    Copyright (c) 2022
    Started Jun 16, 2021
    Updated Dec 28, 2022
    See end of file for terms of use.
    --------------------------------------------
}
{ pull in methods common to all Temp/RH drivers }
#include "sensor.temp_rh.common.spinh"

CON

    { I2C }
    SLAVE_WR    = core#SLAVE_ADDR
    SLAVE_RD    = core#SLAVE_ADDR | 1
    DEF_SCL     = 28
    DEF_SDA     = 29
    DEF_HZ      = 100_000

VAR

    long _lastrhvalid, _lasttempvalid
    byte _crccheck

OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef HTU21D_I2C_BC
    i2c : "com.i2c.nocog"                       ' BC I2C engine
#else
    i2c : "com.i2c"                             ' PASM I2C engine
#endif
    core: "core.con.htu21d"                     ' hw-specific low-level const's
    time: "time"                                ' basic timing functions
    crc : "math.crc"

PUB null{}
' This is not a top-level object

PUB start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start using custom IO pins and I2C bus frequency
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ                 ' validate pins and bus freq
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#T_POR)             ' wait for device startup
            if i2c.present(SLAVE_WR)            ' test device bus presence
                return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog 
    return FALSE

PUB stop{}
' Stop the driver
    i2c.deinit{}
    bytefill(@_lastrhvalid, 0, 9)

PUB defaults{}
' Set factory defaults
'   ADC res: RH 12bits / Temp 14bits
'   Heater off
    reset{}

PUB batt_low{}: flag
' Flag indicating battery/supply voltage low
'   Returns:
'       TRUE (-1): VDD < 2.25V (+/- 0.1V)
'       FALSE (0): VDD > 2.25V (+/- 0.1V)
    flag := 0
    readreg(core#RD_USR_REG, 1, @flag)
    return ((flag >> core#BATT) & 1) == 1

PUB crc_check_ena(mode): curr_mode
' Enable CRC check of sensor data
'   Valid values:
'      *TRUE (-1 or 1)
'       FALSE (0)
'   Any other value returns the current setting
    case ||(mode)
        0, 1:
            _crccheck := mode
        other:
            return _crccheck

PUB heater_ena(state): curr_state
' Enable/Disable built-in heater
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: Per HTU21D datasheet, this is for functionality diagnosis only
'   NOTE: Enabling should increase temperature reading by approx 0.5-1.5C
    curr_state := 0
    readreg(core#RD_USR_REG, 1, @curr_state)
    case ||(state)
        0, 1:
            state <<= core#HEATER
        other:
            return (((curr_state >> core#HEATER) & 1) == 1)

    state := ((curr_state & core#HEATER_MASK) | state)
    writereg(core#WR_USR_REG, 1, @state)

PUB last_rh_valid{}: isvalid
' Flag indicating CRC check of last RH measurement was good
    return _lastrhvalid

PUB last_temp_valid{}: isvalid
' Flag indicating CRC check of last temperature measurement was good
    return _lasttempvalid

PUB measure{}
' dummy method

PUB reset{}
' Reset the device
'   NOTE: Soft-reset waits a 15ms delay
    writereg(core#SOFTRESET, 0, 0)
    time.msleep(core#T_POR)

PUB rh_adc_res(r_res): curr_res | adc_bits
' Set RH ADC resolution, in bits
'   Valid values: 8, 10, 11, 12
'       Temp ADC res:   RH ADC res:
'      *14              12
'       12              8
'       13              10
'       11              11
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting also directly affects the temperature ADC resolution
    curr_res := 0
    readreg(core#RD_USR_REG, 1, @curr_res)
    case r_res
        8, 10, 11, 12:
            ' map resolution to reg bits
            ' ADC resolution is in bits 7 and 0
            adc_bits := lookdownz(r_res: 12, 8, 10, 11)
            adc_bits := ((adc_bits & %10) << 6) | (adc_bits & 1)
        other:
            adc_bits := ((curr_res >> 6) & %10) | (curr_res & 1)
            return lookupz(adc_bits: 12, 8, 10, 11)

    r_res := ((curr_res & core#ADCRES_MASK) | adc_bits)
    writereg(core#WR_USR_REG, 1, @r_res)

PUB rh_data{}: rh_adc | crc_in
' Read relative humidity data
'   Returns: u12
    rh_adc := 0

    if (_crccheck)
        readreg(core#RHMEAS_CS, 3, @rh_adc)
        crc_in := rh_adc.byte[0]
        rh_adc >>= 8
        _lastrhvalid := (crc.meas_crc8(@rh_adc, 2) == crc_in)
    else
        readreg(core#RHMEAS_CS, 2, @rh_adc)

PUB rh_word2pct(rh_word): rh
' Convert RH ADC word to percent
'   Returns: relative humidity, in hundredths of a percent
    return ((rh_word * 125_00) / 65536) - 6_00

PUB temp_adc_res(t_res): curr_res | adc_bits
' Set temperature ADC resolution, in bits
'   Valid values: 11..14
'       Temp ADC res:   RH ADC res:
'      *14              12
'       12              8
'       13              10
'       11              11
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting also directly affects the RH ADC resolution
    curr_res := 0
    readreg(core#RD_USR_REG, 1, @curr_res)
    case t_res
        11..14:
            ' map resolution to reg bits
            ' ADC resolution is in bits 7 and 0
            adc_bits := lookdownz(t_res: 14, 12, 13, 11)
            adc_bits := ((adc_bits & %10) << 6) | (adc_bits & 1)
        other:
            adc_bits := ((curr_res >> 6) & %10) | (curr_res & 1)
            return lookupz(adc_bits: 14, 12, 13, 11)

    t_res := ((curr_res & core#ADCRES_MASK) | adc_bits)
    curr_res := t_res
    writereg(core#WR_USR_REG, 1, @t_res)

PUB temp_data{}: temp_adc | crc_in
' Read temperature data
'   Returns: s14
    temp_adc := 0

    if (_crccheck)                              ' CRC checks enabled?
        readreg(core#TEMPMEAS_CS, 3, @temp_adc)
        crc_in := temp_adc.byte[0]              ' cache the CRC from the sensor
        temp_adc := (temp_adc >> 8) & $fffc     ' chop it off the measurement
        _lasttempvalid := (crc.meas_crc8(@temp_adc, 2) == crc_in)
        return ~~temp_adc
    else
        ' no CRC checks; just read the sensor data
        readreg(core#TEMPMEAS_CS, 2, @temp_adc)
        temp_adc &= $fffc                       ' mask off status bits (unused)
        return ~~temp_adc

PUB temp_word2deg(temp_word): temp
' Convert temperature ADC word to temperature
'   Returns: temperature, in hundredths of a degree, in chosen scale
    temp := ((temp_word * 175_72) / 65536) - 46_85
    case _temp_scale
        C:
            return
        F:
            return (temp * 9_00 / 5_00) + 32_00
        other:
            return FALSE

PRI readreg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from the device into ptr_buff
    case reg_nr                                 ' validate register num
        $E3, $E5, $F3, $F5, $E7:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start{}
            i2c.wr_byte(SLAVE_RD)

            { read MSByte to LSByte }
            i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}
    '
        other:                                  ' invalid reg_nr
            return

PRI writereg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes to the device from ptr_buff
    case reg_nr
        $E6, $FE:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)

            { write MSByte to LSByte }
            i2c.wrblock_msbf(ptr_buff, nr_bytes)
            i2c.stop{}
    '
        other:
            return


DAT
{
Copyright 2022 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}


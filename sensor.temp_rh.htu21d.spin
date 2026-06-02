{
----------------------------------------------------------------------------------------------------
    Filename:       sensor.temp_rh.htu21d.spin
    Description:    Driver for the HTU21D Temp/RH sensor
    Author:         Jesse Burt
    Started:        Jun 16, 2021
    Updated:        Jun 2, 2026
    Copyright (c) 2026 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

#include "sensor.temp_rh.common.spinh"          ' use code common to all temp/rh drivers


CON

    { default I/O settings; these can be overridden in the parent object }
    SCL         = 28
    SDA         = 29
    I2C_FREQ    = 100_000
    I2C_ADDR    = 0


    { I2C }
    SLAVE_WR    = core.SLAVE_ADDR
    SLAVE_RD    = core.SLAVE_ADDR | 1


VAR

    long _lastrhvalid, _lasttempvalid
    byte _crccheck


OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef HTU21D_I2C_BC
    i2c:    "com.i2c.nocog"                     ' BC I2C engine
#else
    i2c:    "com.i2c"                           ' PASM I2C engine
#endif
    core:   "core.con.htu21d"                   ' hw-specific low-level const's
    time:   "time"                              ' basic timing functions
    crc:    "math.crc"


PUB null()
' This is not a top-level object


PUB start(): status
' Start using default I/O settings
    return startx(SCL, SDA, I2C_FREQ)


PUB startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start the driver with custom I/O settings
'   SCL_PIN:    I2C clock, 0..31
'   SDA_PIN:    I2C data, 0..31
'   I2C_HZ:     I2C clock speed (max official specification is 400_000 but is unenforced)
'   Returns:
'       cog ID+1 of I2C engine on success (= calling cog ID+1, if the bytecode I2C engine is used)
'       0 on failure
    if ( lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) )
        if ( status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ) )
            time.usleep(core.T_POR)             ' wait for device startup
            if ( i2c.present(SLAVE_WR) )        ' test device bus presence
                return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog 
    return FALSE


PUB stop()
' Stop the driver
    i2c.deinit()
    bytefill(@_lastrhvalid, 0, 9)


PUB defaults()
' Set factory defaults
'   ADC res: RH 12bits / Temp 14bits
'   Heater off
    reset()


PUB batt_low(): l
' Flag indicating battery/supply voltage low
'   Returns:
'       TRUE (-1): VDD < 2.25V (+/- 0.1V)
'       FALSE (0): VDD > 2.25V (+/- 0.1V)
    return ( ( readreg(core.RD_USR_REG) >> core.BATT) & 1) == 1


PUB crc_check_ena(m): cm
' Enable CRC check of sensor data
'   Valid values:
'      *TRUE (-1 or 1)
'       FALSE (0)
'   Any other value returns the current setting
    case abs(m)
        0, 1:
            _crccheck := m
        other:
            return _crccheck


PUB heater_ena(s): cs
' Enable/Disable built-in heater
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: Per HTU21D datasheet, this is for functionality diagnosis only
'   NOTE: Enabling should increase temperature reading by approx 0.5-1.5C
    cs := readreg(core.RD_USR_REG)
    case abs(s)
        0, 1:
            s := ( (cs & core.HEATER_MASK) | (s << core.HEATER) )
            writereg(core.WR_USR_REG, s)
        other:
            return (((cs >> core.HEATER) & 1) == 1)


PUB last_rh_valid(): v
' Flag indicating CRC check of last RH measurement was good
    return _lastrhvalid


PUB last_temp_valid(): v
' Flag indicating CRC check of last temperature measurement was good
    return _lasttempvalid


PUB measure()
' dummy method


PUB reset()
' Reset the device
'   NOTE: Soft-reset waits a 15ms delay
    writereg(core.SOFTRESET, 0, 0)
    time.msleep(core.T_POR)


PUB rh_adc_res(r): cr | b
' Set RH ADC resolution, in bits
'   Valid values: 8, 10, 11, 12
'       Temp ADC res:   RH ADC res:
'      *14              12
'       12              8
'       13              10
'       11              11
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting also directly affects the temperature ADC resolution
    cr := readreg(core.RD_USR_REG)
    case r
        8, 10, 11, 12:
            ' map resolution to reg bits
            ' ADC resolution is in bits 7 and 0
            b := lookdownz(r: 12, 8, 10, 11)
            b := ((b & %10) << 6) | (b & 1)
            r := ((cr & core.ADCRES_MASK) | b)
            writereg(core.WR_USR_REG, r)
        other:
            b := ((cr >> 6) & %10) | (cr & 1)
            return lookupz(b: 12, 8, 10, 11)


PUB rh_data(): r | tmp, crc_rd
' Read relative humidity data
'   Returns: u12
    if ( _crccheck )
        tmp := readreg(core.RHMEAS_CS, 3)
        crc_rd := tmp.byte[0]
        r := (tmp.byte[2] << 8) | tmp.byte[1]
        _lastrhvalid := (crc.meas_crc8(@r, 2) == crc_rd)
    else
        r := readreg(core.RHMEAS_CS, 2)

    return (r & $fffc)                          ' remove 2 status LSBs


PUB rh_word2pct(w): r
' Convert RH ADC word to percent
'   Returns: relative humidity, in hundredths of a percent
    return ( (w * 125_00) / 65536) - 6_00


PUB temp_adc_res(r): cr | b
' Set temperature ADC resolution, in bits
'   Valid values: 11..14
'       Temp ADC res:   RH ADC res:
'      *14              12
'       12              8
'       13              10
'       11              11
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting also directly affects the RH ADC resolution
    cr := readreg(core.RD_USR_REG)
    case r
        11..14:
            ' map resolution to reg bits
            ' ADC resolution is in bits 7 and 0
            b := lookdownz(r: 14, 12, 13, 11)
            b := ((b & %10) << 6) | (b & 1)
            r := ((cr & core.ADCRES_MASK) | b)
            cr := r
            writereg(core.WR_USR_REG, r)
        other:
            b := ((cr >> 6) & %10) | (cr & 1)
            return lookupz(b: 14, 12, 13, 11)


PUB temp_data(): t | crc_rd
' Read temperature data
'   Returns: s14
    if ( _crccheck )                            ' CRC checks enabled?
        t := readreg(core.TEMPMEAS_CS, 3)
        crc_rd := t.byte[0]                     ' cache the CRC from the sensor
        _lasttempvalid := (crc.meas_crc8(@t, 2) == crc_rd)
        t := (t >> 8)                           ' chop it off the measurement
    else
        ' no CRC checks; just read the sensor data
        t := readreg(core.TEMPMEAS_CS, 2)

    t &= $fffc                                  ' mask off status bits (unused)
    return ~~t                                  ' extend sign


PUB temp_word2deg(w): t
' Convert temperature ADC word to temperature
'   Returns: temperature, in hundredths of a degree, in chosen scale
    t := ((w * 175_72) / 65536) - 46_85
    case _temp_scale
        C:
            return
        F:
            return (t * 1_80) + 32_00           ' = t * 9 / 5 + 32  (x100)
        other:
            return FALSE


PRI readreg(reg_nr, len=1): v | cmd_pkt
' Read value(s) from register
    v := 0
    case reg_nr                                 ' validate register num
        $E3, $E5, $F3, $F5, $E7:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start()
            i2c.wr_byte(SLAVE_RD)
            i2c.rdblock_msbf(@v, len, i2c.NAK)
            i2c.stop()
        other:                                  ' invalid reg_nr
            return


PRI writereg(reg_nr, val, len=1) | cmd_pkt
' Write value(s) to register
    cmd_pkt.byte[0] := SLAVE_WR
    cmd_pkt.byte[1] := reg_nr
    i2c.start()
    i2c.wrblock_lsbf(@cmd_pkt, 2)
    if ( reg_nr == core.WR_USR_REG )
        i2c.wrblock_msbf(@val, len)
    i2c.stop()


DAT
{
Copyright 2026 Jesse Burt

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


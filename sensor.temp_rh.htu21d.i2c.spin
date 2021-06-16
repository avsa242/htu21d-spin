{
    --------------------------------------------
    Filename: sensor.temp_rh.htu21d.i2c.spin
    Author: Jesse Burt
    Description: Driver for the HTU21D Temp/RH sensor
    Copyright (c) 2021
    Started Jun 16, 2021
    Updated Jun 16, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR        = core#SLAVE_ADDR
    SLAVE_RD        = core#SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000
    I2C_MAX_FREQ    = core#I2C_MAX_FREQ

    C               = 0
    F               = 1

VAR

    byte _temp_scale

OBJ

' choose an I2C engine below
    i2c : "com.i2c"                             ' PASM I2C engine (up to ~800kHz)
'    i2c : "tiny.com.i2c"                        ' SPIN I2C engine (~40kHz)
    core: "core.con.htu21d"       ' hw-specific low-level const's
    time: "time"                                ' basic timing functions

PUB Null{}
' This is not a top-level object

PUB Start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): status
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

PUB Stop{}

    i2c.deinit{}

PUB Defaults{}
' Set factory defaults

PUB HumData{}: rh_adc
' Read relative humidity data
'   Returns: u16
    rh_adc := 0
    readreg(core#RHMEAS_CS, 2, @rh_adc)

PUB Humidity{}: rh
' Current Relative Humidity, in hundredths of a percent
'   Returns: Integer
'   (e.g., 4762 is equivalent to 47.62%)
    rh := calcrh(humdata{})

PUB Reset{}
' Reset the device
'   NOTE: Soft-reset waits a 15ms delay
    writereg(core#SOFTRESET, 0, 0)
    time.msleep(core#T_POR)

PUB TempData{}: temp_adc | tmp
' Read temperature data
'   Returns: s16
    temp_adc := 0
    readreg(core#TEMPMEAS_CS, 2, @temp_adc)
    temp_adc &= $fffc

PUB Temperature{}: deg
' Current Temperature, in hundredths of a degree
'   Returns: Integer
'   (e.g., 2105 is equivalent to 21.05 deg C)
    return calctemp(tempdata{})

PUB TempScale(scale): curr_scale
' Set temperature scale used by Temperature method
'   Valid values:
'       C (0): Celsius
'       F (1): Fahrenheit
'   Any other value returns the current setting
    case scale
        C, F:
            _temp_scale := scale
        other:
            return _temp_scale

PRI calcRH(rh_word): rh_cal
' RH = -6 + 125 * S_RH / 2^16
    return ((rh_word * 125_00) / 65536) - 6_00

PRI calcTemp(temp_word): temp_cal
' Temp = -46.85+175.72 * S_TEMP / 2^16
    temp_cal := ((temp_word * 175_72) / 65536) - 46_85
    case _temp_scale
        C:
            return
        F:
            return (temp_cal * 9_00 / 5_00) + 32_00
        other:
            return FALSE

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from the device into ptr_buff
    case reg_nr                                 ' validate register num
        $E3, $E5, $F3, $F5, $E7:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start{}
            i2c.wr_byte(SLAVE_RD)

    ' write MSByte to LSByte
            i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}
    '
        other:                                  ' invalid reg_nr
            return

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes to the device from ptr_buff
    case reg_nr
        $E6, $FE:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)

    ' write MSByte to LSByte
            i2c.wrblock_msbf(ptr_buff, nr_bytes)
            i2c.stop{}
    '
        other:
            return


DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}

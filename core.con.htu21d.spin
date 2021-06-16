{
    --------------------------------------------
    Filename: core.con.htu21d.spin
    Author:
    Description:
    Copyright (c) 2021
    Started MMMM DDDD, YYYY
    Updated MMMM DDDD, YYYY
    See end of file for terms of use.
    --------------------------------------------
}

CON

' I2C Configuration
    I2C_MAX_FREQ    = 400_000                   ' device max I2C bus freq
    SLAVE_ADDR      = $40 << 1                  ' 7-bit format slave address
    T_POR           = 15_000                    ' startup time (usecs)


' Register definitions
    TEMPMEAS_CS     = $E3
    RHMEAS_CS       = $E5
    TEMPMEAS        = $F3
    RHMEAS          = $F5
    WR_USR_REG      = $E6
    RD_USR_REG      = $E7
    SOFTRESET       = $FE


PUB Null{}
' This is not a top-level object


# htu21d-spin 
-------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the HTU21D Temperature/RH sensor.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or ~~[p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P)~~. Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection at up to 400kHz
* Read temperature (hundredths of a degree), humidity (hundredths of a percent)
* Enable optional CRC checking of data - read flags indicating last acquired data was valid
* Set sensor resolution
* Enable on-chip heater (intended for diagnosis only - 0.5-1.5C temperature increase)

## Requirements

P1/SPIN1:
* spin-standard-library

~~P2/SPIN2:~~
* ~~p2-spin-standard-library~~

## Compiler Compatibility

* P1/SPIN1: OpenSpin (tested with 1.00.81), FlexSpin (tested with 5.5.0)
* ~~P2/SPIN2: FlexSpin (tested with 5.5.0)~~ _(not yet implemented)_
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* Very early in development - may malfunction, or outright fail to build

## TODO

- [x] add support for optional CRC checking
- [x] add support for changing sensor resolution
- [ ] add support for reading battery status
- [x] add support for on-chip heater
- [ ] port to P2/SPIN2

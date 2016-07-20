#
# (C) Copyright 2016 Olliver Schinagl <o.schinagl@ultimaker.com>
#
# SPDX-License-Identifier:	AGPL-3.0+
#
# GPIO's are connected as follows:
#
# LED's
# PH2 (226) is connected to the green Olimex board LED
# PH20 (244) is connected to the amber D2 interface board LED
# PH21 (245) is connected to the amber D1 interface board LED
#
# Loopbacks
# PG6  (198) ------> PB20 (52)
# PC20 (84)  ------> PG7 (199)
# PC21 (85)  ------> PB21 (53)
# PC23 (87)  ------> PC22 (86)
# PI13 (269) ------> PI0 (256)
# PI3  (259) ------> PI1 (257)
# PH0  (224) <--+--> PH7 (321)
#               |
#              \ /
#             LRADC0
#
# Setup
setenv test_status 0
setenv lradc_status -1
setenv status_led "PH2"
setenv result_leds "PH20 PH21"
setenv led_pins ${status_led} ${result_leds}
setenv board_lradc_pin_0 "PH0"
setenv board_lradc_pin_1 "PH7"
setenv board_lradc_pins ${board_lradc_pin_0} ${board_lradc_pin_1}
setenv board_out_normal_pins "PC20 PC21 PG6 PI3 PI13"
setenv board_out_quirky_pins "PC23" # This pin can't be read as input due to a level translator
setenv board_out_pins ${board_out_normal_pins} ${board_out_quirky_pins}
setenv board_in_pins "PB20 PB21 PC22 PG7 PI0 PI1"
setenv board_pins ${board_out_pins} ${board_in_pins}
setenv lradc_cfg "0x1C22800" # Low Resolution Analog Dgital Converter cfg register
setenv lradc_data "0x1C2280C" # LRADC data register
setenv lradc_top "0x37" # Values above indicate both lradc input pins are high
setenv lradc_bottom "0x17" # Values above indicates one lradc input pin is high

# Define some functions

# LRADC functions
# Note that we have to wait for the ADC to settle a bit on the lradc_check and thus the 1 second sleep. Unfortunatly is 1 second the shortest time sleep can handle.
setenv lradc_init 'mw ${lradc_cfg} 0x12C; mw ${lradc_cfg} 0x12D'
setenv lradc_check 'sleep 1; if itest *${lradc_data} -le ${lradc_bottom}; then setenv lradc_status 0; else if itest *${lradc_data} -le ${lradc_top}; then setenv lradc_status 1; else setenv lradc_status 2; fi; fi'

# Pin functions, takes as 'input' an array of ${pins} in the env.
setenv pins_clear 'setenv pin; for pin in ${pins}; do gpio clear ${pin}; done'
setenv pins_set 'setenv pin; for pin in ${pins}; do gpio set ${pin}; done'
setenv pins_clear_check 'setenv pin; for pin in ${pins}; do if gpio input ${pin}; then true; else setenv test_status 1; fi; done'
setenv pin_set_check 'if gpio input ${pin}; then setenv test_status 2; fi'
setenv print_status 'if test ${test_status} -eq 0; then echo "  Test okay"; else echo "  Test failed"; fi'

# Flash status leds
setenv flash_status 'setenv pins ${result_leds}; while true; do run pins_set; sleep 1; run pins_clear; sleep 1; done'


# main

# Briefly flash leds
echo "Starting Olimex Interface Board tests ..."
echo "Enabling status leds to indicate test is running ..."
echo "Expected output: 3 gpio pins value is 1."
setenv pins ${led_pins}
run pins_set
run print_status

# Clear all GPIO's to bring them to a known state.
echo "Clearing all pins ..."
echo "Expected output: All gpio pins value is 0."
setenv pins ${board_out_pins} ${board_in_pins} ${board_lradc_pins}
run pins_clear
run print_status

# Clear leds
echo "Clearing leds, indicating test has begun ..."
echo "Expected output: 3 gpio pins value is 0."
setenv pins ${led_pins}
run pins_clear
run print_status

# Initialize LRADC a little early, so that it is ready for the first test later
echo "Pre-initialize LRADC ..."
echo "Expected output: No output expected."
run lradc_init
run print_status

# Verify all pins are clear
echo "Checking all pins if they are low ..."
echo "Expected output: All pins value is 0."
setenv pins ${board_out_normal_pins} ${board_in_pins}
run pins_clear_check
run print_status

# We can verify quirky pins only once, due to the way they are connected,
# clear it afterwards so we get expected results.
echo "Clearing quirky pins (${board_out_quirky_pins}) ..."
echo "Expected output: quirky pins value is 0."
setenv pins ${board_out_quirky_pins}
run pins_clear_check
echo "Checking quirky pins (${board_out_quirky_pins}) ..."
echo "Expected output: quirky pins value is 0."
run pins_clear
run print_status

# Check LRADC output
echo "Checking ADC no input ..."
echo "Expected output: No output expected."
echo "  If status is failed, ADC value is not low (ADC < 0.75 V)"
setenv pins ${board_out_normal_pins} ${board_in_pins}
run lradc_check
test ${lradc_status} -ne 0 && setenv test_status 1
run print_status

echo "Checking if all pins are still 0."
echo "Expected output: All pins value is 0."
run pins_clear_check

echo "Setting ${board_lradc_pin_0} pin high for ADC test"
gpio set ${board_lradc_pin_0}
echo "Check ADC for 1 input ..."
echo "Expected output: No output expected."
echo "  If status is failed, ADC value is not medium (0.75 < ADC < 2.5 V)"
run lradc_check
test ${lradc_status} -ne 1 && setenv test_status 1
run print_status

echo "Checking if all pins are still 0."
echo "Expected output: All pins value is 0."
run pins_clear_check

echo "Setting ${board_lradc_pin_1} pin high for ADC test"
gpio set ${board_lradc_pin_1}
echo "Check ADC for 2 inputs ..."
echo "Expected output: No output expected."
echo "  If status is failed, ADC value is not high (2.5 V < ADC)"
run lradc_check
test ${lradc_status} -ne 2 && setenv test_status 1
run print_status

echo "Checking if all pins are still 0."
echo "Expected output: All pins value is 0."
run pins_clear_check

setenv pins ${board_lradc_pin_0} ${board_lradc_pin_1}
echo "Setting pins ${pins} low to finish ADC test"
run pins_clear
echo "Check ADC for no input ..."
echo "Expected output: No output expected."
echo "  If status is failed, ADC value is not low (ADC < 0.5 V)"
run lradc_check
test ${lradc_status} -ne 0 && setenv test_status 1
run print_status

echo "Checking if both ADC input pins are still 0..."
echo "Expected output: All pins value is 0."
run pins_clear_check
run print_status

echo "Clearing all board pins..."
echo "Expected output: All pins value is 0."
setenv pins ${board_pins}
run pins_clear
echo "Checking all board input pins..."
echo "Expected output: All pins value is 0."
setenv pins ${board_in_pins}
run pins_clear_check
run print_status

echo "Checking PG6 (output) -> PB20 (input)"
echo "  Setting output high ..."
gpio set "PG6"
echo "  Checking input is high ..."
echo "  Expected output: input value is 1."
setenv pin "PB20"
run pin_set_check
echo "  Checking remaining pins ..."
echo "  Expected output: All pins value is 0."
setenv pins "PG7 PB21 PC22 PI0 PI1"
run pins_clear_check
echo "  Clearing output"
gpio clear "PG6"
run print_status

echo "Checking all board input pins..."
echo "Expected output: All pins value is 0."
setenv pins ${board_in_pins}
run pins_clear_check
run print_status

echo "Checking PC20 (output) -> PG7 (input)"
echo "  Setting output high ..."
gpio set "PC20"
echo "  Checking input is high ..."
echo "  Expected output: input value is 1."
setenv pin "PG7"
run pin_set_check
echo "  Checking remaining pins ..."
echo "  Expected output: All pins value is 0."
setenv pins "PB20 PB21 PC22 PI0 PI1"
run pins_clear_check
echo "  Clearing output"
gpio clear "PC20"
run print_status

echo "Checking all board input pins..."
echo "Expected output: All pins value is 0."
setenv pins ${board_in_pins}
run pins_clear_check
run print_status

echo "Checking PC21 (output) -> PB21 (input)"
echo "  Setting output high ..."
gpio set "PC21"
echo "  Checking input is high ..."
echo "  Expected output: input value is 1."
setenv pin "PB21"
run pin_set_check
echo "  Checking remaining pins ..."
echo "  Expected output: All pins value is 0."
setenv pins "PB20 PG7 PC22 PI0 PI1"
run pins_clear_check
echo "  Clearing output"
gpio clear "PC21"
run print_status

echo "Checking all board input pins..."
echo "Expected output: All pins value is 0."
setenv pins ${board_in_pins}
run pins_clear_check
run print_status

echo "Checking PC23 (output) -> PC22 (input)"
echo "  Setting output high ..."
gpio set "PC23"
echo "  Checking input is high ..."
echo "  Expected output: input value is 1."
setenv pin "PC22"
run pin_set_check
echo "  Checking remaining pins ..."
echo "  Expected output: All pins value is 0."
setenv pins "PB20 PG7 PB21 PI0 PI1"
run pins_clear_check
echo "  Clearing output"
gpio clear "PC23"
run print_status

echo "Checking all board input pins..."
echo "Expected output: All pins value is 0."
setenv pins ${board_in_pins}
run pins_clear_check
run print_status

echo "Checking PI13 (output) -> PI0 (input)"
echo "  Setting output high ..."
gpio set "PI13"
echo "  Checking input is high ..."
echo "  Expected output: input value is 1."
setenv pin "PI0"
run pin_set_check
echo "  Checking remaining pins ..."
echo "  Expected output: All pins value is 0."
setenv pins "PB20 PG7 PB21 PC22 PI1"
run pins_clear_check
echo "  Clearing output"
gpio clear "PI13"
run print_status

echo "Checking all board input pins..."
echo "Expected output: All pins value is 0."
setenv pins ${board_in_pins}
run pins_clear_check
run print_status

echo "Checking PI3 (output) -> PI1 (input)"
echo "  Setting output high ..."
gpio set "PI3"
echo "  Checking input is high ..."
echo "  Expected output: input value is 1."
setenv pin "PI1"
run pin_set_check
echo "  Checking remaining pins ..."
echo "  Expected output: All pins value is 0."
setenv pins "PB20 PG7 PB21 PC22 PI0"
run pins_clear_check
echo "  Clearing output"
gpio clear "PI3"
run print_status

echo "Checking all board input pins..."
echo "Expected output: All pins value is 0."
setenv pins ${board_in_pins}
run pins_clear_check
run print_status

echo "Done testing all pins"
gpio set ${status_led};
if test ${test_status} -eq 0; then echo "All tests okay (Ignore the SCRIPT FAILED message below)."; else run flash_status; echo "One or more tests failed"; fi

exit

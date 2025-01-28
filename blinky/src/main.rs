// Based on https://github.com/esp-rs/esp-hal/blob/fbc57542a8f4b71e30f0dcea4045c508ce753139/examples/src/bin/blinky.rs
// The example was removed in 0.22.0
// See: https://github.com/esp-rs/esp-hal/pull/2538

//! Blinks an LED
//!
//! The following wiring is assumed:
//! - LED => GPIO10

//% CHIPS: esp32 esp32c2 esp32c3 esp32c6 esp32h2 esp32s2 esp32s3

#![no_std]
#![no_main]

use esp_backtrace as _;
use esp_println::println;
use esp_hal::{
    delay::Delay,
    gpio::{Level, Output},
    main,
    time::ExtU64,
};

#[main]
fn main() -> ! {
    let peripherals = esp_hal::init(esp_hal::Config::default());

    println!("Hello world!");

    // Set GPIO10 as an output, and set its state high initially.
    let mut led = Output::new(peripherals.GPIO10, Level::High);

    let delay = Delay::new();

    loop {
        led.toggle();
        delay.delay_millis(500);
        led.toggle();
        // or using `fugit` duration
        delay.delay(1u64.secs());
    }
}

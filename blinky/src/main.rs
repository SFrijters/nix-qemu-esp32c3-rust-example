#![no_std]
#![no_main]

use esp_backtrace as _;
use esp_println::println;
use esp_hal::{peripherals::Peripherals, system::SystemControl, clock::ClockControl, delay::Delay, gpio::{Io, Level, Output}, entry};

#[entry]
fn main() -> ! {
    let peripherals = Peripherals::take();
    let system = SystemControl::new(peripherals.SYSTEM);
    let clocks = ClockControl::boot_defaults(system.clock_control).freeze();

    println!("Hello world!");

    // Set GPIO7 as an output, and set its state high initially.
    let io = Io::new(peripherals.GPIO, peripherals.IO_MUX);
    let mut led = Output::new(io.pins.gpio7, Level::High);

    led.set_high();

    // Initialize the Delay peripheral, and use it to toggle the LED state in a
    // loop.
    let delay = Delay::new(&clocks);

    loop {
        led.toggle();
        delay.delay_millis(500u32);
    }
}

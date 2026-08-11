// mandelbrot <size> <max_iterations>


fn main() {
    let mut args = std::env::args().skip(1);

    let size: usize = args
        .next()
        .expect("invalid usage. usage: mandelbrot <size> <max iterations>")
        .parse()
        .expect("error: given size is a negativve number");

    let max_iterations: u64 = args
        .next()
        .expect("invalid usage. usage: mandelbrot <size> <max iterations>")
        .parse()
        .expect("error: given max iterations is a negative number");

    let mut counter: u64 = 0;

    let divisor: f64 = size as f64;

    for j in 0..size {
        // imaginary
        let cy: f64 = -2.0 + 4.0 * (j as f64) / divisor;

        for i in 0..size {
            // real
            let cx: f64 = -2.0 + 4.0 * (i as f64) / divisor;

            let mut zx: f64 = 0.0;
            let mut zy: f64 = 0.0;

            let mut iterations: u64 = 0;
            loop {
                let ztemp: f64 = zx * zx - zy * zy + cx;
                zy = 2.0 * zx * zy + cy;
                zx = ztemp;

                iterations += 1;
                if iterations >= max_iterations || 
                    zx * zx + zy * zy >= 4.0
                {
                    break;
                }
            }

            counter += iterations;
        }
    }

    // The final result not used naywhere else 
    // since this is a bnechmark
    // This prevents Rust from optimizing away the computation.
    std::hint::black_box(counter);
}

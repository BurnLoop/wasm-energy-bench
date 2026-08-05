use std::env;

fn main() {
    let n: usize = env::args()
        .nth(1)
        .expect("invalid usage. expected: matmul <matrix size>")
        .parse()
        .expect("error: matrix size must be a positive number");

    // matrices are stored in 1D vectors for better
    // cache effieicny (continous memory)
    // Common implementation best practice form computer graphics world
    let mut a: Vec<f64> = vec![0.0f64; n * n];
    let mut b: Vec<f64> = vec![0.0f64; n * n];
    let mut result: Vec<f64> = vec![0.0f64; n * n];

    // Initialize with values
    for i in 0..n {
        for j in 0..n {
            a[i * n + j] = 0.64 * ((i + j) as f64);
            b[i * n + j] = 0.33 * ((i * j + 1) as f64);
        }
    }

    // Perform multiplication
    for i in 0..n {
        for k in 0..n {
            for j in 0..n {
                result[i * n + j] += a[i * n + k] * b[k * n + j];
            }
        }
    }

    // This is to prevent the optimzier from discarding
    // the entire computation as we do not use the value 
    // anwyhere else.
    std::hint::black_box(&result);
}

// ileio <num_blocks> <directory>   
// Each block is 64B
// This is primarily used to test syscall overhead thourgh file
// opeartions so block is deliberately small.

use std::env;
use std::fs::{remove_file, File};
use std::io::{Read, Write};
use std::path::PathBuf;


const BLOCK_SIZE: usize = 64;
const DATA: &[u8; BLOCK_SIZE] = b"Benchmarking serverless file io with WebAssembly and WASI......\n";

fn main() {
    let mut args = env::args().skip(1);

    let num_blocks: u64 = args
        .next()
        .expect("invalid usage. expected: fileio <num_blocks> <directory>")
        .parse()
        .expect("error: num_blocks must be a positive number");

    let dir = args
        .next()
        .expect("invalid usage. expected: fileio <num_blocks> <directory>");

    let mut path = PathBuf::from(&dir);
    path.push("bench_io.txt");

    // Write data
    {
        let mut file = File::create(&path)
            .expect("FAILED TO CREATE FILE!");

        for _ in 0..num_blocks {
            file.write_all(DATA).expect("WRITE FAILED!");
        }
    }

    // REad
    {
        let mut file = File::open(&path).expect("FAILED TO OPEN FILE!");
        let mut read_buffer = [0u8; BLOCK_SIZE];

        loop {
            let n = file.read(&mut read_buffer).expect("READ FAILED!");
            // EOF reached
            if n == 0 {
                break;
            }
        }
    }

    remove_file(&path).expect("FAILED TO DELETE FILE!");
}

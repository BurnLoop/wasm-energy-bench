// image_processing <png image> <output image size> <output_directory>

use std::env;
use std::path::PathBuf;

use image::imageops::FilterType;

fn main() {
    let mut args = env::args().skip(1);

    let input_img_path = args
        .next()
        .expect("invalid usage.Usage: image_processing <png image> <output image size> <output_dir>");

    let final_img_size: u32 = args
        .next()
        .expect("invalid usage. Usage: image_processing <png image> <output image size> <output_dir>")
        .parse()
        .expect("error: size must be a positive number");

    let output_directory = args
        .next()
        .expect("invalid usage. Usage: image_processing <png image> <output image size> <output_dir>");

    let mut output_path = PathBuf::from(
        &output_directory);
    output_path.push("thumb.png");


    let original_image = image::open(&input_img_path)
        .expect("failed to open image");

    let rotated_image = original_image.rotate90();
    let resized_image = rotated_image.resize_to_fill(
        final_img_size, 
        final_img_size, 
        FilterType::Lanczos3);

    // Downcsscaling blurs image so apply a sharpening effect.
    let sharpened_image = resized_image.unsharpen(2.0, 10);

    sharpened_image
        .save(&output_path)
        .expect("failed to save the final processed image");
}

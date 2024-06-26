#### Colour space conversion functions ####

#### RGB to hex and hex to RGB
#' Convert RGB colour channels to hex colour codes.
#' @importFrom stringr str_pad
#' @export
#' @param rgb A dataframe or matrix with red, green and blue colour channels located in the columns 1 to 3, respectively. Colour channel values should be between 0 and 255, inclusive.
#' @return A character vector with hex representations of RGB colour channels.
#' @examples
#' red <- sample(x = 1:255, size = 10, replace = TRUE)
#' green <- sample(x = 1:255, size = 10, replace = TRUE)
#' blue <- sample(x = 1:255, size = 10, replace = TRUE)
#' rgb_to_hex(data.frame(r = red, g = green, b = blue))
rgb_to_hex <- function(rgb) {

    # Extract colour channels from first three colummns
    red <- unlist(rgb[ , 1], FALSE, FALSE)
    green <- unlist(rgb[ , 2], FALSE, FALSE)
    blue <- unlist(rgb[ , 3], FALSE, FALSE)

    # Test if any RGB values are outside of [0, 255]
    if (
        any(red < 0 | red > 255) |
        any(green < 0 | green > 255) |
        any(blue < 0 | blue > 255)
        ) {
        stop("Colour channels should be between 0 and 255.")
    }

    # Convert colour channels to hex
    hex_value <- paste0(
        "#",
        # Convert red
        str_pad(
            string = as.hexmode(round(red, 0)),
            width = 2, pad = "0", side = "left"
            ),
        # Convert green
        str_pad(
            string = as.hexmode(round(green, 0)),
            width = 2, pad = "0", side = "left"
            ),
        # Convert blue
        str_pad(
            string = as.hexmode(round(blue, 0)),
            width = 2, pad = "0", side = "left"
            )
        )

    return(hex_value)
}

#### Convert hexadecimal colours to RGB
#' Convert hexadecimal colours to RGB colour channels.
#' @export
#' @param hex A character vector containing hex representations of RGB colours.
#' @return A \code{tibble} of red, green and blue colour channels.
#' @examples
#' hex_to_rgb(c("#5f9e3a"))
hex_to_rgb <- function(hex) {

    # Take out any #s
    stripped <- gsub(pattern = "#", replacement = "", x = hex)

    # Test character length - each channel needs two hex digits
    if (!all(nchar(stripped) == 6)) {
        bad_colours <- which(nchar(stripped) != 6)
        stop(paste("The following colours do not have six digits:\n", paste(bad_colours, collapse = ", ")))
    }

    # Test all parse to numeric
    if (any(is.na(strtoi(paste0("0x", stripped))))) {
        bad_colours <- which(is.na(strtoi(paste0("0x", stripped))))
        stop(paste("The following colours do not parse from hex to decimal:\n", paste(bad_colours, collapse = ", ")))
    }

    return(
        tibble(
            red = strtoi(paste0("0x", substr(stripped, 1, 2))),
            green = strtoi(paste0("0x", substr(stripped, 3, 4))),
            blue = strtoi(paste0("0x", substr(stripped, 5, 6)))
            )
        )

}

#### RGB to XYZ to RGB
#' Convert from RGB colour channels to XYZ space.
#' @export
#' @importFrom methods is
#' @param rgb A dataframe or matrix with red, green and blue colour channels located in the columns 1 to 3, respectively. Colour channel values should be between 0 and 255, inclusive.
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A \code{tibble} of X, Y and Z colour channels.
#' @examples
#' red <- sample(x = 1:255, size = 10, replace = TRUE)
#' green <- sample(x = 1:255, size = 10, replace = TRUE)
#' blue <- sample(x = 1:255, size = 10, replace = TRUE)
#' rgb_to_xyz(data.frame(r = red, g = green, b = blue), transformation = "Adobe")
rgb_to_xyz <- function(rgb, transformation = "sRGB", linear_func = NULL) {

    # Extract transformation matrix or default matrix
    if (is(transformation, "matrix")) {
        if (all(dim(transformation) == c(3L, 3L))) {
            m <- transformation
        } else {
            stop("Transformation should be a 3x3 matrix.")
        }
    } else {
        transformation_match <- match.arg(transformation, names(transformation_matrix), several.ok = FALSE)
        m <- transformation_matrix[[transformation_match]]
    }

    # Unlist RGB from data structure
    temp_r <- unlist(rgb[ , 1], FALSE, FALSE) / 255
    temp_g <- unlist(rgb[ , 2], FALSE, FALSE) / 255
    temp_b <- unlist(rgb[ , 3], FALSE, FALSE) / 255


    # Convert RGB space to linear space
    if (transformation_match == "sRGB") {
        temp_r <- srgb_transformation(temp_r)
        temp_g <- srgb_transformation(temp_g)
        temp_b <- srgb_transformation(temp_b)
    } else if (transformation_match == "Adobe") {
        temp_r <- adobe_transformation(temp_r)
        temp_g <- adobe_transformation(temp_g)
        temp_b <- adobe_transformation(temp_b)
    } else if (!is.null(linear_func)) {
        temp_r <- linear_func(temp_r)
        temp_g <- linear_func(temp_g)
        temp_b <- linear_func(temp_b)
    } else {
        temp_r <- temp_r * 100
        temp_g <- temp_g * 100
        temp_b <- temp_b * 100
    }

    # Apply linear transformation for RGB to XYZ
    xyz <- tibble(
        x = temp_r * m[1, 1] + temp_g * m[1, 2] + temp_b * m[1, 3],
        y = temp_r * m[2, 1] + temp_g * m[2, 2] + temp_b * m[2, 3],
        z = temp_r * m[3, 1] + temp_g * m[3, 2] + temp_b * m[3, 3]
        )

    return(xyz)

}

# Conversion from XYZ space to RGB space
#' Convert from RGB colour channels to XYZ space.
#' @export
#' @importFrom methods is
#' @param xyz A dataframe or matrix with X, Y and Z colour channels located in the columns 1 to 3, respectively.
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert linear RGB colour space into RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A \code{tibble} of red, green and blue colour channels.
#' @examples
#' x <- sample(x = 40:60, size = 10, replace = TRUE)
#' y <- sample(x = 40:60, size = 10, replace = TRUE)
#' z <- sample(x = 40:60, size = 10, replace = TRUE)
#' xyz_to_rgb(data.frame(x = x, y = y, z = z))
xyz_to_rgb <- function(xyz, transformation = "sRGB", linear_func = NULL) {

    # Extract transformation matrix or default type
    if (is(transformation, "matrix")) {
        if (all(dim(transformation) == c(3L, 3L))) {
            m <- transformation
        } else {
            stop("Transformation should be a 3x3 matrix.")
        }
    } else {
        transformation_match <- match.arg(transformation, names(transformation_matrix), several.ok = FALSE)
        m <- transformation_matrix_inverse[[transformation_match]]
    }

    # Unlist x, y, z from data structure
    temp_x <- unlist(xyz[ , 1], FALSE, FALSE) / 100
    temp_y <- unlist(xyz[ , 2], FALSE, FALSE) / 100
    temp_z <- unlist(xyz[ , 3], FALSE, FALSE) / 100

    # Linear transformation from converted XYZ to RGB
    temp_r <- pmax(temp_x * m[1, 1] + temp_y * m[1, 2] + temp_z * m[1, 3], 0)
    temp_g <- pmax(temp_x * m[2, 1] + temp_y * m[2, 2] + temp_z * m[2, 3], 0)
    temp_b <- pmax(temp_x * m[3, 1] + temp_y * m[3, 2] + temp_z * m[3, 3], 0)

    # Convert to non-linear RGB space
    if (transformation_match == "sRGB") {
        temp_r <- srgb_transformation_inverse(temp_r)
        temp_g <- srgb_transformation_inverse(temp_g)
        temp_b <- srgb_transformation_inverse(temp_b)
    } else if (transformation_match == "Adobe") {
        temp_r <- adobe_transformation_inverse(temp_r)
        temp_g <- adobe_transformation_inverse(temp_g)
        temp_b <- adobe_transformation_inverse(temp_b)
    } else if (!is.null(linear_func)) {
        temp_r <- linear_func(temp_r)
        temp_g <- linear_func(temp_g)
        temp_b <- linear_func(temp_b)
    } else {
        temp_r <- temp_r * 255
        temp_g <- temp_g * 255
        temp_b <- temp_b * 255
    }

    return(
        tibble(
            red = as.integer(round(temp_r, 0)),
            green = as.integer(round(temp_g, 0)),
            blue = as.integer(round(temp_b, 0))
            )
        )
}

# Conversion from sRGB to linear space
# Source: https://en.wikipedia.org/wiki/SRGB; https://entropymine.com/imageworsener/srgbformula/.
srgb_transformation <- function(x) {
    output <- ifelse(
        test = x > 0.0404482362771082,
        yes = ((x + 0.055) / 1.055) ^ 2.4,
        no = x / 12.92
        )
    output <- output * 100
    return(output)
}

# Conversion from XYZ to linear space
# Source: https://en.wikipedia.org/wiki/SRGB; https://entropymine.com/imageworsener/srgbformula/.
srgb_transformation_inverse <- function(x) {
    output <- ifelse(
        test = x > 0.00313066844250063,
        yes = (1.055 * (x ^ (1 / 2.4))) - 0.055,
        no = x * 12.92
        )
    output <- output * 255
    return(output)
}

# Conversion from Adobe RGB to linear space
# Source: https://en.wikipedia.org/wiki/SRGB.
adobe_transformation <- function(x) {
    output <- (x ^ 2.19921875) * 100
    return(output)
}

# Conversion from XYZ to linear space
# Source: https://en.wikipedia.org/wiki/SRGB.
adobe_transformation_inverse <- function(x) {
    output <- (x ^ (1 / 2.19921875)) * 255
    return(output)
}

#### XYZ to Lab
# Source: https://en.wikipedia.org/wiki/CIELAB_color_space#CIELAB%E2%80%93CIEXYZ_conversions
f <- function(num, dem) {
    delta <- 6 / 29
    t <- num / dem
    output <- ifelse(
        test = t > (delta ^ 3),
        yes = t ^ (1 / 3),
        no = (t / (3 * delta ^ 2)) + (4 / 29)
        )
    return(output)
}

l_star <- function(.y, .y_n, .f) {
    return(116 * .f(.y, .y_n) - 16)
}

a_star <- function(.x, .x_n, .y, .y_n, .f) {
    return(500 * (.f(.x, .x_n) - .f(.y, .y_n)))
}

b_star <- function(.y, .y_n, .z, .z_n, .f) {
    return(200 * (.f(.y, .y_n) - .f(.z, .z_n)))
}

# Conversion from XYZ space to Lab space
#' Convert from XYZ colour channels to Lab space.
#' @export
#' @param xyz A dataframe or matrix with X, Y and Z colour channels located in the columns 1 to 3, respectively.
#' @return A \code{tibble} of L, a and b colour space values.
#' @examples
#' x <- sample(x = 40:60, size = 10, replace = TRUE)
#' y <- sample(x = 40:60, size = 10, replace = TRUE)
#' z <- sample(x = 40:60, size = 10, replace = TRUE)
#' xyz_to_lab(data.frame(x = x, y = y, z = z))
xyz_to_lab <- function(xyz) {
    if (ncol(xyz) != 3) {
        stop("XYZ colours should be a matrix or tibble with three columns.")
    }

    colours_lab <- tibble(
        l = l_star(
            .y = unlist(xyz[ , 2], FALSE, FALSE),
            .y_n = y_n,
            .f = f
            ),
        a = a_star(
            .x = unlist(xyz[ , 1], FALSE, FALSE),
            .x_n = x_n,
            .y = unlist(xyz[ , 2], FALSE, FALSE),
            .y_n = y_n,
            .f = f
            ),
        b = b_star(
            .y = unlist(xyz[ , 2], FALSE, FALSE),
            .y_n = y_n,
            .z = unlist(xyz[ , 3], FALSE, FALSE),
            .z_n = z_n,
            .f = f
            )
        )

    return(colours_lab)
}


#### Lab to XYZ
# Source: https://en.wikipedia.org/wiki/CIELAB_color_space#CIELAB%E2%80%93CIEXYZ_conversions
f_inv <- function(t) {
    delta <- 6 / 29

    ifelse(t > delta, t ^ 3, (3 * delta ^ 2) * (t - (4 / 29)))
}

lab_to_x <- function(.l, .a, .x_n, .f_inv) {
    return(.x_n * .f_inv(((.l + 16) / 116) + (.a / 500)))
}

lab_to_y <- function(.l, .y_n, .f_inv) {
    return(.y_n * .f_inv((.l + 16) / 116))
}

lab_to_z <- function(.l, .b, .z_n, .f_inv) {
    return(.z_n * .f_inv(((.l + 16) / 116) - (.b / 200)))
}

#' Convert from Lab space to XYZ colour channels.
#' @export
#' @param lab A dataframe or matrix with L, a and b colour channels located in the columns 1 to 3, respectively.
#' @return A \code{tibble} of X, Y and Z colour channels.
#' @examples
#' l <- sample(x = 40:60, size = 10, replace = TRUE)
#' a <- sample(x = -128:128, size = 10, replace = TRUE)
#' b <- sample(x = -128:128, size = 10, replace = TRUE)
#' lab_to_xyz(data.frame(l = l, a = a, b = b))
lab_to_xyz <- function(lab) {
    if (ncol(lab) != 3) {
        stop("Lab colours should be a matrix or tibble with three columns.")
    }

    colours_xyz <- tibble(
        x = lab_to_x(
            .l = unlist(lab[ , 1], FALSE, FALSE),
            .a = unlist(lab[ , 2], FALSE, FALSE),
            .x_n = x_n,
            .f_inv = f_inv
            ),
        y = lab_to_y(
            .l = unlist(lab[ , 1], FALSE, FALSE),
            .y_n = y_n,
            .f_inv = f_inv
            ),
        z = lab_to_z(
            .l = unlist(lab[ , 1], FALSE, FALSE),
            .b = unlist(lab[ , 3], FALSE, FALSE),
            .z_n = z_n,
            .f_inv = f_inv
            )
        )
    return(colours_xyz)

}

#### RGB/hex to Lab and RGB/hex to Lab
#' Convert from RGB colour channels to Lab space.
#' @export
#' @param rgb A dataframe or matrix with red, green and blue colour channels located in the columns 1 to 3, respectively. Colour channel values should be between 0 and 255, inclusive.
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A \code{tibble} of L, a and b colour space values.
#' @examples
#' red <- sample(x = 1:255, size = 10, replace = TRUE)
#' green <- sample(x = 1:255, size = 10, replace = TRUE)
#' blue <- sample(x = 1:255, size = 10, replace = TRUE)
#' rgb_to_lab(data.frame(r = red, g = green, b = blue), transformation = "Adobe")
rgb_to_lab <- function(rgb, transformation = "sRGB", linear_func = NULL) {
    xyz <- rgb_to_xyz(
        rgb = rgb,
        transformation = transformation,
        linear_func = linear_func
        )
    lab <- xyz_to_lab(xyz = xyz)
    return(lab)
}

#' Convert from Lab space into RGB colour channels.
#' @export
#' @param lab A dataframe or matrix with L, a and b colour channels located in the columns 1 to 3, respectively.
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into non-linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A \code{tibble} of red, green and blue colour channels.
#' @examples
#' red <- sample(x = 1:255, size = 10, replace = TRUE)
#' green <- sample(x = 1:255, size = 10, replace = TRUE)
#' blue <- sample(x = 1:255, size = 10, replace = TRUE)
#' lab_to_rgb(rgb_to_lab(data.frame(r = red, g = green, b = blue)))
lab_to_rgb <- function(lab, transformation = "sRGB", linear_func = NULL) {
    xyz <- lab_to_xyz(lab = lab)
    rgb <- xyz_to_rgb(
        xyz = xyz,
        transformation = transformation,
        linear_func = linear_func
        )
    return(rgb)
}

#' Convert hex RGB values to Lab space.
#' @export
#' @param hex A character vector containing hex representations of RGB colours.
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into non-linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A \code{tibble} of L, a and b colour space values.
#' @examples
#' red <- sample(x = 1:255, size = 10, replace = TRUE)
#' green <- sample(x = 1:255, size = 10, replace = TRUE)
#' blue <- sample(x = 1:255, size = 10, replace = TRUE)
#' hex_to_lab(rgb_to_hex(data.frame(r = red, g = green, b = blue)))
hex_to_lab <- function(hex, transformation = "sRGB", linear_func = NULL) {
    rgb <- hex_to_rgb(hex = hex)
    lab <- rgb_to_lab(
        rgb,
        transformation = transformation,
        linear_func = linear_func
        )
    return(lab)
}

#' Convert from Lab space into hex RGB colour values.
#' @export
#' @param lab A dataframe or matrix with L, a and b colour channels located in the columns 1 to 3, respectively.
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into non-linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A character vector with hex representations of RGB colour channels.
#' @examples
#' red <- sample(x = 1:255, size = 10, replace = TRUE)
#' green <- sample(x = 1:255, size = 10, replace = TRUE)
#' blue <- sample(x = 1:255, size = 10, replace = TRUE)
#' lab_to_hex(rgb_to_lab(data.frame(r = red, g = green, b = blue)))
lab_to_hex <- function(lab, transformation = "sRGB", linear_func = NULL) {
    rgb <- lab_to_rgb(
        lab = lab,
        transformation = transformation,
        linear_func = linear_func
        )
    hex <- rgb_to_hex(rgb)
    return(hex)
}

#' Convert hex RGB values to XYZ space.
#' @export
#' @param hex A character vector containing hex representations of RGB colours.
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into non-linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A \code{tibble} of X, Y and Z colour space values.
#' @examples
#' red <- sample(x = 1:255, size = 10, replace = TRUE)
#' green <- sample(x = 1:255, size = 10, replace = TRUE)
#' blue <- sample(x = 1:255, size = 10, replace = TRUE)
#' hex_to_xyz(rgb_to_hex(data.frame(r = red, g = green, b = blue)))
hex_to_xyz <- function(hex, transformation = "sRGB", linear_func = NULL) {
    rgb <- hex_to_rgb(hex = hex)
    lab <- rgb_to_xyz(
        rgb,
        transformation = transformation,
        linear_func = linear_func
        )
    return(lab)
}

#' Convert from XYZ space into hex RGB colour values.
#' @export
#' @param xyz A dataframe or matrix with X, Y and Z colour channels located in the columns 1 to 3, respectively.
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into non-linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A character vector with hex representations of RGB colour channels.
#' @examples
#' x <- sample(x = 40:60, size = 10, replace = TRUE)
#' y <- sample(x = 40:60, size = 10, replace = TRUE)
#' z <- sample(x = 40:60, size = 10, replace = TRUE)
#' xyz_to_hex(data.frame(x = x, y = y, z = z))
xyz_to_hex <- function(xyz, transformation = "sRGB", linear_func = NULL) {
    rgb <- xyz_to_rgb(
        xyz = xyz,
        transformation = transformation,
        linear_func = linear_func
        )
    hex <- rgb_to_hex(rgb)
    return(hex)
}

### RGB to HSL
#' Convert RGB space into HSL space
#' @export
#' @param rgb A dataframe or matrix with red, green and blue colour channels located in the columns 1 to 3, respectively. Colour channel values should be between 0 and 255, inclusive.
#' @return a \code{tibble} of H, S and L colour channels.
#' @examples
#' red <- sample(x = 1:255, size = 10, replace = TRUE)
#' green <- sample(x = 1:255, size = 10, replace = TRUE)
#' blue <- sample(x = 1:255, size = 10, replace = TRUE)
#' rgb_to_hsl(data.frame(r = red, g = green, b = blue))
rgb_to_hsl <- function(rgb) {

    # Convert rbg into [0, 1]
    temp_rgb <- rgb / 255

    # Computing constants
    M <- apply(X = temp_rgb, MARGIN = 1, FUN = max)
    m <- apply(X = temp_rgb, MARGIN = 1, FUN = min)
    C <- M - m

    ### Calculating H
    # Finding H'
    H_dash <-
        case_when(
            C == 0 ~ NA_real_,
            M == temp_rgb[ , 1] ~ ((temp_rgb[ , 2] - temp_rgb[ , 3]) / C) %% 6,
            M == temp_rgb[ , 2] ~ ((temp_rgb[ , 3] - temp_rgb[ , 1]) / C) + 2,
            TRUE ~ ((temp_rgb[ , 1] - temp_rgb[ , 2]) / C) + 4
        )

    # Calculate H = 60deg * H'
    H <- H_dash * 60

    ### Calculating L
    L <- (M + m) / 2

    ### Calculating S
    S <- 
        case_when(
            (L == 0) | (L == 1) ~ 0,
            TRUE ~ C / (1 - abs(2 * L - 1))
        )
    
    # Package together in one dataframe
    hsl <- tibble(
        h = H,
        s = S,
        l = L
    )

    return(hsl)

}

### HSL to RGB 
#' Convert HSL space into RGB space
#' @export
#' @param hsl A dataframe or matrix with H, S and L colour channels located in the columns 1 to 3, respectively. H in degrees in [0, 360], S and L in [0, 1]
#' @return A \code{tibble} of red, green and blue colour channels.
#' @examples
#' H <- sample(x = 0:360, size = 10, replace = TRUE)
#' S <- runif(n = 10)
#' L <- runif(n = 10)
#' hsl_to_rgb(data.frame(h = H, s = S, l = L))
hsl_to_rgb <- function(hsl) {
    # Unlist from hsl
    temp_h <- unlist(hsl[ , 1])
    temp_s <- unlist(hsl[ , 2])
    temp_l <- unlist(hsl[ , 3])

    # Calculate parameters
    C <- (1 - abs(2 * temp_l - 1)) * temp_s
    H_dash <- temp_h / 60
    X <- C * (1 - abs((H_dash %% 2) - 1))
    m <- temp_l - (C / 2)

    # Create a temporary dataframe
    cxmhash <- tibble(
        C = C,
        X = X,
        m = m,
        H_dash = H_dash
    )

    # Calculate RGB
    rgb <- cxmhash 
    rgb$r <- case_when(
                ((rgb$H_dash >= 0) & (rgb$H_dash < 1)) | ((rgb$H_dash >= 5) & (rgb$H_dash < 6)) ~ C + m,
                ((rgb$H_dash >= 1) & (rgb$H_dash < 2)) | ((rgb$H_dash >= 4) & (rgb$H_dash < 5))  ~ rgb$X + rgb$m,
                TRUE ~ rgb$m          
                )
    rgb$g <- case_when(
                (rgb$H_dash >= 1) & (rgb$H_dash < 3) ~ rgb$C + rgb$m,
                ((rgb$H_dash >= 0) & (rgb$H_dash < 1)) | ((rgb$H_dash >= 3) & (rgb$H_dash < 4)) ~ rgb$X + rgb$m,
                TRUE ~ rgb$m          
            )
    rgb$b = case_when(
                (rgb$H_dash >= 0) & (rgb$H_dash < 2) ~ rgb$m,
                (rgb$H_dash >= 3) & (rgb$H_dash < 5) ~ rgb$C + rgb$m,
                TRUE ~ X + m          
            )
        
    rgb <- rgb[, c("r", "g", "b")] |>
        mutate(
            across(.cols = c("r", "g", "b"), function(x) if_else((x < 0) & (abs(x) < 1e-14), 0, x)) # Correcting for machine precision negative values
        ) * 255
    
    return(rgb)
}

### HSL to HSV
#' Convert HSL to HSV
#' @export
#' @param hsl A dataframe or matrix with H, S and L colour channels located in the columns 1 to 3, respectively. H in degrees in [0, 360], S and L in [0, 1]
#' @return A \code{tibble} of H, S and V colour channels. Hue is constant between colour spaces, while saturation differs.
#' @examples
#' H <- sample(x = 0:360, size = 10, replace = TRUE)
#' S <- runif(n = 10)
#' L <- runif(n = 10)
#' hsl_to_hsv(data.frame(h = H, s = S, l = L))
hsl_to_hsv <- function(hsl) {
    temp_h <- unlist(hsl[ , 1])
    temp_s <- unlist(hsl[ , 2])
    temp_l <- unlist(hsl[ , 3])

    # Calculate v
    V <- temp_l + temp_s * pmin(temp_l, 1 - temp_l)

    # Calculate S
    S = case_when(
        V == 0 ~ 0,
        TRUE ~ 2 * (1 - (temp_l / V))
    )

    hsv <- tibble(
        h = temp_h,
        s = S,
        v = V
    )

    return(hsv)
}

### HSV to HSL
#' Convert HSV to HSL
#' @export
#' @param hsv A dataframe or matrix with H, S and V colour channels located in the columns 1 to 3, respectively. H in degrees in [0, 360], S and L in [0, 1]
#' @return A \code{tibble} of H, S and L colour channels. Hue is constant between colour spaces, while saturation differs.
#' @examples
#' H <- sample(x = 0:360, size = 10, replace = TRUE)
#' S <- runif(n = 10)
#' V <- runif(n = 10)
#' hsv_to_hsl(data.frame(h = H, s = S, v = V))
hsv_to_hsl <- function(hsv) {
    temp_h <- unlist(hsv[ , 1])
    temp_s <- unlist(hsv[ , 2])
    temp_v <- unlist(hsv[ , 3])

    # Calculate L
    L <- temp_v * (1 - (temp_s / 2))

    # Calculate S
    S <- case_when(
        (L == 0) | (L == 1) ~ 0,
        TRUE ~ (temp_v - L) / (pmin(L, 1 - L))
    )

    hsl <- tibble(
        h = temp_h,
        s = S,
        l = L
    )

    return(hsl)

}

### RGB to HSV
#' Convert RGB to HSV
#' @export
#' @param rgb A dataframe or matrix with red, green and blue colour channels located in the columns 1 to 3, respectively. Colour channel values should be between 0 and 255, inclusive.
#' @return A \code{tibble} of H, S and V colour channels.
rgb_to_hsv <- function(rgb) {
    hsl <- rgb_to_hsl(rgb)
    hsv <- hsl_to_hsv(hsl)
    return(hsv)
}

### HSV to RGB
#' Convert HSV to RGB
#' @export
#' @param hsv A dataframe or matrix with H, S and V colour channels located in the columns 1 to 3, respectively. H in degrees in [0, 360], S and L in [0, 1]
#' @return A \code{tibble} of red, green and blue colour channels.
hsv_to_rgb <- function(hsv) {
    hsl <- hsv_to_hsl(hsv)
    rgb <- hsl_to_rgb(hsl)
    return(rgb)
}

### XYZ to HSL
#' Convert XYZ to HSL
#' @export
#' @param xyz A dataframe or matrix with X, Y and Z colour channels located in the columns 1 to 3, respectively.
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A \code{tibble} of H, S and L colour channels.
xyz_to_hsl <- function(xyz, transformation = "sRGB", linear_func = NULL) {
    rgb <- xyz_to_rgb(xyz, transformation = transformation, linear_func = linear_func)
    hsl <- rgb_to_hsl(rgb)
    return(hsl)
}

### HSL to XYZ
#' Convert HSL to XYZ
#' @export
#' @param hsl A dataframe or matrix with H, S and L colour channels located in the columns 1 to 3, respectively. H in degrees in [0, 360], S and L in [0, 1]
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A \code{tibble} of X, Y and Z colour channels.
hsl_to_xyz <- function(hsl, transformation = "sRGB", linear_func = NULL) {
    rgb <- hsl_to_rgb(hsl)
    xyz <- rgb_to_xyz(rgb, transformation = transformation, linear_func = linear_func)
    return(xyz)
}

### XYZ to HSV
#' Convert XYZ to HSV
#' @export
#' @param xyz A dataframe or matrix with X, Y and Z colour channels located in the columns 1 to 3, respectively.
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A \code{tibble} of H, S and V colour channels.
xyz_to_hsv <- function(xyz, transformation = "sRGB", linear_func = NULL) {
    rgb <- xyz_to_rgb(xyz, transformation = transformation, linear_func = linear_func)
    hsv <- rgb_to_hsv(rgb)
    return(hsv)
}

### HSV to XYZ
#' Convert HSV to XYZ
#' @export
#' @param hsv A dataframe or matrix with H, S and V colour channels located in the columns 1 to 3, respectively. H in degrees in [0, 360], S and L in [0, 1]
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A \code{tibble} of X, Y and Z colour channels.
hsv_to_xyz <- function(hsv, transformation = "sRGB", linear_func = NULL) {
    rgb <- hsv_to_rgb(hsv)
    xyz <- rgb_to_xyz(rgb, transformation = transformation, linear_func = linear_func)
    return(xyz)
}

### HSL to Lab
#' Convert HSL to Lab
#' @export
#' @param hsl A dataframe or matrix with H, S and L colour channels located in the columns 1 to 3, respectively. H in degrees in [0, 360], S and L in [0, 1]
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A \code{tibble} of L, a and b colour space values.
hsl_to_lab <- function(hsl, transformation = "sRGB", linear_func = NULL) {
    rgb <- hsl_to_rgb(hsl)
    lab <- rgb_to_lab(rgb, transformation = transformation, linear_func = linear_func)
    return(lab)
}

### Lab to HSL
#' Convert Lab to HSL
#' @export
#' @param lab A dataframe or matrix with L, a and b colour channels located in the columns 1 to 3, respectively.
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A \code{tibble} of H, S and L colour channels.
lab_to_hsl <- function(lab, transformation = "sRGB", linear_func = NULL) {
    rgb <- lab_to_rgb(lab, transformation = transformation, linear_func = linear_func)
    hsl <- rgb_to_hsl(rgb)
    return(hsl)
}

### HSV to Lab
#' Convert HSV to Lab 
#' @export
#' @param hsv A dataframe or matrix with H, S and V colour channels located in the columns 1 to 3, respectively. H in degrees in [0, 360], S and L in [0, 1]
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A \code{tibble} of L, a and b colour space values.
hsv_to_lab <- function(hsv, transformation = "sRGB", linear_func = NULL) {
    hsl <- hsv_to_hsl(hsv)
    lab <- hsl_to_lab(hsl, transformation = transformation, linear_func = linear_func)
    return(lab)
}

### Lab to HSV
#' Convert Lab to HSv
#' @export
#' @param lab A dataframe or matrix with L, a and b colour channels located in the columns 1 to 3, respectively.
#' @param transformation An option in \code{c("sRGB", "Adobe")} for a built-in transformation or, alternatively, a custom 3x3 transformation matrix.
#' @param linear_func A function to convert RGB colour space into linear RGB space. Used only if a custom transformation matrix is provided. Transformation skips if no function is provided under a user-defined transformation matrix. See: https://en.wikipedia.org/wiki/SRGB.
#' @return A \code{tibble} of H, S and V colour channels.
lab_to_hsv <- function(lab, transformation = "sRGB", linear_func = NULL) {
    hsl <- lab_to_hsl(lab, transformation = transformation, linear_func = linear_func)
    hsv <- hsl_to_hsv(hsl)
    return(hsv)
}
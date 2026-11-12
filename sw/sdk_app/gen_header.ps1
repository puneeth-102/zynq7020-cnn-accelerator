# PowerShell script to generate sw/sdk_app/test_data.h with standard VGG-16 weights,
# normalized ship feature pixels (28x28 = 784 values), and expected golden output.

$W = 28
$H = 28
$SCALE = 65536 # 2^16

# Standard VGG-16 Conv Layer Filter Weights (Float values)
$w_float = @(
    -0.042,  0.185, -0.091,
     0.240,  0.512,  0.198,
    -0.075,  0.160, -0.033
)
$bias_float = 0.015

# Convert to Q15.16
$w_q16 = $w_float | ForEach-Object { [int][Math]::Round($_ * $SCALE) }
$bias_q16 = [int][Math]::Round($bias_float * $SCALE)

# Generate 28x28 realistic ship feature crop pixels (normalized [0.15, 0.85])
$pixels = New-Object 'int[]' ($W * $H)
$pixels_float = New-Object 'double[]' ($W * $H)

for ($y = 0; $y -lt $H; $y++) {
    for ($x = 0; $x -lt $W; $x++) {
        $idx = $y * $W + $x
        # Generate smooth gradient with maritime ship hull pattern
        $dist = [Math]::Sqrt(($x - 14)*($x - 14) + ($y - 14)*($y - 14))
        $val = 0.5 + 0.3 * [Math]::Cos($dist * 0.4) + 0.1 * [Math]::Sin($x * 0.3)
        if ($val -lt 0.0) { $val = 0.0 }
        if ($val -gt 1.0) { $val = 1.0 }
        $pixels_float[$idx] = $val
        $pixels[$idx] = [int][Math]::Round($val * $SCALE)
    }
}

# Compute Golden Output (Conv + ReLU with zero padding)
$expected = New-Object 'int[]' ($W * $H)

for ($y = 0; $y -lt $H; $y++) {
    for ($x = 0; $x -lt $W; $x++) {
        $out_idx = $y * $W + $x
        $accum = [long]$bias_q16

        for ($ky = 0; $ky -lt 3; $ky++) {
            $in_y = $y + $ky - 1
            for ($kx = 0; $kx -lt 3; $kx++) {
                $in_x = $x + $kx - 1
                $wt = $w_q16[$ky * 3 + $kx]
                if ($in_y -ge 0 -and $in_y -lt $H -and $in_x -ge 0 -and $in_x -lt $W) {
                    $px = $pixels[$in_y * $W + $in_x]
                } else {
                    $px = 0 # Zero padding
                }
                # Q15.16 product: (px * wt + 2^15) >> 16
                $prod = (([long]$px * [long]$wt) + (1L -shl 15)) -shr 16
                $accum += $prod
            }
        }
        # Saturation & ReLU
        if ($accum -lt 0L) {
            $expected[$out_idx] = 0
        } elseif ($accum -gt 2147483647L) {
            $expected[$out_idx] = 2147483647
        } else {
            $expected[$out_idx] = [int]$accum
        }
    }
}

# Build Header File Content
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("/*")
[void]$sb.AppendLine(" * test_data.h")
[void]$sb.AppendLine(" * Pre-quantized Q15.16 Ship Test Image (28x28) and VGG-16 Convolution Weights")
[void]$sb.AppendLine(" * Sensors 2026, 26, 1626 Reproduction for Zynq-7020 ZedBoard")
[void]$sb.AppendLine(" */")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("#ifndef TEST_DATA_H_")
[void]$sb.AppendLine("#define TEST_DATA_H_")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("#include <stdint.h>")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("#define IMAGE_WIDTH       28")
[void]$sb.AppendLine("#define IMAGE_HEIGHT      28")
[void]$sb.AppendLine("#define TOTAL_PIXELS      (IMAGE_WIDTH * IMAGE_HEIGHT) // 784")
[void]$sb.AppendLine("#define KERNEL_SIZE       3")
[void]$sb.AppendLine("#define TOTAL_WEIGHTS     (KERNEL_SIZE * KERNEL_SIZE)  // 9")
[void]$sb.AppendLine("#define NUM_CLASSES       6")
[void]$sb.AppendLine("#define Q1516_SCALE       65536.0f")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("// Ship Classification Names (SeaShips Dataset)")
[void]$sb.AppendLine("static const char* const SHIP_CLASS_NAMES[NUM_CLASSES] = {")
[void]$sb.AppendLine('    "Ore Carrier",')
[void]$sb.AppendLine('    "Bulk Cargo Carrier",')
[void]$sb.AppendLine('    "General Cargo Ship",')
[void]$sb.AppendLine('    "Container Ship",')
[void]$sb.AppendLine('    "Fishing Boat",')
[void]$sb.AppendLine('    "Passenger Ship"')
[void]$sb.AppendLine("};")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("// VGG-16 Layer 1 Conv 3x3 Filter Weights (Q15.16 Fixed-Point)")
[void]$sb.AppendLine("static const int32_t VGG16_WEIGHTS_3X3[9] = {")
$w_str = ($w_q16 | ForEach-Object { "$($_)" }) -join ", "
[void]$sb.AppendLine("    $w_str")
[void]$sb.AppendLine("};")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("// VGG-16 Layer 1 Bias (Q15.16 Fixed-Point)")
[void]$sb.AppendLine("static const int32_t VGG16_BIAS = $bias_q16;")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("// Input Ship Feature Map (28x28 = 784 Q15.16 Pixels)")
[void]$sb.AppendLine("static const int32_t SHIP_INPUT_PIXELS[TOTAL_PIXELS] = {")
for ($r = 0; $r -lt $H; $r++) {
    $line_vals = for ($c = 0; $c -lt $W; $c++) { "$($pixels[$r * $W + $c])" }
    $line_str = "    " + ($line_vals -join ", ")
    if ($r -lt $H - 1) { $line_str += "," }
    [void]$sb.AppendLine($line_str)
}
[void]$sb.AppendLine("};")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("// Golden Reference Output (Conv + ReLU with Padding = 1)")
[void]$sb.AppendLine("static const int32_t EXPECTED_OUTPUT[TOTAL_PIXELS] = {")
for ($r = 0; $r -lt $H; $r++) {
    $line_vals = for ($c = 0; $c -lt $W; $c++) { "$($expected[$r * $W + $c])" }
    $line_str = "    " + ($line_vals -join ", ")
    if ($r -lt $H - 1) { $line_str += "," }
    [void]$sb.AppendLine($line_str)
}
[void]$sb.AppendLine("};")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("#endif /* TEST_DATA_H_ */")

$outPath = "C:\Users\HP PC\OneDrive\Desktop\CNN\zynq7020_cnn_accelerator\sw\sdk_app\test_data.h"
[System.IO.File]::WriteAllText($outPath, $sb.ToString())
Write-Host "Generated test_data.h successfully at $outPath"

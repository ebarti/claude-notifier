#!/bin/bash
#
# generate-icon.sh — Generate AppIcon.icns from a source PNG for claude-notifier
#
# Usage: ./generate-icon.sh [path-to-source-png]
#   Defaults to Resources/claude-logo.png if no argument is provided.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_PNG="${1:-${SCRIPT_DIR}/Resources/claude-logo.png}"
OUTPUT_ICNS="${SCRIPT_DIR}/Resources/AppIcon.icns"
ICONSET_DIR=$(mktemp -d)/AppIcon.iconset

# ---------------------------------------------------------------------------
# If the source PNG doesn't exist, generate a placeholder
# ---------------------------------------------------------------------------
generate_placeholder() {
    local dest="$1"
    echo "Source PNG not found at: ${dest}"
    echo "Generating placeholder icon (orange circle on transparent background)..."
    echo "Using placeholder icon. Replace Resources/claude-logo.png with the actual Claude logo for production use."

    python3 - "$dest" << 'PYEOF'
import struct, zlib, sys, math

output_path = sys.argv[1]
width = height = 1024
cx, cy, radius = 512, 512, 450

# Claude brand color: #D97757 (terracotta orange)
fill_r, fill_g, fill_b, fill_a = 217, 119, 87, 255

# Build raw image rows (filter byte 0 = None, then RGBA pixels)
rows = []
for y in range(height):
    row = bytearray()
    row.append(0)  # PNG filter: None
    for x in range(width):
        dx = x - cx
        dy = y - cy
        dist = math.sqrt(dx * dx + dy * dy)
        if dist <= radius:
            # Anti-alias the edge (1px band)
            if dist > radius - 1.0:
                alpha = int(fill_a * (radius - dist))
                alpha = max(0, min(255, alpha))
            else:
                alpha = fill_a
            row.extend([fill_r, fill_g, fill_b, alpha])
        else:
            row.extend([0, 0, 0, 0])
    rows.append(bytes(row))

raw_data = b''.join(rows)
compressed = zlib.compress(raw_data, 9)

def make_chunk(chunk_type, data):
    chunk = chunk_type + data
    crc = struct.pack('>I', zlib.crc32(chunk) & 0xFFFFFFFF)
    return struct.pack('>I', len(data)) + chunk + crc

# PNG signature
png = b'\x89PNG\r\n\x1a\n'

# IHDR: width, height, bit depth 8, color type 6 (RGBA)
ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
png += make_chunk(b'IHDR', ihdr_data)

# IDAT
png += make_chunk(b'IDAT', compressed)

# IEND
png += make_chunk(b'IEND', b'')

with open(output_path, 'wb') as f:
    f.write(png)

print(f"Placeholder PNG written to {output_path} ({width}x{height})")
PYEOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if [ ! -f "$SOURCE_PNG" ]; then
    generate_placeholder "$SOURCE_PNG"
fi

# Verify the source PNG exists (in case placeholder generation failed)
if [ ! -f "$SOURCE_PNG" ]; then
    echo "Error: Source PNG not found and placeholder generation failed." >&2
    echo "Please provide a 1024x1024 PNG at: ${SOURCE_PNG}" >&2
    exit 1
fi

echo "Source PNG: ${SOURCE_PNG}"

# Create temporary iconset directory
mkdir -p "$ICONSET_DIR"
echo "Created iconset directory: ${ICONSET_DIR}"

# Define all required icon sizes: "filename width height"
ICON_SIZES=(
    "icon_16x16.png 16 16"
    "icon_16x16@2x.png 32 32"
    "icon_32x32.png 32 32"
    "icon_32x32@2x.png 64 64"
    "icon_128x128.png 128 128"
    "icon_128x128@2x.png 256 256"
    "icon_256x256.png 256 256"
    "icon_256x256@2x.png 512 512"
    "icon_512x512.png 512 512"
    "icon_512x512@2x.png 1024 1024"
)

echo "Generating icon sizes..."
for entry in "${ICON_SIZES[@]}"; do
    read -r filename w h <<< "$entry"
    cp "$SOURCE_PNG" "${ICONSET_DIR}/${filename}"
    sips -z "$h" "$w" "${ICONSET_DIR}/${filename}" --out "${ICONSET_DIR}/${filename}" > /dev/null 2>&1
    echo "  ${filename} (${w}x${h})"
done

# Generate the icns file
echo "Generating AppIcon.icns..."
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

# Clean up
rm -rf "$(dirname "$ICONSET_DIR")"
echo "Cleaned up temporary iconset directory."

echo ""
echo "Done! AppIcon.icns written to: ${OUTPUT_ICNS}"

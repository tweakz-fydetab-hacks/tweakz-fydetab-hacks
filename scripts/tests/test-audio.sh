#!/bin/bash
# test-audio.sh - Audio verification for FydeTab Duo
# Verifies: es8388 driver, ALSA devices, HDMI audio, speaker status

set -e

OUTPUT_DIR="${1:-.}"

echo "=== Audio Test ==="

# Check ALSA devices
echo "Checking ALSA devices..."
{
    echo "=== ALSA Cards ==="
    cat /proc/asound/cards 2>/dev/null || echo "No ALSA cards"
    echo ""
    echo "=== ALSA Devices ==="
    if command -v aplay &>/dev/null; then
        aplay -l 2>&1 || echo "aplay -l failed"
    else
        echo "aplay not available"
    fi
    echo ""
    echo "=== ALSA PCMs ==="
    if command -v aplay &>/dev/null; then
        aplay -L 2>&1 | head -50 || echo "aplay -L failed"
    fi
} > "${OUTPUT_DIR}/alsa-devices.txt"

cat "${OUTPUT_DIR}/alsa-devices.txt" | head -20

# Check for audio cards
if grep -qE "^\s*[0-9]+ \[" /proc/asound/cards 2>/dev/null; then
    echo "PASS: ALSA cards detected"
else
    echo "FAIL: No ALSA cards found"
fi

# Check es8388 codec
echo "Checking es8388 codec..."
{
    echo "=== ES8388 Codec ==="
    if lsmod | grep -q snd_soc_es8388; then
        echo "es8388 module: loaded"
        lsmod | grep -E "es8388|snd_soc"
    else
        echo "es8388 module: not loaded (may be built-in)"
        lsmod | grep -E "snd_soc" || echo "No snd_soc modules"
    fi
    echo ""
    echo "=== Kernel messages ==="
    dmesg 2>/dev/null | grep -iE "es8388|codec|audio\|asoc" | tail -30 || echo "No audio messages"
} > "${OUTPUT_DIR}/es8388.txt"

# Check HDMI audio
echo "Checking HDMI audio..."
{
    echo "=== HDMI Audio ==="
    if grep -qi "hdmi" /proc/asound/cards 2>/dev/null; then
        echo "HDMI audio: detected in ALSA cards"
    else
        echo "HDMI audio: not detected"
    fi
    echo ""
    echo "=== HDMI messages ==="
    dmesg 2>/dev/null | grep -iE "hdmi.*audio\|audio.*hdmi\|dw-hdmi" | tail -20 || echo "No HDMI audio messages"
} > "${OUTPUT_DIR}/hdmi-audio.txt"

if grep -qi "hdmi" /proc/asound/cards 2>/dev/null; then
    echo "PASS: HDMI audio detected"
else
    echo "INFO: HDMI audio not detected (may need HDMI connected)"
fi

# Check speaker status
echo "Checking speaker configuration..."
{
    echo "=== Speaker Status ==="
    echo "Note: Speakers are documented as 'partial' - HDMI works, speakers need config"
    echo ""
    echo "=== ALSA Mixer Controls ==="
    if command -v amixer &>/dev/null; then
        amixer 2>&1 | head -50 || echo "amixer failed"
    else
        echo "amixer not available"
    fi
} > "${OUTPUT_DIR}/speaker-status.txt"

# Check PipeWire/PulseAudio
echo "Checking audio server..."
{
    echo "=== Audio Server ==="
    if pgrep -x pipewire &>/dev/null; then
        echo "PipeWire: running"
        ps aux | grep "[p]ipewire"
    elif pgrep -x pulseaudio &>/dev/null; then
        echo "PulseAudio: running"
    else
        echo "No audio server detected"
    fi
    echo ""
    echo "=== PipeWire Status ==="
    if command -v wpctl &>/dev/null; then
        wpctl status 2>&1 | head -50 || echo "wpctl failed"
    else
        echo "wpctl not available"
    fi
    echo ""
    echo "=== PulseAudio Sinks ==="
    if command -v pactl &>/dev/null; then
        pactl list sinks short 2>&1 || echo "pactl failed"
    fi
} > "${OUTPUT_DIR}/audio-server.txt"

echo ""
echo "Audio test completed"
echo "Note: Speaker audio is documented as partial - HDMI audio works"
exit 0

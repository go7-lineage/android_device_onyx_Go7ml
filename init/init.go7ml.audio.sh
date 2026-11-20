#!/vendor/bin/sh
# Internal speaker and microphones: starts the audio DSP, waits for the sound card and sets the playback path
# MultiMedia2 -> RX macro (AUX) -> WCD9370 AUX -> AW87390, with the level and output-stage mode of stock's
# mixer paths. MultiMedia2 is PCM device 1, where the audio policy file puts the speaker.
# Runs before the audio HAL starts: a playback attempt without the card leaves the HAL's stream in an error
# state. The kernel can't start the DSP itself, its firmware is on /vendor.
for r in /sys/class/remoteproc/remoteproc*; do
    if [ "$(/vendor/bin/cat $r/name)" = adsp ] && [ "$(/vendor/bin/cat $r/state)" = offline ]; then
        echo start > $r/state
    fi
done
i=0
while [ ! -e /dev/snd/controlC0 ] || [ ! -e /dev/snd/pcmC0D1p ]; do
    [ $i -lt 100 ] || exit 1	# init logs the exit status
    /vendor/bin/sleep 0.1
    i=$((i + 1))
done
m() { /system/bin/tinymix -D 0 "$1" "$2"; }
m "RX_CODEC_DMA_RX_0 Audio Mixer MultiMedia2" 1
m "RX_MACRO RX0 MUX" AIF1_PB
m "RX INT2_1 MIX1 INP0" RX0
m "RX INT2_1 INTERP" "RX INT2_1 MIX1"
m "LO Switch" 1
m "AUX_RDAC Switch" 1
# 78 = -6 dB
m "RX_RX2 Digital Volume" 78
# item 3 = class AB (wcd937x.c shows it as "CLS_H_LP": its labels are one off)
m "RX HPH Mode" 3
# Recording: the two digital microphones through the VA macro to MultiMedia1 (PCM device 0). The first
# channel is DMIC2, the microphone stock records mono from.
m "MultiMedia1 Mixer VA_CODEC_DMA_TX_0" 1
m "VA DMIC MUX0" DMIC2
m "VA DEC0 MUX" VA_DMIC
m "VA_AIF1_CAP Mixer DEC0" 1
m "VA DMIC MUX1" DMIC0
m "VA DEC1 MUX" VA_DMIC
m "VA_AIF1_CAP Mixer DEC1" 1
exit 0

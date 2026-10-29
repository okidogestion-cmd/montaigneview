#!/bin/sh
# Outil : découpe les sons de tir du jeu dans sources/k98_pixabay.mp3 (Karabiner 98k, Pixabay, sovetsky_rastov72).
#   sh tools/sons_k98.sh
# - son_tir.ogg : premier tir (0,05 à 1,95 s) puis la culasse (4,7 à 7 s), placée 1,1 s après le coup.
# - son_loin.ogg : second tir (1,9 à 4,6 s), étouffé (passe-bas) et avec plus d'écho : l'ennemi, sur l'autre île.
# (son_impact.wav, la balle qui passe tout près, vient de tools/sons.py.)
set -e
SRC=sources/k98_pixabay.mp3
OUT=game/art
ffmpeg -loglevel error -y -i $SRC -filter_complex \
  "[0:a]atrim=0.05:1.95,asetpts=PTS-STARTPTS,afade=t=out:st=1.4:d=0.5[a];[0:a]atrim=4.7:7.0,asetpts=PTS-STARTPTS,adelay=1100|1100,volume=0.8[b];[a][b]amix=inputs=2:normalize=0,afade=t=out:st=3.0:d=0.4,pan=mono|c0=0.5*c0+0.5*c1" \
  -ar 44100 -c:a libvorbis -q:a 4 $OUT/son_tir.ogg
ffmpeg -loglevel error -y -i $SRC -filter_complex \
  "[0:a]atrim=1.9:4.6,asetpts=PTS-STARTPTS,lowpass=f=1100,lowpass=f=1400,aecho=0.8:0.7:380|900:0.35|0.22,volume=1.6,afade=t=out:st=3.2:d=0.6,pan=mono|c0=0.5*c0+0.5*c1" \
  -ar 44100 -c:a libvorbis -q:a 3 $OUT/son_loin.ogg

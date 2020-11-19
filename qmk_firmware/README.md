I used qmk firmware to tweak the keymap of the ID80 keyboard.
using:
- https://beta.docs.qmk.fm/tutorial/newbs_flashing
- https://config.qmk.fm/#/id80/LAYOUT
- and `bin/qmk json2c id80_layout_msf.json`


# TODO:
- macro: shift-backspace -> delete
- macro: "esq, :wa<enter>"
- macro: better use of left alt/ctrl for layers/macros


# Put keyboard into Flash/Bootloader mode

first:
> bin/qmk flash
while it probes and searches for the keyboard, with the keyboard plugged, press:
> FN + ESQ

(iirc, did this two nights ago and not 100% certain anymore)

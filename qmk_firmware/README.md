I used qmk firmware to tweak the keymap of the ID80 keyboard.
using:
- https://docs.qmk.fm/#/newbs_building_firmware
- https://beta.docs.qmk.fm/tutorial/newbs_flashing
- https://config.qmk.fm/#/id80/LAYOUT

# Put keyboard into Flash/Bootloader mode
```
$ # edit code ...
$ vac  #virtualenv activate
$ ./bin/qmk compile
$ ./bin/qmk flash
# while it probes for the keyboard, with the keyboard plugged, press:
 FN + ESQ
```


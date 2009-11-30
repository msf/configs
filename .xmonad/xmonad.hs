import XMonad hiding (Tall)
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.SetWMName
import XMonad.Util.Run
import XMonad.Hooks.EwmhDesktops
import XMonad.Hooks.ManageDocks
import XMonad.Layout.NoBorders
import System.IO
import Data.List(isPrefixOf)
import XMonad.Layout.HintedTile
--import XMonad.Layout.ResizableTile
import qualified XMonad.StackSet as W
import qualified Data.Map as M
import qualified XMonad.Actions.Submap as SM
import qualified XMonad.Actions.Search as S
import XMonad.Prompt
import XMonad.Prompt.Shell
import System.Exit


myFont = "-xos4-terminus-bold-r-normal-*-12-*-*-*-*-*-*-*"
focusColor = "#ff5045"
textColor = "#c0c0a0"
lightTextColor = "#fffff0"
backgroundColor = "#304520"
lightBackgroundColor = "#456030"
urgentColor = "#ffc000"

-- TODO: kb shortcuts for sound: raise and lower volume
main = do
    xmobar <- spawnPipe "xmobar ~/.xmonad/xmobarrc"
    trayer <- spawnPipe "trayer --edge top --align right --SetDockType true --SetPartialStrut true --expand true --width 10 --height 12 --transparent true --tint 0x191970"
    gss <- spawnPipe "gnome-screensaver"
    gsd <- spawnPipe "gnome-settings-daemon"

    xmonad $ defaultConfig
        { terminal = "/usr/bin/xterm +sb -sl 5000 -bg black -fg grey -fa Monospace -fs 10 -u8"
        , borderWidth = 1
        , modMask = mod4Mask
        , normalBorderColor = "#000000"
        , focusedBorderColor = focusColor
        , focusFollowsMouse = True
        , logHook = ewmhDesktopsLogHook
            >> (dynamicLogWithPP $ xmobarPP
                { ppLayout = const ""
                , ppTitle = xmobarColor "lightblue" "" . shorten 50
                , ppOutput = hPutStrLn xmobar}
                )
        , startupHook = setWMName "LG3D"
        , layoutHook = avoidStruts $ smartBorders (myLayout)
        , manageHook = manageDocks <+> manageHook defaultConfig <+> myManageHook
        , workspaces = [ "1:adm+pvt", "2:mail", "3:web1", "4:webwork", "5:terms","6:misc","7:rand","8:rand2" ]
        , keys = myKeys
        }

myLayout = hintedTile Tall ||| hintedTile Wide ||| noBorders Full
    where
        hintedTile = HintedTile nmaster delta ratio TopLeft
        nmaster = 1
        ratio = 1/2
        delta = 3/100

myManageHook = composeAll . concat $
    [[ className =? c --> doFloat | c <- [ "Git-gui"
                                         , "Gitk"
                                         , "Gimp"
                                         , "Terminator"
                                         , "Update-manager"]]]


myKeys conf@(XConfig {XMonad.modMask = modm}) = M.fromList $
    [ ((modm .|. shiftMask, xK_Return), spawn $ XMonad.terminal conf)
    , ((modm, xK_p ), shellPrompt defaultXPConfig { font = myFont } )
    {- , ((modm .|. shiftMask, xK_p ), spawn "gmrun") -}
    , ((modm .|. shiftMask, xK_p ), spawn "/usr/bin/setxkbmap pt")
    , ((modm .|. shiftMask, xK_d ), spawn "/usr/bin/setxkbmap dvorak")
    , ((modm .|. shiftMask, xK_l ), spawn "/usr/bin/gnome-screensaver-command --lock")
    , ((modm .|. shiftMask, xK_c ), kill)
    , ((modm, xK_space ), sendMessage NextLayout)
    , ((modm .|. shiftMask, xK_space ), setLayout $ XMonad.layoutHook conf)
    , ((modm, xK_n ), refresh)
    , ((modm, xK_Tab ), windows W.focusDown)
    , ((modm, xK_j ), windows W.focusDown)
    , ((modm, xK_k ), windows W.focusUp )
    , ((modm, xK_m ), windows W.focusMaster )
    , ((modm, xK_Return), windows W.swapMaster)
    , ((modm .|. shiftMask, xK_j ), windows W.swapDown )
    , ((modm .|. shiftMask, xK_k ), windows W.swapUp )
    , ((modm, xK_h ), sendMessage Shrink)
    , ((modm, xK_l ), sendMessage Expand)
    , ((modm, xK_s ), SM.submap $ searchEngineMap $ S.promptSearch defaultXPConfig {font = myFont})
    , ((modm .|. shiftMask, xK_s ), SM.submap $ searchEngineMap $ S.selectSearch )
    , ((modm, xK_t ), withFocused $ windows . W.sink)
    , ((modm , xK_comma ), sendMessage (IncMasterN 1))
    , ((modm , xK_period), sendMessage (IncMasterN (-1)))
    , ((modm .|. shiftMask, xK_q ), io (exitWith ExitSuccess))
    , ((modm , xK_q ), restart "xmonad" True)
    ]
    ++
    [((m .|. modm, k), windows $ f i)
        | (i, k) <- zip (XMonad.workspaces conf) [xK_1 .. xK_9]
        , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]]
    ++
    [((m .|. modm, key), screenWorkspace sc >>= flip whenJust (windows . f))
        | (key, sc) <- zip [xK_e, xK_w, xK_r] [0..]
        , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]]

searchEngineMap method = M.fromList $
      [ ((0, xK_g), method S.google)
      , ((0, xK_w), method S.wikipedia)
      , ((0, xK_i), method S.imdb)
      , ((0, xK_y), method S.youtube)
      ]



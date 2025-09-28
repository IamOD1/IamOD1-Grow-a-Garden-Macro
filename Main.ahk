#SingleInstance, Force
#NoEnv
SetWorkingDir %A_ScriptDir%
#WinActivateForce
SetMouseDelay, -1
SetWinDelay, -1
SetControlDelay, -1
SetBatchLines, -1

; -------------------------
; Paths / constants
; -------------------------

mainDir      := A_ScriptDir . "\"
settingsFile := A_ScriptDir "\settings.ini"

; -------------------------
; Runtime globals (state)
; -------------------------

; Discord / notifications
global webhookURL := ""    
global discordUserID := ""  
global PingSelected := 0   

; Private server join
global privateServerLink := "" 

; Multi-instance/window management
global windowIDS := []     
global currentWindow := "" 
global firstWindow := ""  
global instanceNumber := 0
global idDisplay := ""
global started := 0

; Cycle / queue orchestration
global actionQueue := []
global cycleCount := 0
global cycleFinished := 0
global toolTipText := ""

; Selection context used by ui/buy helpers
global currentItem := ""
global currentArray := ""
global currentSelectedArray := ""
global indexItem := ""
global indexArray := []

; Clock cache (refreshed every second)
global currentHour := 0
global currentMinute := 0
global currentSecond := 0

; Cached window-relative mid coords
global midX := 0
global midY := 0

; Misc small flags
global msgBoxCooldown := 0

; Feature flags / automations (activated in SetTimers)
global gearAutoActive := 0
global seedAutoActive := 0
global eggAutoActive  := 0
global cosmeticAutoActive := 0
global honeyShopAutoActive := 0
global honeyDepositAutoActive := 0
global collectPollinatedAutoActive := 0

; -------------------------
; HTTP / Discord helpers
; -------------------------

SendDiscordMessage(webhookURL, message) {

    FormatTime, messageTime, , hh:mm:ss tt
    fullMessage := "[" . messageTime . "] " . message

    json := "{""content"": """ . fullMessage . """}"
    whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")

    try {
        whr.Open("POST", webhookURL, false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send(json)
        whr.WaitForResponse()
        status := whr.Status

        if (status != 200 && status != 204) {
            return
        }
    } catch {
        return
    }

}

checkValidity(url, msg := 0, mode := "nil") {

    global webhookURL
    global privateServerLink
    global settingsFile

    isValid := 0

    if (mode = "webhook" && (url = "" || !(InStr(url, "discord.com/api") || InStr(url, "discordapp.com/api")))) {
        isValid := 0
        if (msg) {
            MsgBox, 0, Message, Invalid Webhook
            IniRead, savedWebhook, %settingsFile%, Main, UserWebhook,
            GuiControl,, webhookURL, %savedWebhook%
        }
        return false
    }

    if (mode = "privateserver" && (url = "" || !InStr(url, "roblox.com/share"))) {
        isValid := 0
        if (msg) {
            MsgBox, 0, Message, Invalid Private Server Link
            IniRead, savedServerLink, %settingsFile%, Main, PrivateServerLink,
            GuiControl,, privateServerLink, %savedServerLink%
        }
        return false
    }

    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", url, false)
        whr.Send()
        whr.WaitForResponse()
        status := whr.Status

        if (mode = "webhook" && (status = 200 || status = 204)) {
            isValid := 1
        } else if (mode = "privateserver" && (status >= 200 && status < 400)) {
            isValid := 1
        }
    } catch {
        isValid := 0
    }

    if (msg) {
        if (mode = "webhook") {
            if (isValid && webhookURL != "") {
                IniWrite, %webhookURL%, %settingsFile%, Main, UserWebhook
                MsgBox, 0, Message, Webhook Saved Successfully
            }
            else if (!isValid && webhookURL != "") {
                MsgBox, 0, Message, Invalid Webhook
                IniRead, savedWebhook, %settingsFile%, Main, UserWebhook,
                GuiControl,, webhookURL, %savedWebhook%
            }
        } else if (mode = "privateserver") {
            if (isValid && privateServerLink != "") {
                IniWrite, %privateServerLink%, %settingsFile%, Main, PrivateServerLink
                MsgBox, 0, Message, Private Server Link Saved Successfully
            }
            else if (!isValid && privateServerLink != "") {
                MsgBox, 0, Message, Invalid Private Server Link
                IniRead, savedServerLink, %settingsFile%, Main, PrivateServerLink,
                GuiControl,, privateServerLink, %savedServerLink%
            }
        }
    }

    return isValid

}

; Lightweight centered popup message tied to the active GUI
showPopupMessage(msgText := "nil", duration := 2000) {

    static popupID := 99

    ; get main GUI position and size
    WinGetPos, guiX, guiY, guiW, guiH, A

    innerX := 20
    innerY := 35
    innerW := 200
    innerH := 50
    winW := 200
    winH := 50
    x := guiX + (guiW - winW) // 2 - 40
    y := guiY + (guiH - winH) // 2

    if (!msgBoxCooldown) {
        msgBoxCooldown = 1
        Gui, %popupID%:Destroy
        Gui, %popupID%:+AlwaysOnTop -Caption +ToolWindow +Border
        Gui, %popupID%:Color, FFFFFF
        Gui, %popupID%:Font, s10 cBlack, Segoe UI
        Gui, %popupID%:Add, Text, x%innerX% y%innerY% w%innerW% h%innerH% BackgroundWhite Center cBlack, %msgText%
        Gui, %popupID%:Show, x%x% y%y% NoActivate
        SetTimer, HidePopupMessage, -%duration%
        Sleep, 2200
        msgBoxCooldown = 0
    }

}

; -------------------------
; Mouse functions
; -------------------------

SafeMoveRelative(xRatio, yRatio) {

    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinGetPos, winX, winY, winW, winH, ahk_exe RobloxPlayerBeta.exe
        moveX := winX + Round(xRatio * winW)
        moveY := winY + Round(yRatio * winH)
        MouseMove, %moveX%, %moveY%
    }

}


SafeClickRelative(xRatio, yRatio) {

    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinGetPos, winX, winY, winW, winH, ahk_exe RobloxPlayerBeta.exe
        clickX := winX + Round(xRatio * winW)
        clickY := winY + Round(yRatio * winH)
        Click, %clickX%, %clickY%
    }

}


getMouseCoord(axis) {

    WinGetPos, winX, winY, winW, winH, ahk_exe RobloxPlayerBeta.exe
        CoordMode, Mouse, Screen
        MouseGetPos, mouseX, mouseY

        relX := (mouseX - winX) / winW
        relY := (mouseY - winY) / winH

        if (axis = "x")
            return relX
        else if (axis = "y")
            return relY

    return ""  ; error

}


uiUniversal(order := 0, exitUi := 1, continuous := 0, spam := 0, spamCount := 30, delayTime := 50, mode := "universal", index := 0, dir := "nil", itemType := "nil") {
  
    global SavedSpeed
    global SavedKeybind

    global indexItem
    global currentArray

    If (!order && mode = "universal") {
        return
    }

    if (!continuous) {
        sendKeybind(SavedKeybind)
        Sleep, 50
    }  

    ; right = 1, left = 2, up = 3, down = 4, enter = 0, manual delay = 5
    if (mode = "universal") {

        Loop, Parse, order 
        {
            if (A_LoopField = "1") {
                repeatKey("Right", 1)
            }
            else if (A_LoopField = "2") {
                repeatKey("Left", 1)
            }
            else if (A_LoopField = "3") {
                repeatKey("Up", 1)
            }        
            else if (A_LoopField = "4") {
                repeatKey("Down", 1)
            }  
            else if (A_LoopField = "0") {
                repeatKey("Enter", spam ? spamCount : 1, spam ? 10 : 0)
            }       
            else if (A_LoopField = "5") {
                Sleep, 100
            } 
            if (SavedSpeed = "Stable" && A_LoopField != "5") {
                Sleep, %delayTime%
            }
        }

    }
    else if (mode = "calculate") {

        previousIndex := findIndex(currentArray, indexItem)
        sendCount := index - previousIndex

        if (dir = "up") {
            repeatKey(dir)
            repeatKey("Enter")
            repeatKey(dir, sendCount)
        }
        else if (dir = "down") {
            repeatKey(dir, sendCount)
            repeatKey("Enter")
            repeatKey(dir)
            repeatKey("Left")
            if ((currentArray.Name = "gearItems") && (index = 3)) {
                repeatKey("Right")
                repeatKey(dir)
            }
        }

    }
    else if (mode = "close") {

        if (dir = "up") {
            repeatKey(dir)
            repeatKey("Enter")
            if (currentArray.Name = "eggItems") {
                repeatKey(dir, index)
            }
            repeatKey(dir, index)
        }
        else if (dir = "down") {
            repeatKey(dir, index)
            repeatKey("Enter")
            repeatKey(dir)
        }

    }

    if (exitUi) {
        Sleep, 50
        sendKeybind(SavedKeybind)
    }

    return

}


buyUniversal(itemType) {

    global currentArray
    global currentSelectedArray
    global indexItem := ""
    global indexArray := []

    indexArray := []
    lastIndex := 0
    
    ; name array
    arrayName := itemType . "Items"
    currentArray := %arrayName%
    currentArray.Name := arrayName

    ; get arrays
    StringUpper, itemType, itemType, T

    selectedArrayName := "selected" . itemtype . "Items"
    currentSelectedArray := %selectedArrayName%

    ; get item indexes
    for i, selectedItem in currentSelectedArray {
        indexArray.Push(findIndex(currentArray, selectedItem))
    }

    ; buy items
    for i, index in indexArray {
        currentItem := currentSelectedArray[i]
        Sleep, 50
        uiUniversal(, 0, 1, , , , "calculate", index, "down", itemType)
        indexItem := currentSelectedArray[i]
        sleepAmount(100, 200)
        quickDetect(0x26EE26, 0x1DB31D, 5, 0.4262, 0.2903, 0.6918, 0.8508)
        Sleep, 50
        lastIndex := index - 1
    }

    ; end
    Sleep, 100
    uiUniversal(, 0, 1,,,, "close", lastIndex, "up", itemType)
    Sleep, 100

}


closeShop(shop, success) {

    StringUpper, shop, shop, T

    if (success) {

        Sleep, 500
        if (shop = "Egg") {
        uiUniversal("43333311140320", 1, 1)
        }
        else {
            uiUniversal("4330320", 1, 1)
        }

    }
    else {

        ToolTip, % "Error In Detecting " . shop
        SetTimer, HideTooltip, -1500
        SendDiscordMessage(webhookURL, "Failed To Detect " . shop . " Shop Opening [Error]" . (PingSelected ? " <@" . discordUserID . ">" : ""))
        ; failsafe
        uiUniversal("3332223111133322231111054105")

    }

}

; -------------------------
; Helper functions
; -------------------------

repeatKey(key := "nil", count := 1, delay := 30) {

    global SavedSpeed

    if (key = "nil") {
        return
    }

    Loop, %count% {
        Send {%key%}

        sleepTime := delay
        if (SavedSpeed = "Stable") {
            sleepTime := delay + 50
        } else if (SavedSpeed = "Fast") {
            sleepTime := delay
        } else if (SavedSpeed = "Ultra") {
            sleepTime := (delay - 25) > 5 ? (delay - 25) : 5
        } else if (SavedSpeed = "Max") {
            sleepTime := (delay - 30) > 0 ? (delay - 30) : 0
        }
        Sleep, %sleepTime%
    }

}

sendKeybind(keybind) {
    if (keybind = "\") {
        Send, \
    } else {
        Send, {%keybind%} 
    }
}


sleepAmount(fastTime, slowTime) {

    global SavedSpeed

    Sleep, % (SavedSpeed != "Stable") ? fastTime : slowTime

}

findIndex(array := "", value := "", returnValue := "int") {

    for index, item in array {
        if (value = item) {
            if (returnValue = "int") {
                return index
            }
            else if (returnValue = "bool") {
                return true
            }
        }
    }

    if (returnValue = "int") {
        return 1
    }
    else if (returnValue = "bool") {
        return false
    }

}

/*
searchItem(search := "nil") {

    if(search = "nil") {
        Return
    }

    uiUniversal("3220241021030", 0) 
    
    typeString(search)
    Sleep, 50

    if (search = "recall") {
        uiUniversal("4335505541555055", 1, 1)
    }

    uiUniversal(10)

}
*/

typeString(string, enter := 1, clean := 1) {

    if (string = "") {
        Return
    }

    if (clean) {
        Send {BackSpace 20}
        Sleep, 100
    }

    Loop, Parse, string
    {
        Send, {%A_LoopField%}
        Sleep, 100
    }

    if (enter) {
        Send, {Enter}
    }

    Return

}

dialogueClick(shop) {

    Loop, 5 {
        Send, {WheelUp}
        Sleep, 20
    }

    Sleep, 500

    if (shop = "gear") {
        SafeClickRelative(midX + 0.4, midY - 0.1)
    }
    if (shop = "egg") {
        SafeClickRelative(midX + 0.4, midY - 0.4)
    }
    else if (shop = "honey") {
        SafeClickRelative(midX + 0.4, midY)
    }

    Sleep, 500

    Loop, 5 {
    Send, {WheelDown}
        Sleep, 20
    }

    SafeClickRelative(midX, midY)

}


hotbarController(select := 0, unselect := 0, key := "nil") {

    if ((select = 1 && unselect = 1) || (select = 0 && unselect = 0) || key = "nil") {
        Return
    }

    if (unselect) {
        Send, {%key%}
        Sleep, 200
        Send, {%key%}
    }
    else if (select) {
        Send, {%key%}
    }

}


getWindowIDS(returnIndex := 0) {

    global windowIDS
    global idDisplay
    global firstWindow

    windowIDS := []
    idDisplay := ""
    firstWindow := ""

    WinGet, robloxWindows, List, ahk_exe RobloxPlayerBeta.exe

    Loop, %robloxWindows% {
        windowIDS.Push(robloxWindows%A_Index%)
        idDisplay .= windowIDS[A_Index] . ", "
    }

    firstWindow := % windowIDS[1]

    StringTrimRight, idDisplay, idDisplay, 2

    if (returnIndex) {
        Return windowIDS[returnIndex]
    }
    
}


simpleDetect(colorInBGR, variation, x1Ratio := 0.0, y1Ratio := 0.0, x2Ratio := 1.0, y2Ratio := 1.0) {

    CoordMode, Pixel, Screen
    CoordMode, Mouse, Screen

    ; limit search to specified area
	WinGetPos, winX, winY, winW, winH, ahk_exe RobloxPlayerBeta.exe

    x1 := winX + Round(x1Ratio * winW)
    y1 := winY + Round(y1Ratio * winH)
    x2 := winX + Round(x2Ratio * winW)
    y2 := winY + Round(y2Ratio * winH)

    PixelSearch, FoundX, FoundY, x1, y1, x2, y2, colorInBGR, variation, Fast
    if (ErrorLevel = 0) {
        return true
    }

}

quickDetect(color1, color2, variation := 10, x1Ratio := 0.0, y1Ratio := 0.0, x2Ratio := 1.0, y2Ratio := 1.0, item := 1, egg := 0) {

    CoordMode, Pixel, Screen
    CoordMode, Mouse, Screen

    stock := 0
    eggDetected := 0

    global currentItem
    
    ; change to whatever you want to be pinged for
    pingItems := ["Dragon Fruit Seed", "Mango Seed", "Grape Seed"
             , "Mushroom Seed", "Pepper Seed", "Cacao Seed", "Beanstalk Seed", "Ember Lily Seed"
             , "Sugar Apple Seed", "Burning Bud Seed", "Giant Pinecone Seed", "Elder Strawberry Seed"
             , "Godly Sprinkler", "Master Sprinkler", "Harvest Tool", "Levelup lollipop"
                , "Rare Egg", "Legendary Egg", "Mythical Egg", "Bug Egg", "Rare Summer Egg", "Paradise Egg"
                , "Flower Seed Pack", "Nectarine Seed", "Hive Fruit Seed", "Honey Sprinkler"
                , "Bee Egg", "Bee Crate", "Honey Comb", "Bee Chair", "Honey Torch", "Honey Walkway"]

	ping := false

    if (PingSelected) {
        for i, pingitem in pingItems {
            if (pingitem = currentItem) {
                ping := true
                break
            }
        }
    }

    ; limit search to specified area
	WinGetPos, winX, winY, winW, winH, ahk_exe RobloxPlayerBeta.exe

    x1 := winX + Round(x1Ratio * winW)
    y1 := winY + Round(y1Ratio * winH)
    x2 := winX + Round(x2Ratio * winW)
    y2 := winY + Round(y2Ratio * winH)

    ; for seeds/gears checks if either color is there (buy button)
    if (item) {
        for index, color in [color1, color2] {
            PixelSearch, FoundX, FoundY, x1, y1, x2, y2, %color%, variation, Fast RGB
            if (ErrorLevel = 0) {
                stock := 1
                ToolTip, %currentItem% `nIn Stock
                SetTimer, HideTooltip, -1500  
                uiUniversal(50, 0, 1, 1)
                Sleep, 50
                if (ping)
                    SendDiscordMessage(webhookURL, "Bought " . currentItem . ". <@" . discordUserID . ">")
                else
                    SendDiscordMessage(webhookURL, "Bought " . currentItem . ".")
            }
        }
    }

    ; for eggs
    if (egg) {
        PixelSearch, FoundX, FoundY, x1, y1, x2, y2, color1, variation, Fast RGB
        if (ErrorLevel = 0) {
            stock := 1
            ToolTip, %currentItem% `nIn Stock
            SetTimer, HideTooltip, -1500  
            uiUniversal(500, 1, 1)
            Sleep, 50
            if (ping)
                SendDiscordMessage(webhookURL, "Bought " . currentItem . ". <@" . discordUserID . ">")
            else
                SendDiscordMessage(webhookURL, "Bought " . currentItem . ".")
        }
        if (!stock) {
            uiUniversal(1105, 1, 1)
            SendDiscordMessage(webhookURL, currentItem . " Not In Stock.")  
        }
    }

    Sleep, 100

    if (!stock) {
        ToolTip, %currentItem% `nNot In Stock
        SetTimer, HideTooltip, -1500
        ; SendDiscordMessage(webhookURL, currentItem . " Not In Stock.")  
    }

}

; -------------------------
; Item arrays
; -------------------------

seedItems := ["Carrot Seed", "Strawberry Seed", "Blueberry Seed", "Orange Tulip", "Tomato Seed"
             , "Corn Seed", "Daffodil Seed", "Watermelon Seed", "Pumpkin Seed", "Apple Seed", "Bamboo Seed"
             , "Coconut Seed", "Cactus Seed", "Dragon Fruit Seed", "Mango Seed", "Grape Seed"
             , "Mushroom Seed", "Pepper Seed", "Cacao Seed", "Beanstalk Seed", "Ember Lily Seed"
             , "Sugar Apple Seed", "Burning Bud Seed", "Giant Pinecone Seed", "Elder Strawberry Seed"
             , "Romanesco"]

gearItems := ["Watering Can", "Trading Ticket", "Trowel", "Recall Wrench", "Basic Sprinkler", "Advanced Sprinkler"
             , "Medium Toy", "Medium Treat", "Godly Sprinkler", "Magnifying Glass", "Tanning Mirror", "Master Sprinkler"
             , "Cleaning Spray", "Favorite Tool", "Harvest Tool", "Friendship Pot", "Grandmaster Sprinkler"
             , "Levelup lollipop"]

eggItems := ["Common Egg", "Uncommon Egg", "Rare Egg", "Legendary Egg", "Mythical Egg"
             , "Bug Egg"]

cosmeticItems := ["Cosmetic 1", "Cosmetic 2", "Cosmetic 3", "Cosmetic 4", "Cosmetic 5"
             , "Cosmetic 6",  "Cosmetic 7", "Cosmetic 8", "Cosmetic 9"]

/*craftItems := ["Crafters Seed Pack", "Manuka Flower", "Dandelion"
    , "Lumira", "Honeysuckle", "Bee Balm", "Nectar Thorn", "Suncoil"]

craftItems2 := ["Tropical Mist Sprinkler", "Berry Blusher Sprinkler"
    , "Spice Spritzer Sprinkler", "Sweet Soaker Sprinkler"
    , "Flower Freeze Sprinkler", "Stalk Sprout Sprinkler"
    , "Mutation Spray Choc", "Mutation Spray Pollinated"
    , "Mutation Spray Shocked", "Honey Crafters Crate"
    , "Anti Bee Egg", "Pack Bee"]
*/

; -------------------------
; MAIN GUI START
; -------------------------


ShowGui:

    Gui, Destroy
    Gui, +Resize +MinimizeBox +SysMenu
    Gui, Margin, 10, 10
    Gui, Color, 0x000000
    Gui, Font, s9 cWhite, Segoe UI
    Gui, Add, Tab, x10 y10 w500 h400 vMyTab, Seeds|Gears|Eggs|Cosmetics|Settings|Credits

; -------------------------
Gui, Tab, 1
; -------------------------

    Gui, Font, s9 c90EE90 Bold, Segoe UI
    Gui, Add, GroupBox, x23 y50 w475 h340 c90EE90, Seed Shop Items
    IniRead, SelectAllSeeds, %settingsFile%, Seed, SelectAllSeeds, 0
    Gui, Add, Checkbox, % "x50 y90 vSelectAllSeeds gHandleSelectAll c90EE90 " . (SelectAllSeeds ? "Checked" : ""), Select All Seeds
    Loop, % seedItems.Length() {
        IniRead, sVal, %settingsFile%, Seed, Item%A_Index%, 0
        if (A_Index > 20) {
            col := 330
            idx := A_Index - 20
            yBase := 100
        }
        else if (A_Index > 10) {
            col := 190
            idx := A_Index - 10
            yBase := 100
        }
        else {
            col := 50
            idx := A_Index
            yBase := 100
        }
        y := yBase + (idx * 25)
        Gui, Add, Checkbox, % "x" col " y" y " vSeedItem" A_Index " gHandleSelectAll cD3D3D3 " . (sVal ? "Checked" : ""), % seedItems[A_Index]
    }

; -------------------------
Gui, Tab, 2
; -------------------------

    Gui, Font, s9 c87CEEB Bold, Segoe UI
    Gui, Add, GroupBox, x23 y50 w475 h340 c87CEEB, Gear Shop Items
    IniRead, SelectAllGears, %settingsFile%, Gear, SelectAllGears, 0
    Gui, Add, Checkbox, % "x50 y90 vSelectAllGears gHandleSelectAll c87CEEB " . (SelectAllGears ? "Checked" : ""), Select All Gears
    Loop, % gearItems.Length() {
        IniRead, gVal, %settingsFile%, Gear, Item%A_Index%, 0
        if (A_Index > 10) {
            col := 190
            idx := A_Index - 10
            yBase := 100
        }
        else {
            col := 50
            idx := A_Index
            yBase := 100
        }
        y := yBase + (idx * 25)
        Gui, Add, Checkbox, % "x" col " y" y " vGearItem" A_Index " gHandleSelectAll cD3D3D3 " . (gVal ? "Checked" : ""), % gearItems[A_Index]
    }
    
; -------------------------
Gui, Tab, 3
; -------------------------

    Gui, Font, s9 ce87b07 Bold, Segoe UI
    Gui, Add, GroupBox, x23 y50 w475 h340 ce87b07, Egg Shop
    IniRead, SelectAllEggs, %settingsFile%, Egg, SelectAllEggs, 0
    Gui, Add, Checkbox, % "x50 y90 vSelectAllEggs gHandleSelectAll ce87b07 " . (SelectAllEggs ? "Checked" : ""), Select All Eggs
    Loop, % eggItems.Length() {
        IniRead, eVal, %settingsFile%, Egg, Item%A_Index%, 0
        y := 125 + (A_Index - 1) * 25
        Gui, Add, Checkbox, % "x50 y" y " vEggItem" A_Index " gHandleSelectAll cD3D3D3 " . (eVal ? "Checked" : ""), % eggItems[A_Index]
    }


    /*
    Gui, Tab, 5
    Gui, Font, s9 cBF40BF Bold, Segoe UI

    Gui, Add, GroupBox, x23 y50 w230 h380 cBF40BF, Crafting Seeds
    Gui, Add, Text, x40 y130 w200 h40, Coming soon

    IniRead, SelectAllCraft, %settingsFile%, Craft, SelectAllCraft, 0
    Gui, Add, Checkbox, % "x40 y90 vSelectAllCraft gHandleSelectAll cBF40BF " . (SelectAllCraft ? "Checked" : ""), Select All Seeds
    Loop, % craftItems.Length() {
        IniRead, cVal,   %settingsFile%, Craft, Item%A_Index%, 0
        y := 125 + (A_Index - 1) * 25
        Gui, Add, Checkbox, % "x40 y" y " vCraftItem" A_Index " gHandleSelectAll cD3D3D3 " . (cVal ? "Checked" : ""), % craftItems[A_Index]
    }

    Gui, Add, GroupBox, x270 y50 w230 h380 cBF40BF, Crafting Tools

    IniRead, SelectAllCraft2, %settingsFile%, Craft2, SelectAllCraft2, 0
    Gui, Add, Checkbox, % "x280 y90 vSelectAllCraft2 gHandleSelectAll cBF40BF " . (SelectAllCraft2 ? "Checked" : ""), Select All Tools
    Loop, % craftItems2.Length() {
        IniRead, c2Val,  %settingsFile%, Craft2, Item%A_Index%, 0
        y := 125 + (A_Index - 1) * 25
        Gui, Add, Checkbox, % "x280 y" y " vCraftItem2" A_Index " gHandleSelectAll cD3D3D3 " . (c2Val ? "Checked" : ""), % craftItems2[A_Index]
    }
    */

; -------------------------
Gui, Tab, 4
; -------------------------

    Gui, Font, s9 cD41551 Bold, Segoe UI
    Gui, Add, GroupBox, x23 y50 w475 h340 cD41551, Cosmetic Shop

    IniRead, BuyTier1Cosmetics, %settingsFile%, Cosmetic, BuyTier1Cosmetics, 0
    IniRead, BuyTier2Cosmetics, %settingsFile%, Cosmetic, BuyTier2Cosmetics, 0
    IniRead, SelectAllCosmetics, %settingsFile%, Cosmetic, SelectAllCosmetics, 0

    Gui, Add, Checkbox, % "x50 y80 vBuyTier1Cosmetics gHandleCosmeticTier cD41551 " . (BuyTier1Cosmetics ? "Checked" : ""), Buy Tier 1
    Gui, Font, s7 cD41551, Segoe UI
    Gui, Add, Text, x50 y95 w100 h12 cD41551, (Cosmetic 4-9)
    Gui, Font, s9 cD41551 Bold, Segoe UI
    Gui, Add, Checkbox, % "x200 y80 vBuyTier2Cosmetics gHandleCosmeticTier cD41551 " . (BuyTier2Cosmetics ? "Checked" : ""), Buy Tier 2
    Gui, Font, s7 cD41551, Segoe UI
    Gui, Add, Text, x200 y95 w100 h12 cD41551, (Cosmetic 1-3)
    Gui, Font, s9 cD41551 Bold, Segoe UI
    Gui, Add, Checkbox, % "x350 y80 vSelectAllCosmetics gHandleSelectAll cD41551 " . (SelectAllCosmetics ? "Checked" : ""), Select All Cosmetics

    Loop, % cosmeticItems.Length() {
        IniRead, cVal, %settingsFile%, Cosmetic, Item%A_Index%, 0
        if (A_Index > 6) {
            col := 330
            idx := A_Index - 6
            yBase := 120
        }
        else if (A_Index > 3) {
            col := 190
            idx := A_Index - 3
            yBase := 120
        }
        else {
            col := 50
            idx := A_Index
            yBase := 120
        }
        y := yBase + (idx - 1) * 25
        Gui, Add, Checkbox, % "x" col " y" y " vCosmeticItem" A_Index " gHandleSelectAll cD3D3D3 " . (cVal ? "Checked" : ""), % cosmeticItems[A_Index]
    }

; -------------------------
Gui, Tab, 5
; -------------------------

    Gui, Font, s9, cWhite Bold, Segoe UI
    Gui, Add, GroupBox, x23 y50 w475 h340 cD3D3D3, Settings

    IniRead, PingSelected, %settingsFile%, Main, PingSelected, 0
    pingColor := PingSelected ? "c90EE90" : "cD3D3D3"
    Gui, Add, Checkbox, % "x50 y225 vPingSelected gUpdateSettingColor " . pingColor . (PingSelected ? " Checked" : ""), Discord Pings
    
    IniRead, AutoAlign, %settingsFile%, Main, AutoAlign, 0
    autoColor := AutoAlign ? "c90EE90" : "cD3D3D3"
    Gui, Add, Checkbox, % "x50 y250 vAutoAlign gUpdateSettingColor " . autoColor . (AutoAlign ? " Checked" : ""), Auto-Align

    Gui, Font, s8 cD3D3D3 Bold, Segoe UI
    Gui, Add, Text, x50 y90, Webhook URL:
    Gui, Font, s8 cBlack, Segoe UI
    IniRead, savedWebhook, %settingsFile%, Main, UserWebhook
    if (savedWebhook = "ERROR") {
        savedWebhook := ""
    }
    Gui, Add, Edit, x140 y90 w250 h18 vwebhookURL +BackgroundFFFFFF, %savedWebhook%
    Gui, Font, s8 cWhite, Segoe UI
    Gui, Add, Button, x400 y90 w85 h18 gDisplayWebhookValidity Background202020, Save Webhook

    Gui, Font, s8 cD3D3D3 Bold, Segoe UI
    Gui, Add, Text, x50 y115, Discord User ID:
    Gui, Font, s8 cBlack, Segoe UI
    IniRead, savedUserID, %settingsFile%, Main, DiscordUserID
    if (savedUserID = "ERROR") {
        savedUserID := ""
    }
    Gui, Add, Edit, x140 y115 w250 h18 vdiscordUserID +BackgroundFFFFFF, %savedUserID%
    Gui, Font, s8 cD3D3D3 Bold, Segoe UI
    Gui, Add, Button, x400 y115 w85 h18 gUpdateUserID Background202020, Save UserID
    IniRead, savedUserID, %settingsFile%, Main, DiscordUserID

    Gui, Add, Text, x50 y140, Private Server:
    Gui, Font, s8 cBlack, Segoe UI
    IniRead, savedServerLink, %settingsFile%, Main, PrivateServerLink
    if (savedServerLink = "ERROR") {
        savedServerLink := ""
    }
    Gui, Add, Edit, x140 y140 w250 h18 vprivateServerLink +BackgroundFFFFFF, %savedServerLink%
    Gui, Font, s8 cD3D3D3 Bold, Segoe UI
    Gui, Add, Button, x400 y140 w85 h18 gDisplayServerValidity Background202020, Save Link

    Gui, Add, Button, x400 y165 w85 h18 gClearSaves Background202020, Clear Saves

    Gui, Font, s8 cD3D3D3 Bold, Segoe UI
    Gui, Add, Text, x50 y165, UI Navigation Keybind:
    Gui, Font, s8 cBlack, Segoe UI
    IniRead, SavedKeybind, %settingsFile%, Main, UINavigationKeybind, \
    if (SavedKeybind = "")
    {
        SavedKeybind := "\"   
        IniWrite, %SavedKeybind%, %settingsFile%, Main, UINavigationKeybind
    }
    Gui, Add, Edit, x180 y165 w40 h18 Limit1 vSavedKeybind gUpdateKeybind, %SavedKeybind%

    Gui, Font, s8 cD3D3D3 Bold, Segoe UI
    Gui, Add, Text, x50 y190, Macro Speed:
    Gui, Font, s8 cBlack, Segoe UI
    IniRead, SavedSpeed, %settingsFile%, Main, MacroSpeed, Stable
    Gui, Add, DropDownList, vSavedSpeed gUpdateSpeed x130 y190 w50, Stable|Fast|Ultra|Max
    GuiControl, ChooseString, SavedSpeed, %SavedSpeed%

    Gui, Font, s10 cWhite Bold, Segoe UI
    Gui, Add, Button, x50 y335 w150 h40 gStartMacro Background202020, Start Macro (F5)
    Gui, Add, Button, x320 y335 w150 h40 gQuit Background202020, Stop Macro (F7)

; -------------------------
Gui, Tab, 6
; -------------------------

    Gui, Font, s9 cWhite Bold, Segoe UI
    Gui, Add, GroupBox, x23 y50 w475 h340 cD3D3D3, Credits

    Gui, Font, s10 cFFC0CB Italic, Segoe UI
    Gui, Add, Text, x30 y63 w400 h16, If you sell shit at least make the shit good - IamODI1

   
    Gui, Show, w520 h420, Cracked Virage Premium GAG Macro [PREMIUM/PAID VERSION]
Return

; -------------------------
; UI handlers
; -------------------------

DisplayWebhookValidity:
    Gui, Submit, NoHide

    checkValidity(webhookURL, 1, "webhook")
Return

UpdateUserID:
    Gui, Submit, NoHide

    if (discordUserID != "") {
        IniWrite, %discordUserID%, %settingsFile%, Main, DiscordUserID
        MsgBox, 0, Message, Discord UserID Saved
    }
Return

DisplayServerValidity:
    Gui, Submit, NoHide

    checkValidity(privateServerLink, 1, "privateserver")
Return

ClearSaves:
    IniWrite, %A_Space%, %settingsFile%, Main, UserWebhook
    IniWrite, %A_Space%, %settingsFile%, Main, DiscordUserID
    IniWrite, %A_Space%, %settingsFile%, Main, PrivateServerLink

    IniRead, savedWebhook, %settingsFile%, Main, UserWebhook
    IniRead, savedUserID, %settingsFile%, Main, DiscordUserID
    IniRead, savedServerLink, %settingsFile%, Main, PrivateServerLink

    GuiControl,, webhookURL, %savedWebhook% 
    GuiControl,, discordUserID, %savedUserID% 
    GuiControl,, privateServerLink, %savedServerLink% 

    MsgBox, 0, Message, Webhook, User Id, and Private Server Link Cleared
Return

UpdateKeybind:
    Gui, Submit, NoHide

    IniWrite, %SavedKeybind%, %settingsFile%, Main, UINavigationKeybind
    GuiControl,, SavedKeybind, %SavedKeybind%
    MsgBox, 0, Message, % "Keybind saved as: " . SavedKeybind
Return

UpdateSpeed:
    Gui, Submit, NoHide

    IniWrite, %SavedSpeed%, %settingsFile%, Main, MacroSpeed
    GuiControl, ChooseString, SavedSpeed, %SavedSpeed%
    if (SavedSpeed = "Fast") {
        MsgBox, 0, Disclaimer, % "Macro speed set to " . SavedSpeed . ". Use with caution (Requires a stable FPS rate)."
    }
    else if (SavedSpeed = "Ultra") {
        MsgBox, 0, Disclaimer, % "Macro speed set to " . SavedSpeed . ". Use at your own risk, high chance of erroring/breaking (Requires a very stable and high FPS rate)."
    }
    else if (SavedSpeed = "Max") {
        MsgBox, 0, Disclaimer, % "Macro speed set to " . SavedSpeed . ". Zero delay on UI Navigation inputs, I wouldn't recommend actually using this it's mostly here for fun."
    }
    else {
        MsgBox, 0, Message, % "Macro speed set to " . SavedSpeed . ". Recommended for lower end devices."
    }
Return

UpdateResolution:
    Gui, Submit, NoHide

    IniWrite, %selectedResolution%, %settingsFile%, Main, Resolution
return

HandleSelectAll:
    Gui, Submit, NoHide

    if (SubStr(A_GuiControl, 1, 9) = "SelectAll") {
        group := SubStr(A_GuiControl, 10)
        controlVar := A_GuiControl
        Loop {
            item := group . "Item" . A_Index
            if (%item% = "")
                break
            GuiControl,, %item%, % %controlVar%
        }
    }
    else if (RegExMatch(A_GuiControl, "^(Seed|Gear|Egg|Cosmetic)Item\d+$", m)) {
        group := m1
        
        assign := (group = "Seed" || group = "Gear" || group = "Egg" || group = "Cosmetic") ? "SelectAll" . group . "s" : "SelectAll" . group

        if (!%A_GuiControl%)
            GuiControl,, %assign%, 0
    }
    if (A_GuiControl = "SelectAllSeeds") {
        Loop, % seedItems.Length()
            GuiControl,, SeedItem%A_Index%, % SelectAllSeeds
            Gosub, SaveSettings
    }
    else if (A_GuiControl = "SelectAllEggs") {
        Loop, % eggItems.Length()
            GuiControl,, EggItem%A_Index%, % SelectAllEggs
            Gosub, SaveSettings
    }
    else if (A_GuiControl = "SelectAllGears") {
        Loop, % gearItems.Length()
            GuiControl,, GearItem%A_Index%, % SelectAllGears
            Gosub, SaveSettings
    }
    else if (A_GuiControl = "SelectAllCosmetics") {
        Loop, % cosmeticItems.Length()
            GuiControl,, CosmeticItem%A_Index%, % SelectAllCosmetics
        Gosub, SaveSettings
    }
return

HandleCosmeticTier:
    Gui, Submit, NoHide
    if (A_GuiControl = "BuyTier1Cosmetics") {
        if (BuyTier1Cosmetics) {
            ; set items 4-9
            Loop, % cosmeticItems.Length() {
                val := (A_Index >= 4) ? 1 : 0
                GuiControl,, CosmeticItem%A_Index%, %val%
            }
            GuiControl,, SelectAllCosmetics, 0
            GuiControl,, BuyTier2Cosmetics, 0
        } else {
            ; untoggle tier -> clear those items
            Loop, % cosmeticItems.Length() - 3 {
                idx := A_Index + 3
                GuiControl,, CosmeticItem%idx%, 0
            }
        }
    }
    else if (A_GuiControl = "BuyTier2Cosmetics") {
        if (BuyTier2Cosmetics) {
            ; set items 1-3
            Loop, % cosmeticItems.Length() {
                val := (A_Index <= 3) ? 1 : 0
                GuiControl,, CosmeticItem%A_Index%, %val%
            }
            GuiControl,, SelectAllCosmetics, 0
            GuiControl,, BuyTier1Cosmetics, 0
        } else {
            ; untoggle tier -> clear those items
            Loop, 3
                GuiControl,, CosmeticItem%A_Index%, 0
        }
    }
    Gosub, SaveSettings
Return

UpdateSettingColor:
    Gui, Submit, NoHide

    autoColor := "+c" . (AutoAlign ? "90EE90" : "D3D3D3")
    pingColor := "+c" . (PingSelected ? "90EE90" : "D3D3D3")
    multiInstanceColor := "+c" . (MultiInstanceMode ? "90EE90" : "D3D3D3")

    GuiControl, %autoColor%, AutoAlign
    GuiControl, +Redraw, AutoAlign
    
    GuiControl, %pingColor%, PingSelected
    GuiControl, +Redraw, PingSelected

    GuiControl, %multiInstanceColor%, MultiInstanceMode
    GuiControl, +Redraw, MultiInstanceMode
return

UpdateSelectedItems:
    Gui, Submit, NoHide
    
    selectedSeedItems := []
    Loop, % seedItems.Length() {
        if (SeedItem%A_Index%)
            selectedSeedItems.Push(seedItems[A_Index])
    }

    selectedGearItems := []
    Loop, % gearItems.Length() {
        if (GearItem%A_Index%)
            selectedGearItems.Push(gearItems[A_Index])
    }

    selectedEggItems := []
    Loop, % eggItems.Length() {
        if (EggItem%A_Index%)
            selectedEggItems.Push(eggItems[A_Index])
    }

    selectedCosmeticItems := []
    Loop, % cosmeticItems.Length() {
        if (CosmeticItem%A_Index%)
            selectedCosmeticItems.Push(cosmeticItems[A_Index])
    }
Return

GetSelectedItems() {
    result := ""
    if (selectedSeedItems.Length()) {
        result .= "Seed Items:`n"
        for _, name in selectedSeedItems
            result .= "  - " name "`n"
    }
    if (selectedGearItems.Length()) {
        result .= "Gear Items:`n"
        for _, name in selectedGearItems
            result .= "  - " name "`n"
    }
    if (selectedEggItems.Length()) {
        result .= "Egg Items:`n"
        for _, name in selectedEggItems
            result .= "  - " name "`n"
    }
    return result
}

HideTooltip:
    ToolTip
return

HidePopupMessage:
    Gui, 99:Destroy
Return

; -------------------------
; MACRO START
; -------------------------

StartMacro:
    Gui, Submit, NoHide

    global cycleCount
    global cycleFinished

    global lastGearMinute := -1
    global lastSeedMinute := -1
    global lastEggShopMinute := -1
    global lastCosmeticShopHour := -1

    started := 1
    cycleFinished := 1

    currentSection := "StartMacro"

    SetTimer, AutoReconnect, Off
    SetTimer, CheckLoadingScreen, Off

    getWindowIDS()

    SendDiscordMessage(webhookURL, "Macro started.")

    if WinExist("ahk_id " . firstWindow) {
        WinActivate
        WinWaitActive, , , 2
    }

    Sleep, 500
    Gosub, alignment
    Sleep, 100

    WinActivate, % "ahk_id " . firstWindow

    Gui, Submit, NoHide
        
    Gosub, UpdateSelectedItems  
    itemsText := GetSelectedItems()

    Sleep, 500

    Gosub, SetTimers

    while (started) {
        if (actionQueue.Length()) {
            SetTimer, AutoReconnect, Off
            ToolTip  
            next := actionQueue.RemoveAt(1)

            WinActivate, % "ahk_id " . firstWindow
            Gosub, % next

            if (!actionQueue.MaxIndex()) {
                cycleFinished := 1
            }
            Sleep, 500
        } else {
            Gosub, SetToolTip
            if (cycleFinished) {
                WinActivate, % "ahk_id " . firstWindow
                cycleCount++
                SendDiscordMessage(webhookURL, "[**CYCLE " . cycleCount . " COMPLETED**]")
                cycleFinished := 0
                SetTimer, AutoReconnect, 5000
            }
            Sleep, 1000
        }
    }
Return

; -------------------------
; MACRO ACTIONS
; -------------------------

AutoBuySeed:
    ; queues if its not the first cycle and the time is a multiple of 5
    if (cycleCount > 0 && Mod(currentMinute, 5) = 0 && currentMinute != lastSeedMinute) {
        lastSeedMinute := currentMinute
        SetTimer, PushBuySeed, -8000
    }
Return

PushBuySeed: 
    actionQueue.Push("BuySeed")
Return

BuySeed:
    currentSection := "BuySeed"
    if (selectedSeedItems.Length())
        Gosub, SeedShopPath
Return


AutoBuyGear:
    ; queues if its not the first cycle and the time is a multiple of 5
    if (cycleCount > 0 && Mod(currentMinute, 5) = 0 && currentMinute != lastGearMinute) {
        lastGearMinute := currentMinute
        SetTimer, PushBuyGear, -8000
    }
Return

PushBuyGear: 
    actionQueue.Push("BuyGear")
Return

BuyGear:
    currentSection := "BuyGear"
    if (selectedGearItems.Length())
        Gosub, GearShopPath
Return

AutoBuyEggShop:
    ; queues if its not the first cycle and the time is a multiple of 30
    if (cycleCount > 0 && Mod(currentMinute, 30) = 0 && currentMinute != lastEggShopMinute) {
        lastEggShopMinute := currentMinute
        SetTimer, PushBuyEggShop, -8000
    }
Return

PushBuyEggShop: 
    actionQueue.Push("BuyEggShop")
Return

BuyEggShop:
    currentSection := "BuyEggShop"
    if (selectedEggItems.Length()) {
        Gosub, EggShopPath
    } 
Return

AutoBuyCosmeticShop:
    ; queues if its not the first cycle, the minute is 0, and the current hour is an even number (every 4 hours)
    if (cycleCount > 0 && currentMinute = 0 && Mod(currentHour, 4) = 0 && currentHour != lastCosmeticShopHour) {
        lastCosmeticShopHour := currentHour
        SetTimer, PushBuyCosmeticShop, -8000
    }
Return

PushBuyCosmeticShop: 
    actionQueue.Push("BuyCosmeticShop")
Return

BuyCosmeticShop:
    currentSection := "BuyCosmeticShop"
    if (selectedCosmeticItems.Length()) {
        Gosub, CosmeticShopPath
    }
Return

; -------------------------
; HELPERS
; -------------------------

SetToolTip:

    mod5 := Mod(currentMinute, 5)
    rem5min := (mod5 = 0) ? 5 : 5 - mod5
    rem5sec := rem5min * 60 - currentSecond
    if (rem5sec < 0)
        rem5sec := 0
    seedMin := rem5sec // 60
    seedSec := Mod(rem5sec, 60)
    seedText := (seedSec < 10) ? seedMin . ":0" . seedSec : seedMin . ":" . seedSec
    gearMin := rem5sec // 60
    gearSec := Mod(rem5sec, 60)
    gearText := (gearSec < 10) ? gearMin . ":0" . gearSec : gearMin . ":" . gearSec

    mod30 := Mod(currentMinute, 30)
    rem30min := (mod30 = 0) ? 30 : 30 - mod30
    rem30sec := rem30min * 60 - currentSecond
    if (rem30sec < 0)
        rem30sec := 0
    eggMin := rem30sec // 60
    eggSec := Mod(rem30sec, 60)
    eggText := (eggSec < 10) ? eggMin . ":0" . eggSec : eggMin . ":" . eggSec

    totalSecNow := currentHour * 3600 + currentMinute * 60 + currentSecond
    nextCosHour := (Floor(currentHour/4) + 1) * 4
    nextCosTotal := nextCosHour * 3600
    remCossec := nextCosTotal - totalSecNow
    if (remCossec < 0)
        remCossec := 0
    cosH := remCossec // 3600
    cosM := (remCossec - cosH*3600) // 60
    cosS := Mod(remCossec, 60)
    if (cosH > 0)
        cosText := cosH . ":" . (cosM < 10 ? "0" . cosM : cosM) . ":" . (cosS < 10 ? "0" . cosS : cosS)
    else
        cosText := cosM . ":" . (cosS < 10 ? "0" . cosS : cosS)

    tooltipText := ""
    if (selectedSeedItems.Length()) {
        tooltipText .= "Seed Shop: " . seedText . "`n"
    }
    if (selectedGearItems.Length()) {
        tooltipText .= "Gear Shop: " . gearText . "`n"
    }
    if (selectedEggItems.Length()) {
        tooltipText .= "Egg Shop : " . eggText . "`n"
    }
    if (selectedCosmeticItems.Length()) {
        tooltipText .= "Cosmetic Shop: " . cosText . "`n"
    }

    if (tooltipText != "") {
        CoordMode, Mouse, Screen
        MouseGetPos, mX, mY
        offsetX := 10
        offsetY := 10
        ToolTip, % tooltipText, % (mX + offsetX), % (mY + offsetY)
    } else {
        ToolTip  ; clears any existing tooltip
    }

Return


SetTimers:

    SetTimer, UpdateTime, 1000

    if (selectedSeedItems.Length()) {
        actionQueue.Push("BuySeed")
    }
    seedAutoActive := 1
    SetTimer, AutoBuySeed, 1000 ; checks every second if it should queue

    if (selectedGearItems.Length()) {
        actionQueue.Push("BuyGear")
    }
    gearAutoActive := 1
    SetTimer, AutoBuyGear, 1000 ; checks every second if it should queue

    if (selectedEggItems.Length()) {
        actionQueue.Push("BuyEggShop")
    }
    eggAutoActive := 1
    SetTimer, AutoBuyEggShop, 1000 ; checks every second if it should queue

    if (selectedCosmeticItems.Length()) {
        actionQueue.Push("BuyCosmeticShop")
    }
    cosmeticAutoActive := 1
    SetTimer, AutoBuyCosmeticShop, 1000 ; checks every second if it should queue

Return


UpdateTime:

    FormatTime, currentHour,, hh
    FormatTime, currentMinute,, mm
    FormatTime, currentSecond,, ss

    currentHour := currentHour + 0
    currentMinute := currentMinute + 0
    currentSecond := currentSecond + 0

Return

; -------------------------
; AUTO RECONNECT HELPERS
; -------------------------

AutoReconnect:

    global actionQueue

    if (simpleDetect(0x302927, 0, 0.3988, 0.3548, 0.6047, 0.6674) && simpleDetect(0xFFFFFF, 0, 0.3988, 0.3548, 0.6047, 0.6674) && privateServerLink != "") {
        started := 0
        actionQueue := []
        SetTimer, AutoReconnect, Off
        Sleep, 500
        WinClose, % "ahk_id" . firstWindow
        Sleep, 1000
        WinClose, % "ahk_id" . firstWindow
        Sleep, 500
        Run, % privateServerLink
        ToolTip, Attempting To Reconnect
        SetTimer, HideTooltip, -5000
        SendDiscordMessage(webhookURL, "Lost connection or macro errored, attempting to reconnect..." . (PingSelected ? " <@" . discordUserID . ">" : ""))
        sleepAmount(15000, 30000)
        SetTimer, CheckLoadingScreen, 5000
    }

Return

CheckLoadingScreen:

    ToolTip, Detecting Rejoin

    getWindowIDS()

    WinActivate, % "ahk_id" . firstWindow

    if (simpleDetect(0x000000, 0, 0.75, 0.75, 0.9, 0.9)) {
        SafeClickRelative(midX, midY)
    }
    else {
        ToolTip, Rejoined Successfully
        sleepAmount(5000, 10000)
        SendDiscordMessage(webhookURL, "Successfully reconnected to server." . (PingSelected ? " <@" . discordUserID . ">" : ""))
        Sleep, 200
        Gosub, StartMacro
    }

Return

; -------------------------
; MACRO SETUP HELPERS
; -------------------------

alignment:

    ToolTip, Beginning Alignment
    SetTimer, HideTooltip, -5000

    SafeClickRelative(0.5, 0.5)
    Sleep, 100

    ;searchitem("recall")

    Sleep, 200

    if (AutoAlign) {
        GoSub, cameraChange
        Sleep, 100
        Gosub, zoomAlignment
        Sleep, 100
        GoSub, cameraAlignment
        Sleep, 100
        Gosub, characterAlignment
        Sleep, 100
        Gosub, cameraChange
        Sleep, 100
        }
    else {
        Gosub, zoomAlignment
        Sleep, 100
    }

    ToolTip, Alignment Complete
    SetTimer, HideTooltip, -1000

Return

cameraChange:

    ; changes camera mode to follow and can be called again to reverse it (0123, 0->3, 3->0)
    Send, {Escape}
    Sleep, 500
    Send, {Tab}
    Sleep, 400
    Send {Down}
    Sleep, 100
    repeatKey("Right", 2, (SavedSpeed = "Ultra") ? 55 : (SavedSpeed = "Max") ? 60 : 30)
    Sleep, 100
    Send {Escape}

Return

cameraAlignment:

    ; puts character in overhead view
    Click, Right, Down
    Sleep, 200
    SafeMoveRelative(0.5, 0.5)
    Sleep, 200
    MouseMove, 0, 800, R
    Sleep, 200
    Click, Right, Up

Return

zoomAlignment:

    ; sets correct player zoom
    SafeMoveRelative(0.5, 0.5)
    Sleep, 100

    Loop, 40 {
        Send, {WheelUp}
        Sleep, 20
    }

    Sleep, 200

    Loop, 6 {
        Send, {WheelDown}
        Sleep, 20
    }

    midX := getMouseCoord("x")
    midY := getMouseCoord("y")

Return

characterAlignment:

    ; aligns character through spam tping and using the follow camera mode
    sendKeybind(SavedKeybind)
    Sleep, 10

    uiUniversal(3, 0, 1)
    Sleep, 10

    Loop, % ((SavedSpeed = "Ultra") ? 12 : (SavedSpeed = "Max") ? 18 : 12) {
    Send, {Enter}
    Sleep, 10
    Send, {right}
    Sleep, 20
    Send, {right}
    Sleep, 10
    Send, {Enter}
    Sleep, 10
    Send, {left}
    Sleep, 20
    Send, {left}
    }
    Sleep, 10
    sendKeybind(SavedKeybind)

Return

; -------------------------
; BUYING SHOPS HELPERS
; -------------------------

EggShopPath:

    eggsCompleted := 0

    Sleep, 100
    uiUniversal("1")
    Sleep, 100
    hotbarController(1, 0, "2")
    sleepAmount(100, 1000)
    SafeClickRelative(midX, midY)
    sleepAmount(1200, 2500)
    Send, {w Down}
    Sleep, 650
    Send, {w Up}
    sleepAmount(100, 1000)
    Send, {e}
    sleepAmount(1500, 5000)
    dialogueClick("egg")
    SendDiscordMessage(webhookURL, "**[Egg Shop Cycle]**")
    sleepAmount(2500, 5000)
    ; checks for the shop opening up to 5 times to ensure it doesn't fail
    Loop, 5 {
       if (simpleDetect(0x00CCFF, 10, 0.54, 0.20, 0.65, 0.325)) {
            ToolTip, Egg Shop Opened
            SetTimer, HideTooltip, -1500
            SendDiscordMessage(webhookURL, "Egg Shop Opened.")
            Sleep, 200
            uiUniversal("3333333333333314", 0)
            Sleep, 100
            buyUniversal("egg")
            SendDiscordMessage(webhookURL, "Egg Shop Closed.")
            eggsCompleted = 1
        }
        if (eggsCompleted) {
            break
        }
        Sleep, 2000
    }

    closeShop("egg", eggsCompleted)

    hotbarController(0, 1, "0")
    SendDiscordMessage(webhookURL, "**[Egg Shop Completed]**")


Return

SeedShopPath:

    seedsCompleted := 0

    uiUniversal("30")
    sleepAmount(100, 1000)
    Send, {e}
    SendDiscordMessage(webhookURL, "**[Seed Cycle]**")
    sleepAmount(2500, 5000)
    ; checks for the shop opening up to 5 times to ensure it doesn't fail
    Loop, 5 {
        if (simpleDetect(0x00CCFF, 10, 0.54, 0.20, 0.65, 0.325)) {
            ToolTip, Seed Shop Opened
            SetTimer, HideTooltip, -1500
            SendDiscordMessage(webhookURL, "Seed Shop Opened.")
            Sleep, 200
            uiUniversal("333333333333333333333333333333333333333333314", 0)
            Sleep, 100
            buyUniversal("seed")
            SendDiscordMessage(webhookURL, "Seed Shop Closed.")
            seedsCompleted = 1
        }
        if (seedsCompleted) {
            break
        }
        Sleep, 2000
    }

    closeShop("seed", seedsCompleted)

    Sleep, 200
    Gosub, alignment
    Sleep, 200

    SendDiscordMessage(webhookURL, "**[Seeds Completed]**")

Return

GearShopPath:

    gearsCompleted := 0

    ;hotbarController(0, 1, "0")
    uiUniversal("1")
    sleepAmount(100, 500)
    hotbarController(1, 0, "2")
    sleepAmount(100, 500)
    SafeClickRelative(midX, midY)
    sleepAmount(1200, 2500)
    Send, {e}
    SendDiscordMessage(webhookURL, "**[Gear Cycle]**")
    sleepAmount(2500, 5000)
    ; checks for the shop opening up to 5 times to ensure it doesn't fail
    Loop, 5 {
        if (simpleDetect(0x00CCFF, 10, 0.54, 0.20, 0.65, 0.325)) {
            ToolTip, Gear Shop Opened
            SetTimer, HideTooltip, -1500
            SendDiscordMessage(webhookURL, "Gear Shop Opened.")
            Sleep, 200
            uiUniversal("3333333333333333333333333333333314", 0)
            Sleep, 100
            buyUniversal("gear")
            SendDiscordMessage(webhookURL, "Gear Shop Closed.")
            gearsCompleted = 1
        }
        if (gearsCompleted) {
            break
        }
        Sleep, 2000
    }

    closeShop("gear", gearsCompleted)

    ;hotbarController(0, 1, "0")
    SendDiscordMessage(webhookURL, "**[Gears Completed]**")

Return

CosmeticShopPath:

    cosmeticsCompleted := 0

    ;hotbarController(0, 1, "0")
    uiUniversal("1")
    sleepAmount(100, 500)
    hotbarController(1, 0, "2")
    sleepAmount(100, 500)
    SafeClickRelative(midX, midY)
    sleepAmount(800, 1000)
    Send, {s Down}
    Sleep, 550
    Send, {s Up}
    sleepAmount(100, 1000)
    Send, {e}
    sleepAmount(2500, 5000)
    SendDiscordMessage(webhookURL, "**[Cosmetic Cycle]**")

    Loop, 5 {
        if (simpleDetect(0x00CCFF, 10, 0.61, 0.182, 0.764, 0.259)) {
            ToolTip, Cosmetic Shop Opened
            SetTimer, HideTooltip, -1500
            SendDiscordMessage(webhookURL, "Cosmetic Shop Opened.")
            Sleep, 200
            ; buy selected cosmetics (selectedCosmeticItems populated in UpdateSelectedItems)
            for _, item in selectedCosmeticItems {
                label := StrReplace(item, " ", "")
                currentItem := item
                Gosub, %label%
                SendDiscordMessage(webhookURL, "Bought " . currentItem . (PingSelected ? " <@" . discordUserID . ">" : ""))
                Sleep, 100
            }
            SendDiscordMessage(webhookURL, "Cosmetic Shop Closed.")
            cosmeticsCompleted = 1
        }
        if (cosmeticsCompleted) {
            break
        }
        Sleep, 2000
    }

    if (cosmeticsCompleted) {
        Sleep, 500
        uiUniversal("333333311110")
    }
    else {
        SendDiscordMessage(webhookURL, "Failed To Detect Cosmetic Shop Opening [Error]" . (PingSelected ? " <@" . discordUserID . ">" : ""))
        ; failsafe
        uiUniversal("333333311110")
        Sleep, 10000
    }

    hotbarController(0, 1, "0")
    SendDiscordMessage(webhookURL, "**[Cosmetics Completed]**")

Return

; -------------------------
; BUYING SHOPS LABELS
; -------------------------

Cosmetic1:

    Sleep, 50
    Loop, 5 {
        uiUniversal("330")
        sleepAmount(50, 200)
    }

Return

Cosmetic2:

    Sleep, 50
    Loop, 5 {
        uiUniversal("3310")
        sleepAmount(50, 200)
    }

Return

Cosmetic3:

    Sleep, 50
    Loop, 5 {
        uiUniversal("331110")
        sleepAmount(50, 200)
    }

Return

Cosmetic4:

    Sleep, 50
    Loop, 5 {
        uiUniversal("320")
        sleepAmount(50, 200)
    }

Return

Cosmetic5:

    Sleep, 50
    Loop, 5 {
        uiUniversal("30")
        sleepAmount(50, 200)
    }

Return

Cosmetic6:

    Sleep, 50
    Loop, 5 {
        uiUniversal("310")
        sleepAmount(50, 200)
    }

Return

Cosmetic7:

    Sleep, 50
    Loop, 5 {
        uiUniversal("3110")
        sleepAmount(50, 200)
    }

Return

Cosmetic8:

    Sleep, 50
    Loop, 5 {
        uiUniversal("31110")
        sleepAmount(50, 200)
    }

Return

Cosmetic9:

    Sleep, 50
    Loop, 5 {
        uiUniversal("311110")
        sleepAmount(50, 200)
    }

Return

; -------------------------
; SAVE SYSTEM
; -------------------------


SaveSettings:

    Gui, Submit, NoHide

    ; — Egg section —
    Loop, % eggItems.Length()
        IniWrite, % (EggItem%A_Index%    ? 1 : 0), %settingsFile%, Egg, Item%A_Index%
    IniWrite, % SelectAllEggs,         %settingsFile%, Egg, SelectAllEggs

    ; — Gear section —
    Loop, % gearItems.Length()
        IniWrite, % (GearItem%A_Index%   ? 1 : 0), %settingsFile%, Gear, Item%A_Index%
    IniWrite, % SelectAllGears,        %settingsFile%, Gear, SelectAllGears

    ; — Seed section —
    Loop, % seedItems.Length()
        IniWrite, % (SeedItem%A_Index%   ? 1 : 0), %settingsFile%, Seed, Item%A_Index%
    IniWrite, % SelectAllSeeds,        %settingsFile%, Seed, SelectAllSeeds

    ; — Cosmetic section —
    Loop, % cosmeticItems.Length()
        IniWrite, % (CosmeticItem%A_Index% ? 1 : 0), %settingsFile%, Cosmetic, Item%A_Index%
    IniWrite, % SelectAllCosmetics,     %settingsFile%, Cosmetic, SelectAllCosmetics
    IniWrite, % BuyTier1Cosmetics,      %settingsFile%, Cosmetic, BuyTier1Cosmetics
    IniWrite, % BuyTier2Cosmetics,      %settingsFile%, Cosmetic, BuyTier2Cosmetics

    ; — Main section —
    IniWrite, % AutoAlign,             %settingsFile%, Main, AutoAlign
    IniWrite, % PingSelected,          %settingsFile%, Main, PingSelected
    IniWrite, % SavedSpeed,            %settingsFile%, Main, MacroSpeed
    IniWrite, % privateServerLink,     %settingsFile%, Main, PrivateServerLink
    IniWrite, % discordUserID,         %settingsFile%, Main, DiscordUserID
    IniWrite, % SavedKeybind,          %settingsFile%, Main, UINavigationKeybind
    IniWrite, % webhookURL,            %settingsFile%, Main, UserWebhook

Return

; -------------------------
; HOTKEYS
; -------------------------

StopMacro(terminate := 1) {

    Gui, Submit, NoHide
    Sleep, 50
    started := 0
    Gosub, SaveSettings
    Gui, Destroy
    if (terminate)
        ExitApp

}

PauseMacro(terminate := 1) {

    Gui, Submit, NoHide
    Sleep, 50
    started := 0
    Gosub, SaveSettings

}

; pressing x on window closes macro 
GuiClose:

    StopMacro(1)

Return

; pressing f7 button reloads
Quit:

    PauseMacro(1)
    SendDiscordMessage(webhookURL, "Macro reloaded.")
    Reload

Return

; f7 reloads
F7::

    PauseMacro(1)
    SendDiscordMessage(webhookURL, "Macro reloaded.")
    Reload

Return

; f5 starts macro
F5:: 

Gosub, StartMacro

Return

#MaxThreadsPerHotkey, 2

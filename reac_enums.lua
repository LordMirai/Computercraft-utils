REAC_DISABLED = 0
REAC_STOPPED = 1
REAC_HALF_POWER = 2
REAC_FULL_POWER = 3
REAC_OVERRIDE = 4

REAC_STATUS = {
    [REAC_DISABLED] = "Disabled",
    [REAC_STOPPED] = "Stopped",
    [REAC_HALF_POWER] = "Half Power",
    [REAC_FULL_POWER] = "Full Power",
    [REAC_OVERRIDE] = "OVERRIDE"
}

REAC_STATUS_COLOR = {
    [REAC_DISABLED] = colors.gray,
    [REAC_STOPPED] = colors.orange,
    [REAC_HALF_POWER] = colors.yellow,
    [REAC_FULL_POWER] = colors.green,
    [REAC_OVERRIDE] = colors.red
}
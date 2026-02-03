Config = {}

-- [1] LICENCIA Y MODO PRODUCCIÓN
Config.LicenseKey = "JELER-LICENSE-KEY" 
Config.DebugMode = false -- [IMPORTANTE] false = BANEOS ACTIVOS y consola limpia.

-- [2] LISTAS NEGRAS (VEHÍCULOS Y ARMAS)
Config.BlacklistedVehicles = {
    "rhino", "lazer", "hydra", "oppressor", "oppressor2", "khanjali", "cargoplane"
}
Config.BlacklistedWeapons = {
    "WEAPON_RPG", "WEAPON_MINIGUN", "WEAPON_RAILGUN", "WEAPON_GARBAGEBAG", "WEAPON_HOMINGLAUNCHER"
}
Config.BlacklistAction = "ban" 

-- [3] BYPASS VEHÍCULOS (WHITELIST)
Config.WhitelistedVehicles = {
    "police", "cargoplane", "volaticus", "deluxo", 
    "ferrari488", "supra_mk4", "gtr_r35"
}

-- [4] LÍMITES DE MOVIMIENTO
Config.NoclipCheckInterval = 2000 
Config.MaxRunSpeed = 12.0 
Config.MaxFlyHeight = 10.0 
Config.MaxVehicleSpeed = 60.0 
Config.MaxWalkSpeed = 3.5 
Config.MaxSprintSpeed = 7.5 

-- [5] TOLERANCIAS DE AIM
Config.WeaponClasses = {
    ['default'] = { tolerance = 6.0, severity = 10 },
    ['sniper']  = { tolerance = 3.5, severity = 25 },
    ['shotgun'] = { tolerance = 14.0, severity = 5 },
    ['smg']     = { tolerance = 8.0, severity = 8 },
}
Config.MaxHitboxRadius = 0.25 

-- [6] SISTEMA DE INTEGRIDAD
Config.BanThreshold = 100.0 -- Puntos necesarios para banear
Config.LegitReward = 3.0    
Config.AnalysisWindow = 20
Config.MinBoneVariety = 3 
Config.MinAngularVariance = 0.4
Config.PingAssist = 110

-- [7] SEGURIDAD AVANZADA
Config.GodmodeStrikes = 4
Config.MagicBulletSeverity = 40
Config.MaxEntitiesPerSecond = 10 
Config.BlacklistedEntities = { "prop_windmill_01", "p_spinning_anus_s", "cargoplane", "blimp" }
Config.BlacklistedExplosions = { 29, 30, 31, 32 }

-- [8] ANTI-STOP RESOURCE
Config.HeartbeatTimeout = 60    -- Tiempo límite Jugando
Config.LoginTimeout = 300       -- Tiempo límite Cargando

-- [9] DETECTOR DE TECLAS
Config.BlacklistedKeys = {
    { key = 121, name = "INSERT" },
    { key = 212, name = "HOME" },
    { key = 178, name = "DELETE" }
}

-- [10] COMANDOS PROHIBIDOS
Config.BlacklistedCommands = {
    "god", "noclip", "givemoney", "giveitem", "setjob", "esx:giveaccountmoney", "unban", "bring", "revive"
}

-- [11] SEGURIDAD DE TOKEN
Config.TokenRotationInterval = 300 

-- [12] DETECCIÓN DE INYECTORES (GLOBAL SCAN)
Config.BlacklistedGlobals = {
    "Eulen", "Skript", "Lynx", "Ham", "Murtaza", "Fallout", "Tiago", "Brutan", "Fallen", "RedENGINE"
}

-- [13] SNAP DETECTION
Config.MaxRotationSpeed = 85.0 

-- [14] DAMAGE DESYNC
Config.MaxDesyncDistance = 4.5
Config = {}

-- [1] LICENCIA Y DEBUG
Config.LicenseKey = "TEST-DEV-KEY" 
Config.DebugMode = true 

-- [2] LISTAS NEGRAS
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
Config.BanThreshold = 100.0 
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
Config.HeartbeatTimeout = 60 

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

-- [17] SEGURIDAD DE TOKEN (NUEVO)
Config.TokenRotationInterval = 300 -- Segundos (Cada 5 min rota la clave)
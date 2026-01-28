Config = {}

-- [1] LICENCIA Y DEBUG
Config.LicenseKey = "TEST-DEV-KEY" 
Config.DebugMode = true -- Pon false en producción

-- [2] LISTAS NEGRAS (VEHÍCULOS Y ARMAS PROHIBIDAS)
Config.BlacklistedVehicles = {
    "rhino", "lazer", "hydra", "oppressor", "oppressor2", "khanjali", "cargoplane"
}
Config.BlacklistedWeapons = {
    "WEAPON_RPG", "WEAPON_MINIGUN", "WEAPON_RAILGUN", "WEAPON_GARBAGEBAG", "WEAPON_HOMINGLAUNCHER"
}
Config.BlacklistAction = "ban" -- "ban", "delete" o "log"

-- [3] BYPASS VEHÍCULOS (WHITELIST)
-- Agrega aquí los nombres de tus autos custom rápidos para que NO sean detectados como Speedhack.
Config.WhitelistedVehicles = {
    "police", "cargoplane", "volaticus", "deluxo", 
    "ferrari488", "supra_mk4", "gtr_r35" -- Tus autos custom aquí
}

-- [4] LÍMITES DE MOVIMIENTO
Config.NoclipCheckInterval = 2000 
Config.MaxRunSpeed = 12.0 -- Max velocidad a pie (Server-side)
Config.MaxFlyHeight = 10.0 -- Max altura salto (Server-side)
Config.MaxVehicleSpeed = 60.0 -- Max velocidad vehículo (60m/s = ~216km/h). Ignorado si está en Whitelist.
Config.MaxWalkSpeed = 3.5 -- (Client-side)
Config.MaxSprintSpeed = 7.5 -- (Client-side)

-- [5] TOLERANCIAS DE AIM (SILENT AIM)
Config.WeaponClasses = {
    ['default'] = { tolerance = 6.0, severity = 10 },
    ['sniper']  = { tolerance = 3.5, severity = 25 },
    ['shotgun'] = { tolerance = 14.0, severity = 5 },
    ['smg']     = { tolerance = 8.0, severity = 8 },
}
Config.MaxHitboxRadius = 0.25 -- 25cm (Magic Bullet)

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
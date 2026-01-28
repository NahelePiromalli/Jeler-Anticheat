Config = {}

-- [1] LICENCIA SAAS
-- Usa "TEST-DEV-KEY" para probar sin servidor API externo.
Config.LicenseKey = "TEST-DEV-KEY" 

-- [2] SISTEMA DE INTEGRIDAD (CREDIT SCORE)
-- Umbral de baneo. Si la sospecha llega a 100, Adiós.
Config.BanThreshold = 100.0 
-- Puntos que se RESTAN por cada tiro legítimo (Premio al jugador Pro).
Config.LegitReward = 3.0    

-- [3] HEURÍSTICA (DETECCIÓN DE "LEGIT CHEATS")
Config.AnalysisWindow = 20 -- Analizar bloques de 20 disparos
Config.MinBoneVariety = 3  -- Un humano debe pegar en al menos 3 huesos distintos en 20 tiros.
Config.MinAngularVariance = 0.4 -- Si la varianza es menor a esto, es un robot (Aim Lock Suave).

-- [4] TOLERANCIAS DE ÁNGULO (SILENT AIM)
Config.WeaponClasses = {
    ['default'] = { tolerance = 6.0, severity = 10 },
    ['sniper']  = { tolerance = 3.5, severity = 25 }, -- Snipers deben ser precisos
    ['shotgun'] = { tolerance = 14.0, severity = 5 }, -- Escopetas dispersan mucho
    ['smg']     = { tolerance = 8.0, severity = 8 },
}

-- [5] MAGIC BULLET (HITBOX EXPANSION)
-- Distancia máxima permitida entre la línea de mira y la hitbox (Metros).
-- 0.25m = 25cm (Permite un poco de lag, pero detecta expansiones grandes).
Config.MaxHitboxRadius = 0.25 
Config.MagicBulletSeverity = 40 -- Castigo severo.

-- [6] AJUSTES DE RED
Config.PingAssist = 110 -- MS de Ping para empezar a relajar la seguridad.
Config.DebugMode = true -- Ver datos matemáticos en consola del servidor.

-- [7] DETECCIÓN DE NOCLIP / SPEEDHACK
Config.NoclipCheckInterval = 2000 -- Chequear cada 2 segundos (Ahorra CPU)
Config.MaxRunSpeed = 12.0 -- Metros por segundo (Humano corriendo ~7m/s)
Config.MaxFlyHeight = 10.0 -- Si sube X metros sin vehículo, es sospechoso.

-- [8] DETECCIÓN DE GODMODE
Config.GodmodeStrikes = 4 -- Cuántas veces debe bloquear daño antes de banear (Por si hay desync)
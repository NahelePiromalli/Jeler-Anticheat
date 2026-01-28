local isAuthenticated = false
local PlayerSuspicion = {} -- Score de Integridad
local PlayerStats = {}     -- Historial Estadístico (Últimos 20 tiros)
local API_URL = "https://tu-api.com/verify" -- Tu Backend real
local PlayerPositions = {} -- Para guardar donde estaba el jugador hace 2 segundos
local GodmodeStrikes = {}  -- Contador de veces que bloqueó daño

-- =============================================================================
-- MÓDULO 1: GODMODE VALIDATOR (Server Side)
-- =============================================================================
-- Se activa cuando alguien recibe un disparo
AddEventHandler('weaponDamageEvent', function(sender, data)
    if not isAuthenticated then return end
    
    local victimId = data.hitGlobalId
    local victimPed = GetPlayerPed(victimId)
    
    -- Solo nos importa si la víctima es un jugador y existe
    if not DoesEntityExist(victimPed) or not IsPedAPlayer(victimPed) then return end
    
    -- Si el daño es 0 (ej: armas de juguete), ignorar
    if data.weaponDamage <= 0 then return end

    -- FOTO DE SALUD ANTES DEL DAÑO
    local healthBefore = GetEntityHealth(victimPed)
    local armorBefore = GetPedArmour(victimPed)

    -- Esperamos 150ms a que el servidor procese el impacto
    SetTimeout(150, function()
        -- Verificamos si la entidad sigue existiendo (pudo desconectarse)
        if not DoesEntityExist(victimPed) then return end

        local healthAfter = GetEntityHealth(victimPed)
        local armorAfter = GetPedArmour(victimPed)

        -- LÓGICA: Si la vida y armadura siguen IGUALES, pero recibió daño -> Godmode
        if healthBefore == healthAfter and armorBefore == armorAfter then
            -- Excepción: Si ya estaba muerto (Vida 0 o 100 según el framework)
            if IsEntityDead(victimPed) then return end
            
            -- Excepción: Admins
            if IsPlayerAceAllowed(victimId, "sentinel.bypass") then return end

            -- SUMAR STRIKE
            if not GodmodeStrikes[victimId] then GodmodeStrikes[victimId] = 0 end
            GodmodeStrikes[victimId] = GodmodeStrikes[victimId] + 1
            
            if Config.DebugMode then
                print("^3[GODMODE CHECK] ^7Jugador "..victimId.." no recibió daño. Strike: "..GodmodeStrikes[victimId])
            end

            if GodmodeStrikes[victimId] >= Config.GodmodeStrikes then
                -- BANEO
                DropPlayer(victimId, "🛡️ Sentinel AC: Invencibilidad Detectada (Godmode)")
                -- Enviar a API SaaS...
            end
        else
            -- Si recibió daño, bajamos los strikes (Falso positivo por lag limpiado)
            if GodmodeStrikes[victimId] and GodmodeStrikes[victimId] > 0 then
                GodmodeStrikes[victimId] = GodmodeStrikes[victimId] - 1
            end
        end
    end)
    
    -- (Aquí sigue tu código anterior de Silent Aim / Magic Bullet...)
end)

-- =============================================================================
-- MÓDULO 2: NOCLIP & SPEEDHACK DETECTOR (Loop Optimizado)
-- =============================================================================
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.NoclipCheckInterval) -- Cada 2 segundos
        
        if isAuthenticated then
            for _, playerId in ipairs(GetPlayers()) do
                local ped = GetPlayerPed(playerId)
                
                -- Solo analizamos si existe y NO es admin
                if DoesEntityExist(ped) and not IsPlayerAceAllowed(playerId, "sentinel.bypass") then
                    local pos = GetEntityCoords(ped)
                    
                    if PlayerPositions[playerId] then
                        local prevPos = PlayerPositions[playerId]
                        local distance = #(pos - prevPos)
                        
                        -- CÁLCULO DE VELOCIDAD (Distancia / Tiempo)
                        -- Como chequeamos cada 2s, la velocidad es Distancia / 2
                        local speed = distance / (Config.NoclipCheckInterval / 1000)

                        -- VALIDACIONES DE ENTORNO (Para no banear injustamente)
                        local isInVehicle = IsPedInAnyVehicle(ped, false)
                        local isFalling = IsPedFalling(ped) or IsPedRagdoll(ped) or IsPedInParachuteFreeFall(ped)
                        
                        -- CHEQUEO 1: MOVIMIENTO HORIZONTAL RÁPIDO (Speedhack)
                        if not isInVehicle and not isFalling then
                            if speed > Config.MaxRunSpeed then
                                -- Posible Speedhack o Noclip rápido
                                -- Usamos AddSuspicion de tu código anterior
                                AddSuspicion(playerId, 20, "Speedhack/Noclip (Vel: "..math.floor(speed).."m/s)")
                            end
                        end

                        -- CHEQUEO 2: MOVIMIENTO VERTICAL (Volar hacia arriba)
                        -- Si Z aumenta drásticamente y no está cayendo ni en vehículo
                        local heightDiff = pos.z - prevPos.z
                        if heightDiff > Config.MaxFlyHeight and not isInVehicle and not isFalling then
                            -- Nadie salta 10 metros hacia arriba
                            AddSuspicion(playerId, 50, "Flying/Noclip (Altura: +"..math.floor(heightDiff).."m)")
                        end
                    end
                    
                    -- Actualizar posición para el siguiente ciclo
                    PlayerPositions[playerId] = pos
                else
                    -- Si deja de existir, limpiamos memoria
                    PlayerPositions[playerId] = nil
                    GodmodeStrikes[playerId] = nil
                end
            end
        end
    end
end)

-- Hashes de Armas
local WeaponGroups = {
    [GetHashKey("WEAPON_SNIPERRIFLE")] = 'sniper', [GetHashKey("WEAPON_HEAVYSNIPER")] = 'sniper',
    [GetHashKey("WEAPON_HEAVYSNIPER_MK2")] = 'sniper', [GetHashKey("WEAPON_MARKSMANRIFLE")] = 'sniper',
    [GetHashKey("WEAPON_PUMPSHOTGUN")] = 'shotgun', [GetHashKey("WEAPON_SAWNOFFSHOTGUN")] = 'shotgun',
    [GetHashKey("WEAPON_MICROSMG")] = 'smg', [GetHashKey("WEAPON_SMG")] = 'smg'
}

-- 1. AUTENTICACIÓN SAAS
AddEventHandler('onResourceStart', function(res)
    if GetCurrentResourceName() ~= res then return end
    
    if Config.LicenseKey == "TEST-DEV-KEY" then
        isAuthenticated = true
        print("^2[Jeler AC] ^7MODO TEST: Sistema Activo Localmente.")
    else
        -- AQUÍ TU PETICIÓN HTTP A TU NUBE
        isAuthenticated = true -- Simulamos éxito
    end
end)

-- 2. GESTIÓN DE SOSPECHA (CREDIT SCORE)
local function AddSuspicion(source, points, reason)
    if not PlayerSuspicion[source] then PlayerSuspicion[source] = 0.0 end
    PlayerSuspicion[source] = PlayerSuspicion[source] + points
    
    if Config.DebugMode then
        print(string.format("^3[ANALYSIS] ^7ID:%s | +%.1f pts | Total: %.1f/%d | Razón: %s", 
            source, points, PlayerSuspicion[source], Config.BanThreshold, reason))
    end

    if PlayerSuspicion[source] >= Config.BanThreshold then
        print("^1[BAN] ^7BANEANDO A ID " .. source)
        DropPlayer(source, "🛡️ Jeler AC: Detección Confirmada ("..reason..")")
        PlayerSuspicion[source] = 0 
        -- Enviar reporte a API SaaS
    end
end

local function RewardLegitShot(source)
    if PlayerSuspicion[source] and PlayerSuspicion[source] > 0 then
        PlayerSuspicion[source] = PlayerSuspicion[source] - Config.LegitReward
        if PlayerSuspicion[source] < 0 then PlayerSuspicion[source] = 0 end
    end
end

-- 3. ANÁLISIS ESTADÍSTICO (HEURÍSTICA)
local function AnalyzeHeuristics(source, stats)
    local name = GetPlayerName(source)
    
    -- A. BONE LOCKING (Siempre pega en el mismo hueso)
    local uniqueBones = {}
    for _, b in pairs(stats.bones) do uniqueBones[b] = true end
    local count = 0
    for _ in pairs(uniqueBones) do count = count + 1 end

    if count < Config.MinBoneVariety then
        AddSuspicion(source, 35, "Bone Locking (Variety: "..count..")")
    end

    -- B. ROBOTIC AIM (Varianza Artificialmente Baja)
    local variance = MathUtils.StandardDeviation(stats.angles)
    local avgAngle = MathUtils.Average(stats.angles)

    -- Si el ángulo promedio es bajo (Apunta bien) PERO la varianza es CASI CERO
    -- Significa que es un aimbot suavizado (Low FOV). Un humano tiembla más.
    if avgAngle < 8.0 and variance < Config.MinAngularVariance then
        print("^1[HEURÍSTICA] ^7ID:"..source.." Puntería Robótica. Var: "..variance)
        AddSuspicion(source, 50, "Robotic Aim (Low Variance)")
    end
end

-- 4. EVENTO PRINCIPAL DE DISPARO
AddEventHandler('weaponDamageEvent', function(sender, data)
    if not isAuthenticated then return end
    if not sender or not data.hitGlobalId then return end

    local shooter = GetPlayerPed(sender)
    local victim = GetPlayerPed(data.hitGlobalId)
    if not DoesEntityExist(victim) or not IsPedAPlayer(victim) then return end
    if IsPlayerAceAllowed(sender, "jeler.bypass") then return end

    -- Preparar Datos
    local weaponHash = GetSelectedPedWeapon(shooter)
    local wClass = WeaponGroups[weaponHash] or 'default'
    local wConfig = Config.WeaponClasses[wClass]
    local ping = GetPlayerPing(sender)

    -- Ajuste por Lag
    local tolerance = wConfig.tolerance
    local hitRadius = Config.MaxHitboxRadius
    if ping > Config.PingAssist then
        tolerance = tolerance * 1.5
        hitRadius = hitRadius + 0.15
    end

    -- Cálculos Vectores
    local headPos = MathUtils.GetHeadCoords(shooter)
    local hitPos = GetEntityCoords(victim)
    if data.hitComponent == 31086 then -- Refinar si es headshot
        local s, h = pcall(GetPedBoneCoords, victim, 31086, 0.0, 0.0, 0.0)
        if s then hitPos = h end
    end

    local distance = #(hitPos - headPos)
    if distance < 3.0 then return end -- Ignorar melee range

    local bulletVec = MathUtils.NormalizeVector(hitPos - headPos)
    local camDir = MathUtils.RotationToDirection(GetEntityRotation(shooter, 2))
    
    -- A. MAGIC BULLET CHECK (Geometría)
    local missDist = MathUtils.DistanceFromLineToPoint(headPos, camDir, hitPos)
    
    if missDist > hitRadius then
        -- Bala pasó lejos de la hitbox permitida
        AddSuspicion(sender, Config.MagicBulletSeverity, "Magic Bullet (Miss: "..string.format("%.2fm", missDist)..")")
        return -- No premiamos este tiro
    end

    -- B. SILENT AIM CHECK (Ángulo)
    local angle = MathUtils.CalculateAngle(bulletVec, camDir)
    
    if angle > tolerance then
        local excess = angle - tolerance
        AddSuspicion(sender, wConfig.severity + (excess * 2), "Silent Aim (Dev: "..string.format("%.1f", angle).."°)")
    else
        -- TIRO VÁLIDO -> PREMIAR Y GUARDAR ESTADÍSTICA
        RewardLegitShot(sender)
        
        -- Guardar para Heurística
        if not PlayerStats[sender] then 
            PlayerStats[sender] = { shots = 0, angles = {}, bones = {} } 
        end
        local st = PlayerStats[sender]
        st.shots = st.shots + 1
        table.insert(st.angles, angle)
        table.insert(st.bones, data.hitComponent)

        -- Si llenamos la ventana de análisis (20 tiros)
        if st.shots >= Config.AnalysisWindow then
            AnalyzeHeuristics(sender, st)
            PlayerStats[sender] = { shots = 0, angles = {}, bones = {} } -- Reset
        end
    end
end)
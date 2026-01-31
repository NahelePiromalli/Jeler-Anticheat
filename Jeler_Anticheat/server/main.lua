local isAuthenticated = false
local PlayerSuspicion = {} 
local PlayerStats = {}     
local PlayerPositions = {} 
local GodmodeStrikes = {}  
local EntityRates = {}     
local LastHeartbeat = {} 

-- NUEVO: Historial de Rotación para Snap Check
local PlayerRotations = {} 

-- SISTEMA DE SEGURIDAD STATEFUL
local PlayerSecurity = {} 

-- CACHÉ
local BlacklistedVehHashes = {}
local BlacklistedWepHashes = {}
local WhitelistedVehHashes = {}

local WeaponGroups = {
    [GetHashKey("WEAPON_SNIPERRIFLE")] = 'sniper', [GetHashKey("WEAPON_HEAVYSNIPER")] = 'sniper',
    [GetHashKey("WEAPON_HEAVYSNIPER_MK2")] = 'sniper', [GetHashKey("WEAPON_MARKSMANRIFLE")] = 'sniper',
    [GetHashKey("WEAPON_PUMPSHOTGUN")] = 'shotgun', [GetHashKey("WEAPON_SAWNOFFSHOTGUN")] = 'shotgun',
    [GetHashKey("WEAPON_MICROSMG")] = 'smg', [GetHashKey("WEAPON_SMG")] = 'smg'
}

-- INICIALIZACIÓN
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    local oneSync = GetConvar("onesync", "off")
    if oneSync == "off" then print("^1[Jeler AC] ^7ERROR: OneSync requerido.") return end

    for _, v in pairs(Config.BlacklistedVehicles) do BlacklistedVehHashes[GetHashKey(v)] = true end
    for _, w in pairs(Config.BlacklistedWeapons) do BlacklistedWepHashes[GetHashKey(w)] = true end
    if Config.WhitelistedVehicles then
        for _, v in pairs(Config.WhitelistedVehicles) do WhitelistedVehHashes[GetHashKey(v)] = true end
    end
    print("^2[Jeler AC] ^7v9.0.0 Server System Iniciado (ANTI-CRASH ACTIVO - MODO VISUAL).")
end)

-- TOKEN GENERATOR
local function GenerateSecureToken(src, nonce)
    local time = os.time()
    local clock = os.clock() * 1000 
    local salt = math.random(100000, 999999)
    local rawString = string.format("%s:%s:%s:%s:%s", src, time, clock, nonce, salt)
    local hash = ""
    for i = 1, #rawString do
        local byte = string.byte(rawString, i)
        hash = hash .. string.format("%02x", byte ~ 0xAB)
    end
    return hash
end

-- VALIDATOR (MODIFICADO: NO KICKEA SI FALLA)
local function ValidateToken(src, receivedToken, receivedSeq)
    local data = PlayerSecurity[src]
    if not data then 
        print("^3[Jeler AC] Advertencia: ID "..src.." sin sesión (No kickeado por Test Mode)") 
        return false 
    end
    if data.token ~= receivedToken then 
        print("^3[Jeler AC] Advertencia: ID "..src.." token inválido (No kickeado por Test Mode)") 
        return false 
    end
    if receivedSeq then
        if receivedSeq <= data.sequence then return false end
        data.sequence = receivedSeq
    end
    return true
end

-- ROTATION THREAD
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.TokenRotationInterval * 1000)
        local nonce = math.random(1, 10000)
        for _, playerId in ipairs(GetPlayers()) do
            if PlayerSecurity[playerId] then
                local newToken = GenerateSecureToken(playerId, nonce)
                PlayerSecurity[playerId].token = newToken
                PlayerSecurity[playerId].sequence = 0 
                TriggerClientEvent('jeler:updateToken', playerId, newToken)
            end
        end
    end
end)

-- REQUEST TOKEN
RegisterNetEvent('jeler:requestToken')
AddEventHandler('jeler:requestToken', function()
    local src = source
    if not PlayerSecurity[src] then
        local nonce = 0
        local token = GenerateSecureToken(src, nonce)
        PlayerSecurity[src] = { token = token, sequence = 0 }
        TriggerClientEvent('jeler:setToken', src, token)
        LastHeartbeat[src] = os.time()
    end
end)

-- ADD SUSPICION (MODIFICADO: MUESTRA PANTALLA EN VEZ DE BANEAR)
function AddSuspicion(source, points, reason)
    if not PlayerSuspicion[source] then PlayerSuspicion[source] = 0.0 end
    PlayerSuspicion[source] = PlayerSuspicion[source] + points
    
    if Config.DebugMode then
        print(string.format("^3[ANALYSIS] ^7ID:%s | +%.1f pts | Total: %.1f/%d | Razón: %s", source, points, PlayerSuspicion[source], Config.BanThreshold, reason))
    end

    if PlayerSuspicion[source] >= Config.BanThreshold then
        print("^2[TEST MODE] ^7Detección VALIDADA en ID "..source.." ("..reason.."). Enviando UI...")
        
        -- ENVÍO DE PANTALLA (SIN BAN)
        TriggerClientEvent('jeler:mostrarPantalla', source, reason) 
        
        -- Reseteamos sospecha para que puedas seguir probando sin reiniciar
        PlayerSuspicion[source] = 0 
    end
end

-- PROTECCIONES BÁSICAS (HONEYPOTS)
local HoneyPotEvents = { "esx:giveInventoryItem", "admin:reviveAll", "bank:transfer", "vrp:addMoney", "anticheat:bypass" }
for _, eventName in pairs(HoneyPotEvents) do
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, function() 
        print("^3[HoneyPot] ^7Evento prohibido detectado en ID "..source)
        AddSuspicion(source, 100, "HoneyPot Triggered: "..eventName)
    end)
end

-- =====================================================
-- [NUEVO] SISTEMA ANTI-CRASH (ENTITY SPAM REWORK)
-- =====================================================
local SpamCheck = {}
-- Límites internos (Tolerancia alta para evitar falsos positivos por ahora)
local MaxVehiclesPerSec = 15
local MaxPedsPerSec = 15
local MaxObjectsPerSec = 20  -- Props (Objetivo principal de crashers)

AddEventHandler('entityCreating', function(entity)
    if not isAuthenticated then return end
    local src = NetworkGetEntityOwner(entity)
    
    -- Si no tiene dueño (es del mapa o población), lo ignoramos
    if not src then return end
    
    -- Inicializar tabla del jugador si no existe
    if not SpamCheck[src] then 
        SpamCheck[src] = { veh = 0, ped = 0, obj = 0, time = os.time() } 
    end

    -- Resetear contadores cada segundo
    if os.time() > SpamCheck[src].time then
        SpamCheck[src] = { veh = 0, ped = 0, obj = 0, time = os.time() }
    end

    local type = GetEntityType(entity) -- 1: Ped, 2: Veh, 3: Obj
    local count = SpamCheck[src]
    local limit = 20
    local label = "Entity Spam"

    -- Clasificar y contar
    if type == 1 then 
        count.ped = count.ped + 1
        limit = MaxPedsPerSec
        label = "Ped Spam (Crash Attempt)"
    elseif type == 2 then 
        count.veh = count.veh + 1
        limit = MaxVehiclesPerSec
        label = "Vehicle Spam (Crash Attempt)"
    elseif type == 3 then 
        count.obj = count.obj + 1
        limit = MaxObjectsPerSec
        label = "Object/Prop Spam (Crash Attempt)"
    end

    -- VERIFICAR SI SE PASÓ DEL LÍMITE
    if (type == 1 and count.ped > limit) or (type == 2 and count.veh > limit) or (type == 3 and count.obj > limit) then
        
        -- 1. CANCELAR EL SPAWN (Lo más importante, evita el crash)
        CancelEvent()
        
        -- 2. ALERTAR Y MOSTRAR PANTALLA (Con un pequeño margen extra)
        if (type == 1 and count.ped > (limit + 5)) or 
           (type == 2 and count.veh > (limit + 5)) or 
           (type == 3 and count.obj > (limit + 10)) then
            
            print("^1[ANTI-CRASH] ^7Bloqueado spawn masivo de ID: " .. src .. " ("..label..")")
            TriggerClientEvent('jeler:mostrarPantalla', src, label)
        end
        return -- Salimos para no procesar el resto
    end
    
    -- VALIDAR MODELOS PROHIBIDOS (Props glitcheados)
    local model = GetEntityModel(entity)
    for _, blockedModel in ipairs(Config.BlacklistedEntities) do
        if model == GetHashKey(blockedModel) then 
            CancelEvent()
            TriggerClientEvent('jeler:mostrarPantalla', src, "Blacklisted Prop Detected")
            break 
        end
    end
end)

-- Limpieza periódica de tablas de spam para ahorrar memoria
Citizen.CreateThread(function() 
    while true do 
        Citizen.Wait(60000) 
        SpamCheck = {} 
    end 
end)

-- =====================================================
-- [NUEVO] ANTI-EXPLOSION SPAM
-- =====================================================
local ExplosionRates = {}
local MaxExplosionsPerSec = 5

AddEventHandler('explosionEvent', function(sender, ev)
    if not sender then CancelEvent(); return end
    
    -- 1. CHECK DE TIPOS PROHIBIDOS
    for _, type in ipairs(Config.BlacklistedExplosions) do
        if ev.explosionType == type then 
            CancelEvent() 
            print("^1[ANTI-CRASH] ^7Explosión prohibida bloqueada de ID: " .. sender)
            AddSuspicion(sender, 100, "Illegal Explosion Type: "..type)
            return 
        end
    end

    -- 2. RATE LIMIT (Evitar ametralladora de explosiones)
    if not ExplosionRates[sender] then ExplosionRates[sender] = { count = 0, time = os.time() } end
    
    if os.time() > ExplosionRates[sender].time then
        ExplosionRates[sender] = { count = 0, time = os.time() }
    end
    
    ExplosionRates[sender].count = ExplosionRates[sender].count + 1
    
    if ExplosionRates[sender].count > MaxExplosionsPerSec then
        CancelEvent() -- Anula el daño y efecto visual
        if ExplosionRates[sender].count > (MaxExplosionsPerSec + 2) then
             print("^1[ANTI-CRASH] ^7Spam de explosiones bloqueado de ID: " .. sender)
             TriggerClientEvent('jeler:mostrarPantalla', sender, "Explosion Spam Detected")
        end
    end
end)

AddEventHandler('executeCommand', function(commandSource, command)
    if not commandSource or commandSource == 0 then return end
    local cmd = string.lower(command)
    for _, blockedCmd in ipairs(Config.BlacklistedCommands) do
        if string.find(cmd, blockedCmd) then
            -- if IsPlayerAceAllowed(commandSource, "jeler.bypass") then return end -- <-- COMENTADO BYPASS DE ADMIN
            CancelEvent()
            AddSuspicion(commandSource, 100, "Illegal Command Injection")
            return
        end
    end
end)

-- =============================================================================
-- HEURÍSTICA DE COMBATE AVANZADA (V7)
-- =============================================================================
AddEventHandler('weaponDamageEvent', function(sender, data)
    if not isAuthenticated then return end
    local victimId = data.hitGlobalId
    local victimPed = GetPlayerPed(victimId)
    local shooter = GetPlayerPed(sender)
    
    if not DoesEntityExist(victimPed) or not IsPedAPlayer(victimPed) then return end
    if data.weaponDamage <= 0 then return end

    -- [1] DAMAGE DESYNC CHECK
    local serverCoords = GetEntityCoords(shooter)
    local clientReportedCoords = PlayerPositions[sender] or serverCoords 
    local desyncDist = #(serverCoords - clientReportedCoords)
    
    if desyncDist > Config.MaxDesyncDistance then
        if not IsPedInAnyVehicle(shooter, false) then
             AddSuspicion(sender, 40, "Damage Desync (Dist: "..math.floor(desyncDist).."m)")
        end
    end

    -- [2] SNAP DETECTION
    local currentRot = GetEntityRotation(shooter, 2)
    if PlayerRotations[sender] then
        local prevRot = PlayerRotations[sender]
        local deltaYaw = math.abs(currentRot.z - prevRot.z)
        if deltaYaw > 180 then deltaYaw = 360 - deltaYaw end
        
        if deltaYaw > Config.MaxRotationSpeed then
            AddSuspicion(sender, 35, "Snap Aim (Flick: "..math.floor(deltaYaw).."°)")
        end
    end
    PlayerRotations[sender] = currentRot

    -- [3] CHEQUEOS EXISTENTES
    local damageLimit = 250
    local weaponHash = GetSelectedPedWeapon(shooter)
    local wClass = WeaponGroups[weaponHash] or 'default'
    if wClass == 'sniper' then damageLimit = 400 end
    if data.weaponDamage > damageLimit then AddSuspicion(sender, 100, "Extreme Damage") return end

    local healthBefore = GetEntityHealth(victimPed)
    local armorBefore = GetPedArmour(victimPed)
    SetTimeout(150, function()
        if not DoesEntityExist(victimPed) then return end
        if healthBefore == GetEntityHealth(victimPed) and armorBefore == GetPedArmour(victimPed) then
             -- if not IsEntityDead(victimPed) then -- <-- BYPASS COMENTADO PARA TEST
             if not IsEntityDead(victimPed) then 
                if not GodmodeStrikes[victimId] then GodmodeStrikes[victimId] = 0 end
                GodmodeStrikes[victimId] = GodmodeStrikes[victimId] + 1
                if GodmodeStrikes[victimId] >= Config.GodmodeStrikes then AddSuspicion(victimId, 100, "Godmode") end
             end
        else
            if GodmodeStrikes[victimId] and GodmodeStrikes[victimId] > 0 then GodmodeStrikes[victimId] = GodmodeStrikes[victimId] - 1 end
        end
    end)
    
    -- Silent Aim Math
    local wConfig = Config.WeaponClasses[wClass]
    local ping = GetPlayerPing(sender)
    local tolerance = wConfig.tolerance
    local hitRadius = Config.MaxHitboxRadius
    if IsPedInCover(shooter, 0) then tolerance = 50.0; hitRadius = hitRadius + 0.5 end
    if GetEntitySpeed(shooter) > 2.5 then tolerance = tolerance * 2.0 end
    if ping > Config.PingAssist then tolerance = tolerance * 1.5 end

    local headPos = MathUtils.GetHeadCoords(shooter)
    local hitPos = GetEntityCoords(victimPed)
    if data.hitComponent == 31086 then local s, h = pcall(GetPedBoneCoords, victimPed, 31086, 0.0, 0.0, 0.0); if s then hitPos = h end end
    if #(hitPos - headPos) < 3.0 then return end 

    local bulletVec = MathUtils.NormalizeVector(hitPos - headPos)
    local camDir = MathUtils.RotationToDirection(GetEntityRotation(shooter, 2))
    local missDist = MathUtils.DistanceFromLineToPoint(headPos, camDir, hitPos)
    if missDist > hitRadius then AddSuspicion(sender, Config.MagicBulletSeverity, "Magic Bullet") return end

    local angle = MathUtils.CalculateAngle(bulletVec, camDir)
    if angle > tolerance then
        local excess = angle - tolerance
        AddSuspicion(sender, wConfig.severity + (excess * 2), "Silent Aim")
    else
        RewardLegitShot(sender)
        if not PlayerStats[sender] then PlayerStats[sender] = { shots = 0, angles = {}, bones = {} } end
        local st = PlayerStats[sender]
        st.shots = st.shots + 1
        table.insert(st.angles, angle)
        table.insert(st.bones, data.hitComponent)
        if st.shots >= Config.AnalysisWindow then
            AnalyzeHeuristics(sender, st)
            PlayerStats[sender] = { shots = 0, angles = {}, bones = {} } 
        end
    end
end)

-- LOOP SEGURIDAD
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.NoclipCheckInterval)
        if isAuthenticated then
            for _, playerId in ipairs(GetPlayers()) do
                local ped = GetPlayerPed(playerId)
                -- if DoesEntityExist(ped) and not IsPlayerAceAllowed(playerId, "jeler.bypass") then <-- BYPASS COMENTADO
                if DoesEntityExist(ped) then 
                    local pos = GetEntityCoords(ped)
                    PlayerPositions[playerId] = pos -- Guardar posición para Desync Check

                    local vehicle = GetVehiclePedIsIn(ped, false)
                    local isInVehicle = (vehicle ~= 0)
                    local model = 0
                    if isInVehicle then
                        model = GetEntityModel(vehicle)
                        if BlacklistedVehHashes[model] then
                            -- if Config.BlacklistAction == "ban" then AddSuspicion(playerId, 100, "Vehículo Prohibido")
                            -- elseif Config.BlacklistAction == "delete" then DeleteEntity(vehicle) end
                            DeleteEntity(vehicle)
                            TriggerClientEvent('jeler:mostrarPantalla', playerId, "Vehículo Prohibido")
                        end
                    end
                    local weaponHash = GetSelectedPedWeapon(ped)
                    if weaponHash ~= -1569615261 and BlacklistedWepHashes[weaponHash] then
                        -- if Config.BlacklistAction == "ban" then AddSuspicion(playerId, 100, "Arma Prohibida")
                        -- elseif Config.BlacklistAction == "delete" then RemoveWeaponFromPed(ped, weaponHash) end
                        RemoveWeaponFromPed(ped, weaponHash)
                        TriggerClientEvent('jeler:mostrarPantalla', playerId, "Arma Prohibida")
                    end
                end
            end
        end
    end
end)

-- WATCHDOG (MODIFICADO: NO KICKEA)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000)
        local now = os.time()
        for _, playerId in ipairs(GetPlayers()) do
            if LastHeartbeat[playerId] then
                if (now - LastHeartbeat[playerId]) > Config.HeartbeatTimeout then
                    -- DropPlayer(playerId, "🛡️ Jeler AC: Security Resource Stopped") <-- DESACTIVADO
                    print("^3[WATCHDOG] ^7ID "..playerId.." timeout (Ignorado por Modo Prueba).")
                end
            end
        end
    end
end)

AddEventHandler('onResourceStart', function(res) if GetCurrentResourceName() == res then isAuthenticated = true end end)
AddEventHandler('playerDropped', function() LastHeartbeat[source] = nil; PlayerSecurity[source] = nil; PlayerRotations[source] = nil end)

function RewardLegitShot(source)
    if PlayerSuspicion[source] and PlayerSuspicion[source] > 0 then PlayerSuspicion[source] = math.max(0, PlayerSuspicion[source] - Config.LegitReward) end
end

function AnalyzeHeuristics(source, stats)
    local uniqueBones = {}
    for _, b in pairs(stats.bones) do uniqueBones[b] = true end
    local count = 0
    for _ in pairs(uniqueBones) do count = count + 1 end
    if count < Config.MinBoneVariety then AddSuspicion(source, 35, "Bone Locking (Aimbot)") end
    
    local variance = MathUtils.StandardDeviation(stats.angles)
    local avgAngle = MathUtils.Average(stats.angles)
    if avgAngle < 1.5 and variance < 0.1 then AddSuspicion(source, 60, "Triggerbot (Zero Variance)") end
end

RegisterNetEvent('jeler:flag')
AddEventHandler('jeler:flag', function(token, reason)
    local src = source
    if not ValidateToken(src, token) then return end
    AddSuspicion(src, 100, "Client Flag: " .. reason)
end)

-- [4] RESOURCE INJECTION CHECK
RegisterNetEvent('jeler:heartbeat')
AddEventHandler('jeler:heartbeat', function(token, seq, clientResCount)
    local src = source
    if not ValidateToken(src, token, seq) then return end
    LastHeartbeat[src] = os.time()
    
    local serverResCount = GetNumResources()
    if clientResCount and (clientResCount > serverResCount + 2) then
        AddSuspicion(src, 100, "Resource Injection (Lua Executor Detected)")
    end
end)